from datetime import datetime
from typing import Dict, List, Optional, Any, Union
from pydantic import BaseModel, Field


class SkillLessonResponse(BaseModel):
    id: str
    skill_type: str
    title: str
    category_or_topic: Optional[str] = None
    band_score_target: str
    stage_number: Optional[int] = None
    difficulty_label: Optional[str] = None
    pass_score_required: Optional[int] = None
    target_band: Optional[float] = None
    pass_condition: Optional[Dict[str, Any]] = None
    content_json: Dict[str, Any]

    class Config:
        from_attributes = True


class SkillLessonCreateRequest(BaseModel):
    id: Optional[str] = None
    skill_type: str = Field(..., pattern="^(reading|listening|speaking|writing)$")
    title: str
    category_or_topic: Optional[str] = None
    stage_number: int = Field(1, ge=1)
    difficulty_label: Optional[str] = None
    target_band: Optional[float] = 7.0
    band_score_target: Optional[str] = "7.0"
    pass_score_required: Optional[int] = None
    pass_condition: Optional[Dict[str, Any]] = None
    content_json: Dict[str, Any]


class SkillLessonUpdateRequest(BaseModel):
    title: Optional[str] = None
    category_or_topic: Optional[str] = None
    stage_number: Optional[int] = Field(None, ge=1)

    difficulty_label: Optional[str] = None
    target_band: Optional[float] = None
    band_score_target: Optional[str] = None
    pass_score_required: Optional[int] = None
    pass_condition: Optional[Dict[str, Any]] = None
    content_json: Optional[Dict[str, Any]] = None


class SkillLessonImportResponse(BaseModel):
    success: bool
    imported_count: int
    message: str
    errors: Optional[List[str]] = None


class SkillSubmissionRequest(BaseModel):
    lesson_id: str
    skill_type: str = Field(..., pattern="^(reading|listening|speaking|writing)$")
    answers: Optional[Dict[str, str]] = None  # Key là question_id (dạng chuỗi hoặc số), Value là đáp án người dùng chọn
    essay_text: Optional[str] = None         # Dành cho Writing
    ratings: Optional[Dict[str, int]] = None # Dành cho Speaking (fluency, vocabulary, pronunciation: 1-9)
    spoken_transcript: Optional[str] = None  # Bản ghi lời nói học viên (AI Speech-to-Text / Transcript)
    speaking_duration_seconds: Optional[int] = None  # Thời lượng nói (giây)


class SkillSubmissionResponse(BaseModel):
    lesson_id: str
    skill_type: str
    score: int
    total_questions: int
    band_score: str
    passed: bool
    stars: int
    feedback: Optional[str] = None
    question_results: Optional[List[Dict[str, Any]]] = None
    ai_evaluation: Optional[Dict[str, Any]] = None


class LearnerAnalyticsResponse(BaseModel):
    streak_days: int = 0
    is_active_today: bool = False
    total_tests_completed: int = 0
    total_stars_earned: int = 0
    overall_band: float = 0.0
    skill_bands: Dict[str, float] = Field(default_factory=dict)
    skill_attempts: Dict[str, int] = Field(default_factory=dict)
    active_weekdays: List[int] = Field(default_factory=list)


class PracticeHistoryResponse(BaseModel):
    id: int
    user_id: int
    skill_type: str
    lesson_id: str
    lesson_title: str
    score: int
    total_questions: int
    band_score: str
    created_at: datetime

    class Config:
        from_attributes = True


class StageItemProgress(BaseModel):
    stage_number: int
    stars: int
    best_score: int
    is_unlocked: bool


class ListeningProgressResponse(BaseModel):
    highest_unlocked_stage: int
    stages: List[StageItemProgress]


# Alias dùng chung cho cả 4 kỹ năng (reading, listening, writing, speaking)
SkillProgressResponse = ListeningProgressResponse
