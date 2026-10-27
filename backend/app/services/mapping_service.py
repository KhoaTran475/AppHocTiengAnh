import os
import json
import logging
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import or_
from app.models.mapping import ObjectMapping
from app.schemas.vocabulary import ObjectMappingCreate, ObjectMappingUpdate
from app.core.supabase import get_supabase_admin

logger = logging.getLogger(__name__)

# Đường dẫn tới file JSON dữ liệu gốc trong assets
JSON_ASSET_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))),
    "assets",
    "data",
    "ielts_vocab_80_labels.json",
)


def get_mapping_by_label(db: Session, label: str) -> Optional[ObjectMapping]:
    """Tìm từ vựng học thuật theo nhãn YOLO (vd: 'person', 'cell phone')."""
    normalized = label.strip().lower()
    return db.query(ObjectMapping).filter(ObjectMapping.label == normalized).first()


def get_mapping_by_id(db: Session, mapping_id: int) -> Optional[ObjectMapping]:
    """Tìm từ vựng theo ID."""
    return db.query(ObjectMapping).filter(ObjectMapping.id == mapping_id).first()


def get_all_mappings(
    db: Session,
    search: Optional[str] = None,
    band: Optional[str] = None,
    skip: int = 0,
    limit: int = 100,
) -> List[ObjectMapping]:
    """Lấy danh sách từ vựng, hỗ trợ tìm kiếm keyword và lọc theo Band điểm."""
    query = db.query(ObjectMapping)

    if search:
        kw = f"%{search.strip().lower()}%"
        query = query.filter(
            or_(
                ObjectMapping.label.ilike(kw),
                ObjectMapping.common_word.ilike(kw),
                ObjectMapping.academic_word.ilike(kw),
                ObjectMapping.vietnamese_meaning.ilike(kw),
            )
        )

    if band and band != "Tất cả":
        clean_band = band.replace("Band", "").strip()
        query = query.filter(ObjectMapping.band_score.ilike(f"%{clean_band}%"))

    return query.order_by(ObjectMapping.id.asc()).offset(skip).limit(limit).all()


def create_mapping(db: Session, mapping_in: ObjectMappingCreate, sync_supabase: bool = True) -> ObjectMapping:
    """Thêm mới một bản ghi từ vựng mapping."""
    norm_label = mapping_in.label.strip().lower()
    if get_mapping_by_label(db, norm_label):
        raise ValueError(f"Nhãn '{norm_label}' đã tồn tại trong kho từ điển")

    db_obj = ObjectMapping(
        label=norm_label,
        common_word=mapping_in.common_word,
        vietnamese_meaning=mapping_in.vietnamese_meaning,
        academic_word=mapping_in.academic_word,
        ipa=mapping_in.ipa,
        band_score=mapping_in.band_score,
        collocations=mapping_in.collocations or [],
        idioms=mapping_in.idioms,
        speaking_part1_example=mapping_in.speaking_part1_example,
        speaking_part1_translation=mapping_in.speaking_part1_translation,
    )
    db.add(db_obj)
    db.commit()
    db.refresh(db_obj)

    if sync_supabase:
        try:
            supabase = get_supabase_admin()
            supabase.table("object_mappings").upsert({
                "label": db_obj.label,
                "common_word": db_obj.common_word,
                "vietnamese_meaning": db_obj.vietnamese_meaning,
                "academic_word": db_obj.academic_word,
                "ipa": db_obj.ipa,
                "band_score": db_obj.band_score,
                "collocations": db_obj.collocations,
                "idioms": db_obj.idioms,
                "speaking_part1_example": db_obj.speaking_part1_example,
                "speaking_part1_translation": db_obj.speaking_part1_translation,
            }, on_conflict="label").execute()
        except Exception as e:
            logger.warning(f"Lỗi sync mapping '{db_obj.label}' lên Supabase: {e}")

    return db_obj


