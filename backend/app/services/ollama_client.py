import asyncio
import json
import logging
import re
import time
from typing import Any, Dict, Optional, Tuple

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

# Giới hạn 1 request suy luận tại một thời điểm để bảo vệ 8GB VRAM RTX 5050 không bị tranh chấp tài nguyên
_inference_semaphore = asyncio.Semaphore(1)


def clean_json_text(raw_text: str) -> str:
    """Làm sạch output text từ Qwen 2.5, bóc tách code block markdown và lấy JSON object hợp lệ."""
    if not raw_text:
        return ""
    text = raw_text.strip()
    # Bỏ markdown code blocks nếu có
    if "```json" in text:
        match = re.search(r"```json\s*(.*?)\s*```", text, re.DOTALL)
        if match:
            text = match.group(1).strip()
    elif "```" in text:
        match = re.search(r"```\s*(.*?)\s*```", text, re.DOTALL)
        if match:
            text = match.group(1).strip()

    # Tìm cặp ngoặc nhọn JSON { ... } bao ngoài cùng
    start = text.find("{")
    end = text.rfind("}")
    if start != -1 and end != -1 and end > start:
        return text[start : end + 1]
    return text


async def call_qwen_generate(
    prompt: str,
    system_prompt: Optional[str] = None,
    timeout: Optional[float] = None,
    temperature: float = 0.1,
    format_json: bool = True,
    max_retries: int = 1,
    meta: Optional[Dict[str, Any]] = None,
) -> Tuple[bool, Optional[Dict[str, Any]], str]:
    """
    Gọi model Qwen 2.5 7B qua Ollama API với cơ chế kiểm soát Semaphore và Timeout.
    
    Lưu ý 1 (Timeout Proxy Nginx/ngrok):
    - Đặt timeout mặc định 40 giây (dưới 60 giây của Nginx/ngrok proxy_read_timeout).
    - Bắt lỗi TimeoutException và ConnectionError để phản hồi graceful fallback thay vì để treo kết nối 504.
    """
    effective_timeout = timeout or float(settings.AI_EXPLAIN_TIMEOUT_SECONDS)
    model_name = settings.OLLAMA_GRADING_MODEL or "qwen2.5:7b"
    url = f"{settings.OLLAMA_BASE_URL.rstrip('/')}/api/generate"

    if meta is not None:
        meta["model"] = model_name
        meta["latency_ms"] = 0
        meta["prompt_tokens"] = None
        meta["completion_tokens"] = None

    payload: Dict[str, Any] = {
        "model": model_name,
        "prompt": prompt,
        "stream": False,
        "options": {
            "temperature": temperature,
            "seed": 42,
            "num_ctx": 4096,
        },
    }
    if system_prompt:
        payload["system"] = system_prompt
    if format_json:
        payload["format"] = "json"

    for attempt in range(max_retries + 1):
        try:
            async with _inference_semaphore:
                t0 = time.time()
                logger.info(f"🚀 [Qwen 2.5 7B] Bắt đầu suy luận (Thử lần {attempt + 1}, timeout: {effective_timeout}s)...")
                
                async with httpx.AsyncClient(timeout=effective_timeout) as client:
                    resp = await client.post(url, json=payload)

                latency_ms = int((time.time() - t0) * 1000)
                if meta is not None:
                    meta["latency_ms"] = latency_ms

                if resp.status_code != 200:
                    err_msg = f"Ollama HTTP {resp.status_code}: {resp.text[:200]}"
                    logger.warning(err_msg)
                    if attempt < max_retries:
                        await asyncio.sleep(1.0)
                        continue
                    return False, None, err_msg

                data = resp.json()
                if meta is not None:
                    meta["prompt_tokens"] = data.get("prompt_eval_count")
                    meta["completion_tokens"] = data.get("eval_count")

                raw_response = data.get("response", "")
                cleaned = clean_json_text(raw_response)

                if format_json:
                    try:
                        parsed = json.loads(cleaned)
                        logger.info(f"✅ [Qwen 2.5 7B] Hoàn tất sau {latency_ms}ms (JSON hợp lệ).")
                        return True, parsed, ""
                    except json.JSONDecodeError as jde:
                        logger.warning(f"Lỗi parse JSON lần {attempt + 1}: {jde}. Raw: {raw_response[:200]}")
                        if attempt < max_retries:
                            # Tăng nhẹ temperature hoặc nhắc lại JSON
                            payload["prompt"] = f"{prompt}\n\nIMPORTANT: Output strictly raw valid JSON. Do not cut off."
                            await asyncio.sleep(0.5)
                            continue
                        return False, None, f"JSON parse error: {jde}"
                else:
                    return True, {"text": raw_response}, ""

        except httpx.TimeoutException:
            logger.error(f"⏱️ [Qwen 2.5 7B Timeout] Hết thời gian chờ {effective_timeout}s khi kết nối Ollama!")
            return False, None, f"Timeout {effective_timeout}s: Mô hình AI mất quá nhiều thời gian để phản hồi."
        except httpx.ConnectError:
            logger.error(f"🔌 [Qwen 2.5 7B ConnectError] Không thể kết nối tới Ollama tại {settings.OLLAMA_BASE_URL}!")
            return False, None, "Không thể kết nối tới dịch vụ Ollama local. Vui lòng kiểm tra xem Ollama đã chạy chưa."
        except Exception as e:
            logger.exception(f"Lỗi không xác định khi gọi Ollama: {e}")
            if attempt < max_retries:
                await asyncio.sleep(1.0)
                continue
            return False, None, str(e)

    return False, None, "Không thể hoàn thành yêu cầu suy luận sau các lần thử."

