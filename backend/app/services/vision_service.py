import io
import os
import logging
from typing import List, Optional
from PIL import Image
from sqlalchemy.orm import Session
from app.schemas.vocabulary import DetectedObject, BoundingBox, ObjectMappingResponse
from app.services.mapping_service import get_mapping_by_label

logger = logging.getLogger(__name__)

# Singleton YOLO model
_yolo_model = None

# Đường dẫn đến file trọng số yolov8n.pt ở root
MODEL_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))),
    "yolov8n.pt",
)


def get_yolo_model():
    """Lazy loader cho model YOLOv8n."""
    global _yolo_model
    if _yolo_model is None:
        try:
            from ultralytics import YOLO
            if not os.path.exists(MODEL_PATH):
                logger.warning(f"Không tìm thấy model tại {MODEL_PATH}, sử dụng yolov8n mặc định")
                _yolo_model = YOLO("yolov8n.pt")
            else:
                logger.info(f"Đang nạp model YOLOv8 từ: {MODEL_PATH}")
                _yolo_model = YOLO(MODEL_PATH)
        except Exception as e:
            logger.error(f"Lỗi khởi tạo model YOLO: {e}")
            raise RuntimeError(f"Không thể khởi tạo model YOLO: {e}")
    return _yolo_model


def detect_objects_in_image(
    image_bytes: bytes,
    db: Session,
    conf_threshold: float = 0.35,
) -> List[DetectedObject]:
    """Nhận diện vật thể trong ảnh và tự động ánh xạ với kho từ vựng IELTS."""
    model = get_yolo_model()
    
    # Đọc ảnh từ bytes
    try:
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        width, height = image.size
    except Exception as e:
        raise ValueError(f"Dữ liệu hình ảnh không hợp lệ: {e}")

    # Chạy inference
    results = model.predict(image, conf=conf_threshold, verbose=False)
    
    detections: List[DetectedObject] = []
    if not results or len(results) == 0:
        return detections

    boxes = results[0].boxes
    if boxes is None or len(boxes) == 0:
        return detections

    mapping_cache: dict[str, Optional[ObjectMappingResponse]] = {}

    for box in boxes:
        cls_id = int(box.cls[0].item())
        conf = float(box.conf[0].item())
        label_name = model.names.get(cls_id, f"class_{cls_id}").strip().lower()

        # Bounding box tọa độ chuẩn hóa [0.0, 1.0]
        xyxy = box.xyxy[0].tolist()
        norm_box = BoundingBox(
            xmin=max(0.0, min(1.0, xyxy[0] / width)),
            ymin=max(0.0, min(1.0, xyxy[1] / height)),
            xmax=max(0.0, min(1.0, xyxy[2] / width)),
            ymax=max(0.0, min(1.0, xyxy[3] / height)),
        )

        # Ánh xạ từ vựng IELTS từ Database (có cache theo nhãn tránh N+1 queries)
        if label_name not in mapping_cache:
            vocab_mapping = get_mapping_by_label(db, label_name)
            mapping_cache[label_name] = (
                ObjectMappingResponse.model_validate(vocab_mapping)
                if vocab_mapping
                else None
            )
        vocab_resp = mapping_cache[label_name]

        detections.append(
            DetectedObject(
                label=label_name,
                confidence=round(conf, 4),
                box=norm_box,
                vocabulary=vocab_resp,
            )
        )

    # Sắp xếp theo confidence giảm dần
    detections.sort(key=lambda d: d.confidence, reverse=True)
    return detections
