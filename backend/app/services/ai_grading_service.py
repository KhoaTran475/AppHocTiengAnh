import json
import logging
from typing import Any, Dict, List, Optional, Tuple
from sqlalchemy.orm import Session

from app.models.skill import SkillLesson, AiExplanation, WritingFeedback
from app.services.ollama_client import call_qwen_generate
from app.core.config import settings
import re

logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────────────────────
# 1. GIAI ĐOẠN 1: GIẢI THÍCH ĐÁP ÁN READING & LISTENING (QWEN 2.5 7B)
# ─────────────────────────────────────────────────────────────

SYSTEM_PROMPT_EXPLAIN = """Bạn là chuyên gia sư phạm và khảo thí IELTS Band 8.5+.
Nhiệm vụ của bạn là giải thích cặn kẽ đáp án câu hỏi IELTS Reading/Listening cho học viên người Việt.
Yêu cầu bắt buộc:
1. Giải thích tự nhiên, sư phạm, bằng tiếng Việt chuẩn mực.
2. Nêu rõ dẫn chứng trích xuất nguyên văn từ bài đọc hoặc audio script chứng minh đáp án đúng.
3. Nếu học viên chọn SAI: Phân tích vì sao phương án đó là bẫy (paraphrase ngầm, bóp méo thông tin, hay Not Given).
   Nếu học viên chọn ĐÚNG: Khẳng định vì sao lựa chọn này hoàn toàn chuẩn xác và cảnh báo các bẫy khác mà bài thi thường gài.
4. Rút ra mẹo chiến thuật (strategy tips) cho dạng câu hỏi này.
5. Cung cấp 2-3 cặp từ vựng học thuật hoặc paraphrase đáng học từ ngữ cảnh.

Đầu ra BẮT BUỘC là 1 JSON Object duy nhất có cấu trúc sau:
{
  "explanation_vi": "Tóm tắt phân tích tổng quan súc tích bằng tiếng Việt...",
  "why_correct": "Dẫn chứng câu gốc: '...' -> Chứng minh vì sao đáp án đúng...",
  "why_trap": "Phân tích bẫy đối với phương án học viên đã chọn...",
  "strategy_tips": "Chiến thuật hoặc lưu ý nhận diện keyword/paraphrase...",
  "key_vocabulary": [
    {"word": "từ_gốc", "meaning": "nghĩa tiếng Việt", "paraphrase_with": "từ đồng nghĩa/paraphrase trong bài"}
  ]
}
"""


async def explain_answer_with_qwen(
    skill_type: str,
    lesson_title: str,
    context_text: str,
    question_text: str,
    options: List[str],
    correct_answer: str,
    user_choice: str,
    existing_explanation: Optional[str] = None,
) -> Tuple[bool, Dict[str, Any], str]:
    """Gọi Qwen 2.5 7B sinh giải thích chi tiết kèm phân tích bẫy và từ vựng mở rộng."""
    is_correct = (user_choice.strip().lower() == correct_answer.strip().lower())
    
    prompt = f"""KỸ NĂNG: IELTS {skill_type.upper()}
BÀI HỌC: {lesson_title}

NGỮ CẢNH BÀI THI (ĐOẠN VĂN HOẶC AUDIO SCRIPT):
\"\"\"
{context_text}
\"\"\"

CÂU HỎI: {question_text}
CÁC PHƯƠNG ÁN LỰA CHỌN:
{chr(10).join([f"- {opt}" for opt in options])}

ĐÁP ÁN ĐÚNG CỦA BÀI THI: {correct_answer}
LỰA CHỌN CỦA HỌC VIÊN: {user_choice} (Trạng thái: {'ĐÚNG' if is_correct else 'CHƯA ĐÚNG'})
{f'Gợi ý cơ bản sẵn có: {existing_explanation}' if existing_explanation else ''}

Hãy phân tích chi tiết câu hỏi trên theo đúng định dạng JSON yêu cầu. Output purely raw JSON object."""

    qwen_meta: Dict[str, Any] = {}
    success, data, err = await call_qwen_generate(
        prompt=prompt,
        system_prompt=SYSTEM_PROMPT_EXPLAIN,
        timeout=40.0,
        temperature=0.1,
        format_json=True,
        meta=qwen_meta,
    )

    if not success or not data:
        # Fallback giải thích cơ bản nếu AI bị timeout hoặc lỗi
        fallback_data = {
            "explanation_vi": existing_explanation or f"Đáp án đúng là '{correct_answer}'. Lựa chọn của bạn là '{user_choice}'.",
            "why_correct": f"Đáp án chuẩn xác là '{correct_answer}'.",
            "why_trap": "Hãy đối chiếu kỹ lại từ khóa trong bài và phương án để tránh nhầm lẫn." if not is_correct else "Bạn đã nắm bắt rất tốt thông tin trong bài đọc/nghe!",
            "strategy_tips": "Gạch chân từ khóa trong câu hỏi và tìm cụm từ đồng nghĩa (paraphrase) trong bài.",
            "key_vocabulary": [],
            "ai_used": False,
            "_meta": qwen_meta,
        }
        return False, fallback_data, err

    data["ai_used"] = True
    data["_meta"] = qwen_meta
    return True, data, ""


