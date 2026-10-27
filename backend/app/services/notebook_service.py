import logging
from typing import List, Optional
from sqlalchemy.orm import Session
from app.models.user import User
from app.models.notebook import VocabularyNotebook
from app.schemas.notebook import NotebookItemCreate
from app.core.supabase import get_supabase_admin

logger = logging.getLogger(__name__)


def resolve_user_uuid(db: Session, user: User) -> str:
    """Đảm bảo user luôn có UUID hợp lệ khớp với bảng profiles trên Supabase."""
    if user.supabase_uuid:
        return user.supabase_uuid
    try:
        supabase = get_supabase_admin()
        prof = (
            supabase.from_("profiles")
            .select("id")
            .eq("username", user.username)
            .maybe_single()
            .execute()
        )
        if prof.data and prof.data.get("id"):
            user.supabase_uuid = prof.data.get("id")
            db.commit()
            return user.supabase_uuid
        else:
            new_prof = (
                supabase.from_("profiles")
                .insert({"username": user.username, "role": user.role})
                .select("id")
                .single()
                .execute()
            )
            if new_prof.data and new_prof.data.get("id"):
                user.supabase_uuid = new_prof.data.get("id")
                db.commit()
                return user.supabase_uuid
    except Exception as e:
        logger.warning(f"Không thể resolve UUID từ Supabase: {e}")
    
    # Fallback mặc định
    return str(user.supabase_uuid or user.id)


def get_user_notebook(db: Session, user: User) -> List[VocabularyNotebook]:
    """Lấy danh sách tất cả các từ trong sổ tay của học viên."""
    uuid_str = resolve_user_uuid(db, user)
    return (
        db.query(VocabularyNotebook)
        .filter(VocabularyNotebook.user_id == uuid_str)
        .order_by(VocabularyNotebook.created_at.desc())
        .all()
    )


def is_word_saved(db: Session, user: User, label: str) -> bool:
    """Kiểm tra xem học viên đã lưu từ theo nhãn này hay chưa."""
    norm_label = label.strip().lower()
    uuid_str = resolve_user_uuid(db, user)
    return (
        db.query(VocabularyNotebook)
        .filter(
            VocabularyNotebook.user_id == uuid_str,
            VocabularyNotebook.label == norm_label,
        )
        .first()
        is not None
    )


def add_to_notebook(
    db: Session,
    user: User,
    item_in: NotebookItemCreate,
    sync_supabase: bool = True,
) -> VocabularyNotebook:
    """Lưu từ vựng mới vào sổ tay và đồng bộ lên Supabase cloud."""
    norm_label = item_in.label.strip().lower()
    uuid_str = resolve_user_uuid(db, user)

    # Kiểm tra xem từ này đã có trong sổ tay của user chưa
    existing = (
        db.query(VocabularyNotebook)
        .filter(
            VocabularyNotebook.user_id == uuid_str,
            VocabularyNotebook.label == norm_label,
        )
        .first()
    )
    if existing:
        return existing

    collocations_val = item_in.collocations
    if isinstance(collocations_val, str):
        collocations_val = [c.strip() for c in collocations_val.split(";") if c.strip()]
    elif collocations_val is None:
        collocations_val = []

    db_item = VocabularyNotebook(
        user_id=uuid_str,
        label=norm_label,
        word=item_in.word.strip(),
        ipa=item_in.ipa or "",
        translation=item_in.translation or "",
        example=item_in.example,
        example_translation=item_in.example_translation,
        band_score=item_in.band_score or "7.0",
        collocations=collocations_val,
        idioms=item_in.idioms or "",
    )
    db.add(db_item)
    db.commit()
    db.refresh(db_item)


    # Nếu DB không phải PostgreSQL trực tiếp (ví dụ đang dùng SQLite cục bộ),
    # đồng bộ qua REST API của Supabase
    is_postgres = db.bind and db.bind.dialect.name == "postgresql"
    if sync_supabase and not is_postgres:
        try:
            supabase = get_supabase_admin()
            if uuid_str:
                existing_cloud = (
                    supabase.table("vocabulary_notebook")
                    .select("id")
                    .match({"user_id": uuid_str, "label": db_item.label})
                    .execute()
                )
                if not existing_cloud.data:
                    supabase.table("vocabulary_notebook").insert({
                        "user_id": uuid_str,
                        "label": db_item.label,
                        "word": db_item.word,
                        "ipa": db_item.ipa,
                        "translation": db_item.translation,
                        "example": db_item.example,
                        "example_translation": db_item.example_translation,
                        "band_score": db_item.band_score,
                        "collocations": collocations_val,
                        "idioms": db_item.idioms,
                    }).execute()
                logger.info(f"Đã sync từ '{db_item.word}' của user '{user.username}' lên Supabase notebook!")
        except Exception as e:
            logger.warning(f"Lỗi khi sync notebook lên Supabase REST: {e}")

    return db_item


def delete_from_notebook(
    db: Session,
    user: User,
    item_id: int,
    sync_supabase: bool = True,
) -> bool:
    """Xóa một từ khỏi sổ tay của học viên (và xóa trên Supabase)."""
    uuid_str = resolve_user_uuid(db, user)
    item = (
        db.query(VocabularyNotebook)
        .filter(
            VocabularyNotebook.id == item_id,
            VocabularyNotebook.user_id == uuid_str,
        )
        .first()
    )
    if not item:
        raise ValueError("Không tìm thấy từ vựng cần xóa trong sổ tay của bạn")

    target_word = item.word
    db.delete(item)
    db.commit()

    is_postgres = db.bind and db.bind.dialect.name == "postgresql"
    if sync_supabase and not is_postgres and user.supabase_uuid:
        try:
            supabase = get_supabase_admin()
            supabase.table("vocabulary_notebook").delete().match({
                "user_id": user.supabase_uuid,
                "word": target_word,
            }).execute()
            logger.info(f"Đã xóa từ '{target_word}' trên Supabase notebook")
        except Exception as e:
            logger.warning(f"Lỗi khi xóa từ trên Supabase: {e}")

    return True

