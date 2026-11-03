import uuid
from datetime import datetime
from sqlalchemy import Column, Integer, BigInteger, String, Boolean, Float, DateTime, ForeignKey, JSON, UniqueConstraint, Text
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.types import TypeDecorator, CHAR
from app.db.session import Base


class UniversalUUID(TypeDecorator):
    """Platform-independent UUID type: PostgreSQL UUID or SQLite CHAR(36)."""
    impl = CHAR(36)
    cache_ok = True

    def load_dialect_impl(self, dialect):
        if dialect.name == "postgresql":
            return dialect.type_descriptor(PG_UUID(as_uuid=True))
        return dialect.type_descriptor(CHAR(36))

    def process_bind_param(self, value, dialect):
        if value is None:
            return None
        if isinstance(value, uuid.UUID):
            return value if dialect.name == "postgresql" else str(value)
        try:
            val_uuid = uuid.UUID(str(value))
            return val_uuid if dialect.name == "postgresql" else str(val_uuid)
        except Exception:
            return value

    def process_result_value(self, value, dialect):
        if value is None:
            return None
        if isinstance(value, uuid.UUID):
            return value
        try:
            return uuid.UUID(str(value))
        except Exception:
            return value


class SkillLesson(Base):
    __tablename__ = "skill_lessons"

    id = Column(String(50), primary_key=True, index=True)  # r1, r2, l1, l2..., s1, w1...
    skill_type = Column(String(20), index=True, nullable=False)  # 'reading', 'listening', 'speaking', 'writing'
    title = Column(String(255), nullable=False)
    category_or_topic = Column(String(150), nullable=True)
    band_score_target = Column(String(20), default="7.0", nullable=False)
    
    # Gamification specific fields (Áp dụng cho cả 4 kỹ năng)
    stage_number = Column(Integer, nullable=True, index=True)
    difficulty_label = Column(String(100), nullable=True)
    pass_score_required = Column(Integer, nullable=True)
    target_band = Column(Float, nullable=True)  # e.g. 6.5, 7.0, 8.0
    pass_condition = Column(JSON, nullable=True)  # e.g. {"min_correct": 2} or {"min_words": 150}

    # Toàn bộ nội dung bài học (paragraphs, questions, audio_script, essay prompt...)
    content_json = Column(JSON, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    def __repr__(self):
        return f"<SkillLesson id={self.id} type={self.skill_type} title={self.title}>"


class PracticeHistory(Base):
    __tablename__ = "practice_history"

    id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    user_id = Column(UniversalUUID, nullable=False, index=True)
    skill_type = Column(String(20), nullable=False, index=True)
    lesson_id = Column(String(50), nullable=False, index=True)
    lesson_title = Column(String(255), nullable=False)
    score = Column(Integer, default=0, nullable=False)
    total_questions = Column(Integer, default=0, nullable=False)
    band_score = Column(String(20), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    def __repr__(self):
        return f"<PracticeHistory user_id={self.user_id} skill={self.skill_type} band={self.band_score}>"


class UserStageProgress(Base):
    __tablename__ = "user_stage_progress"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    skill_type = Column(String(20), default="listening", nullable=False, index=True)  # 'reading', 'listening', 'speaking', 'writing'
    stage_number = Column(Integer, nullable=False)
    stars = Column(Integer, default=0, nullable=False)
    best_score = Column(Integer, default=0, nullable=False)
    is_unlocked = Column(Boolean, default=False, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    __table_args__ = (
        UniqueConstraint("user_id", "skill_type", "stage_number", name="uq_user_skill_stage"),
    )

    def __repr__(self):
        return f"<UserStageProgress user_id={self.user_id} skill={self.skill_type} stage={self.stage_number} stars={self.stars}>"


class AiExplanation(Base):
    """
    Bảng cache giải thích chi tiết đáp án IELTS Reading / Listening sinh bởi Qwen 2.5 7B.
    Khóa cache duy nhất theo (lesson_id, question_id, user_choice).
    Sử dụng UniversalUUID tương thích hoàn hảo Supabase PostgreSQL và SQLite.
    """
    __tablename__ = "ai_explanations"

    id = Column(UniversalUUID, primary_key=True, default=uuid.uuid4)
    lesson_id = Column(String(50), nullable=False, index=True)
    question_id = Column(String(50), nullable=False, index=True)
    user_choice = Column(String(255), nullable=False, index=True)
    is_correct = Column(Boolean, default=False, nullable=False)
    explanation_vi = Column(Text, nullable=False)
    why_correct = Column(Text, nullable=True)
    why_trap = Column(Text, nullable=True)
    key_vocabulary = Column(JSON, nullable=True)
    strategy_tips = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    __table_args__ = (
        UniqueConstraint("lesson_id", "question_id", "user_choice", name="uq_ai_explanation_choice"),
    )

    def __repr__(self):
        return f"<AiExplanation id={self.id} lesson={self.lesson_id} q={self.question_id}>"


class WritingFeedback(Base):
    """
    Bảng lưu trữ phản hồi chi tiết bài viết IELTS Writing sinh bởi Qwen 2.5 7B.
    Khóa ngoại practice_history_id kiểu BigInteger khớp chính xác với practice_history.id trên Supabase PostgreSQL.
    """
    __tablename__ = "writing_feedback"

    id = Column(UniversalUUID, primary_key=True, default=uuid.uuid4)
    practice_history_id = Column(BigInteger, ForeignKey("practice_history.id", ondelete="CASCADE"), nullable=True, index=True)
    user_id = Column(UniversalUUID, nullable=True, index=True)
    lesson_id = Column(String(50), nullable=False, index=True)
    overall_band = Column(String(20), nullable=False)
    
    # 4 Tiêu chí IELTS Writing
    task_response_band = Column(Float, nullable=True)
    task_response_comment = Column(Text, nullable=True)
    coherence_band = Column(Float, nullable=True)
    coherence_comment = Column(Text, nullable=True)
    lexical_band = Column(Float, nullable=True)
    lexical_comment = Column(Text, nullable=True)
    grammar_band = Column(Float, nullable=True)
    grammar_comment = Column(Text, nullable=True)

    # Danh sách lỗi đã kiểm tra so khớp quote (Chống Hallucination)
    errors_json = Column(JSON, nullable=True)
    strengths = Column(JSON, nullable=True)
    improvements = Column(JSON, nullable=True)
    improved_paragraph = Column(Text, nullable=True)
    ai_used = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    def __repr__(self):
        return f"<WritingFeedback id={self.id} band={self.overall_band}>"

