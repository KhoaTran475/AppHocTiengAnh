from typing import Optional
from datetime import datetime
from pydantic import BaseModel, Field
from app.schemas.user import UserResponse


class FaceNonceResponse(BaseModel):
    """Phản hồi cấp phát mã xác thực thử thách Nonce."""
    nonce: str = Field(..., description="Mã nonce ngẫu nhiên 32-bytes an toàn mật mã học")
    expires_in: int = Field(default=60, description="Thời gian hiệu lực tính bằng giây")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="Thời điểm tạo")


class FaceRegisterRequest(BaseModel):
    """Yêu cầu đăng ký/cập nhật FaceID từ Client."""
    nonce: str = Field(..., min_length=10, description="Mã challenge nonce thu được từ GET /auth/face/nonce")
    image_base64: str = Field(..., min_length=50, description="Ảnh khuôn mặt base64 đã được ML Kit phát hiện & căn góc")


class FaceLoginRequest(BaseModel):
    """Yêu cầu đăng nhập bằng FaceID."""
    nonce: str = Field(..., min_length=10, description="Mã challenge nonce thu được từ GET /auth/face/nonce")
    image_base64: str = Field(..., min_length=50, description="Ảnh khuôn mặt base64 thu từ camera quét mặt")
    username_hint: Optional[str] = Field(None, description="Username tùy chọn nếu học viên nhớ, giúp so khớp 1:1 siêu tốc")


class FaceAuthStatusResponse(BaseModel):
    """Trạng thái cấu hình FaceID của người dùng."""
    username: str
    is_face_auth_enabled: bool
    face_registered_at: Optional[datetime] = None


class FaceLoginResponse(BaseModel):
    """Kết quả đăng nhập FaceID thành công kèm Bearer Token."""
    access_token: str
    token_type: str = "bearer"
    user: UserResponse
    similarity_score: float = Field(..., ge=0.0, le=1.0, description="Điểm số tương đồng Cosine Similarity (0.0 - 1.0)")
    message: str = "Đăng nhập bằng FaceID thành công"