def get_or_create_ai_explanation(
    db: Session,
    lesson: SkillLesson,
    question_id: str,
    user_choice: str,
    cached_only: bool = False,
) -> Optional[Dict[str, Any]]:
    """Lấy giải thích đã cache trong database. Nếu cached_only=True và chưa có thì trả về None."""
    q_id_str = str(question_id).strip()
    norm_choice = user_choice.strip()

    cached = (
        db.query(AiExplanation)
        .filter(
            AiExplanation.lesson_id == lesson.id,
            AiExplanation.question_id == q_id_str,
            AiExplanation.user_choice == norm_choice,
        )
        .first()
    )

    if cached:
        return {
            "lesson_id": cached.lesson_id,
            "question_id": cached.question_id,
            "user_choice": cached.user_choice,
            "is_correct": cached.is_correct,
            "explanation_vi": cached.explanation_vi,
            "why_correct": cached.why_correct,
            "why_trap": cached.why_trap,
            "key_vocabulary": cached.key_vocabulary or [],
            "strategy_tips": cached.strategy_tips,
            "ai_used": True,
            "from_cache": True,
        }

    return None


async def generate_and_cache_ai_explanation(
    db: Session,
    lesson: SkillLesson,
    question_id: str,
    user_choice: str,
) -> Dict[str, Any]:
    """
    Tạo mới giải thích qua Qwen 2.5 7B và tự động lưu cache vào bảng ai_explanations.
    Xử lý Lưu ý 1 (Timeout Proxy): Nếu Qwen timeout, trả về fallback thân thiện không để client bị đơ.
    """
    # 1. Kiểm tra cache trước
    cached_result = get_or_create_ai_explanation(db, lesson, question_id, user_choice)
    if cached_result:
        return cached_result

    # 2. Tìm thông tin câu hỏi trong lesson.content_json
    questions = lesson.content_json.get("questions", [])
    target_q = None
    for q in questions:
        if str(q.get("id")) == str(question_id):
            target_q = q
            break

    if not target_q:
        raise ValueError(f"Không tìm thấy câu hỏi có ID '{question_id}' trong bài học '{lesson.id}'")

    correct_answer = target_q.get("correctAnswer", "")
    options = target_q.get("options", [])
    question_text = target_q.get("questionText", "")
    existing_explanation = target_q.get("explanation", "")
    is_correct = (user_choice.strip().lower() == correct_answer.strip().lower())

    # Lấy văn cảnh (Reading: đoạn văn hoặc đoạn trích; Listening: audio script)
    context_text = ""
    if lesson.skill_type == "reading":
        paragraphs = lesson.content_json.get("paragraphs", {})
        pref = target_q.get("paragraphRef", "")
        # Nếu có trích dẫn đoạn A, B, C thì ưu tiên lấy đoạn đó
        pref_key = pref.replace("Đoạn", "").replace("Paragraph", "").strip()
        if pref_key in paragraphs:
            context_text = f"Đoạn {pref_key}: {paragraphs[pref_key]}"
        else:
            context_text = "\n\n".join([f"Đoạn {k}: {v}" for k, v in paragraphs.items()])
    elif lesson.skill_type == "listening":
        context_text = lesson.content_json.get("audioScript", "")

    # 3. Gọi Qwen 2.5 7B
    success, result_data, err = await explain_answer_with_qwen(
        skill_type=lesson.skill_type,
        lesson_title=lesson.title,
        context_text=context_text,
        question_text=question_text,
        options=options,
        correct_answer=correct_answer,
        user_choice=user_choice,
        existing_explanation=existing_explanation,
    )

    # 4. Lưu cache vào bảng ai_explanations nếu AI sinh thành công
    if success:
        try:
            new_exp = AiExplanation(
                lesson_id=lesson.id,
                question_id=str(question_id),
                user_choice=user_choice,
                is_correct=is_correct,
                explanation_vi=result_data.get("explanation_vi", ""),
                why_correct=result_data.get("why_correct", ""),
                why_trap=result_data.get("why_trap", ""),
                key_vocabulary=result_data.get("key_vocabulary", []),
                strategy_tips=result_data.get("strategy_tips", ""),
            )
            db.add(new_exp)
            db.commit()
            db.refresh(new_exp)
            logger.info(f"💾 Đã lưu cache AiExplanation cho {lesson.id} Q{question_id} ({user_choice[:30]})")
        except Exception as save_err:
            db.rollback()
            logger.warning(f"Lỗi khi lưu cache AiExplanation: {save_err}")

    return {
        "lesson_id": lesson.id,
        "question_id": str(question_id),
        "user_choice": user_choice,
        "is_correct": is_correct,
        "explanation_vi": result_data.get("explanation_vi", ""),
        "why_correct": result_data.get("why_correct", ""),
        "why_trap": result_data.get("why_trap", ""),
        "key_vocabulary": result_data.get("key_vocabulary", []),
        "strategy_tips": result_data.get("strategy_tips", ""),
        "ai_used": success,
        "from_cache": False,
        "_meta": result_data.get("_meta", {}),
    }


