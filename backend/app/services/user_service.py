import logging
from typing import Optional, List
from sqlalchemy.orm import Session
from app.models.user import User
from app.schemas.user import UserCreate
from app.core.security import get_password_hash, verify_password
from app.core.supabase import get_supabase_admin

logger = logging.getLogger(__name__)


def get_user_by_username(db: Session, username: str) -> Optional[User]:
    """Tìm user theo username (không phân biệt hoa thường)."""
    return db.query(User).filter(User.username == username.strip().lower()).first()


def get_user_by_id(db: Session, user_id: int) -> Optional[User]:
    """Tìm user theo ID."""
    return db.query(User).filter(User.id == user_id).first()


def authenticate_user(db: Session, username: str, password: str) -> Optional[User]:
    """Xác thực tài khoản và mật khẩu."""
    user = get_user_by_username(db, username)
    if not user:
        return None
    if not verify_password(password, user.hashed_password):
        return None
    return user


def sync_user_to_supabase(username: str, role: str) -> Optional[str]:
    """Đồng bộ tài khoản người dùng sang bảng profiles trên Supabase."""
    try:
        admin_client = get_supabase_admin()
        res = admin_client.from_("profiles").upsert({
            "username": username,
            "role": role,
        }, on_conflict="username").select("id").execute()
        if res.data and len(res.data) > 0:
            return res.data[0].get("id")
    except Exception as e:
        logger.warning(f"Không thể đồng bộ profile sang Supabase cho user '{username}': {e}")
    return None


def create_user(db: Session, user_in: UserCreate, sync_supabase: bool = True) -> User:
    """Tạo mới một người dùng và lưu vào database."""
    normalized_username = user_in.username.strip().lower()
    
    # Kiểm tra tồn tại
    existing = get_user_by_username(db, normalized_username)
    if existing:
        raise ValueError("Tên đăng nhập đã tồn tại trong hệ thống")

    supabase_uuid = None
    if sync_supabase:
        supabase_uuid = sync_user_to_supabase(normalized_username, user_in.role)

    db_user = User(
        username=normalized_username,
        hashed_password=get_password_hash(user_in.password),
        role=user_in.role,
        supabase_uuid=supabase_uuid,
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    logger.info(f"Đã tạo user mới: {db_user.username} ({db_user.role})")
    return db_user


def get_all_users(db: Session) -> List[User]:
    """Lấy danh sách tất cả người dùng."""
    return db.query(User).order_by(User.id.asc()).all()


def delete_user(db: Session, user_id: int, current_user: User) -> bool:
    """Xóa người dùng (Admin only)."""
    user = get_user_by_id(db, user_id)
    if not user:
        raise ValueError("Không tìm thấy người dùng cần xóa")
    
    if user.id == current_user.id:
        raise ValueError("Không thể tự xóa tài khoản của chính mình")
    
    if user.username == "admin":
        raise ValueError("Không thể xóa tài khoản Quản trị viên mặc định (admin)")

    db.delete(user)
    db.commit()
    logger.info(f"Đã xóa user ID {user_id} ({user.username})")
    return True


def seed_default_users(db: Session):
    """Khởi tạo tài khoản mặc định (admin/password123, learner/password123) và đồng bộ từ Supabase."""
    default_accounts = [
        {"username": "admin", "password": "password123", "role": "admin"},
        {"username": "learner", "password": "password123", "role": "learner"},
    ]

    for acc in default_accounts:
        user = get_user_by_username(db, acc["username"])
        if not user:
            try:
                create_user(
                    db,
                    UserCreate(
                        username=acc["username"],
                        password=acc["password"],
                        role=acc["role"],
                    ),
                    sync_supabase=True,
                )
                logger.info(f"Đã seed tài khoản mặc định: {acc['username']}")
            except Exception as e:
                logger.warning(f"Lỗi khi seed tài khoản {acc['username']}: {e}")

    # Đọc thêm các tài khoản đã có trên Supabase profiles nếu có
    try:
        admin_client = get_supabase_admin()
        profiles_res = admin_client.from_("profiles").select("*").execute()
        if profiles_res.data:
            for p in profiles_res.data:
                uname = p.get("username")
                if uname and not get_user_by_username(db, uname):
                    new_u = User(
                        username=uname.strip().lower(),
                        hashed_password=get_password_hash("password123"),
                        role=p.get("role", "learner"),
                        supabase_uuid=p.get("id"),
                    )
                    db.add(new_u)
            db.commit()
    except Exception as e:
        logger.warning(f"Không thể sync profiles từ Supabase: {e}")
