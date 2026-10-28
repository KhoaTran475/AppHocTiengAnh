from datetime import datetime
import json
from sqlalchemy import Column, Integer, String, Boolean, DateTime, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.types import TypeDecorator
from app.db.session import Base


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


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    username = Column(String(100), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    role = Column(String(20), default="learner", nullable=False)  # 'learner' hoặc 'admin'
    supabase_uuid = Column(String(100), nullable=True)  # UUID tương ứng trên Supabase profiles

    # Cấu hình bảo mật sinh trắc học FaceID (ML Kit + ONNX MobileFaceNet)
    face_embedding = Column(UniversalJSON, nullable=True)  # 128-d float vector (JSONB / Text)
    is_face_auth_enabled = Column(Boolean, default=False, nullable=False)
    face_registered_at = Column(DateTime(timezone=True), nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    def __repr__(self):
        return f"<User id={self.id} username={self.username} role={self.role} face_auth={self.is_face_auth_enabled}>"
