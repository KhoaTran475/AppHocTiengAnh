from fastapi import APIRouter, Depends, UploadFile, File, Query, HTTPException, status
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.schemas.vocabulary import VisionDetectionResponse, DeepScanResponse
from app.services.vision_service import detect_objects_in_image
from app.services.ollama_vision_service import deep_scan_and_cache

router = APIRouter()


@router.post(
    "/detect",
    response_model=VisionDetectionResponse,
    summary="Nhận diện vật thể bằng AI YOLOv8n & Ánh xạ từ vựng IELTS",
)
async def detect_objects(
    file: UploadFile = File(..., description="File hình ảnh chụp từ camera hoặc thư viện"),
    conf_threshold: float = Query(0.35, ge=0.1, le=1.0, description="Ngưỡng độ tin cậy confidence"),
    db: Session = Depends(get_db),
):
    """
    Tải lên hình ảnh -> Chạy YOLOv8n nhận diện vật thể -> Trả về danh sách bounding boxes, nhãn
    và tự động đính kèm chi tiết từ vựng IELTS Band 7.0 - 8.5 tương ứng.
    """
    if not file.content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tập tin tải lên phải là hình ảnh (jpg, png, webp, heic)",
        )

    try:
        image_bytes = await file.read()
        detections = detect_objects_in_image(
            image_bytes=image_bytes,
            db=db,
            conf_threshold=conf_threshold,
        )
        return VisionDetectionResponse(
            total_detected=len(detections),
            detections=detections,
        )
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Lỗi xử lý nhận diện AI: {e}",
        )


@router.post(
    "/deep-scan",
    response_model=DeepScanResponse,
    summary="Quét vật thể chuyên sâu bằng Ollama LLaVA-Phi3 & Tự động mở rộng từ vựng IELTS",
)
async def deep_scan_object(
    file: UploadFile = File(..., description="Ảnh crop vật thể đã nén (<200KB)"),
    db: Session = Depends(get_db),
):
    """
    Quét chuyên sâu mở rộng (Open-Vocabulary):
    1. Nhận ảnh nén từ camera / tap-to-scan.
    2. Gửi LLaVA-Phi3 nhận diện vật thể & trích xuất từ vựng IELTS.
    3. Tra cứu cache Database: Nếu có -> Trả về ngay; Nếu chưa -> Tự động lưu vào DB.
    """
    if file.content_type and not file.content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tập tin tải lên phải là hình ảnh (jpg, png, webp)",
        )

    try:
        image_bytes = await file.read()
        if len(image_bytes) == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Dữ liệu ảnh trống",
            )

        vocab_resp, source = await deep_scan_and_cache(image_bytes=image_bytes, db=db)
        return DeepScanResponse(
            source=source,
            vocabulary=vocab_resp,
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Lỗi phân tích chuyên sâu LLaVA-Phi3: {e}",
        )

