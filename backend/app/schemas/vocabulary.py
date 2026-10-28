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
    label: Optional[str] = None
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
