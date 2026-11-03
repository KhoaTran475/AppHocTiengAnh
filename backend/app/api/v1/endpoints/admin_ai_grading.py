from datetime import datetime
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.core.deps import get_current_admin
from app.models.user import User
from app.schemas.ai_grading_log import (
    AiGradingLogItem,
    AiGradingLogPageResponse,
    AiGradingStatsResponse,
    AiGradingBulkDeleteRequest,
)
from app.services.ai_grading_log_service import (
    get_ai_grading_logs,
    get_ai_grading_log_detail,
    get_ai_grading_stats,
    delete_ai_grading_log,
    bulk_delete_ai_grading_logs,
    export_ai_grading_logs_csv,
)

router = APIRouter()


@router.get(
    "/stats",
    response_model=AiGradingStatsResponse,
    summary="Thống kê tổng quan hiệu suất và tần suất chấm điểm AI Qwen 2.5",
)
def get_stats(
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Số liệu KPI tổng quan về hoạt động AI: số request, tỷ lệ fallback, cache hit, độ trễ và điểm trung bình."""
    return get_ai_grading_stats(db=db)


@router.get(
    "/logs",
    response_model=AiGradingLogPageResponse,
    summary="Lấy danh sách lịch sử chấm điểm AI có phân trang và bộ lọc",
)
def list_logs(
    feature: Optional[str] = Query(None, description="writing_grading, reading_explain, listening_explain, vocab_sentence"),
    skill_type: Optional[str] = Query(None, description="writing, reading, listening, vocabulary"),
    username: Optional[str] = Query(None, description="Lọc theo tên tài khoản"),
    status: Optional[str] = Query(None, description="success, fallback, error"),
    ai_used: Optional[bool] = Query(None, description="Có gọi AI thực tế hay không"),
    from_cache: Optional[bool] = Query(None, description="Lấy từ bộ nhớ cache hay không"),
    search: Optional[str] = Query(None, description="Tìm kiếm trong bài học, từ vựng hoặc câu nộp"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Truy xuất danh sách log với các bộ lọc phân hệ và từ khóa tìm kiếm."""
    data = get_ai_grading_logs(
        db=db,
        feature=feature,
        skill_type=skill_type,
        username=username,
        status=status,
        ai_used=ai_used,
        from_cache=from_cache,
        search=search,
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


@router.get(
    "/logs/{log_id}",
    summary="Xem chi tiết 1 bản ghi log chấm điểm AI kèm JSON và Writing Feedback",
)
def get_single_log(
    log_id: str,
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Lấy dữ liệu chi tiết gồm đầu vào đầy đủ, 4 tiêu chí chấm, câu nâng cấp và thông số mô hình."""
    detail = get_ai_grading_log_detail(db=db, log_id=log_id)
    if not detail:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Không tìm thấy bản ghi log có ID '{log_id}'",
        )
    return detail


@router.delete(
    "/logs/{log_id}",
    summary="Xóa 1 bản ghi log chấm điểm AI",
)
def delete_single_log(
    log_id: str,
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Xóa bản ghi log chỉ định (không ảnh hưởng tới điểm số thực tế của học viên)."""
    success = delete_ai_grading_log(db=db, log_id=log_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Không tìm thấy bản ghi log có ID '{log_id}'",
        )
    return {"message": "Đã xóa bản ghi log thành công", "id": log_id}


@router.post(
    "/logs/bulk-delete",
    summary="Xóa hàng loạt bản ghi log chấm điểm AI",
)
def bulk_delete_logs(
    req: AiGradingBulkDeleteRequest,
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Xóa danh sách các bản ghi log đã chọn."""
    count = bulk_delete_ai_grading_logs(db=db, log_ids=req.ids)
    return {"message": f"Đã xóa thành công {count} bản ghi log", "deleted_count": count}


@router.get(
    "/export-csv",
    summary="Xuất danh sách log chấm điểm AI ra file CSV",
)
def export_csv(
    feature: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Xuất tối đa 1000 bản ghi theo bộ lọc hiện tại ra file CSV hỗ trợ tiếng Việt."""
    csv_content = export_ai_grading_logs_csv(
        db=db,
        feature=feature,
        status=status,
        search=search,
    )
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"qwen_ai_grading_logs_{timestamp}.csv"

    return Response(
        content=csv_content,
        media_type="text/csv; charset=utf-8",
        headers={
            "Content-Disposition": f"attachment; filename={filename}",
        },
    )

