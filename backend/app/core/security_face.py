import time
import secrets
import threading
import logging
from typing import Dict, Tuple, Optional

logger = logging.getLogger("ielts_vision.security_face")


class FaceNonceManager:
    """
    Quản lý mã xác thực thử thách (Nonce Challenge-Response) cho FaceID
    để chống tấn công phát lại (Anti-Replay Attack).
    
    Đặc điểm kỹ thuật:
    - Thread-safe tuyệt đối với threading.Lock.
    - Thời gian sống (TTL) mặc định: 60 giây.
    - Cơ chế Burn-on-Verify: Nonce bị hủy (xóa) ngay lập tức sau lần kiểm tra đầu tiên.
    - Tự động dọn dẹp các nonce đã quá hạn khi kích thước bộ nhớ lớn.
    """

    def __init__(self, default_ttl: int = 60):
        self._default_ttl = default_ttl
        # Map: nonce_token -> (expires_at_timestamp, metadata)
        self._nonces: Dict[str, Tuple[float, Optional[str]]] = {}
        self._lock = threading.Lock()

    def create_nonce(self, ttl: Optional[int] = None, metadata: Optional[str] = None) -> str:
        """Sinh mã nonce ngẫu nhiên an toàn mật mã học và lưu kèm thời hạn hết hạn."""
        token = secrets.token_urlsafe(32)
        duration = ttl if ttl is not None else self._default_ttl
        expires_at = time.time() + duration

        with self._lock:
            # Dọn dẹp định kỳ nếu bộ đệm lớn
            if len(self._nonces) > 500:
                self._cleanup_unsafe()
            self._nonces[token] = (expires_at, metadata)

        logger.debug(f"Đã tạo FaceID Nonce mới: {token[:8]}... (TTL={duration}s)")
        return token

    def burn_nonce(self, nonce: str) -> bool:
        """
        Kiểm tra và đốt (xóa vĩnh viễn) nonce ngay lập tức.
        Trả về True nếu nonce hợp lệ và còn hạn trong 60 giây; ngược lại trả về False.
        """
        if not nonce or not isinstance(nonce, str):
            return False

        now = time.time()
        with self._lock:
            if nonce not in self._nonces:
                logger.warning("Thử sử dụng Nonce không tồn tại hoặc đã bị đốt (burned).")
                return False

            expires_at, _ = self._nonces.pop(nonce)
            if now <= expires_at:
                logger.info(f"Xác thực FaceID Nonce thành công và đã burn: {nonce[:8]}...")
                return True
            else:
                logger.warning(f"Mã FaceID Nonce đã hết hạn: {nonce[:8]}...")
                return False

    def _cleanup_unsafe(self) -> int:
        """Dọn dẹp các nonce đã hết hạn (chỉ gọi khi đã giữ lock)."""
        now = time.time()
        expired_keys = [k for k, (exp, _) in self._nonces.items() if now > exp]
        for k in expired_keys:
            del self._nonces[k]
        return len(expired_keys)

    def cleanup_expired(self) -> int:
        """Dọn dẹp các nonce đã hết hạn (thread-safe)."""
        with self._lock:
            cleaned = self._cleanup_unsafe()
            if cleaned > 0:
                logger.info(f"Đã dọn dẹp {cleaned} FaceID Nonces hết hạn.")
            return cleaned

    def count_active(self) -> int:
        """Đếm số lượng nonce hiện đang có hiệu lực trong bộ đệm."""
        now = time.time()
        with self._lock:
            return sum(1 for _, (exp, _) in self._nonces.items() if now <= exp)


# Instance toàn cục sử dụng cho hệ thống
face_nonce_manager = FaceNonceManager(default_ttl=60)
