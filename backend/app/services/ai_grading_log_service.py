import csv
import io
import logging
import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional, Tuple

from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.models.ai_grading_log import AiGradingLog
from app.models.skill import WritingFeedback

logger = logging.getLogger(__name__)


def log_ai_grading(
    db: Session,
    feature: str,
    skill_type: str,
    user_id: Optional[Any] = None,
    username: Optional[str] = None,
    lesson_id: Optional[str] = None,
    lesson_title: Optional[str] = None,
    question_id: Optional[str] = None,
    vocab_word: Optional[str] = None,
    vocab_level: Optional[int] = None,
    input_text: Optional[str] = None,
    input_word_count: Optional[int] = None,
    band_score: Optional[str] = None,
    score_numeric: Optional[float] = None,
    is_correct: Optional[bool] = None,
    result_json: Optional[Dict[str, Any]] = None,
    model_name: Optional[str] = "qwen2.5:7b",
    ai_used: bool = True,
    from_cache: bool = False,
    status: str = "success",
    error_message: Optional[str] = None,
    latency_ms: int = 0,
    prompt_tokens: Optional[int] = None,
    completion_tokens: Optional[int] = None,
    practice_history_id: Optional[int] = None,
    writing_feedback_id: Optional[Any] = None,
) -> Optional[AiGradingLog]:
    """
    Hàm an toàn tuyệt đối ghi log lịch sử chấm điểm / giải thích của Qwen 2.5.
    Không bao giờ throw exception làm hỏng luồng nộp bài của học viên.
    """
    try:
        # Chuẩn hóa user_id thành UUID hợp lệ nếu có
        norm_user_uuid = None
        if user_id:
            try:
                norm_user_uuid = uuid.UUID(str(user_id))
            except Exception:
                norm_user_uuid = None

        # Chuẩn hóa writing_feedback_id thành UUID nếu có
        norm_wf_uuid = None
        if writing_feedback_id:
            try:
                norm_wf_uuid = uuid.UUID(str(writing_feedback_id))
            except Exception:
                norm_wf_uuid = None

        # Tự động tính số từ nếu chưa có
        if input_word_count is None and input_text:
            input_word_count = len(input_text.strip().split())

        log_entry = AiGradingLog(
            user_id=norm_user_uuid,
            username=username,
            feature=feature,
            skill_type=skill_type,
            lesson_id=lesson_id,
            lesson_title=lesson_title,
            question_id=str(question_id) if question_id is not None else None,
            vocab_word=vocab_word,
            vocab_level=vocab_level,
            input_text=input_text,
            input_word_count=input_word_count,
            band_score=str(band_score) if band_score is not None else None,
            score_numeric=score_numeric,
            is_correct=is_correct,
            result_json=result_json,
            model_name=model_name or "qwen2.5:7b",
            ai_used=ai_used,
            from_cache=from_cache,
            status=status,
            error_message=error_message,
            latency_ms=max(0, int(latency_ms or 0)),
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            practice_history_id=practice_history_id,
            writing_feedback_id=norm_wf_uuid,
            created_at=datetime.utcnow(),
        )

        db.add(log_entry)
        db.commit()
        db.refresh(log_entry)
        logger.info(
            f"📝 [AiGradingLog] Đã lưu log '{feature}' cho user='{username or norm_user_uuid}' "
            f"(status={status}, latency={latency_ms}ms, band/score={band_score or score_numeric})"
        )
        return log_entry
    except Exception as e:
        db.rollback()
        logger.warning(f"⚠️ Không thể lưu AiGradingLog: {e}")
        return None


