import os
import sys
import re
import json
import time
import requests
from typing import List


if sys.stdout.encoding != "utf-8":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.db.session import SessionLocal
from app.models.mapping import ObjectMapping


OLLAMA_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")

EXTENDED_IELTS_OBJECTS = [
    "eyeglasses",
    "ballpoint pen",
    "pencil",
    "stapler",
    "highlighter",
    "calculator",
    "notebook",
    "wristwatch",
    "headphones",
    "earbuds",
    "wallet",
    "keychain",
    "desk lamp",
    "ceiling fan",
    "water tumbler",
    "whiteboard",
    "microscope",
    "guitar",
    "violin",
    "projector",
    "calendar",
    "curtain",
    "bookshelf",
    "paper clip",
    "scissors",
]


def generate_vocab_for_object(object_name: str) -> dict:
    prompt = f"""You are an expert IELTS examiner and English lexicographer.
Provide academic IELTS Band 7.5+ vocabulary and Collocations for the object: '{object_name}'.
You MUST return ONLY a JSON object with this exact structure:
{{
  "label": "{object_name.lower().strip()}",
  "common_word": "{object_name.lower().strip()}",
  "vietnamese_meaning": "accurate Vietnamese translation for this object",
  "academic_word": "IELTS academic Band 7.5-8.5 formal synonym or term",
  "ipa": "IPA pronunciation for the academic word",
  "band_score": "7.5",
  "collocations": ["collocation 1", "collocation 2"],
  "idioms": "a relevant idiom if applicable or empty string",
  "speaking_part1_example": "A natural IELTS Speaking Part 1 answer using this object",
  "speaking_part1_translation": "Vietnamese translation of the speaking sentence"
}}
Output purely the JSON object."""

    payload = {
        "model": "llava-phi3:latest",
        "prompt": prompt,
        "format": "json",
        "stream": False,
        "options": {
            "temperature": 0.1,
            "num_predict": 512,
        },
    }

    resp = requests.post(f"{OLLAMA_URL}/api/generate", json=payload, timeout=40)
    resp.raise_for_status()
    raw = resp.json().get("response", "")

    # Clean text
    clean = raw.strip()
    clean = re.sub(r"^```(?:json)?\s*", "", clean, flags=re.IGNORECASE)
    clean = re.sub(r"\s*```$", "", clean).strip()
    s = clean.find("{")
    e = clean.rfind("}")
    if s != -1 and e != -1:
        clean = clean[s : e + 1]

    return json.loads(clean)


def expand_database(objects: List[str]):
    print("=" * 65)
    print("🚀 BẮT ĐẦU MỞ RỘNG KHO TỪ VỰNG IELTS BẰNG OLLAMA PHI-3 LOCAL")
    print(f"📌 Tổng số vật thể mục tiêu: {len(objects)}")
    print("=" * 65)

    db = SessionLocal()
    success_count = 0
    skip_count = 0

    try:
        for idx, obj in enumerate(objects, start=1):
            norm_label = obj.lower().strip()
            print(f"\n[{idx}/{len(objects)}] Đang kiểm tra vật thể: '{norm_label}'...")

            # 1. Kiểm tra xem đã có trong DB chưa
            existing = (
                db.query(ObjectMapping)
                .filter(ObjectMapping.label == norm_label)
                .first()
            )
            if existing:
                print(f"   ⏩ Đã tồn tại trong Database -> Bỏ qua.")
                skip_count += 1
                continue

            # 2. Sinh từ mới qua Ollama
            print(f"   🧠 Đang gọi Ollama Phi-3 tạo từ vựng Band 7.5+...")
            t0 = time.time()
            try:
                data = generate_vocab_for_object(norm_label)
                elapsed = time.time() - t0
                print(f"   ✨ Đã sinh xong trong {elapsed:.1f}s:")
                print(f"      - Academic: {data.get('academic_word')} ({data.get('ipa')})")
                print(f"      - Vietnamese: {data.get('vietnamese_meaning')}")

                new_mapping = ObjectMapping(
                    label=norm_label,
                    common_word=data.get("common_word") or norm_label,
                    vietnamese_meaning=data.get("vietnamese_meaning") or norm_label,
                    academic_word=data.get("academic_word") or norm_label,
                    ipa=data.get("ipa") or "",
                    band_score=data.get("band_score") or "7.5",
                    collocations=data.get("collocations") or [],
                    idioms=data.get("idioms") or "",
                    speaking_part1_example=data.get("speaking_part1_example") or "",
                    speaking_part1_translation=data.get("speaking_part1_translation") or "",
                )
                db.add(new_mapping)
                db.commit()
                print(f"   💾 Đã lưu thành công vào Database (ID={new_mapping.id})!")
                success_count += 1

            except Exception as e:
                db.rollback()
                print(f"   ❌ Lỗi sinh từ cho '{norm_label}': {e}")

    finally:
        db.close()

    print("\n" + "=" * 65)
    print(f"🎉 HOÀN THÀNH MỞ RỘNG:")
    print(f"   - Thêm mới thành công: {success_count} vật thể")
    print(f"   - Đã có sẵn: {skip_count} vật thể")
    print("=" * 65)


if __name__ == "__main__":
    expand_database(EXTENDED_IELTS_OBJECTS)


