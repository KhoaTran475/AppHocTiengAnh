from datetime import datetime
from typing import List, Optional, Dict
from pydantic import BaseModel, Field


class VocabCardBase(BaseModel):
    level: int = Field(default=1, ge=1, le=5, description="Cấp độ từ 1 (Cơ bản) đến 5 (Bậc thầy)")
    cefr_level: str = Field(default="A2-B1", description="Khung tham chiếu CEFR: A2-B1, B1-B2, B2-C1, C1, C2")
    band_target: str = Field(default="5.5", description="Mục tiêu Band IELTS tương ứng")
    topic: str = Field(default="General IELTS", description="Chủ đề từ vựng")

    word: str = Field(..., description="Từ vựng trọng tâm của thẻ")
    basic_word: str = Field(..., description="Từ bậc Cơ bản (Band 4.5 - 5.5)")
    intermediate_word: str = Field(..., description="Từ bậc Trung cấp (Band 6.0 - 6.5)")
    advanced_word: str = Field(..., description="Từ bậc Nâng cao / Học thuật (Band 7.5 - 8.5+)")

    ipa: Optional[str] = Field(default="", description="Phiên âm IPA")
    part_of_speech: Optional[str] = Field(default="noun", description="Từ loại (noun, verb, adjective, adverb)")
    vietnamese_meaning: str = Field(..., description="Nghĩa tiếng Việt chuẩn xác")

    collocations: List[str] = Field(default_factory=list, description="Danh sách cụm từ cố định (Collocations)")
    word_family: Dict[str, str] = Field(default_factory=dict, description="Gia đình từ (noun, verb, adj, adv)")
    synonyms: List[str] = Field(default_factory=list, description="Từ đồng nghĩa học thuật")

    example_basic: Optional[str] = Field(default="", description="Câu ví dụ ở mức cơ bản")
    example_advanced: Optional[str] = Field(default="", description="Câu ví dụ ở mức nâng cao / IELTS")
    example_translation: Optional[str] = Field(default="", description="Bản dịch tiếng Việt của câu ví dụ nâng cao")
    nuance_note: Optional[str] = Field(default="", description="Ghi chú sắc thái nghĩa & cách dùng từ AI Qwen 2.5")
    source: str = Field(default="seed", description="Nguồn dữ liệu: 'seed' hoặc 'qwen2.5'")


class VocabCardCreate(VocabCardBase):
    pass


class VocabCardResponse(VocabCardBase):
    id: int
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class VocabCardWithMasteryResponse(VocabCardResponse):
    mastery_level: int = Field(default=0, description="0: Chưa học, 1: Quên, 2: Nhớ sơ, 3: Đã thuộc")
    review_count: int = Field(default=0)
    correct_streak: int = Field(default=0)


class VocabLevelInfoResponse(BaseModel):
    level: int
    title: str
    subtitle: str
    cefr_level: str
    band_target: str
    total_cards: int
    mastered_cards: int
    learning_cards: int
    stars: int = 0
    best_score: int = 0
    is_unlocked: bool = True
    topics: List[str] = Field(default_factory=list)


class VocabRoadmapResponse(BaseModel):
    highest_unlocked_level: int = 1
    total_cards_in_system: int = 0
    total_mastered_by_user: int = 0
    total_learning_by_user: int = 0
    ollama_model: str = "qwen2.5:latest"
    levels: List[VocabLevelInfoResponse] = Field(default_factory=list)


class OllamaStatusResponse(BaseModel):
    online: bool
    base_url: str
    configured_model: str
    resolved_model: str
    available_models: List[str] = Field(default_factory=list)
    message: str


class OllamaGenerateVocabRequest(BaseModel):
    topic: str = Field(..., min_length=2, max_length=120, description="Chủ đề muốn AI Qwen 2.5 sinh từ vựng")
    level: int = Field(default=1, ge=1, le=5, description="Cấp độ từ 1 (Cơ bản) đến 5 (Bậc thầy)")
    count: int = Field(default=5, ge=1, le=10, description="Số lượng thẻ từ muốn sinh (1-10)")


class OllamaGenerateVocabResponse(BaseModel):
    source: str = Field(..., description="'qwen2.5' nếu vừa sinh từ Ollama, 'cache' nếu lấy từ DB")
    model_used: str
    topic: str
    level: int
    cards: List[VocabCardWithMasteryResponse]


class OllamaSentenceEvaluateRequest(BaseModel):
    word: str = Field(..., min_length=1, description="Từ vựng mục tiêu đang luyện tập")
    level: int = Field(default=2, ge=1, le=5, description="Cấp độ hiện tại (1..5)")
    user_sentence: str = Field(..., min_length=3, max_length=600, description="Câu do học viên tự đặt")


