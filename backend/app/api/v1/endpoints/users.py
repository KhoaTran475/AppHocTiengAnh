from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.schemas.user import UserCreate, UserResponse
from app.services.user_service import get_all_users, create_user, delete_user
from app.core.deps import get_current_admin
from app.models.user import User

router = APIRouter()


@router.get("/", response_model=List[UserResponse], summary="Lấy danh sách người dùng (Admin only)")
def list_users(
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Lấy danh sách tất cả người dùng trong hệ thống (chỉ dành cho Quản trị viên)."""
    users = get_all_users(db)
    return [UserResponse.model_validate(u) for u in users]


@router.post("/", response_model=UserResponse, status_code=status.HTTP_201_CREATED, summary="Tạo người dùng mới (Admin only)")
def admin_create_user(
    user_in: UserCreate,
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Quản trị viên tạo tài khoản mới với vai trò tùy chọn (learner hoặc admin)."""
    try:
        user = create_user(db, user_in, sync_supabase=True)
        return UserResponse.model_validate(user)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.delete("/{user_id}", summary="Xóa người dùng (Admin only)")
def admin_delete_user(
    user_id: int,
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Xóa một tài khoản theo ID (không được xóa chính mình hoặc admin mặc định)."""
    try:
        delete_user(db, user_id, current_admin)
        return {"success": True, "message": f"Đã xóa thành công người dùng ID {user_id}"}
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
