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
