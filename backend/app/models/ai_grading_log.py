import uuid
from datetime import datetime
from sqlalchemy import Column, Integer, BigInteger, String, Boolean, Float, DateTime, JSON, Text
from app.db.session import Base
from app.models.skill import UniversalUUID


class AiGradingLog(Base):
    """
    Bảng lưu trữ tập trung lịch sử chấm điểm & giải thích của mô hình AI Qwen 2.5:
    - Writing: Chấm 4 tiêu chí IELTS Writing (Task 1 / Task 2)
    - Reading / Listening: Giải thích chi tiết đáp án & phân tích bẫy
    - Vocabulary: Chấm điểm đặt câu (AI Sentence Lab) & gợi ý 3 bậc nâng cấp câu
    
    Tương thích 100% giữa SQLite local và Supabase PostgreSQL qua UniversalUUID.
    """
    __tablename__ = "ai_grading_logs"

    id = Column(UniversalUUID, primary_key=True, default=uuid.uuid4)
    user_id = Column(UniversalUUID, nullable=True, index=True)
    username = Column(String(100), nullable=True, index=True)

    # Phân loại nghiệp vụ
    # feature: 'writing_grading' | 'reading_explain' | 'listening_explain' | 'vocab_sentence'
    feature = Column(String(50), nullable=False, index=True)
    # skill_type: 'writing' | 'reading' | 'listening' | 'vocabulary'
    skill_type = Column(String(20), nullable=False, index=True)

    # Ngữ cảnh bài thi / bài học / từ vựng
    lesson_id = Column(String(50), nullable=True, index=True)
    lesson_title = Column(String(255), nullable=True)
    question_id = Column(String(50), nullable=True)
    vocab_word = Column(String(100), nullable=True, index=True)
    vocab_level = Column(Integer, nullable=True)

    # Dữ liệu học viên nộp vào
    input_text = Column(Text, nullable=True)
    input_word_count = Column(Integer, nullable=True)

    # Kết quả đánh giá
    band_score = Column(String(20), nullable=True)  # e.g. "6.5", "7.0"
    score_numeric = Column(Float, nullable=True)    # Điểm dạng số để tính trung bình và sắp xếp
    is_correct = Column(Boolean, nullable=True)     # True/False nếu có
    result_json = Column(JSON, nullable=True)       # Toàn bộ JSON chi tiết

    # Trạng thái vận hành AI
    model_name = Column(String(100), nullable=True, default="qwen2.5:7b")
    ai_used = Column(Boolean, default=True, nullable=False)
    from_cache = Column(Boolean, default=False, nullable=False)
    # status: 'success' | 'fallback' | 'error'
    status = Column(String(20), default="success", nullable=False, index=True)
    error_message = Column(Text, nullable=True)
    latency_ms = Column(Integer, default=0, nullable=False)
    prompt_tokens = Column(Integer, nullable=True)
    completion_tokens = Column(Integer, nullable=True)

    # Khóa ngoại liên kết
    practice_history_id = Column(BigInteger, nullable=True, index=True)
    writing_feedback_id = Column(UniversalUUID, nullable=True, index=True)

    created_at = Column(DateTime, default=datetime.utcnow, index=True, nullable=False)

    def __repr__(self):
        return f"<AiGradingLog id={self.id} feature={self.feature} user={self.username} status={self.status}>"

