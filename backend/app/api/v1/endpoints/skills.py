from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.schemas.skill import (
    SkillLessonResponse,
    SkillSubmissionRequest,
    SkillSubmissionResponse,
    PracticeHistoryResponse,
    ListeningProgressResponse,
)
from app.services.skill_service import (
    get_lessons_by_skill,
    get_lesson_by_id,
    submit_lesson,
    get_user_practice_history,
    get_user_listening_progress,
    get_user_skill_progress,
)
from app.core.deps import get_current_user
from app.models.user import User

router = APIRouter()


@router.get(
    "/{skill_type}/lessons",
    response_model=List[SkillLessonResponse],
    summary="Lấy danh sách bài học theo kỹ năng (Reading, Listening, Speaking, Writing)",
)
def list_skill_lessons(
    skill_type: str,
    db: Session = Depends(get_db),
):
    """
    Lấy danh sách bài học chuẩn IELTS:
    - reading: Các bài đọc học thuật IELTS
    - listening: Lộ trình vượt ải 5 Cấp độ (Level 1 đến Level 5)
    - speaking: Bài luyện Part 1 và Part 2 Cue Cards
    - writing: Bài luyện Task 1 và Task 2 kèm bài mẫu Band 8.0+
    """
    valid_skills = ["reading", "listening", "speaking", "writing"]
    if skill_type.lower() not in valid_skills:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Kỹ năng không hợp lệ. Chọn 1 trong: {valid_skills}",
        )
    return get_lessons_by_skill(db, skill_type)


@router.get(
    "/lessons/{lesson_id}",
    response_model=SkillLessonResponse,
    summary="Lấy chi tiết một bài học theo ID",
)
def get_single_lesson(
    lesson_id: str,
    db: Session = Depends(get_db),
):
    """Lấy chi tiết bài học (đoạn văn, câu hỏi, audio script, đề bài...)."""
    lesson = get_lesson_by_id(db, lesson_id)
    if not lesson:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Không tìm thấy bài học có ID '{lesson_id}'",
        )
    return lesson


@router.post(
    "/submit",
    response_model=SkillSubmissionResponse,
    summary="Nộp bài làm & Chấm điểm tự động (Reading, Listening, Speaking, Writing)",
)
def submit_skill_test(
    submission: SkillSubmissionRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Nộp bài tập và chấm điểm tức thì trên server:
    - Reading / Listening: So khớp đáp án, giải thích chi tiết, tính Band điểm IELTS.
    - Listening: Tự động mở khóa ải tiếp theo nếu đủ điểm qua ải và tính số sao (⭐).
    - Writing: Đếm từ, kiểm tra từ vựng học thuật, chấm ước lượng band.
    - Speaking: Tính điểm trung bình và ước tính band.
    - Tự động lưu vào lịch sử bài thi và đồng bộ lên Supabase cloud (practice_history).
    """
    try:
        return submit_lesson(db, current_user, submission, sync_supabase=True)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get(
    "/history",
    response_model=List[PracticeHistoryResponse],
    summary="Lấy lịch sử làm bài thi của học viên",
)
def get_practice_history(
    skill_type: Optional[str] = Query(None, description="Lọc theo kỹ năng (reading, listening, speaking, writing)"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Lấy toàn bộ lịch sử điểm số và thời gian làm bài của học viên hiện tại."""
    history = get_user_practice_history(db, current_user.id, skill_type=skill_type)
    return [PracticeHistoryResponse.model_validate(h) for h in history]


@router.get(
    "/listening/progress",
    response_model=ListeningProgressResponse,
    summary="Lấy tiến độ Vượt ải Listening (Gamified Stages)",
)
def get_listening_stage_progress(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Lấy trạng thái mở khóa của 5 ải, số sao đạt được và điểm cao nhất của từng ải."""
    return get_user_skill_progress(db, current_user.id, "listening")


@router.get(
    "/{skill_type}/progress",
    response_model=ListeningProgressResponse,
    summary="Lấy tiến độ Vượt ải 5 Cấp độ của kỹ năng bất kỳ (reading, listening, writing, speaking)",
)
def get_skill_stage_progress(
    skill_type: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Lấy trạng thái mở khóa của 5 ải, số sao đạt được và điểm cao nhất của kỹ năng được yêu cầu."""
    valid_skills = ["reading", "listening", "speaking", "writing"]
    norm_skill = skill_type.strip().lower()
    if norm_skill not in valid_skills:
        raise HTTPException(status_code=400, detail=f"Kỹ năng '{skill_type}' không hợp lệ. Chỉ chấp nhận: {valid_skills}")
    return get_user_skill_progress(db, current_user.id, norm_skill)