def clear_lesson_explanation_cache(db: Session, lesson_id: str) -> int:
    """
    Lưu ý 3: Dọn dẹp toàn bộ cache AiExplanation khi bài học được cập nhật hoặc xóa.
    Đảm bảo dữ liệu giải thích luôn đồng bộ với nội dung bài thi mới nhất.
    """
    try:
        deleted_count = db.query(AiExplanation).filter(AiExplanation.lesson_id == lesson_id).delete()
        db.commit()
        if deleted_count > 0:
            logger.info(f"🧹 [Lưu ý 3] Đã dọn dẹp {deleted_count} bản ghi cache AiExplanation cho bài học '{lesson_id}'")
        return deleted_count
    except Exception as e:
        db.rollback()
        logger.warning(f"Lỗi khi dọn dẹp cache AiExplanation cho bài học '{lesson_id}': {e}")
        return 0


# ─────────────────────────────────────────────────────────────
# 2. GIAI ĐOẠN 2: CHẤM ĐIỂM IELTS WRITING (QWEN 2.5 7B & CHỐNG HALLUCINATION)
# ─────────────────────────────────────────────────────────────

SYSTEM_PROMPT_WRITING = """Bạn là giám khảo chấm thi IELTS Writing quốc tế chính thức (Official IELTS Examiner).
Nhiệm vụ của bạn là đánh giá và chấm điểm bài viết IELTS Writing (Task 1 hoặc Task 2) của thí sinh theo chuẩn 4 tiêu chí của British Council / IDP.

BẠN PHẢI ĐÁNH GIÁ ĐỦ 4 TIÊU CHÍ (Band từ 1.0 đến 9.0, bước nhảy 0.5):
1. Task Achievement (Task 1) / Task Response (Task 2):
   - Mức độ hoàn thành các yêu cầu của đề bài.
   - Task 1: Có Overview rõ ràng bao quát xu hướng chính không? Có chọn lọc và so sánh số liệu quan trọng không?
   - Task 2: Có trả lời đầy đủ tất cả các phần của câu hỏi không? Lập trường rõ ràng và nhất quán không? Có ý tưởng phát triển kèm dẫn chứng không?
2. Coherence and Cohesion (Mạch lạc và liên kết):
   - Tổ chức và phân bổ đoạn văn logic, ý tưởng phát triển tuần tự.
   - Sử dụng phương tiện liên kết (linking words/phrases) tự nhiên, không lạm dụng hoặc dùng sai ngữ cảnh.
3. Lexical Resource (Vốn từ vựng):
   - Sử dụng vốn từ phong phú, linh hoạt, có collocations và từ vựng học thuật theo chủ đề.
   - Nhận diện lỗi dùng từ sai sắc thái, lỗi chính tả và biến thể dạng từ (word formation).
4. Grammatical Range and Accuracy (Ngữ pháp):
   - Sử dụng kết hợp các cấu trúc câu phức (mệnh đề quan hệ, câu điều kiện, bị động, đảo ngữ...).
   - Độ chính xác về thì, sự hòa hợp chủ - vị và dấu câu.

QUY TẮC BẮT BUỘC VỀ TRÍCH XUẤT LỖI (LƯU Ý 2 - CHỐNG HALLUCINATION):
- Cột "quote" trong mảng "errors" BẮT BUỘC PHẢI LÀ NGUYÊN VĂN từ ngữ hoặc câu có thật trong bài viết của học viên.
- TUYỆT ĐỐI KHÔNG TỰ BỊA RA TỪ NGỮ HOẶC LỖI KHÔNG CÓ TRONG BÀI CỦA HỌC VIÊN.
- Chọn lọc từ 3 đến 8 lỗi quan trọng và đáng giá nhất để giúp học viên nâng band.

ĐẦU RA BẮT BUỘC LÀ 1 JSON OBJECT DUY NHẤT:
{
  "criteria": {
    "task_response": {
      "band": 6.5,
      "comment_vi": "Nhận xét chi tiết về mức độ hoàn thành đề bài bằng tiếng Việt..."
    },
    "coherence_cohesion": {
      "band": 6.0,
      "comment_vi": "Nhận xét về liên kết câu và cấu trúc đoạn văn..."
    },
    "lexical_resource": {
      "band": 6.5,
      "comment_vi": "Nhận xét về vốn từ vựng học thuật và collocations..."
    },
    "grammatical_range_accuracy": {
      "band": 6.0,
      "comment_vi": "Nhận xét về độ đa dạng cấu trúc và độ chính xác ngữ pháp..."
    }
  },
  "errors": [
    {
      "quote": "cụm từ nguyên văn trong bài học viên",
      "type": "grammar",
      "fix": "cách sửa chuẩn xác",
      "explain_vi": "giải thích ngắn gọn lỗi sai bằng tiếng Việt"
    }
  ],
  "strengths_vi": [
    "Điểm mạnh nổi bật 1...",
    "Điểm mạnh nổi bật 2..."
  ],
  "improvements_vi": [
    "Điểm cần cải thiện chính 1...",
    "Điểm cần cải thiện chính 2..."
  ],
  "improved_paragraph": "Viết lại 1 đoạn tiêu biểu của học viên ở mức Band 8.0+ để học viên tham khảo"
}
"""


