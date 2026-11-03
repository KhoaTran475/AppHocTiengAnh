from typing import List, Optional
from pydantic import BaseModel, Field


class ObjectMappingBase(BaseModel):
    label: str = Field(..., description="Tên nhãn YOLOv8 (vd: person, cell phone)")
    common_word: str
    vietnamese_meaning: str
    academic_word: str
    ipa: Optional[str] = None
    band_score: str = Field(default="7.0")
    collocations: Optional[List[str]] = Field(default_factory=list)
    idioms: Optional[str] = None
    speaking_part1_example: Optional[str] = None
    speaking_part1_translation: Optional[str] = None


class ObjectMappingCreate(ObjectMappingBase):
    pass


class ObjectMappingUpdate(BaseModel):
    common_word: Optional[str] = None
    vietnamese_meaning: Optional[str] = None
    academic_word: Optional[str] = None
    ipa: Optional[str] = None
    band_score: Optional[str] = None
    collocations: Optional[List[str]] = None
    idioms: Optional[str] = None
    speaking_part1_example: Optional[str] = None
    speaking_part1_translation: Optional[str] = None


class ObjectMappingResponse(ObjectMappingBase):
    id: int

    class Config:
        from_attributes = True


class BoundingBox(BaseModel):
    xmin: float
    ymin: float
    xmax: float
    ymax: float


class DetectedObject(BaseModel):
    label: str
    confidence: float
    box: BoundingBox
    vocabulary: Optional[ObjectMappingResponse] = None


class VisionDetectionResponse(BaseModel):
    total_detected: int
    detections: List[DetectedObject]


class DictionaryLookupResponse(BaseModel):
    word: str
    ipa: str
    vietnamese_meaning: str
    part_of_speech: Optional[str] = "academic word"
    band_score: Optional[str] = "7.0+"
    example: Optional[str] = None


class OllamaVisionExtraction(BaseModel):
    detected_object: str = Field(..., description="Tên đối tượng bằng tiếng Anh (ví dụ: spectacles, pen, wristwatch)")
    common_word: Optional[str] = Field(default=None, description="Từ thông dụng")
    vietnamese_meaning: str = Field(..., description="Nghĩa tiếng Việt")
    academic_word: str = Field(..., description="Từ vựng học thuật IELTS tương đương Band 7.0 - 8.5")
    ipa: Optional[str] = Field(default="", description="Phiên âm IPA")
    band_score: str = Field(default="7.5", description="Band điểm IELTS ước tính")
    collocations: List[str] = Field(default_factory=list, description="Cụm từ thường đi kèm")
    idioms: Optional[str] = Field(default="", description="Thành ngữ liên quan nếu có")
    speaking_part1_example: Optional[str] = Field(default="", description="Ví dụ câu trả lời IELTS Speaking Part 1")
    speaking_part1_translation: Optional[str] = Field(default="", description="Bản dịch tiếng Việt của câu ví dụ")


class DeepScanResponse(BaseModel):
    source: str = Field(..., description="'cache' nếu lấy từ DB, 'ollama' nếu vừa sinh mới")
    vocabulary: ObjectMappingResponse

