import logging
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.core.deps import get_current_user
from app.core.security import create_access_token
from app.core.security_face import face_nonce_manager
from app.models.user import User
from app.schemas.user import UserResponse
from app.schemas.face_auth import (
    FaceNonceResponse,
    FaceRegisterRequest,
    FaceLoginRequest,
    FaceAuthStatusResponse,
    FaceLoginResponse,
)
from app.services.face_service import (
    extract_embedding,
    match_user,
    register_user_face,
    delete_user_face,
)

logger = logging.getLogger("ielts_vision.api.face_auth")

router = APIRouter()


@router.get(
    "/nonce",
    response_model=FaceNonceResponse,
    summary="Cấp phát mã challenge Nonce (Chống Replay Attack, TTL 60s)",
)
def get_face_nonce():
    """
    Cấp phát mã thử thách ngẫu nhiên 32-bytes có thời hạn 60 giây.
    Mỗi khi chuẩn bị quét mặt, Client bắt buộc phải lấy mã này trước.
    Mã này chỉ được sử dụng đúng 1 lần (Burn-on-Verify).
    """
    nonce = face_nonce_manager.create_nonce(ttl=60)
    return FaceNonceResponse(nonce=nonce, expires_in=60)


@router.post(
    "/register",
    response_model=FaceAuthStatusResponse,
    summary="Đăng ký hoặc cập nhật FaceID cho tài khoản hiện tại",
)
def register_face(
    req: FaceRegisterRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Đăng ký FaceID cho tài khoản đang đăng nhập (yêu cầu Bearer Token).
    
    Quy trình:
    1. Xác minh và đốt mã Nonce (chống phát lại ảnh cũ).
    2. Trích xuất vector đặc trưng 128 chiều từ ảnh khuôn mặt.
    3. Lưu vector vào Database (JSONB) và bật cờ is_face_auth_enabled = True.
    4. Đồng bộ hồ sơ sang Supabase profiles.
    """
    # 1. Xác minh Nonce
    if not face_nonce_manager.burn_nonce(req.nonce):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mã xác thực (Nonce) không hợp lệ hoặc đã hết hạn. Vui lòng lấy mã mới và thử lại.",
        )

    # 2. Trích xuất Face Embedding
    try:
        embedding = extract_embedding(req.image_base64)
    except ValueError as e:
        logger.warning(f"Lỗi ảnh đầu vào khi đăng ký FaceID cho '{current_user.username}': {e}")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        logger.error(f"Lỗi hệ thống khi trích xuất khuôn mặt: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Không thể phân tích khuôn mặt từ ảnh gửi lên.",
        )

    # 3. Lưu vào Database & Đồng bộ Supabase
    updated_user = register_user_face(db, current_user, embedding)
    logger.info(f"Người dùng '{updated_user.username}' đã đăng ký FaceID thành công.")

    return FaceAuthStatusResponse(
        username=updated_user.username,
        is_face_auth_enabled=updated_user.is_face_auth_enabled,
        face_registered_at=updated_user.face_registered_at,
    )


@router.post(
    "/login",
    response_model=FaceLoginResponse,
    summary="Đăng nhập tài khoản bằng khuôn mặt (Public Endpoint)",
)
def login_with_face(
    req: FaceLoginRequest,
    db: Session = Depends(get_db),
):
    """
    Đăng nhập bằng nhận diện khuôn mặt sinh trắc học FaceID.
    
    Quy trình:
    1. Xác minh và đốt mã Nonce (chống Replay Attack).
    2. Trích xuất vector 128-d từ ảnh khuôn mặt gửi lên.
    3. So khớp Cosine Similarity với cơ sở dữ liệu:
       - Có username_hint: So khớp 1:1 siêu tốc.
       - Không có username_hint: Quét 1:N toàn bộ học viên đã kích hoạt FaceID.
    4. Phân loại ngưỡng nhận diện (Threshold Tuning):
       - Score >= 0.80: Thành công -> Cấp Bearer JWT Access Token.
       - 0.70 <= Score < 0.80: Trả về HTTP 422 cảnh báo góc/ánh sáng chưa đạt.
       - Score < 0.70: Trả về HTTP 401 từ chối đăng nhập.
    """
    # 1. Xác minh Nonce
    if not face_nonce_manager.burn_nonce(req.nonce):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mã xác thực (Nonce) không hợp lệ hoặc đã hết hạn. Vui lòng thử lại.",
        )

    # 2. Trích xuất Face Embedding
    try:
        query_embedding = extract_embedding(req.image_base64)
    except ValueError as e:
        logger.warning(f"Lỗi ảnh đầu vào khi đăng nhập FaceID: {e}")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        logger.error(f"Lỗi hệ thống khi trích xuất khuôn mặt login: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Không thể phân tích khuôn mặt từ ảnh gửi lên.",
        )

    # 3. So khớp người dùng
    matched_user, score, status_code_name, message = match_user(
        db=db,
        query_embedding=query_embedding,
        username_hint=req.username_hint,
    )

    if status_code_name == "LOW_CONFIDENCE":
        logger.info(f"Đăng nhập FaceID độ tin cậy thấp (Score={score:.4f}): {message}")
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=message,
        )
    elif status_code_name == "NO_MATCH" or not matched_user:
        logger.warning(f"Đăng nhập FaceID thất bại (Score={score:.4f}): {message}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=message,
        )

    # 4. Nhận diện thành công -> Cấp phát JWT Access Token
    access_token = create_access_token(subject=matched_user.username, role=matched_user.role)
    logger.info(f"Đăng nhập FaceID thành công cho user '{matched_user.username}' (Score={score:.4f})")

    return FaceLoginResponse(
        access_token=access_token,
        token_type="bearer",
        user=UserResponse.model_validate(matched_user),
        similarity_score=score,
        message=message,
    )


@router.get(
    "/status",
    response_model=FaceAuthStatusResponse,
    summary="Kiểm tra trạng thái kích hoạt FaceID của tài khoản hiện tại",
)
def get_face_status(
    current_user: User = Depends(get_current_user),
):
    """Kiểm tra tài khoản hiện tại đã đăng ký FaceID hay chưa."""
    return FaceAuthStatusResponse(
        username=current_user.username,
        is_face_auth_enabled=current_user.is_face_auth_enabled,
        face_registered_at=current_user.face_registered_at,
    )


@router.delete(
    "",
    response_model=FaceAuthStatusResponse,
    summary="Hủy kích hoạt và xóa dữ liệu FaceID của tài khoản hiện tại",
)
def disable_face(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Xóa vector khuôn mặt và hủy tính năng FaceID cho tài khoản."""
    updated_user = delete_user_face(db, current_user)
    logger.info(f"Đã hủy FaceID cho tài khoản '{updated_user.username}'")

    return FaceAuthStatusResponse(
        username=updated_user.username,
        is_face_auth_enabled=updated_user.is_face_auth_enabled,
        face_registered_at=updated_user.face_registered_at,
    )
