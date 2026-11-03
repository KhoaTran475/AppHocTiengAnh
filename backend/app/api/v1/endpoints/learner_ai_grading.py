from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.services.notebook_service import resolve_user_uuid
from app.services.ai_grading_log_service import get_ai_grading_logs
from app.schemas.ai_grading_log import AiGradingLogPageResponse, AiGradingLogItem

router = APIRouter()


@router.get(
    "/my-history",
    response_model=AiGradingLogPageResponse,
    summary="Lấy lịch sử chấm điểm AI của chính học viên (Writing, Từ Vựng, Explain)",
)
def get_my_ai_grading_history(
    feature: Optional[str] = Query(None, description="writing_grading, vocab_sentence, reading_explain, listening_explain"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Trả về toàn bộ lịch sử chấm bài thi Writing, bài luyện đặt câu Từ Vựng
    và giải thích câu hỏi do AI Qwen 2.5 chấm cho chính tài khoản đang đăng nhập.
    """
    user_uuid = resolve_user_uuid(db, current_user)

    data = get_ai_grading_logs(
        db=db,
        feature=feature,
        user_id=user_uuid,
        username=current_user.username,
        page=page,
        page_size=page_size,
    )

    items = []
    for it in data["items"]:
        items.append(
            AiGradingLogItem(
                id=str(it.id),
                created_at=it.created_at,
                user_id=str(it.user_id) if it.user_id else None,
                username=it.username,
                feature=it.feature,
                skill_type=it.skill_type,
                lesson_id=it.lesson_id,
                lesson_title=it.lesson_title,
                question_id=it.question_id,
                vocab_word=it.vocab_word,
                vocab_level=it.vocab_level,
                input_text=it.input_text,
                input_word_count=it.input_word_count,
                band_score=it.band_score,
                score_numeric=it.score_numeric,
                is_correct=it.is_correct,
                result_json=it.result_json,
                status=it.status,
                model_name=it.model_name,
                ai_used=it.ai_used,
                from_cache=it.from_cache,
                latency_ms=it.latency_ms,
                error_message=it.error_message,
            )
        )

    return AiGradingLogPageResponse(
        items=items,
        total=data["total"],
        page=data["page"],
        page_size=data["page_size"],
        total_pages=data["total_pages"],
    )

