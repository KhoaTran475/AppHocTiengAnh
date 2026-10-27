import io
import os
import re
import base64
import urllib.request
import logging
import threading
from datetime import datetime, timezone
from typing import List, Optional, Tuple, Union

import numpy as np
from PIL import Image
import onnxruntime as ort
from sqlalchemy.orm import Session

from app.models.user import User
from app.core.supabase import get_supabase_admin

logger = logging.getLogger("ielts_vision.face_service")

# Đường dẫn file mô hình ONNX
BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODEL_DIR = os.path.join(BACKEND_DIR, "app", "core", "models")
MODEL_PATH = os.path.join(MODEL_DIR, "mobilefacenet.onnx")

# URL tải dự phòng chuẩn (MobileFaceNet 128-d ONNX 3.87MB)
FALLBACK_MODEL_URL = "https://raw.githubusercontent.com/Seeed-Solution/grove-vision-face-embedding/main/qat_distill_v2_relu6_128d/model_128d.onnx"

# Thread-safe Session Singleton
_session: Optional[ort.InferenceSession] = None
_session_lock = threading.Lock()
_input_name: Optional[str] = None
_output_name: Optional[str] = None


def _ensure_model_file() -> str:
    """Đảm bảo file mô hình mobilefacenet.onnx tồn tại sẵn sàng."""
    os.makedirs(MODEL_DIR, exist_ok=True)
    if not os.path.exists(MODEL_PATH) or os.path.getsize(MODEL_PATH) < 1024:
        logger.info(f"Đang tự động tải mô hình Face Recognition ONNX từ {FALLBACK_MODEL_URL}...")
        try:
            urllib.request.urlretrieve(FALLBACK_MODEL_URL, MODEL_PATH)
            logger.info("Đã tải xong mô hình nhận diện khuôn mặt thành công!")
        except Exception as e:
            logger.error(f"Lỗi khi tải mô hình Face Recognition: {e}")
            raise RuntimeError(f"Không thể khởi tạo mô hình ONNX tại {MODEL_PATH}: {e}")
    return MODEL_PATH


def get_face_session() -> Tuple[ort.InferenceSession, str, str]:
    """Khởi tạo và trả về singleton ONNX InferenceSession kèm tên input/output."""
    global _session, _input_name, _output_name
    if _session is None:
        with _session_lock:
            if _session is None:
                path = _ensure_model_file()
                opts = ort.SessionOptions()
                opts.log_severity_level = 3  # Tắt các cảnh báo initializer thừa
                opts.intra_op_num_threads = 2
                sess = ort.InferenceSession(path, sess_options=opts)
                _session = sess
                _input_name = sess.get_inputs()[0].name
                _output_name = sess.get_outputs()[0].name
                logger.info(f"Đã nạp ONNX Face Model thành công: Input={_input_name}, Output={_output_name}")
    return _session, _input_name, _output_name


def extract_embedding(image_input: Union[bytes, str]) -> List[float]:
    """
    Trích xuất vector đặc trưng khuôn mặt (128-d L2-normalized Face Embedding).
    
    Quy trình:
    1. Đọc ảnh từ Base64 hoặc raw bytes.
    2. Chuyển đổi hệ màu RGB.
    3. Resize về kích thước chuẩn (112, 112).
    4. Chuẩn hóa pixel: (pixel - 127.5) / 128.0.
    5. Chạy inference qua MobileFaceNet ONNX.
    6. L2-Normalize vector đặc trưng: v = v / norm(v).
    """
    # 1. Giải mã dữ liệu ảnh
    if isinstance(image_input, str):
        # Loại bỏ header dạng data:image/...;base64, nếu có
        cleaned_base64 = re.sub(r"^data:image/[a-zA-Z]+;base64,", "", image_input.strip())
        try:
            img_bytes = base64.b64decode(cleaned_base64)
        except Exception as e:
            raise ValueError(f"Dữ liệu ảnh base64 không hợp lệ: {e}")
    elif isinstance(image_input, bytes):
        img_bytes = image_input
    else:
        raise ValueError("Định dạng ảnh đầu vào phải là chuỗi base64 hoặc bytes")

    # 2. Đọc ảnh bằng Pillow
    try:
        pil_img = Image.open(io.BytesIO(img_bytes))
    except Exception as e:
        raise ValueError(f"Không thể đọc định dạng file ảnh: {e}")

    # 3. Chuyển hệ màu RGB & Resize chuẩn 112x112
    if pil_img.mode != "RGB":
        pil_img = pil_img.convert("RGB")
    pil_img = pil_img.resize((112, 112), Image.Resampling.BILINEAR)

    # 4. Chuẩn hóa ma trận điểm ảnh theo công thức: (pixel - 127.5) / 128.0
    arr = np.array(pil_img, dtype=np.float32)
    normalized = (arr - 127.5) / 128.0

    # Chuyển layout từ HWC (112, 112, 3) -> CHW (3, 112, 112) -> NCHW (1, 3, 112, 112)
    tensor = np.transpose(normalized, (2, 0, 1))
    tensor = np.expand_dims(tensor, axis=0)

    # 5. Chạy Inference qua ONNX Runtime
    session, input_name, output_name = get_face_session()
    raw_outputs = session.run([output_name], {input_name: tensor})
    embedding = raw_outputs[0][0].astype(np.float32)

    # 6. Chuẩn hóa L2-Norm (vector chiều dài = 1.0)
    norm = np.linalg.norm(embedding)
    if norm > 1e-6:
        embedding = embedding / norm

    return embedding.tolist()