class OllamaSentenceEvaluateResponse(BaseModel):
    word: str
    user_sentence: str
    is_correct_usage: bool = Field(..., description="Đã dùng từ đúng ngữ pháp & ngữ cảnh chưa")
    score: int = Field(default=70, ge=0, le=100, description="Điểm đánh giá câu (0 - 100)")
    estimated_band: str = Field(default="6.5", description="Band IELTS ước tính của câu")
    corrected_sentence: str = Field(..., description="Câu đã được sửa lỗi ngữ pháp & tự nhiên hơn")
    feedback_vi: str = Field(..., description="Nhận xét chi tiết bằng tiếng Việt từ AI Qwen 2.5")
    upgraded_basic: str = Field(..., description="Phiên bản câu ở mức Cơ bản (Band 5.0 - 5.5)")
    upgraded_intermediate: str = Field(..., description="Phiên bản câu ở mức Trung cấp (Band 6.5)")
    upgraded_advanced: str = Field(..., description="Phiên bản câu ở mức Nâng cao / Học thuật (Band 8.0+)")
    key_collocations_used: List[str] = Field(default_factory=list, description="Các cụm từ hay gợi ý áp dụng")
    model_used: str = Field(default="qwen2.5:latest")


class MasteryUpdateRequest(BaseModel):
    card_id: int
    mastery_level: int = Field(..., ge=0, le=3, description="0: Chưa học, 1: Quên, 2: Nhớ sơ, 3: Đã thuộc")


class MasteryUpdateResponse(BaseModel):
    card_id: int
    mastery_level: int
    review_count: int
    correct_streak: int
    message: str


class VocabQuizQuestionSchema(BaseModel):
    id: int
    question_type: str = Field(
        default="contextual_mcq",
        description="Loại câu hỏi: 'contextual_mcq' | 'word_upgrade' | 'fill_blank'",
    )
    prompt: str = Field(..., description="Nội dung câu hỏi")
    target_word: str = Field(..., description="Từ vựng trọng tâm")
    options: List[str] = Field(..., description="4 phương án lựa chọn")
    correct_answer: str = Field(..., description="Đáp án đúng")
    explanation_vi: str = Field(..., description="Giải thích đáp án bằng tiếng Việt")


class VocabQuizGenerateRequest(BaseModel):
    level: int = Field(default=1, ge=1, le=5)
    topic: Optional[str] = None
    question_count: int = Field(default=5, ge=3, le=10)
    use_ai_qwen: bool = Field(default=True, description="Có gọi Qwen 2.5 tạo câu hỏi ngữ cảnh mới không")


class VocabQuizResponse(BaseModel):
    level: int
    topic: str
    source: str = Field(default="qwen2.5", description="'qwen2.5' hoặc 'database'")
    pass_score_required: int = 3
    questions: List[VocabQuizQuestionSchema]


class VocabQuizSubmitRequest(BaseModel):
    level: int = Field(..., ge=1, le=5)
    score: int = Field(..., ge=0)
    total_questions: int = Field(..., ge=1)
    mastered_card_ids: List[int] = Field(default_factory=list)


class VocabQuizSubmitResponse(BaseModel):
    level: int
    score: int
    total_questions: int
    passed: bool
    stars_earned: int
    band_equivalent: str
    unlocked_next_level: bool
    highest_unlocked_level: int
    feedback: str


# ─────────────────────────────────────────────────────────────
# SCHEMAS CẤU HÌNH ĐỘNG HỌC TỪ VỰNG & MÔ HÌNH AI (OLLAMA QWEN)
# ─────────────────────────────────────────────────────────────

class SystemVocabConfigResponse(BaseModel):
    id: int = 1
    active_model: str = "qwen2.5:7b"
    temperature: float = 0.3
    default_gen_count: int = 5
    quiz_question_count: int = 5
    pass_percentage: int = 60
    star_thresholds: Dict[str, int] = Field(
        default_factory=lambda: {"star1": 60, "star2": 80, "star3": 100}
    )
    auto_cache_enabled: bool = True
    updated_at: Optional[datetime] = None
    # Trạng thái runtime Ollama
    is_ollama_online: bool = False
    available_models: List[str] = Field(default_factory=list)
    ollama_base_url: str = "http://localhost:11434"

    class Config:
        from_attributes = True


class SystemVocabConfigUpdate(BaseModel):
    active_model: Optional[str] = Field(None, min_length=2, max_length=100)
    temperature: Optional[float] = Field(None, ge=0.0, le=1.0)
    default_gen_count: Optional[int] = Field(None, ge=1, le=15)
    quiz_question_count: Optional[int] = Field(None, ge=3, le=20)
    pass_percentage: Optional[int] = Field(None, ge=50, le=100)
    star_thresholds: Optional[Dict[str, int]] = None
    auto_cache_enabled: Optional[bool] = None


class OllamaModelTestRequest(BaseModel):
    model_name: str = Field(..., min_length=2, description="Tên model muốn kiểm tra")
    test_prompt: Optional[str] = Field(
        None,
        description="Prompt thử nghiệm (tùy chọn, để trống sẽ dùng prompt kiểm tra sinh JSON từ vựng mẫu)",
    )


class OllamaModelTestResponse(BaseModel):
    success: bool
    model: str
    latency_ms: int
    message: str
    sample_response: Optional[str] = None


