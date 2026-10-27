from datetime import datetime
from typing import Optional, Union, List
from pydantic import BaseModel, Field, field_validator


class NotebookItemCreate(BaseModel):
    label: str = Field(..., description="Nhãn nhận diện từ vựng")
    word: str = Field(..., description="Từ tiếng Anh cần lưu")
    ipa: Optional[str] = None
    translation: Optional[str] = None
    example: Optional[str] = None
    example_translation: Optional[str] = None
    band_score: str = Field(default="7.0")
    collocations: Optional[Union[str, List[str]]] = None
    idioms: Optional[str] = None

    @field_validator("collocations", mode="before")
    @classmethod
    def format_collocations(cls, v):
        if isinstance(v, list):
            return "; ".join([str(item) for item in v])
        return v


class NotebookItemResponse(BaseModel):
    id: int
    user_id: Union[int, str]
    label: str
    word: str
    ipa: Optional[str] = None
    translation: Optional[str] = None
    example: Optional[str] = None
    example_translation: Optional[str] = None
    band_score: str
    collocations: Optional[str] = None
    idioms: Optional[str] = None
    created_at: datetime

    @field_validator("collocations", mode="before")
    @classmethod
    def format_collocations_response(cls, v):
        if isinstance(v, list):
            return "; ".join([str(item) for item in v])
        return v

    class Config:
        from_attributes = True

