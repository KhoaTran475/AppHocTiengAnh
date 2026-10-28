from datetime import datetime
import json
from sqlalchemy import Column, Integer, String, Text, DateTime
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.types import TypeDecorator
from app.db.session import Base


class UniversalUUID(TypeDecorator):
    """Platform-independent UUID type: PostgreSQL UUID or SQLite String."""
    impl = String(36)
    cache_ok = True

    def load_dialect_impl(self, dialect):
        if dialect.name == "postgresql":
            return dialect.type_descriptor(UUID(as_uuid=False))
        return dialect.type_descriptor(String(36))


class UniversalJSON(TypeDecorator):
    """Platform-independent JSON type: PostgreSQL JSONB or SQLite Text."""
    impl = Text
    cache_ok = True

    def load_dialect_impl(self, dialect):
        if dialect.name == "postgresql":
            return dialect.type_descriptor(JSONB)
        return dialect.type_descriptor(Text)

    def process_bind_param(self, value, dialect):
        if value is None or dialect.name == "postgresql":
            return value
        if isinstance(value, str):
            return value
        return json.dumps(value, ensure_ascii=False)

    def process_result_value(self, value, dialect):
        if value is None or dialect.name == "postgresql":
            return value
        if isinstance(value, str):
            try:
                return json.loads(value)
            except Exception:
                return value
        return value


class VocabularyNotebook(Base):
    __tablename__ = "vocabulary_notebook"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(UniversalUUID, nullable=False, index=True)
    label = Column(String(100), nullable=False, index=True)
    word = Column(String(150), nullable=False)
    ipa = Column(String(100), nullable=True)
    translation = Column(Text, nullable=True)
    example = Column(Text, nullable=True)
    example_translation = Column(Text, nullable=True)
    band_score = Column(String(20), default="7.0", nullable=False)
    collocations = Column(UniversalJSON, nullable=True)
    idioms = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    def __repr__(self):
        return f"<VocabularyNotebook id={self.id} user_id={self.user_id} word={self.word}>"

