from sqlalchemy import Column, Integer, String, Text, JSON
from app.db.session import Base


class ObjectMapping(Base):
    __tablename__ = "object_mappings"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    label = Column(String(100), unique=True, index=True, nullable=False)
    common_word = Column(String(150), nullable=False)
    vietnamese_meaning = Column(String(255), nullable=False)
    academic_word = Column(String(150), nullable=False)
    ipa = Column(String(100), nullable=True)
    band_score = Column(String(20), default="7.0", nullable=False)
    collocations = Column(JSON, default=list, nullable=True)
    idioms = Column(Text, nullable=True)
    speaking_part1_example = Column(Text, nullable=True)
    speaking_part1_translation = Column(Text, nullable=True)

    def __repr__(self):
        return f"<ObjectMapping label={self.label} academic={self.academic_word} band={self.band_score}>"
