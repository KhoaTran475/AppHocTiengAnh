import os
import re
import json
import base64
import logging
from typing import Tuple, Optional
import httpx
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.models.mapping import ObjectMapping
from app.schemas.vocabulary import OllamaVisionExtraction, ObjectMappingResponse

logger = logging.getLogger(__name__)

OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
MODEL_NAME = os.getenv("OLLAMA_VISION_MODEL", "llava-phi3:latest")

SYSTEM_PROMPT = """You are an expert IELTS examiner and computer vision assistant.
Analyze the main object in the image and provide high-level academic IELTS vocabulary for it.
You MUST output ONLY a valid JSON object with the following exact keys:
{
  "detected_object": "common english name in lowercase (e.g., eyeglasses, ballpoint pen, wristwatch, calculator, coffee mug, scissors)",
  "common_word": "standard english noun (e.g. watch, pen, glasses)",
  "vietnamese_meaning": "accurate and natural Vietnamese meaning of the object (e.g., đồng hồ đeo tay, bút bi, mắt kính)",
  "academic_word": "IELTS academic Band 7.0-8.5 synonym or formal term (e.g. for watch: chronometer / timepiece; for glasses: spectacles)",
  "ipa": "accurate IPA pronunciation (e.g., /ˈkrɒn.əˌmiː.tər/)",
  "band_score": "7.5",
  "collocations": ["relevant collocation 1", "relevant collocation 2"],
  "idioms": "a relevant idiom if applicable or empty string",
  "speaking_part1_example": "A natural IELTS Speaking Part 1 answer using this object/word",
  "speaking_part1_translation": "Dịch nghĩa câu ví dụ trên sang tiếng Việt một cách tự nhiên và chính xác"
}
Do NOT include any introduction, markdown fences, or explanations. Output purely the JSON object."""



def _clean_json_text(raw_text: str) -> str:
    """Loại bỏ markdown code blocks và trích xuất khối JSON chuẩn { ... }."""
    text = raw_text.strip()
    # Loại bỏ code fences ```json hoặc ```
    text = re.sub(r"^```(?:json)?\s*", "", text, flags=re.IGNORECASE)
    text = re.sub(r"\s*```$", "", text)
    text = text.strip()

    # Tìm cặp ngoặc { ... } bao ngoài cùng
    start_idx = text.find("{")
    end_idx = text.rfind("}")
    if start_idx != -1 and end_idx != -1 and end_idx > start_idx:
        return text[start_idx : end_idx + 1]
    return text


async def call_llava_phi3(image_bytes: bytes, retry_count: int = 1) -> OllamaVisionExtraction:
    """
    Gọi mô hình LLaVA-Phi3 trên Ollama local để nhận diện vật thể và trích xuất từ vựng IELTS.
    Hỗ trợ auto-retry 1 lần nếu gặp lỗi parse JSON.
    """
    img_b64 = base64.b64encode(image_bytes).decode("utf-8")
    payload = {
        "model": MODEL_NAME,
        "prompt": SYSTEM_PROMPT,
        "images": [img_b64],
        "format": "json",
        "stream": False,
        "options": {
            "temperature": 0.1,
            "num_predict": 512,
        },
    }

    last_error: Optional[Exception] = None
    max_attempts = 1 + retry_count

    async with httpx.AsyncClient(timeout=45.0) as client:
        for attempt in range(1, max_attempts + 1):
            try:
                logger.info(f"Đang gửi ảnh tới Ollama ({MODEL_NAME}) - lần thử {attempt}/{max_attempts}")
                response = await client.post(
                    f"{OLLAMA_BASE_URL}/api/generate",
                    json=payload,
                )
                response.raise_for_status()
                data = response.json()
                raw_response = data.get("response", "")

                cleaned_json = _clean_json_text(raw_response)
                parsed_data = json.loads(cleaned_json)

                # Validate qua Pydantic schema
                extraction = OllamaVisionExtraction.model_validate(parsed_data)
                logger.info(f"Ollama nhận diện thành công: {extraction.detected_object} -> {extraction.academic_word}")
                return extraction

            except Exception as e:
                logger.warning(f"Lỗi phân tích JSON ở lần thử {attempt}: {e}")
                last_error = e

    raise RuntimeError(f"Không thể trích xuất JSON hợp lệ từ LLaVA-Phi3 sau {max_attempts} lần thử: {last_error}")


async def deep_scan_and_cache(image_bytes: bytes, db: Session) -> Tuple[ObjectMappingResponse, str]:
    """
    Quy trình Cache 2 tầng:
    1. Nhận diện nhãn bằng LLaVA-Phi3
    2. Tra cứu nhãn trong DB (PostgreSQL / SQLite).
    3. Cache HIT: Trả về dữ liệu chuẩn từ DB.
    4. Cache MISS: Lưu bản ghi mới từ LLaVA-Phi3 vào DB để tái sử dụng.
    """
    extraction = await call_llava_phi3(image_bytes)

    # Chuẩn hóa nhãn (lowercase, strip khoảng trắng)
    norm_label = extraction.detected_object.strip().lower()

    # Tra cứu trong Database (kiểm tra cả label lẫn common_word)
    existing_mapping = (
        db.query(ObjectMapping)
        .filter(func.lower(ObjectMapping.label) == norm_label)
        .first()
    )
    if not existing_mapping and extraction.common_word:
        norm_common = extraction.common_word.strip().lower()
        existing_mapping = (
            db.query(ObjectMapping)
            .filter(func.lower(ObjectMapping.common_word) == norm_common)
            .first()
        )

    # 1. Cache HIT -> Trả về ngay
    if existing_mapping:
        logger.info(f"Cache HIT cho vật thể '{norm_label}'. Trả về từ Database.")
        return ObjectMappingResponse.model_validate(existing_mapping), "cache"

    # 2. Cache MISS -> Lưu bản ghi mới vào Database
    logger.info(f"Cache MISS cho vật thể '{norm_label}'. Đang lưu bản ghi mới từ LLaVA-Phi3 vào Database...")
    new_mapping = ObjectMapping(
        label=norm_label,
        common_word=extraction.common_word or extraction.detected_object,
        vietnamese_meaning=extraction.vietnamese_meaning,
        academic_word=extraction.academic_word,
        ipa=extraction.ipa or "",
        band_score=extraction.band_score or "7.5",
        collocations=extraction.collocations or [],
        idioms=extraction.idioms or "",
        speaking_part1_example=extraction.speaking_part1_example or "",
        speaking_part1_translation=extraction.speaking_part1_translation or "",
    )

    try:
        db.add(new_mapping)
        db.commit()
        db.refresh(new_mapping)
        logger.info(f"Đã lưu thành công vật thể mới '{norm_label}' với ID={new_mapping.id} vào Database.")
    except Exception as db_err:
        db.rollback()
        logger.warning(f"Lỗi khi lưu vật thể vào DB (có thể trùng lặp concurrent): {db_err}")
        # Thử lấy lại nếu vừa được tạo bởi request song song
        existing_fallback = (
            db.query(ObjectMapping)
            .filter(func.lower(ObjectMapping.label) == norm_label)
            .first()
        )
        if existing_fallback:
            return ObjectMappingResponse.model_validate(existing_fallback), "cache"
        raise db_err

    return ObjectMappingResponse.model_validate(new_mapping), "ollama"