def validate_and_filter_error_quotes(errors: List[Dict[str, Any]], essay_text: str) -> List[Dict[str, Any]]:
    """
    Lưu ý 2: Kiểm tra so khớp quote trong errors chống Hallucination.
    Chỉ giữ lại các lỗi mà cụm từ 'quote' thực sự xuất hiện trong bài viết của học viên.
    Loại bỏ triệt để các lỗi do AI tự tưởng tượng ra.
    """
    if not errors or not essay_text:
        return []

    norm_essay = re.sub(r"\s+", " ", essay_text.strip().lower())
    clean_essay = re.sub(r"[^\w\s]", "", norm_essay)

    valid_errors = []
    for err in errors:
        quote = str(err.get("quote", "")).strip()
        if not quote:
            continue

        norm_quote = re.sub(r"\s+", " ", quote.lower())
        clean_quote = re.sub(r"[^\w\s]", "", norm_quote)

        # Kiểm tra sự tồn tại trong bài viết gốc
        if norm_quote in norm_essay or (len(clean_quote) >= 4 and clean_quote in clean_essay):
            valid_errors.append(err)
        else:
            logger.warning(f"🛡️ [Anti-Hallucination] Đã lọc bỏ lỗi do AI bịa quote không có trong bài: '{quote}'")

    return valid_errors


