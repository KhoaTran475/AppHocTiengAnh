from typing import Optional
from sqlalchemy.orm import Session
from sqlalchemy import or_
from app.models.mapping import ObjectMapping
from app.schemas.vocabulary import DictionaryLookupResponse

# Danh mục từ vựng học thuật IELTS hay gặp trong bài đọc (Reading passages)
COMMON_ACADEMIC_DICT = {
    "intelligence": {
        "ipa": "/ɪnˈtel.ɪ.dʒəns/",
        "meaning": "Trí thông minh, sự hiểu biết, năng lực trí tuệ",
        "pos": "noun",
        "band": "7.5",
        "example": "Artificial Intelligence is revolutionizing modern education."
    },
    "artificial": {
        "ipa": "/ˌɑː.tɪˈfɪʃ.əl/",
        "meaning": "Nhân tạo, do con người chế tạo",
        "pos": "adjective",
        "band": "7.0",
        "example": "Artificial materials are widely used in construction."
    },
    "education": {
        "ipa": "/ˌedʒ.ʊˈkeɪ.ʃən/",
        "meaning": "Nền giáo dục, sự đào tạo, rèn luyện",
        "pos": "noun",
        "band": "6.5",
        "example": "Higher education plays a critical role in economic development."
    },
    "altering": {
        "ipa": "/ˈɔːl.tər.ɪŋ/",
        "meaning": "Đang thay đổi, làm biến đổi",
        "pos": "verb",
        "band": "7.5",
        "example": "Technology is constantly altering our lifestyle."
    },
    "landscape": {
        "ipa": "/ˈlænd.skeɪp/",
        "meaning": "Bối cảnh, diện mạo, cảnh quan",
        "pos": "noun",
        "band": "7.0",
        "example": "The landscape of higher education is changing rapidly."
    },
    "leveraging": {
        "ipa": "/ˈliː.vər.ɪdʒ.ɪŋ/",
        "meaning": "Tận dụng, phát huy tối đa sức mạnh",
        "pos": "verb",
        "band": "8.0",
        "example": "Companies are leveraging data science to improve customer retention."
    },
    "biodiversity": {
        "ipa": "/ˌbaɪ.əʊ.daɪˈvɜː.sə.ti/",
        "meaning": "Đa dạng sinh học",
        "pos": "noun",
        "band": "8.0",
        "example": "Preserving biodiversity is crucial for ecosystem stability."
    },
    "conservation": {
        "ipa": "/ˌkɒn.səˈveɪ.ʃən/",
        "meaning": "Sự bảo tồn, gìn giữ môi trường tự nhiên",
        "pos": "noun",
        "band": "7.5",
        "example": "Wildlife conservation requires global cooperation."
    },
    "sustainable": {
        "ipa": "/səˈsteɪ.nə.bəl/",
        "meaning": "Bền vững, thân thiện với môi trường",
        "pos": "adjective",
        "band": "7.5",
        "example": "Sustainable energy sources are essential for the future."
    },
    "pedagogy": {
        "ipa": "/ˈped.ə.ɡɒdʒ.i/",
        "meaning": "Phương pháp sư phạm, khoa học giáo dục",
        "pos": "noun",
        "band": "8.5",
        "example": "Innovative pedagogy helps students absorb concepts effectively."
    },
}


def lookup_word(db: Session, word: str) -> Optional[DictionaryLookupResponse]:
    """Tra cứu từ vựng học thuật IELTS (Tap-to-Translate)."""
    cleaned = word.strip().lower()

    # 1. Tra trong bảng Object_Mappings
    mapping = (
        db.query(ObjectMapping)
        .filter(
            or_(
                ObjectMapping.academic_word.ilike(cleaned),
                ObjectMapping.common_word.ilike(cleaned),
                ObjectMapping.label.ilike(cleaned),
            )
        )
        .first()
    )

    if mapping:
        return DictionaryLookupResponse(
            word=mapping.academic_word or mapping.common_word,
            ipa=mapping.ipa or "",
            vietnamese_meaning=mapping.vietnamese_meaning,
            part_of_speech="academic vocabulary",
            band_score=mapping.band_score,
            example=mapping.speaking_part1_example,
        )

    # 2. Tra trong từ điển học thuật IELTS
    if cleaned in COMMON_ACADEMIC_DICT:
        entry = COMMON_ACADEMIC_DICT[cleaned]
        return DictionaryLookupResponse(
            word=cleaned,
            ipa=entry["ipa"],
            vietnamese_meaning=entry["meaning"],
            part_of_speech=entry["pos"],
            band_score=entry["band"],
            example=entry.get("example"),
        )

    return None
