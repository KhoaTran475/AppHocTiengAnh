from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.schemas.vocabulary import (
    ObjectMappingResponse,
    ObjectMappingCreate,
    ObjectMappingUpdate,
    DictionaryLookupResponse,
)
from app.services.mapping_service import (
    get_all_mappings,
    get_mapping_by_label,
    get_mapping_by_id,
    create_mapping,
    update_mapping,
    delete_mapping,
    reset_mappings_to_default,
)
from app.services.dictionary_service import lookup_word
from app.core.deps import get_current_admin
from app.models.user import User

router = APIRouter()


@router.get("/mappings", response_model=List[ObjectMappingResponse], summary="Lấy danh sách kho từ vựng 82 nhãn IELTS")
def list_mappings(
    search: Optional[str] = Query(None, description="Từ khóa tìm kiếm theo label, từ vựng hoặc nghĩa"),
    band: Optional[str] = Query(None, description="Lọc theo Band điểm (vd: Band 7.0, Band 8.0)"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
    db: Session = Depends(get_db),
):
    """Lấy danh sách các nhãn từ vựng IELTS, hỗ trợ tìm kiếm và lọc band."""
    return get_all_mappings(db, search=search, band=band, skip=skip, limit=limit)


@router.get("/mappings/{label}", response_model=ObjectMappingResponse, summary="Tra cứu từ vựng theo nhãn YOLO")
def get_mapping(label: str, db: Session = Depends(get_db)):
    """Lấy thông tin chi tiết từ vựng IELTS tương ứng với nhãn nhận diện AI (vd: 'person')."""
    mapping = get_mapping_by_label(db, label)
    if not mapping:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Không tìm thấy dữ liệu từ vựng cho nhãn '{label}'",
        )
    return mapping


@router.post("/mappings", response_model=ObjectMappingResponse, status_code=status.HTTP_201_CREATED, summary="Thêm nhãn từ vựng mới (Admin only)")
def add_new_mapping(
    mapping_in: ObjectMappingCreate,
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Quản trị viên thêm một nhãn từ vựng mới vào kho từ điển AI."""
    try:
        return create_mapping(db, mapping_in, sync_supabase=True)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.put("/mappings/{mapping_id}", response_model=ObjectMappingResponse, summary="Cập nhật thông tin từ vựng (Admin only)")
def edit_mapping(
    mapping_id: int,
    mapping_in: ObjectMappingUpdate,
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Quản trị viên cập nhật từ vựng, collocations, ví dụ speaking..."""
    try:
        return update_mapping(db, mapping_id, mapping_in, sync_supabase=True)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.delete("/mappings/{mapping_id}", summary="Xóa nhãn từ vựng (Admin only)")
def remove_mapping(
    mapping_id: int,
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Quản trị viên xóa một nhãn từ vựng khỏi kho từ điển."""
    try:
        delete_mapping(db, mapping_id, sync_supabase=True)
        return {"success": True, "message": f"Đã xóa thành công từ vựng ID {mapping_id}"}
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/mappings/reset", summary="Khôi phục 82 nhãn mặc định từ JSON (Admin only)")
def reset_mappings(
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Quản trị viên khôi phục toàn bộ kho dữ liệu từ vựng gốc chuẩn học thuật."""
    reset_mappings_to_default(db)
    return {"success": True, "message": "Đã khôi phục thành công 82 nhãn từ vựng IELTS mặc định"}


@router.get("/lookup", response_model=DictionaryLookupResponse, summary="Tra cứu từ vựng tại chỗ (Tap-to-Translate)")
def dictionary_lookup(
    word: str = Query(..., min_length=1, description="Từ tiếng Anh cần tra cứu"),
    db: Session = Depends(get_db),
):
    """Tra từ nhanh phục vụ tính năng chạm vào từ trong bài đọc để xem IPA và nghĩa tiếng Việt."""
    result = lookup_word(db, word)
    if not result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Chưa có dữ liệu tra cứu cho từ '{word}'",
        )
    return result
