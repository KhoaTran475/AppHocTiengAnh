from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


class AiGradingLogItem(BaseModel):
    id: str
    created_at: datetime
    user_id: Optional[str] = None
    username: Optional[str] = None
    feature: str
    skill_type: str
    lesson_id: Optional[str] = None
    lesson_title: Optional[str] = None
    question_id: Optional[str] = None
    vocab_word: Optional[str] = None
    vocab_level: Optional[int] = None
    input_text: Optional[str] = None
    input_word_count: Optional[int] = None
    band_score: Optional[str] = None
    score_numeric: Optional[float] = None
    is_correct: Optional[bool] = None
    result_json: Optional[Dict[str, Any]] = None
    status: str
    model_name: Optional[str] = None
    ai_used: bool
    from_cache: bool
    latency_ms: int
    error_message: Optional[str] = None

    class Config:
        from_attributes = True


class AiGradingLogPageResponse(BaseModel):
    items: List[AiGradingLogItem]
    total: int
    page: int
    page_size: int
    total_pages: int


class AiGradingStatsResponse(BaseModel):
    total_requests: int
    feature_counts: Dict[str, int]
    status_counts: Dict[str, int]
    avg_latency_ms: int
    cache_hits: int
    cache_hit_rate: float
    writing_avg_band: Optional[float] = None
    vocab_avg_score: Optional[float] = None


class AiGradingBulkDeleteRequest(BaseModel):
    ids: List[str] = Field(..., min_length=1, description="Danh sách các UUID log cần xóa")

