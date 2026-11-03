from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.core.deps import security_bearer
from app.core.security import decode_access_token
from app.models.user import User
from app.models.skill import UserStageProgress
from app.services.user_service import get_user_by_username
from app.schemas.vocab_learning import (
    VocabCardWithMasteryResponse,
    VocabRoadmapResponse,
    OllamaStatusResponse,
    OllamaGenerateVocabRequest,
    OllamaGenerateVocabResponse,
    OllamaSentenceEvaluateRequest,
    OllamaSentenceEvaluateResponse,
    MasteryUpdateRequest,
    MasteryUpdateResponse,
    VocabQuizGenerateRequest,
    VocabQuizResponse,
    VocabQuizSubmitRequest,
    VocabQuizSubmitResponse,
    SystemVocabConfigResponse,
    SystemVocabConfigUpdate,
    OllamaModelTestRequest,
    OllamaModelTestResponse,
)
from app.services.ollama_vocab_service import (
    check_ollama_qwen_status,
    get_vocab_roadmap,
    get_level_cards_for_user,
    generate_vocab_with_qwen,
    evaluate_sentence_with_qwen,
    update_card_mastery,
    generate_quiz_with_qwen,
    submit_vocab_quiz,
    get_or_create_system_vocab_config,
    update_system_vocab_config,
    test_ollama_model_benchmark,
    resolve_qwen_model,
)

router = APIRouter()


def _resolve_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_bearer),
    db: Session = Depends(get_db),
) -> User:
    """
    Trích xuất User từ Bearer JWT Token.
    Nếu không có token (ví dụ gọi thử nghiệm nhanh), tự động fallback về tài khoản learner mặc định.
    """
    if credentials and credentials.credentials:
        payload = decode_access_token(credentials.credentials)
        if payload and payload.get("sub"):
            user = get_user_by_username(db, payload["sub"])
            if user:
                return user

    fallback = get_user_by_username(db, "learner")
    if fallback:
        return fallback
    first_user = db.query(User).first()
    if first_user:
        return first_user
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Không tìm thấy người dùng hợp lệ",
    )


@router.get(
    "/status",
    response_model=OllamaStatusResponse,
    summary="Kiểm tra trạng thái kết nối Ollama & Model Qwen 2.5 Local",
)
async def get_ollama_status():
    """Kiểm tra xem Ollama local (cổng 11434) và model Qwen 2.5 đã sẵn sàng chưa."""
    return await check_ollama_qwen_status()


@router.get(
    "/levels",
    response_model=VocabRoadmapResponse,
    summary="Lấy lộ trình học từ vựng 5 Cấp độ (Cơ bản -> Nâng cao) & Tiến độ học viên",
)
def get_learning_roadmap(
    current_user: User = Depends(_resolve_user),
    db: Session = Depends(get_db),
):
    """
    Trả về danh sách 5 Cấp độ (Level 1: Cơ bản A2-B1 -> Level 5: Bậc thầy C2),
    số lượng thẻ từ, số từ đã thuộc (SRS Mastered), số sao đạt được và trạng thái mở khóa.
    """
    return get_vocab_roadmap(db=db, user_id=current_user.id)


@router.get(
    "/cards",
    response_model=List[VocabCardWithMasteryResponse],
    summary="Lấy danh sách thẻ từ vựng theo Cấp độ (1..5), Chủ đề & Tìm kiếm",
)
def list_learning_cards(
    level: Optional[int] = Query(None, ge=1, le=5, description="Lọc theo cấp độ từ 1 đến 5"),
    topic: Optional[str] = Query(None, description="Lọc theo chủ đề"),
    search: Optional[str] = Query(None, description="Tìm kiếm theo từ cơ bản, nâng cao hoặc nghĩa tiếng Việt"),
    current_user: User = Depends(_resolve_user),
    db: Session = Depends(get_db),
):
    """Lấy danh sách thẻ học từ vựng kèm Thang nâng cấp từ (Basic -> Intermediate -> Advanced) và mức độ thuộc từ."""
    return get_level_cards_for_user(
        db=db,
        user_id=current_user.id,
        level=level,
        topic=topic,
        search=search,
    )


