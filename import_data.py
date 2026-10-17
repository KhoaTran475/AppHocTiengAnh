import json
from supabase import create_client

# 1. URL chuẩn (không có /rest/v1)
SUPABASE_URL = "https://tcbcmzfdidcwblvfmckb.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRjYmNtemZkaWRjd2JsdmZtY2tiIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTI3MTg1NCwiZXhwIjoyMTA2ODQ3ODU0fQ.F6r_J2HlEp_YROwMDmVLpKo6talLid_EbEbxGAf0no4"

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# 2. Đọc file JSON
with open("assets/data/ielts_vocab_80_labels.json", "r", encoding="utf-8") as f:
    data = json.load(f)

# 3. Lọc bỏ trùng lặp nhãn (label) bằng Dictionary
unique_records = {}

for item in data:
    raw_label = item.get("label")
    if not raw_label:
        continue
    
    label = str(raw_label).strip().lower()
    
    unique_records[label] = {
        "label": label,
        "common_word": item.get("common_word", item.get("word", "")),
        "vietnamese_meaning": item.get("vietnamese_meaning", item.get("translation", "")),
        "academic_word": item.get("academic_word", item.get("word", "")),
        "ipa": item.get("ipa", ""),
        "band_score": str(item.get("band_score", "7.0")),
        "collocations": item.get("collocations", []),
        "idioms": item.get("idioms", "") or "",
        "speaking_part1_example": item.get("speaking_part1_example", item.get("example", "")) or "",
        "speaking_part1_translation": item.get("speaking_part1_translation", item.get("example_translation", "")) or ""
    }

records = list(unique_records.values())
print(f"Tổng số từ sau khi lọc trùng lặp label: {len(records)} từ.")
print("Đang đẩy dữ liệu lên Supabase...")

# 4. Gửi lên Supabase theo từng đợt (Batching)
batch_size = 20
for i in range(0, len(records), batch_size):
    batch = records[i:i + batch_size]
    supabase.table("object_mappings").upsert(batch, on_conflict="label").execute()
    print(f"-> Đã tải lên {min(i + batch_size, len(records))}/{len(records)} từ...")

print("✅ ĐÃ IMPORT THÀNH CÔNG TOÀN BỘ DỮ LIỆU VÀO OBJECT_MAPPINGS!")