def calculate_ielts_overall_band(task_b: float, cc_b: float, lr_b: float, gr_b: float) -> str:
    """
    Tính Band điểm tổng theo quy tắc làm tròn 0.5 chính thức của IELTS:
    - Điểm trung bình cộng có phần thập phân < 0.25 -> làm tròn xuống .0
    - Từ 0.25 đến < 0.75 -> làm tròn thành .5
    - Từ 0.75 trở lên -> làm tròn lên số nguyên tiếp theo
    """
    avg = (task_b + cc_b + lr_b + gr_b) / 4.0
    int_part = int(avg)
    fraction = avg - int_part

    if fraction < 0.25:
        overall = float(int_part)
    elif fraction < 0.75:
        overall = float(int_part) + 0.5
    else:
        overall = float(int_part) + 1.0

    overall = max(1.0, min(9.0, overall))
    return f"{overall:0.1f}"


async def grade_writing_with_qwen(
    lesson: SkillLesson,
    essay_text: str,
) -> Dict[str, Any]:
    """
    Chấm điểm bài viết IELTS Writing tự động bằng Qwen 2.5 7B.
    Xử lý:
    - Lưu ý 1 (Timeout Proxy): Giới hạn timeout 45s; nếu timeout thì fallback sang thuật toán rule-based.
    - Lưu ý 2 (Chống Hallucination): So khớp quote trước khi trả về.
    - Quy tắc IELTS: Phạt điểm Task Response nếu thiếu số từ tối thiểu.
    """
    words = len(essay_text.strip().split()) if essay_text else 0
    min_words = lesson.content_json.get("minWordCount", 150)
    task_type = lesson.content_json.get("taskType", "Task 1")
    prompt_topic = lesson.content_json.get("prompt", lesson.title)
    chart_data = lesson.content_json.get("chart_data")
    key_outline = lesson.content_json.get("keyOutline", [])

    if words < 25:
        raise ValueError("Bài viết quá ngắn (dưới 25 từ), vui lòng hoàn thiện thêm trước khi nộp bài!")

    # Chuyển đổi dữ liệu biểu đồ thành dạng bảng chữ nếu là Task 1
    chart_summary = ""
    if chart_data and isinstance(chart_data, dict):
        chart_summary = f"\nDỮ LIỆU BIỂU ĐỒ ({chart_data.get('type', 'chart')} - Đơn vị: {chart_data.get('unit', '')}):\n"
        cats = chart_data.get("categories", [])
        for s in chart_data.get("series", []):
            chart_summary += f"- {s.get('name')}: " + ", ".join([f"{cats[i] if i < len(cats) else ''}: {v}" for i, v in enumerate(s.get("values", []))]) + "\n"

    ai_prompt = f"""ĐỀ BÀI IELTS WRITING ({task_type}):
\"{prompt_topic}\"
{chart_summary}
YÊU CẦU ĐỘ DÀI TỐI THIỂU: {min_words} từ
SỐ TỪ THỰC TẾ HỌC VIÊN ĐÃ VIẾT: {words} từ

BÀI LÀM CỦA HỌC VIÊN:
\"\"\"
{essay_text}
\"\"\"

Hãy chấm điểm bài viết trên theo đúng 4 tiêu chí IELTS và xuất ra kết quả JSON thuần túy."""

    # Gọi Qwen 2.5 7B với timeout kiểm soát (Lưu ý 1)
    timeout_val = float(settings.AI_WRITING_TIMEOUT_SECONDS or 45)
    qwen_meta: Dict[str, Any] = {}
    success, data, err = await call_qwen_generate(
        prompt=ai_prompt,
        system_prompt=SYSTEM_PROMPT_WRITING,
        timeout=timeout_val,
        temperature=0.1,
        format_json=True,
        meta=qwen_meta,
    )
    if err:
        qwen_meta["error"] = err

    pass_score_req = float(lesson.pass_score_required or 6.0)
    target_band_num = float(lesson.band_score_target.replace("+", "") or 7.0)

    if not success or not data or "criteria" not in data:
        logger.warning(f"⚠️ [Qwen 2.5 7B Writing Fallback] AI không phản hồi ({err}). Dùng logic chấm dự phòng.")
        # Fallback an toàn (Lưu ý 1: Không để client bị lỗi 500/504)
        academic_vocab = lesson.content_json.get("academicVocabulary", [])
        text_lower = essay_text.lower()
        matched = [v.split("(")[0].strip().lower() for v in academic_vocab if v.split("(")[0].strip().lower() in text_lower]
        bonus = len(matched)

        if words < min_words * 0.7:
            band_num = 5.0
        elif words < min_words:
            band_num = 5.5
        elif bonus >= 3:
            band_num = min(target_band_num, 8.0)
        elif bonus >= 1:
            band_num = max(6.0, target_band_num - 0.5)
        else:
            band_num = max(5.5, target_band_num - 1.0)

        band_str = f"{band_num:0.1f}"
        passed = words >= min_words and band_num >= pass_score_req
        stars = 3 if band_num >= target_band_num and words >= min_words else (2 if passed else (1 if words >= min_words * 0.7 else 0))

        feedback_msg = f"Độ dài: {words}/{min_words} từ. Điểm ước lượng cơ bản: Band {band_str} (Hệ thống AI bận, đã kích hoạt bộ chấm dự phòng)."
        return {
            "score": words,
            "total_questions": min_words,
            "band_score": band_str,
            "passed": passed,
            "stars": stars,
            "feedback": feedback_msg,
            "ai_used": False,
            "writing_feedback": {
                "overall_band": band_str,
                "task_response_band": band_num,
                "task_response_comment": f"Bài viết đạt {words}/{min_words} từ.",
                "coherence_band": band_num,
                "coherence_comment": "Cấu trúc đoạn văn cơ bản.",
                "lexical_band": band_num,
                "lexical_comment": f"Nhận diện {bonus} từ vựng học thuật phù hợp chủ đề.",
                "grammar_band": band_num,
                "grammar_comment": "Ngữ pháp cơ bản.",
                "errors": [],
                "strengths": ["Hoàn thành độ dài bài tập."],
                "improvements": ["Luyện tập viết các câu phức và bổ sung từ vựng nâng cao."],
                "improved_paragraph": lesson.content_json.get("sampleEssay", "")[:300] + "...",
            },
            "_meta": qwen_meta,
        }

    # Xử lý kết quả từ Qwen 2.5 7B
    criteria = data.get("criteria", {})
    task_b = float(criteria.get("task_response", {}).get("band", 6.0))
    cc_b = float(criteria.get("coherence_cohesion", {}).get("band", 6.0))
    lr_b = float(criteria.get("lexical_resource", {}).get("band", 6.0))
    gr_b = float(criteria.get("grammatical_range_accuracy", {}).get("band", 6.0))

    # Áp dụng quy tắc trừ điểm của IELTS nếu thiếu số từ tối thiểu
    if words < min_words * 0.7:
        task_b = min(task_b, 5.0)
    elif words < min_words:
        task_b = min(task_b, 5.5)

    overall_band = calculate_ielts_overall_band(task_b, cc_b, lr_b, gr_b)
    overall_num = float(overall_band)

    # Lưu ý 2: Lọc bỏ toàn bộ lỗi bịa không có trong bài gốc (Anti-Hallucination)
    raw_errors = data.get("errors", [])
    valid_errors = validate_and_filter_error_quotes(raw_errors, essay_text)

    passed = words >= min_words and overall_num >= pass_score_req
    if overall_num >= target_band_num and words >= min_words:
        stars = 3
    elif passed:
        stars = 2
    else:
        stars = 1 if words >= min_words * 0.7 else 0

    feedback_msg = f"🎉 Vượt ải thành công! Band {overall_band}" if passed else f"Cần đạt tối thiểu {min_words} từ và Band {pass_score_req} để vượt ải này. Band hiện tại: {overall_band}"

    writing_fb_dict = {
        "overall_band": overall_band,
        "task_response_band": task_b,
        "task_response_comment": criteria.get("task_response", {}).get("comment_vi", ""),
        "coherence_band": cc_b,
        "coherence_comment": criteria.get("coherence_cohesion", {}).get("comment_vi", ""),
        "lexical_band": lr_b,
        "lexical_comment": criteria.get("lexical_resource", {}).get("comment_vi", ""),
        "grammar_band": gr_b,
        "grammar_comment": criteria.get("grammatical_range_accuracy", {}).get("comment_vi", ""),
        "errors": valid_errors,
        "strengths": data.get("strengths_vi", []),
        "improvements": data.get("improvements_vi", []),
        "improved_paragraph": data.get("improved_paragraph", ""),
    }

    return {
        "score": words,
        "total_questions": min_words,
        "band_score": overall_band,
        "passed": passed,
        "stars": stars,
        "feedback": feedback_msg,
        "ai_used": True,
        "writing_feedback": writing_fb_dict,
        "_meta": qwen_meta,
    }


