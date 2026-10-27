import os
import logging
from sqlalchemy import create_engine, text
from sqlalchemy.orm import declarative_base, sessionmaker
from app.core.config import settings

logger = logging.getLogger(__name__)

# Cấu hình engine dựa trên loại DB (SQLite vs PostgreSQL)
connect_args = {}
db_url = settings.DATABASE_URL

if db_url.startswith("sqlite"):
    connect_args = {"check_same_thread": False}
    # Đảm bảo file SQLite luôn nằm cố định tại thư mục backend
    if ":///" in db_url:
        path_part = db_url.split(":///", 1)[1]
        if path_part.startswith("./"):
            backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
            abs_db = os.path.join(backend_dir, path_part.replace("./", ""))
            db_url = f"sqlite:///{abs_db.replace(os.sep, '/')}"

try:
    engine = create_engine(
        db_url,
        connect_args=connect_args,
        pool_pre_ping=True,
    )
except Exception as e:
    logger.warning(f"Không thể khởi tạo engine với DATABASE_URL={db_url}: {e}")
    backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    abs_db = os.path.join(backend_dir, "ielts_vision_backend.db")
    engine = create_engine(
        f"sqlite:///{abs_db.replace(os.sep, '/')}",
        connect_args={"check_same_thread": False},
        pool_pre_ping=True,
    )

# Tự động đảm bảo các cột cần thiết cho Gamification tồn tại
with engine.connect() as conn:
    try:
        conn.execute(text("ALTER TABLE user_stage_progress ADD COLUMN skill_type VARCHAR(20) DEFAULT 'listening' NOT NULL;"))
        conn.commit()
    except Exception:
        pass
    try:
        conn.execute(text("CREATE INDEX IF NOT EXISTS ix_user_stage_progress_skill_type ON user_stage_progress (skill_type);"))
        conn.commit()
    except Exception:
        pass
    try:
        conn.execute(text("ALTER TABLE skill_lessons ADD COLUMN target_band FLOAT;"))
        conn.commit()
    except Exception:
        pass
    try:
        conn.execute(text("ALTER TABLE skill_lessons ADD COLUMN pass_condition JSON;"))
        conn.commit()
    except Exception:
        pass
    try:
        # Tự động đảm bảo các cột FaceID cho users và profiles
        if engine.dialect.name == "postgresql":
            conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS face_embedding JSONB;"))
            conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS is_face_auth_enabled BOOLEAN DEFAULT FALSE;"))
            conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS face_registered_at TIMESTAMPTZ;"))
            conn.execute(text("ALTER TABLE profiles ADD COLUMN IF NOT EXISTS face_embedding JSONB;"))
            conn.execute(text("ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_face_auth_enabled BOOLEAN DEFAULT FALSE;"))
            conn.execute(text("ALTER TABLE profiles ADD COLUMN IF NOT EXISTS face_registered_at TIMESTAMPTZ;"))
        else:
            conn.execute(text("ALTER TABLE users ADD COLUMN face_embedding TEXT;"))
            conn.execute(text("ALTER TABLE users ADD COLUMN is_face_auth_enabled BOOLEAN DEFAULT 0;"))
            conn.execute(text("ALTER TABLE users ADD COLUMN face_registered_at DATETIME;"))
        conn.commit()
    except Exception:
        pass

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    """Dependency cung cấp session database cho các endpoint FastAPI."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
