import logging
from typing import Optional
from supabase import create_client, Client
from app.core.config import settings

logger = logging.getLogger(__name__)

# Global client singletons
_supabase_client: Optional[Client] = None
_supabase_admin_client: Optional[Client] = None


def get_supabase_client() -> Client:
    """Trả về Supabase Client sử dụng Anon Key."""
    global _supabase_client
    if _supabase_client is None:
        if not settings.SUPABASE_URL or not settings.SUPABASE_ANON_KEY:
            raise ValueError("SUPABASE_URL và SUPABASE_ANON_KEY phải được cấu hình trong .env")
        _supabase_client = create_client(settings.SUPABASE_URL, settings.SUPABASE_ANON_KEY)
    return _supabase_client


def get_supabase_admin() -> Client:
    """Trả về Supabase Admin Client sử dụng Service Role Key (bỏ qua RLS để quản trị server-side)."""
    global _supabase_admin_client
    if _supabase_admin_client is None:
        key = settings.SUPABASE_SERVICE_ROLE_KEY or settings.SUPABASE_ANON_KEY
        if not settings.SUPABASE_URL or not key:
            raise ValueError("SUPABASE_URL và SUPABASE_SERVICE_ROLE_KEY phải được cấu hình trong .env")
        _supabase_admin_client = create_client(settings.SUPABASE_URL, key)
    return _supabase_admin_client


def verify_supabase_connection() -> dict:
    """Kiểm tra trạng thái kết nối tới Supabase Cloud."""
    try:
        admin = get_supabase_admin()
        # Thử truy vấn bảng profiles hoặc object_mappings
        res = admin.table("object_mappings").select("label").limit(1).execute()
        return {
            "status": "connected",
            "url": settings.SUPABASE_URL,
            "test_query_success": True,
            "records_found": len(res.data) if res.data else 0,
        }
    except Exception as e:
        logger.error(f"Lỗi kết nối Supabase: {e}")
        return {
            "status": "error",
            "url": settings.SUPABASE_URL,
            "error": str(e),
        }


import os
import uuid
import time


def ensure_bucket_exists(bucket_name: str = "ielts-assets", is_public: bool = True) -> bool:
    """Kiểm tra hoặc tạo mới Supabase Storage bucket với chế độ Public (nếu chưa có)."""
    try:
        admin = get_supabase_admin()
        try:
            admin.storage.get_bucket(bucket_name)
            return True
        except Exception:
            # Nếu chưa có bucket, thử tạo mới
            admin.storage.create_bucket(bucket_name, options={"public": is_public})
            logger.info(f"Đã tạo bucket Supabase Storage '{bucket_name}' (public={is_public}) thành công.")
            return True
    except Exception as e:
        logger.warning(f"Không thể kiểm tra/tạo bucket '{bucket_name}' trên Supabase: {e}")
        return False


def upload_file_to_supabase(
    file_bytes: bytes,
    original_filename: str,
    content_type: str = "image/png",
    bucket_name: str = "ielts-assets",
    subfolder: str = "charts",
) -> dict:
    """
    Tải file ảnh lên Supabase Storage bucket (Bucket mặc định: ielts-assets, public).
    Cơ chế Fallback: Nếu Supabase gặp sự cố (mạng, timeout, RLS), tự động lưu vào
    backend/static/uploads/charts/ và trả về URL tĩnh cục bộ mà không throw Exception.
    """
    ext = os.path.splitext(original_filename)[1].lower()
    if not ext:
        ext = ".png"
    unique_name = f"{uuid.uuid4().hex[:12]}_{int(time.time())}{ext}"
    cloud_path = f"{subfolder}/{unique_name}"

    # 1. Thử tải lên Supabase Storage
    try:
        admin = get_supabase_admin()
        ensure_bucket_exists(bucket_name, is_public=True)
        admin.storage.from_(bucket_name).upload(
            path=cloud_path,
            file=file_bytes,
            file_options={"content-type": content_type, "upsert": "true"},
        )
        public_url = admin.storage.from_(bucket_name).get_public_url(cloud_path)
        logger.info(f"Đã upload ảnh thành công lên Supabase Storage: {public_url}")
        return {
            "url": public_url,
            "source": "supabase",
            "path": cloud_path,
            "filename": unique_name,
        }
    except Exception as e:
        logger.warning(
            f"Không thể upload lên Supabase Storage ({e}). Kích hoạt cơ chế Fallback lưu cục bộ..."
        )

    # 2. Cơ chế Fallback: Lưu vào backend/static/uploads/charts/
    try:
        backend_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        local_dir = os.path.join(backend_root, "static", "uploads", subfolder)
        os.makedirs(local_dir, exist_ok=True)
        local_file_path = os.path.join(local_dir, unique_name)
        with open(local_file_path, "wb") as f:
            f.write(file_bytes)

        fallback_url = f"/static/uploads/{subfolder}/{unique_name}"
        logger.info(f"Đã lưu ảnh vào thư mục cục bộ fallback: {local_file_path}")
        return {
            "url": fallback_url,
            "source": "local_fallback",
            "path": local_file_path,
            "filename": unique_name,
        }
    except Exception as fallback_err:
        logger.error(f"Lỗi nghiêm trọng cả ở cơ chế Fallback: {fallback_err}")
        return {
            "url": "",
            "source": "failed",
            "error": str(fallback_err),
            "filename": unique_name,
        }