def get_ai_grading_logs(
    db: Session,
    feature: Optional[str] = None,
    skill_type: Optional[str] = None,
    user_id: Optional[Any] = None,
    username: Optional[str] = None,
    status: Optional[str] = None,
    ai_used: Optional[bool] = None,
    from_cache: Optional[bool] = None,
    search: Optional[str] = None,
    date_from: Optional[datetime] = None,
    date_to: Optional[datetime] = None,
    page: int = 1,
    page_size: int = 20,
) -> Dict[str, Any]:
    """Lấy danh sách log chấm điểm AI có phân trang và bộ lọc nâng cao."""
    query = db.query(AiGradingLog)

    if feature and feature != "all":
        query = query.filter(AiGradingLog.feature == feature.strip())

    if skill_type and skill_type != "all":
        query = query.filter(AiGradingLog.skill_type == skill_type.strip())

    if user_id:
        try:
            uid = uuid.UUID(str(user_id))
            query = query.filter(AiGradingLog.user_id == uid)
        except Exception:
            pass
    elif username and username.strip():
        query = query.filter(AiGradingLog.username.ilike(f"%{username.strip()}%"))

    if status and status != "all":
        query = query.filter(AiGradingLog.status == status.strip())

    if ai_used is not None:
        query = query.filter(AiGradingLog.ai_used == ai_used)

    if from_cache is not None:
        query = query.filter(AiGradingLog.from_cache == from_cache)

    if date_from:
        query = query.filter(AiGradingLog.created_at >= date_from)

    if date_to:
        query = query.filter(AiGradingLog.created_at <= date_to)

    if search and search.strip():
        term = f"%{search.strip()}%"
        query = query.filter(
            or_(
                AiGradingLog.lesson_title.ilike(term),
                AiGradingLog.vocab_word.ilike(term),
                AiGradingLog.input_text.ilike(term),
                AiGradingLog.error_message.ilike(term),
                AiGradingLog.username.ilike(term),
            )
        )

    total = query.count()
    page = max(1, page)
    page_size = max(1, min(100, page_size))
    total_pages = (total + page_size - 1) // page_size if total > 0 else 1

    items = (
        query.order_by(AiGradingLog.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )

    return {
        "items": items,
        "total": total,
        "page": page,
        "page_size": page_size,
        "total_pages": total_pages,
    }


def get_ai_grading_log_detail(db: Session, log_id: str) -> Optional[Dict[str, Any]]:
    """Lấy chi tiết 1 bản ghi log chấm điểm kèm dữ liệu liên kết nếu có."""
    try:
        lid = uuid.UUID(str(log_id))
    except Exception:
        return None

    log = db.query(AiGradingLog).filter(AiGradingLog.id == lid).first()
    if not log:
        return None

    detail = {
        "id": str(log.id),
        "user_id": str(log.user_id) if log.user_id else None,
        "username": log.username,
        "feature": log.feature,
        "skill_type": log.skill_type,
        "lesson_id": log.lesson_id,
        "lesson_title": log.lesson_title,
        "question_id": log.question_id,
        "vocab_word": log.vocab_word,
        "vocab_level": log.vocab_level,
        "input_text": log.input_text,
        "input_word_count": log.input_word_count,
        "band_score": log.band_score,
        "score_numeric": log.score_numeric,
        "is_correct": log.is_correct,
        "result_json": log.result_json,
        "model_name": log.model_name,
        "ai_used": log.ai_used,
        "from_cache": log.from_cache,
        "status": log.status,
        "error_message": log.error_message,
        "latency_ms": log.latency_ms,
        "prompt_tokens": log.prompt_tokens,
        "completion_tokens": log.completion_tokens,
        "practice_history_id": log.practice_history_id,
        "writing_feedback_id": str(log.writing_feedback_id) if log.writing_feedback_id else None,
        "created_at": log.created_at.isoformat() if log.created_at else None,
    }

    # Bổ sung thông tin WritingFeedback nếu có
    if log.writing_feedback_id:
        wf = db.query(WritingFeedback).filter(WritingFeedback.id == log.writing_feedback_id).first()
        if wf:
            detail["writing_feedback"] = {
                "id": str(wf.id),
                "overall_band": wf.overall_band,
                "task_response_band": wf.task_response_band,
                "task_response_comment": wf.task_response_comment,
                "coherence_band": wf.coherence_band,
                "coherence_comment": wf.coherence_comment,
                "lexical_band": wf.lexical_band,
                "lexical_comment": wf.lexical_comment,
                "grammar_band": wf.grammar_band,
                "grammar_comment": wf.grammar_comment,
                "errors": wf.errors_json or [],
                "strengths": wf.strengths or [],
                "improvements": wf.improvements or [],
                "improved_paragraph": wf.improved_paragraph,
            }

    return detail


def get_ai_grading_stats(
    db: Session,
    date_from: Optional[datetime] = None,
    date_to: Optional[datetime] = None,
) -> Dict[str, Any]:
    """Thống kê tổng quan hoạt động chấm điểm và giải thích của AI Qwen 2.5."""
    query = db.query(AiGradingLog)
    if date_from:
        query = query.filter(AiGradingLog.created_at >= date_from)
    if date_to:
        query = query.filter(AiGradingLog.created_at <= date_to)

    total_requests = query.count()

    # Thống kê theo feature
    feature_counts = {
        "writing_grading": 0,
        "reading_explain": 0,
        "listening_explain": 0,
        "vocab_sentence": 0,
    }
    for row in (
        query.with_entities(AiGradingLog.feature, func.count(AiGradingLog.id))
        .group_by(AiGradingLog.feature)
        .all()
    ):
        feature_counts[row[0]] = row[1]

    # Thống kê theo status
    status_counts = {"success": 0, "fallback": 0, "error": 0}
    for row in (
        query.with_entities(AiGradingLog.status, func.count(AiGradingLog.id))
        .group_by(AiGradingLog.status)
        .all()
    ):
        status_counts[row[0]] = row[1]

    # Latency trung bình (chỉ tính các request gọi AI thật)
    avg_latency = (
        query.filter(AiGradingLog.ai_used == True, AiGradingLog.from_cache == False)
        .with_entities(func.avg(AiGradingLog.latency_ms))
        .scalar()
        or 0
    )

    # Tỷ lệ Cache Hit
    cache_hits = query.filter(AiGradingLog.from_cache == True).count()
    cache_hit_rate = round((cache_hits / total_requests * 100), 1) if total_requests > 0 else 0.0

    # Điểm Writing trung bình (tính trên float)
    writing_avg_band = (
        query.filter(AiGradingLog.feature == "writing_grading", AiGradingLog.score_numeric.isnot(None))
        .with_entities(func.avg(AiGradingLog.score_numeric))
        .scalar()
    )

    # Điểm Vocab trung bình
    vocab_avg_score = (
        query.filter(AiGradingLog.feature == "vocab_sentence", AiGradingLog.score_numeric.isnot(None))
        .with_entities(func.avg(AiGradingLog.score_numeric))
        .scalar()
    )

    return {
        "total_requests": total_requests,
        "feature_counts": feature_counts,
        "status_counts": status_counts,
        "avg_latency_ms": int(avg_latency),
        "cache_hits": cache_hits,
        "cache_hit_rate": cache_hit_rate,
        "writing_avg_band": round(float(writing_avg_band), 2) if writing_avg_band else None,
        "vocab_avg_score": round(float(vocab_avg_score), 1) if vocab_avg_score else None,
    }


def delete_ai_grading_log(db: Session, log_id: str) -> bool:
    """Xóa 1 bản ghi log chấm điểm."""
    try:
        lid = uuid.UUID(str(log_id))
    except Exception:
        return False

    item = db.query(AiGradingLog).filter(AiGradingLog.id == lid).first()
    if not item:
        return False

    db.delete(item)
    db.commit()
    logger.info(f"🗑️ Đã xóa AiGradingLog ID={log_id}")
    return True


def bulk_delete_ai_grading_logs(db: Session, log_ids: List[str]) -> int:
    """Xóa nhiều bản ghi log chấm điểm cùng lúc."""
    valid_uuids = []
    for s in log_ids:
        try:
            valid_uuids.append(uuid.UUID(str(s)))
        except Exception:
            continue

    if not valid_uuids:
        return 0

    count = (
        db.query(AiGradingLog)
        .filter(AiGradingLog.id.in_(valid_uuids))
        .delete(synchronize_session=False)
    )
    db.commit()
    logger.info(f"🗑️ Đã xóa {count} AiGradingLog bản ghi")
    return count


def export_ai_grading_logs_csv(
    db: Session,
    feature: Optional[str] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
    limit: int = 1000,
) -> str:
    """Xuất danh sách log ra file CSV (UTF-8 BOM tương thích Excel tiếng Việt)."""
    res = get_ai_grading_logs(
        db=db,
        feature=feature,
        status=status,
        search=search,
        page=1,
        page_size=limit,
    )
    items = res["items"]

    output = io.StringIO()
    # Thêm UTF-8 BOM
    output.write("\ufeff")

    writer = csv.writer(output)
    writer.writerow([
        "ID",
        "Thời gian",
        "Học viên",
        "Kỹ năng / Phân hệ",
        "Tính năng",
        "Bài học / Từ vựng",
        "Kết quả (Band/Điểm)",
        "Trạng thái",
        "Mô hình AI",
        "Độ trễ (ms)",
        "Nội dung nộp (rút gọn)",
        "Lỗi (nếu có)",
    ])

    for it in items:
        input_preview = (it.input_text or "").replace("\n", " ")[:120]
        result_display = it.band_score or (str(it.score_numeric) if it.score_numeric is not None else "")
        subject = it.lesson_title or it.vocab_word or it.lesson_id or ""
        writer.writerow([
            str(it.id),
            it.created_at.strftime("%Y-%m-%d %H:%M:%S") if it.created_at else "",
            it.username or str(it.user_id or "Khách"),
            it.skill_type,
            it.feature,
            subject,
            result_display,
            it.status,
            it.model_name or "",
            it.latency_ms,
            input_preview,
            it.error_message or "",
        ])

    return output.getvalue()

