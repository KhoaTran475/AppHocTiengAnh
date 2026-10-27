from typing import List
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.schemas.notebook import NotebookItemCreate, NotebookItemResponse
from app.services.notebook_service import (
    get_user_notebook,
    add_to_notebook,
    delete_from_notebook,
    is_word_saved,
)
from app.core.deps import get_current_user
from app.models.user import User

router = APIRouter()


@router.get("/", response_model=List[NotebookItemResponse], summary="Lấy danh sách sổ tay của học viên hiện tại")
def list_notebook_items(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Lấy toàn bộ danh sách từ vựng đã lưu trong sổ tay của tài khoản đang đăng nhập."""
    items = get_user_notebook(db, current_user)
    return [NotebookItemResponse.model_validate(i) for i in items]


@router.post("/", response_model=NotebookItemResponse, status_code=status.HTTP_201_CREATED, summary="Lưu từ vào sổ tay")
def save_word_to_notebook(
    item_in: NotebookItemCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Lưu từ vựng mới vào sổ tay học tập của học viên và tự động đồng bộ lên Supabase."""
    item = add_to_notebook(db, current_user, item_in, sync_supabase=True)
    return NotebookItemResponse.model_validate(item)


@router.delete("/{item_id}", summary="Xóa từ khỏi sổ tay")
def remove_from_notebook(
    item_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Xóa một từ khỏi sổ tay theo ID."""
    try:
        delete_from_notebook(db, current_user, item_id, sync_supabase=True)
        return {"success": True, "message": f"Đã xóa thành công từ ID {item_id} khỏi sổ tay"}
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))


@router.get("/check", summary="Kiểm tra từ đã lưu vào sổ tay chưa")
def check_word_saved(
    label: str = Query(..., description="Nhãn từ vựng cần kiểm tra"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Kiểm tra xem nhãn này học viên đã lưu vào sổ tay chưa."""
    saved = is_word_saved(db, current_user, label)
    return {"saved": saved, "label": label}