def update_mapping(db: Session, mapping_id: int, mapping_in: ObjectMappingUpdate, sync_supabase: bool = True) -> ObjectMapping:
    """Cập nhật thông tin từ vựng mapping."""
    db_obj = get_mapping_by_id(db, mapping_id)
    if not db_obj:
        raise ValueError(f"Không tìm thấy bản ghi từ vựng ID {mapping_id}")

    update_data = mapping_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_obj, field, value)

    db.commit()
    db.refresh(db_obj)

    if sync_supabase:
        try:
            supabase = get_supabase_admin()
            supabase.table("object_mappings").upsert({
                "label": db_obj.label,
                "common_word": db_obj.common_word,
                "vietnamese_meaning": db_obj.vietnamese_meaning,
                "academic_word": db_obj.academic_word,
                "ipa": db_obj.ipa,
                "band_score": db_obj.band_score,
                "collocations": db_obj.collocations,
                "idioms": db_obj.idioms,
                "speaking_part1_example": db_obj.speaking_part1_example,
                "speaking_part1_translation": db_obj.speaking_part1_translation,
            }, on_conflict="label").execute()
        except Exception as e:
            logger.warning(f"Lỗi sync update mapping lên Supabase: {e}")

    return db_obj


def delete_mapping(db: Session, mapping_id: int, sync_supabase: bool = True) -> bool:
    """Xóa một bản ghi từ vựng."""
    db_obj = get_mapping_by_id(db, mapping_id)
    if not db_obj:
        raise ValueError(f"Không tìm thấy bản ghi từ vựng ID {mapping_id}")

    label = db_obj.label
    db.delete(db_obj)
    db.commit()

    if sync_supabase:
        try:
            supabase = get_supabase_admin()
            supabase.table("object_mappings").delete().eq("label", label).execute()
        except Exception as e:
            logger.warning(f"Lỗi xóa mapping '{label}' trên Supabase: {e}")

    return True


def seed_default_mappings(db: Session):
    """Nạp 82 từ vựng IELTS chuẩn từ assets JSON nếu database trống."""
    count = db.query(ObjectMapping).count()
    if count >= 80:
        return

    logger.info(f"Đang nạp từ vựng ban đầu từ file: {JSON_ASSET_PATH}")
    if not os.path.exists(JSON_ASSET_PATH):
        logger.warning(f"Không tìm thấy file JSON: {JSON_ASSET_PATH}")
        return

    try:
        with open(JSON_ASSET_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)

        unique_labels = {}
        for item in data:
            raw_label = item.get("label")
            if not raw_label:
                continue
            norm = str(raw_label).strip().lower()
            unique_labels[norm] = item

        for norm, item in unique_labels.items():
            existing = get_mapping_by_label(db, norm)
            if not existing:
                colls = item.get("collocations", [])
                if isinstance(colls, str):
                    colls = [c.strip() for c in colls.split(";") if c.strip()]
                
                db_obj = ObjectMapping(
                    label=norm,
                    common_word=item.get("common_word", item.get("word", "")),
                    vietnamese_meaning=item.get("vietnamese_meaning", item.get("translation", "")),
                    academic_word=item.get("academic_word", item.get("word", "")),
                    ipa=item.get("ipa", ""),
                    band_score=str(item.get("band_score", "7.0")),
                    collocations=colls,
                    idioms=item.get("idioms", "") or "",
                    speaking_part1_example=item.get("speaking_part1_example", item.get("example", "")) or "",
                    speaking_part1_translation=item.get("speaking_part1_translation", item.get("example_translation", "")) or "",
                )
                db.add(db_obj)

        db.commit()
        logger.info(f"Đã seed thành công {len(unique_labels)} nhãn từ vựng IELTS vào Database!")
    except Exception as e:
        logger.error(f"Lỗi khi seed Object_Mappings: {e}")


def reset_mappings_to_default(db: Session):
    """Khôi phục toàn bộ từ vựng IELTS mặc định."""
    db.query(ObjectMapping).delete()
    db.commit()
    seed_default_mappings(db)
