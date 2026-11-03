from datetime import datetime
from sqlalchemy import (
    Column,
    Integer,
    String,
    Text,
    DateTime,
    ForeignKey,
    JSON,
    UniqueConstraint,
)
from app.db.session import Base


class VocabLearningCard(Base):
    """
    Bảng lưu trữ thẻ học từ vựng phân cấp 5 Level (từ Cơ bản A2-B1 đến Nâng cao C2 / Band 8.5+).
    Hỗ trợ Thang nâng cấp từ (Word Upgrade Ladder: basic_word -> intermediate_word -> advanced_word)
    và lưu cache các thẻ từ do Ollama Qwen 2.5 sinh ra.
    """

    __tablename__ = "vocab_learning_cards"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    level = Column(Integer, index=True, nullable=False, default=1)  # 1..5
    cefr_level = Column(String(20), nullable=False, default="A2-B1")
    band_target = Column(String(20), nullable=False, default="5.5")
    topic = Column(String(150), index=True, nullable=False, default="General IELTS")

    # Từ trọng tâm của thẻ và Thang nâng cấp 3 bậc (Word Upgrade Ladder)
    word = Column(String(150), index=True, nullable=False)
    basic_word = Column(String(150), nullable=False)
    intermediate_word = Column(String(150), nullable=False)
    advanced_word = Column(String(150), nullable=False)

    ipa = Column(String(100), nullable=True, default="")
    part_of_speech = Column(String(50), nullable=True, default="noun")
    vietnamese_meaning = Column(String(255), nullable=False)

    # Mở rộng học thuật (JSON)
    collocations = Column(JSON, default=list, nullable=True)
    word_family = Column(JSON, default=dict, nullable=True)
    synonyms = Column(JSON, default=list, nullable=True)

    # Ngữ cảnh & Ví dụ từ cơ bản đến học thuật
    example_basic = Column(Text, nullable=True, default="")
    example_advanced = Column(Text, nullable=True, default="")
    example_translation = Column(Text, nullable=True, default="")
    nuance_note = Column(Text, nullable=True, default="")

    # Nguồn dữ liệu: 'seed' hoặc 'qwen2.5'
    source = Column(String(30), nullable=False, default="seed")
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    def __repr__(self):
        return f"<VocabLearningCard id={self.id} level={self.level} word={self.word} source={self.source}>"


class UserVocabMastery(Base):
    """
    Bảng theo dõi tiến độ ghi nhớ từng thẻ từ vựng của Học viên theo cơ chế Spaced Repetition (SRS).
    mastery_level:
      0 = Chưa học (New)
      1 = Quên / Cần ôn lại ngay (Learning)
      2 = Nhớ mang máng (Familiar)
      3 = Đã thuộc lòng (Mastered)
    """

    __tablename__ = "user_vocab_mastery"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    card_id = Column(Integer, ForeignKey("vocab_learning_cards.id", ondelete="CASCADE"), nullable=False, index=True)
    mastery_level = Column(Integer, default=0, nullable=False)  # 0..3
    review_count = Column(Integer, default=0, nullable=False)
    correct_streak = Column(Integer, default=0, nullable=False)
    last_reviewed_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    __table_args__ = (
        UniqueConstraint("user_id", "card_id", name="uq_user_vocab_card_mastery"),
    )

    def __repr__(self):
        return f"<UserVocabMastery user_id={self.user_id} card_id={self.card_id} mastery={self.mastery_level}>"


class SystemVocabConfig(Base):
    """
    Bảng lưu trữ cấu hình động quản trị phần Học từ vựng & Mô hình AI (Ollama Qwen).
    Được quản lý tập trung từ Web Admin Portal, áp dụng xuống Backend và Mobile App.
    """

    __tablename__ = "system_vocab_configs"

    id = Column(Integer, primary_key=True, index=True, default=1)
    active_model = Column(String(100), nullable=False, default="qwen2.5:7b")
    temperature = Column(Integer, nullable=False, default=3)  # Lưu dạng int = temp * 10 (vd: 3 = 0.3)
    default_gen_count = Column(Integer, nullable=False, default=5)  # Số từ vựng AI sinh mặc định (1..15)
    quiz_question_count = Column(Integer, nullable=False, default=5)  # Số câu kiểm tra vượt cấp (3..20)
    pass_percentage = Column(Integer, nullable=False, default=60)  # Tỷ lệ % đúng để qua ải (50..100)
    star_thresholds = Column(
        JSON,
        nullable=False,
        default=lambda: {"star1": 60, "star2": 80, "star3": 100},
    )
    auto_cache_enabled = Column(Integer, nullable=False, default=1)  # 1: Tự động lưu từ sinh vào DB
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    def __repr__(self):
        return f"<SystemVocabConfig model={self.active_model} quiz_q={self.quiz_question_count} pass={self.pass_percentage}%>"


