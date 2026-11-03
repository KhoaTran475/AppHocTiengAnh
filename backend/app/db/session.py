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

def init_engine():
    global db_url, connect_args
    try:
        eng = create_engine(db_url, connect_args=connect_args, pool_pre_ping=True)
        with eng.connect() as test_conn:
            test_conn.execute(text("SELECT 1"))
        return eng
    except Exception as e:
        logger.warning(f"Không thể kết nối tới {db_url}: {e}. Tự động fallback sang SQLite...")
        backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        abs_db = os.path.join(backend_dir, "ielts_vision_backend.db")
        return create_engine(
            f"sqlite:///{abs_db.replace(os.sep, '/')}",
            connect_args={"check_same_thread": False},
            pool_pre_ping=True,
        )

engine = init_engine()

# Tự động đảm bảo các cột cần thiết cho Gamification tồn tại
try:
    with engine.connect() as conn:
        def safe_exec(query: str):
            try:
                conn.execute(text(query))
                conn.commit()
            except Exception:
                try:
                    conn.rollback()
                except Exception:
                    pass

        safe_exec("ALTER TABLE user_stage_progress ADD COLUMN skill_type VARCHAR(20) DEFAULT 'listening' NOT NULL;")
        safe_exec("CREATE INDEX IF NOT EXISTS ix_user_stage_progress_skill_type ON user_stage_progress (skill_type);")
        safe_exec("ALTER TABLE skill_lessons ADD COLUMN target_band FLOAT;")
        safe_exec("ALTER TABLE skill_lessons ADD COLUMN pass_condition JSON;")

        # Tự động đảm bảo các cột Email & Xác thực OTP cho users
        if engine.dialect.name == "postgresql":
            safe_exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(255);")
            safe_exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS is_email_verified BOOLEAN DEFAULT FALSE;")
            safe_exec("CREATE INDEX IF NOT EXISTS ix_users_email ON users (email);")
            safe_exec("""
                CREATE TABLE IF NOT EXISTS email_otps (
                    id SERIAL PRIMARY KEY,
                    email VARCHAR(255) NOT NULL,
                    otp_code VARCHAR(10) NOT NULL,
                    otp_type VARCHAR(20) DEFAULT 'register' NOT NULL,
                    attempts INTEGER DEFAULT 0 NOT NULL,
                    expires_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
                    is_used BOOLEAN DEFAULT FALSE NOT NULL,
                    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT (NOW() AT TIME ZONE 'utc') NOT NULL
                );
            """)
            safe_exec("CREATE INDEX IF NOT EXISTS ix_email_otps_email ON email_otps (email);")
            safe_exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS face_embedding JSONB;")
            safe_exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS is_face_auth_enabled BOOLEAN DEFAULT FALSE;")
            safe_exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS face_registered_at TIMESTAMPTZ;")
            safe_exec("ALTER TABLE profiles ADD COLUMN IF NOT EXISTS face_embedding JSONB;")
            safe_exec("ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_face_auth_enabled BOOLEAN DEFAULT FALSE;")
            safe_exec("ALTER TABLE profiles ADD COLUMN IF NOT EXISTS face_registered_at TIMESTAMPTZ;")
        else:
            safe_exec("ALTER TABLE users ADD COLUMN email VARCHAR(255);")
            safe_exec("ALTER TABLE users ADD COLUMN is_email_verified BOOLEAN DEFAULT 0;")
            safe_exec("""
                CREATE TABLE IF NOT EXISTS email_otps (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    email VARCHAR(255) NOT NULL,
                    otp_code VARCHAR(10) NOT NULL,
                    otp_type VARCHAR(20) DEFAULT 'register' NOT NULL,
                    attempts INTEGER DEFAULT 0 NOT NULL,
                    expires_at DATETIME NOT NULL,
                    is_used BOOLEAN DEFAULT 0 NOT NULL,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL
                );
            """)
            safe_exec("CREATE INDEX IF NOT EXISTS ix_email_otps_email ON email_otps (email);")
            safe_exec("ALTER TABLE users ADD COLUMN face_embedding TEXT;")
            safe_exec("ALTER TABLE users ADD COLUMN is_face_auth_enabled BOOLEAN DEFAULT 0;")
            safe_exec("ALTER TABLE users ADD COLUMN face_registered_at DATETIME;")
except Exception as alter_err:
    logger.warning(f"Không thể thực hiện migrations tự động: {alter_err}")

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    """Dependency cung cấp session database cho các endpoint FastAPI."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
