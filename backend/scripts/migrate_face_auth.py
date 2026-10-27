import sys
import os
import logging
from sqlalchemy import text, inspect

# Thêm đường dẫn backend vào sys.path
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from app.db.session import engine

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger("migrate_face_auth")


def migrate_face_auth():
    """Tự động kiểm tra và thêm các cột FaceID cho cả bảng users và profiles."""
    logger.info("Bắt đầu kiểm tra và cập nhật cấu trúc Database cho FaceID...")
    
    is_postgres = engine.dialect.name == "postgresql"
    json_type = "JSONB" if is_postgres else "TEXT"
    bool_type = "BOOLEAN DEFAULT FALSE NOT NULL" if is_postgres else "BOOLEAN DEFAULT 0 NOT NULL"
    datetime_type = "TIMESTAMPTZ" if is_postgres else "DATETIME"

    insp = inspect(engine)
    table_names = insp.get_table_names()

    with engine.connect() as conn:
        # 1. Cập nhật bảng 'users'
        if "users" in table_names:
            user_cols = {c["name"] for c in insp.get_columns("users")}
            
            if "face_embedding" not in user_cols:
                logger.info(f"Thêm cột 'face_embedding' ({json_type}) vào bảng 'users'...")
                conn.execute(text(f"ALTER TABLE users ADD COLUMN face_embedding {json_type};"))
            else:
                logger.info("Cột 'face_embedding' đã tồn tại trong 'users'.")

            if "is_face_auth_enabled" not in user_cols:
                logger.info("Thêm cột 'is_face_auth_enabled' vào bảng 'users'...")
                conn.execute(text(f"ALTER TABLE users ADD COLUMN is_face_auth_enabled {bool_type};"))
            else:
                logger.info("Cột 'is_face_auth_enabled' đã tồn tại trong 'users'.")

            if "face_registered_at" not in user_cols:
                logger.info("Thêm cột 'face_registered_at' vào bảng 'users'...")
                conn.execute(text(f"ALTER TABLE users ADD COLUMN face_registered_at {datetime_type};"))
            else:
                logger.info("Cột 'face_registered_at' đã tồn tại trong 'users'.")

            try:
                conn.execute(text("CREATE INDEX IF NOT EXISTS ix_users_face_auth ON users (is_face_auth_enabled);"))
            except Exception as e:
                logger.warning(f"Không thể tạo index ix_users_face_auth: {e}")

            conn.commit()
            logger.info("Đã cập nhật bảng 'users' thành công!")

        # 2. Cập nhật bảng 'profiles' (Supabase synchronized profiles)
        if "profiles" in table_names:
            profile_cols = {c["name"] for c in insp.get_columns("profiles")}
            
            if "face_embedding" not in profile_cols:
                logger.info(f"Thêm cột 'face_embedding' ({json_type}) vào bảng 'profiles'...")
                conn.execute(text(f"ALTER TABLE profiles ADD COLUMN face_embedding {json_type};"))
            else:
                logger.info("Cột 'face_embedding' đã tồn tại trong 'profiles'.")

            if "is_face_auth_enabled" not in profile_cols:
                logger.info("Thêm cột 'is_face_auth_enabled' vào bảng 'profiles'...")
                conn.execute(text(f"ALTER TABLE profiles ADD COLUMN is_face_auth_enabled {bool_type};"))
            else:
                logger.info("Cột 'is_face_auth_enabled' đã tồn tại trong 'profiles'.")

            if "face_registered_at" not in profile_cols:
                logger.info("Thêm cột 'face_registered_at' vào bảng 'profiles'...")
                conn.execute(text(f"ALTER TABLE profiles ADD COLUMN face_registered_at {datetime_type};"))
            else:
                logger.info("Cột 'face_registered_at' đã tồn tại trong 'profiles'.")

            conn.commit()
            logger.info("Đã cập nhật bảng 'profiles' thành công!")

    logger.info("Quá trình di chuyển Database FaceID hoàn tất 100%!")


if __name__ == "__main__":
    migrate_face_auth()
