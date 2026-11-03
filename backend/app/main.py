import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.core.supabase import verify_supabase_connection
from app.api.v1.router import api_router
from app.db.session import engine, Base, SessionLocal
import app.models  # noqa: F401
from app.services.user_service import seed_default_users

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger("ielts_vision")

# Đảm bảo cấu trúc bảng luôn sẵn sàng ngay khi import
Base.metadata.create_all(bind=engine)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Khởi tạo bảng database & nạp tài khoản mẫu khi ứng dụng khởi động
    logger.info("Đang khởi tạo cấu trúc cơ sở dữ liệu...")
    Base.metadata.create_all(bind=engine)
    
    db = SessionLocal()
    try:
        seed_default_users(db)
        from app.services.mapping_service import seed_default_mappings
        seed_default_mappings(db)
        from app.services.skill_service import seed_default_skill_lessons
        seed_default_skill_lessons(db)
        from app.services.ollama_vocab_service import seed_default_vocab_learning
        seed_default_vocab_learning(db)
        logger.info("Khởi tạo và đồng bộ người dùng, từ vựng, lộ trình từ vựng 5 cấp độ & bài học 4 kỹ năng thành công!")
    except Exception as e:
        logger.warning(f"Lỗi khởi tạo dữ liệu ban đầu: {e}")
    finally:
        db.close()
    
    yield
    logger.info("Ứng dụng dừng hoạt động.")


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="Backend API phục vụ ứng dụng IELTS Vision (Xử lý 4 kỹ năng & AI Vision)",
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    docs_url=f"{settings.API_V1_STR}/docs",
    redoc_url=f"{settings.API_V1_STR}/redoc",
    lifespan=lifespan,
)

import os
from fastapi.staticfiles import StaticFiles

# Cấu hình CORS
if settings.BACKEND_CORS_ORIGINS:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

# Đăng ký API Router v1
app.include_router(api_router, prefix=settings.API_V1_STR)

# Cổng Quản Trị Web (Admin Web Portal)
static_admin_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static_admin")
class NoCacheStaticFiles(StaticFiles):
    """StaticFiles luôn buộc trình duyệt kiểm tra lại (tránh dùng CSS/JS cũ trong cache sau khi cập nhật UI)."""

    def file_response(self, *args, **kwargs):
        response = super().file_response(*args, **kwargs)
        response.headers["Cache-Control"] = "no-cache, must-revalidate"
        return response


if os.path.exists(static_admin_dir):
    app.mount("/admin", NoCacheStaticFiles(directory=static_admin_dir, html=True), name="admin")

# Thư mục lưu trữ media tĩnh / fallback uploads
static_uploads_dir = os.path.abspath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "static", "uploads")
)
os.makedirs(static_uploads_dir, exist_ok=True)
app.mount("/static/uploads", StaticFiles(directory=static_uploads_dir), name="static_uploads")


@app.get("/")
def root():
    return {
        "project": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "status": "online",
        "admin_portal": "/admin",
        "docs_url": f"{settings.API_V1_STR}/docs",
    }


@app.get("/health")
@app.get("/api/health")
def health_check():
    """Kiểm tra trạng thái server backend và kết nối cơ sở dữ liệu."""
    supabase_status = verify_supabase_connection()
    return {
        "status": "healthy" if supabase_status.get("status") == "connected" else "degraded",
        "service": settings.PROJECT_NAME,
        "backend": "online",
        "port": 8000,
        "supabase": supabase_status,
    }


@app.get("/api/tags")
async def get_tags_proxy():
    """Endpoint trả về danh sách model Ollama :11434 phục vụ Admin Portal."""
    import httpx
    try:
        async with httpx.AsyncClient(timeout=4.0) as client:
            res = await client.get(f"{settings.OLLAMA_BASE_URL}/api/tags")
            if res.status_code == 200:
                return res.json()
    except Exception as e:
        logger.warning(f"Ollama tags proxy warning: {e}")
    return {"models": []}