@router.post(
    "/generate",
    response_model=OllamaGenerateVocabResponse,
    summary="Sinh bộ thẻ từ vựng mới theo Chủ đề & Cấp độ bằng Ollama Qwen 2.5 Local",
)
async def generate_vocab_cards_ai(
    req: OllamaGenerateVocabRequest,
    current_user: User = Depends(_resolve_user),
    db: Session = Depends(get_db),
):
    """
    Gọi mô hình Ollama Qwen 2.5 local để sinh từ vựng mới theo chủ đề bất kỳ và cấp độ (1..5).
    Các từ mới sinh ra được tự động lưu vào Database (Cache 2 tầng) để dùng lâu dài.
    """
    return await generate_vocab_with_qwen(
        topic=req.topic,
        level=req.level,
        count=req.count,
        user_id=current_user.id,
        db=db,
    )


@router.post(
    "/evaluate-sentence",
    response_model=OllamaSentenceEvaluateResponse,
    summary="Chấm điểm đặt câu & Gợi ý nâng cấp câu (Basic -> Advanced) bằng Ollama Qwen 2.5",
)
async def evaluate_learner_sentence(
    req: OllamaSentenceEvaluateRequest,
    current_user: User = Depends(_resolve_user),
    db: Session = Depends(get_db),
):
    """
    Học viên đặt câu với từ đang học -> Qwen 2.5 chấm điểm ngữ pháp, độ tự nhiên,
    nhận xét bằng tiếng Việt và gợi ý 3 phiên bản nâng cấp câu (Band 5.5 -> Band 6.5 -> Band 8.0+).
    """
    import time
    t0 = time.time()
    res = await evaluate_sentence_with_qwen(
        word=req.word,
        level=req.level,
        user_sentence=req.user_sentence,
        db=db,
    )
    latency_ms = int((time.time() - t0) * 1000)

    # Ghi log tập trung vào bảng ai_grading_logs
    try:
        from app.services.notebook_service import resolve_user_uuid
        from app.services.ai_grading_log_service import log_ai_grading
        user_uuid_str = resolve_user_uuid(db, current_user)
        is_fallback = "fallback" in (res.model_used or "").lower()
        log_ai_grading(
            db=db,
            feature="vocab_sentence",
            skill_type="vocabulary",
            user_id=user_uuid_str,
            username=current_user.username,
            vocab_word=req.word,
            vocab_level=req.level,
            input_text=req.user_sentence,
            band_score=res.estimated_band,
            score_numeric=float(res.score),
            is_correct=res.is_correct_usage,
            result_json=res.model_dump(),
            model_name=res.model_used,
            ai_used=not is_fallback,
            from_cache=False,
            status="fallback" if is_fallback else "success",
            latency_ms=latency_ms,
        )
    except Exception as log_err:
        pass

    return res


@router.post(
    "/mastery",
    response_model=MasteryUpdateResponse,
    summary="Cập nhật mức độ ghi nhớ thẻ từ vựng (Spaced Repetition - SRS)",
)
def update_vocab_card_mastery(
    req: MasteryUpdateRequest,
    current_user: User = Depends(_resolve_user),
    db: Session = Depends(get_db),
):
    """Cập nhật trạng thái thuộc từ (0: Chưa học, 1: Quên, 2: Nhớ sơ, 3: Đã thuộc lòng)."""
    return update_card_mastery(
        db=db,
        user_id=current_user.id,
        card_id=req.card_id,
        mastery_level=req.mastery_level,
    )


@router.post(
    "/quiz",
    response_model=VocabQuizResponse,
    summary="Tạo đề kiểm tra từ vựng vượt cấp (Hỗ trợ AI Qwen 2.5 & Database)",
)
async def create_level_quiz(
    req: VocabQuizGenerateRequest,
    current_user: User = Depends(_resolve_user),
    db: Session = Depends(get_db),
):
    """Tạo bộ câu hỏi kiểm tra vượt cấp (Nâng cấp từ, Điền từ ngữ cảnh, Trắc nghiệm nghĩa)."""
    # Chặn sinh đề thi ở cấp độ chưa mở khóa
    all_stages = (
        db.query(UserStageProgress)
        .filter(
            UserStageProgress.user_id == current_user.id,
            UserStageProgress.skill_type == "vocabulary",
        )
        .all()
    )
    highest = 1
    for s in all_stages:
        if s.is_unlocked and s.stage_number > highest:
            highest = s.stage_number
        if s.stars > 0 and s.stage_number < 5 and (s.stage_number + 1) > highest:
            highest = s.stage_number + 1

    if req.level > highest:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Cấp độ {req.level} đang bị khóa. Bạn cần vượt qua bài thi của Cấp độ {highest} để mở khóa.",
        )

    return await generate_quiz_with_qwen(
        level=req.level,
        topic=req.topic,
        question_count=req.question_count,
        use_ai_qwen=req.use_ai_qwen,
        db=db,
    )


