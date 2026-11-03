import os
import sys
import io
import time
import requests
from PIL import Image, ImageDraw, ImageFont

if sys.stdout.encoding != "utf-8":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass


API_URL = "http://localhost:8000/api/v1/vision/deep-scan"


def create_sample_object_image() -> bytes:
    """Tạo một hình ảnh mẫu đại diện cho một vật thể ngoài 80 nhãn COCO (ví dụ: Đồng hồ đeo tay - Wristwatch)."""
    img = Image.new("RGB", (400, 400), color=(240, 240, 245))
    draw = ImageDraw.Draw(img)

    # Vẽ dây đeo đồng hồ
    draw.rectangle([160, 40, 240, 360], fill=(70, 70, 80))
    # Vẽ mặt đồng hồ tròn
    draw.ellipse([120, 120, 280, 280], fill=(255, 255, 255), outline=(30, 30, 40), width=6)
    draw.ellipse([135, 135, 265, 265], fill=(245, 245, 250), outline=(150, 150, 160), width=2)
    # Vẽ kim đồng hồ
    draw.line([200, 200, 200, 155], fill=(20, 20, 20), width=4)
    draw.line([200, 200, 235, 200], fill=(20, 20, 20), width=3)
    draw.ellipse([194, 194, 206, 206], fill=(220, 50, 50))
    # Chữ mô tả
    draw.text((140, 300), "WRISTWATCH", fill=(100, 100, 120))

    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=80)
    return buf.getvalue()


def run_test():
    print("=" * 60)
    print("🚀 BẮT ĐẦU KIỂM THỬ PHA 1: DEEP SCAN VỚI OLLAMA LLaVA-Phi3")
    print("=" * 60)

    img_bytes = create_sample_object_image()
    print(f"📦 Dung lượng ảnh nén gửi đi: {len(img_bytes) / 1024:.2f} KB (< 200KB chuẩn)")

    # 1. Lần gọi 1: Cache MISS -> LLaVA-Phi3 sinh dữ liệu
    print("\n[LẦN 1] Gửi ảnh phân tích (Kỳ vọng: Cache MISS -> LLaVA-Phi3 sinh dữ liệu)...")
    t0 = time.time()
    try:
        files = {"file": ("wristwatch_sample.jpg", img_bytes, "image/jpeg")}
        resp1 = requests.post(API_URL, files=files, timeout=60)
        t1 = time.time()
        print(f"⏱️ Thời gian phản hồi lần 1: {t1 - t0:.2f}s | HTTP Status: {resp1.status_code}")

        if resp1.status_code != 200:
            print(f"❌ Thất bại: {resp1.text}")
            return False

        data1 = resp1.json()
        print(f"✅ Nguồn dữ liệu: {data1.get('source')} (Mong đợi: 'ollama')")
        vocab1 = data1.get("vocabulary", {})
        print(f"   - Label: {vocab1.get('label')}")
        print(f"   - Common Word: {vocab1.get('common_word')}")
        print(f"   - Academic Word: {vocab1.get('academic_word')}")
        print(f"   - Vietnamese: {vocab1.get('vietnamese_meaning')}")
        print(f"   - IPA: {vocab1.get('ipa')}")
        print(f"   - Band Score: {vocab1.get('band_score')}")
        print(f"   - Collocations: {vocab1.get('collocations')}")
        print(f"   - Speaking Example: {vocab1.get('speaking_part1_example')}")
        print(f"   - Speaking Trans: {vocab1.get('speaking_part1_translation')}")

    except Exception as e:
        print(f"❌ Lỗi kết nối API: {e}")
        return False

    # 2. Lần gọi 2: Cache HIT -> Lấy ngay từ DB trong vài mili-giây
    print("\n[LẦN 2] Gửi lại cùng một ảnh (Kỳ vọng: Cache HIT -> Lấy từ DB siêu tốc)...")
    t2 = time.time()
    try:
        files = {"file": ("wristwatch_sample.jpg", img_bytes, "image/jpeg")}
        resp2 = requests.post(API_URL, files=files, timeout=60)
        t3 = time.time()
        print(f"⏱️ Thời gian phản hồi lần 2: {t3 - t2:.2f}s | HTTP Status: {resp2.status_code}")

        if resp2.status_code != 200:
            print(f"❌ Thất bại lần 2: {resp2.text}")
            return False

        data2 = resp2.json()
        print(f"✅ Nguồn dữ liệu: {data2.get('source')} (Mong đợi: 'cache' hoặc 'ollama')")
        print(f"   - Label: {data2.get('vocabulary', {}).get('label')}")
        print(f"   - Academic Word: {data2.get('vocabulary', {}).get('academic_word')}")

    except Exception as e:
        print(f"❌ Lỗi lần 2: {e}")
        return False

    print("\n" + "=" * 60)
    print("🎉 HOÀN THÀNH KIỂM THỬ PHA 1 XUẤT SẮC!")
    print("=" * 60)
    return True


if __name__ == "__main__":
    run_test()
