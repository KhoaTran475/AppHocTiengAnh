from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.schemas.user import UserCreate, UserLogin, UserResponse, Token
from app.services.user_service import authenticate_user, create_user
from app.core.security import create_access_token
from app.core.deps import get_current_user
from app.models.user import User

router = APIRouter()


@router.post("/login", response_model=Token, summary="Đăng nhập tài khoản")
def login(login_data: UserLogin, db: Session = Depends(get_db)):
    """Đăng nhập bằng username và password. Trả về Bearer JWT Access Token."""
    user = authenticate_user(db, login_data.username, login_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Tên đăng nhập hoặc mật khẩu không chính xác",
        )
    
    access_token = create_access_token(subject=user.username, role=user.role)
    return Token(
        access_token=access_token,
        token_type="bearer",
        user=UserResponse.model_validate(user),
    )


@router.post("/register", response_model=Token, status_code=status.HTTP_201_CREATED, summary="Đăng ký tài khoản học viên")
def register(user_in: UserCreate, db: Session = Depends(get_db)):
    """Đăng ký tài khoản mới (mặc định role 'learner'). Mã hóa mật khẩu và đồng bộ lên Supabase."""
    try:
        new_user = create_user(db, user_in, sync_supabase=True)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    
    access_token = create_access_token(subject=new_user.username, role=new_user.role)
    return Token(
        access_token=access_token,
        token_type="bearer",
        user=UserResponse.model_validate(new_user),
    )


@router.get("/me", response_model=UserResponse, summary="Lấy thông tin tài khoản hiện tại")
def get_current_user_profile(current_user: User = Depends(get_current_user)):
    """Trả về thông tin hồ sơ của người dùng đang đăng nhập qua Bearer Token."""
    return UserResponse.model_validate(current_user)