@router.post(
    "/submit-quiz",
    response_model=VocabQuizSubmitResponse,
    summary="Nộp bài kiểm tra từ vựng vượt cấp, tính Sao (1-3⭐) & Mở khóa cấp độ mới",
)
def submit_level_quiz(
    req: VocabQuizSubmitRequest,
    current_user: User = Depends(_resolve_user),
    db: Session = Depends(get_db),
):
    """Chấm điểm bài kiểm tra từ vựng, trao Sao, mở khóa Level tiếp theo và lưu lịch sử học tập."""
    return submit_vocab_quiz(
        db=db,
        user=current_user,
        req=req,
    )


# ─────────────────────────────────────────────────────────────
# CẤU HÌNH ĐỘNG HỌC TỪ VỰNG & MÔ HÌNH AI (OLLAMA QWEN)
# ─────────────────────────────────────────────────────────────

@router.get(
    "/config",
    response_model=SystemVocabConfigResponse,
    summary="Lấy cấu hình học từ vựng & AI Qwen hiện tại kèm trạng thái Ollama Server",
)
async def get_system_vocab_config_endpoint(
    db: Session = Depends(get_db),
):
    """
    Lấy toàn bộ thông số cấu hình:
    - Model đang kích hoạt (active_model)
    - Số câu hỏi mỗi bài Quiz (quiz_question_count)
    - Tỷ lệ % vượt ải (pass_percentage)
    - Số từ vựng AI sinh mặc định (default_gen_count)
    - Danh sách các model Ollama khả dụng trên máy chủ
    """
    cfg = get_or_create_system_vocab_config(db)
    online, resolved, available = await resolve_qwen_model(db=db)

    return SystemVocabConfigResponse(
        id=cfg.id,
        active_model=cfg.active_model,
        temperature=round(cfg.temperature / 10.0, 1),
        default_gen_count=cfg.default_gen_count,
        quiz_question_count=cfg.quiz_question_count,
        pass_percentage=cfg.pass_percentage,
        star_thresholds=cfg.star_thresholds or {"star1": 60, "star2": 80, "star3": 100},
        auto_cache_enabled=bool(cfg.auto_cache_enabled),
        updated_at=cfg.updated_at,
        is_ollama_online=online,
        available_models=available,
        ollama_base_url="http://localhost:11434",
    )


@router.put(
    "/config",
    response_model=SystemVocabConfigResponse,
    summary="Cập nhật cấu hình học từ vựng & AI Qwen (Dành cho Web Admin Portal)",
)
async def update_system_vocab_config_endpoint(
    update_data: SystemVocabConfigUpdate,
    db: Session = Depends(get_db),
):
    """Cập nhật các thông số quản trị: model AI, số lượng câu quiz, tỷ lệ vượt ải, số từ sinh."""
    cfg = update_system_vocab_config(db=db, update_data=update_data)
    online, resolved, available = await resolve_qwen_model(db=db)

    return SystemVocabConfigResponse(
        id=cfg.id,
        active_model=cfg.active_model,
        temperature=round(cfg.temperature / 10.0, 1),
        default_gen_count=cfg.default_gen_count,
        quiz_question_count=cfg.quiz_question_count,
        pass_percentage=cfg.pass_percentage,
        star_thresholds=cfg.star_thresholds or {"star1": 60, "star2": 80, "star3": 100},
        auto_cache_enabled=bool(cfg.auto_cache_enabled),
        updated_at=cfg.updated_at,
        is_ollama_online=online,
        available_models=available,
        ollama_base_url="http://localhost:11434",
    )


@router.post(
    "/config/test-model",
    response_model=OllamaModelTestResponse,
    summary="Chạy thử nghiệm Model AI Qwen và đo thời gian phản hồi (ms)",
)
async def test_ai_model_endpoint(
    req: OllamaModelTestRequest,
):
    """Gửi test prompt ngắn tới Ollama để kiểm tra khả năng sinh JSON và đo benchmark latency."""
    success, latency_ms, msg, sample = await test_ollama_model_benchmark(
        model_name=req.model_name,
        test_prompt=req.test_prompt,
    )
    return OllamaModelTestResponse(
        success=success,
        model=req.model_name,
        latency_ms=latency_ms,
        message=msg,
        sample_response=sample,
    )


