from datetime import datetime
from sqlalchemy import Column, Integer, String, Boolean, Float, DateTime, ForeignKey, JSON, UniqueConstraint
from app.db.session import Base


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

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
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