def calculate_cosine_similarity(emb1: List[float], emb2: List[float]) -> float:
    """
    Tính điểm số tương đồng Cosine Similarity giữa 2 vector khuôn mặt.
    Do các vector đã được L2-normalize, Cosine Similarity chính là tích vô hướng (Dot Product).
    """
    if not emb1 or not emb2 or len(emb1) != len(emb2):
        return 0.0

    a = np.array(emb1, dtype=np.float32)
    b = np.array(emb2, dtype=np.float32)

    dot_product = float(np.dot(a, b))
    # Giới hạn trong khoảng [0.0, 1.0] và làm tròn 4 chữ số thập phân
    return round(max(0.0, min(1.0, dot_product)), 4)


def match_user(
    db: Session,
    query_embedding: List[float],
    username_hint: Optional[str] = None,
) -> Tuple[Optional[User], float, str, str]:
    """
    So khớp khuôn mặt với cơ sở dữ liệu.
    
    Phân loại trạng thái (status_code_name):
    - 'MATCH_SUCCESS' (Score >= 0.70): Khớp khuôn mặt thành công (độ tin cậy >= 70%).
    - 'LOW_CONFIDENCE' (0.60 <= Score < 0.70): Cần chụp lại góc/ánh sáng rõ hơn.
    - 'NO_MATCH' (Score < 0.60): Không khớp với bất kỳ tài khoản nào.
    
    Trả về: (user_or_none, similarity_score, status_code_name, message)
    """
    # Ngưỡng chấp nhận nhận diện (70%)
    ACCEPT_THRESHOLD = 0.70
    WARNING_THRESHOLD = 0.60

    # Trường hợp 1: Có gợi ý username (So khớp 1:1)
    if username_hint and username_hint.strip():
        clean_hint = username_hint.strip().lower()
        user = db.query(User).filter(User.username == clean_hint).first()
        if not user:
            return None, 0.0, "NO_MATCH", f"Không tìm thấy tài khoản '{username_hint}'"
        
        if not user.is_face_auth_enabled or not user.face_embedding:
            return None, 0.0, "NO_MATCH", f"Tài khoản '{username_hint}' chưa kích hoạt FaceID"

        score = calculate_cosine_similarity(query_embedding, user.face_embedding)
        if score >= ACCEPT_THRESHOLD:
            return user, score, "MATCH_SUCCESS", "Nhận diện khuôn mặt thành công"
        elif score >= WARNING_THRESHOLD:
            return user, score, "LOW_CONFIDENCE", "Góc chụp hoặc điều kiện ánh sáng chưa đạt, vui lòng thử lại"
        else:
            return None, score, "NO_MATCH", "Khuôn mặt không khớp với tài khoản đã chọn"

    # Trường hợp 2: Không có username (So khớp 1:N)
    candidates = db.query(User).filter(
        User.is_face_auth_enabled.is_(True),
        User.face_embedding.isnot(None),
    ).all()

    if not candidates:
        return None, 0.0, "NO_MATCH", "Chưa có tài khoản nào trong hệ thống kích hoạt FaceID"

    best_user: Optional[User] = None
    best_score: float = -1.0

    for cand in candidates:
        if isinstance(cand.face_embedding, list) and len(cand.face_embedding) == 128:
            score = calculate_cosine_similarity(query_embedding, cand.face_embedding)
            if score > best_score:
                best_score = score
                best_user = cand

    if best_score >= ACCEPT_THRESHOLD and best_user is not None:
        return best_user, best_score, "MATCH_SUCCESS", f"Xin chào {best_user.username}, nhận diện thành công!"
    elif best_score >= WARNING_THRESHOLD and best_user is not None:
        return best_user, best_score, "LOW_CONFIDENCE", "Góc chụp hoặc điều kiện ánh sáng chưa đạt, vui lòng thử lại"
    else:
        safe_score = max(0.0, best_score)
        return None, safe_score, "NO_MATCH", "Khuôn mặt không khớp với bất kỳ tài khoản nào trong hệ thống"


def register_user_face(db: Session, user: User, embedding: List[float]) -> User:
    """Lưu vector khuôn mặt cho người dùng và đồng bộ sang Supabase profiles."""
    user.face_embedding = embedding
    user.is_face_auth_enabled = True
    user.face_registered_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(user)

    # Đồng bộ sang Supabase profiles
    try:
        admin_client = get_supabase_admin()
        admin_client.from_("profiles").update({
            "face_embedding": embedding,
            "is_face_auth_enabled": True,
            "face_registered_at": user.face_registered_at.isoformat(),
        }).eq("username", user.username).execute()
        logger.info(f"Đã đồng bộ FaceID của user '{user.username}' lên Supabase profiles!")
    except Exception as e:
        logger.warning(f"Lỗi khi sync FaceID lên Supabase: {e}")

    return user


def delete_user_face(db: Session, user: User) -> User:
    """Xóa FaceID của người dùng và đồng bộ sang Supabase profiles."""
    user.face_embedding = None
    user.is_face_auth_enabled = False
    user.face_registered_at = None
    db.commit()
    db.refresh(user)

    # Đồng bộ hủy trên Supabase profiles
    try:
        admin_client = get_supabase_admin()
        admin_client.from_("profiles").update({
            "face_embedding": None,
            "is_face_auth_enabled": False,
            "face_registered_at": None,
        }).eq("username", user.username).execute()
        logger.info(f"Đã đồng bộ hủy FaceID của user '{user.username}' lên Supabase profiles!")
    except Exception as e:
        logger.warning(f"Lỗi khi sync hủy FaceID lên Supabase: {e}")

    return user
