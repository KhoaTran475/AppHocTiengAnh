import asyncio
import os
import sys
import json

# Cấu hình UTF-8 cho console Windows
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")

os.environ["DATABASE_URL"] = "sqlite:///./ielts_vision_backend.db"

backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from app.db.session import SessionLocal
from app.models.skill import SkillLesson
from app.services.ai_grading_service import grade_writing_with_qwen

USER_ESSAY = """The bar chart compares the figures for urban and rural areas over a ten-year period from 2015 to 2025.   Overall, both urban and rural percentages showed an upward trend throughout the period. Additionally, the figures for urban areas consistently remained higher than those for rural areas in all given years.   In 2015, the percentage of urban areas stood at 6, while the figure for rural areas was significantly lower at 3%. Over the next three years, both categories experienced a gradual increase, reaching 7% for urban and 4% for rural in 2018.   By 2020, the urban figure grew further to 8%, and the rural figure rose to 5%. At the end of the period in 2025, urban areas peaked at 9%, whereas rural areas reached their highest point at 78%."""

async def main():
    db = SessionLocal()
    lesson = db.query(SkillLesson).filter(SkillLesson.id == "w1").first()
    print("Lesson:", lesson.title)
    
    result = await grade_writing_with_qwen(lesson, USER_ESSAY)
    print("\n" + "=" * 60)
    print("GRADING RESULT:")
    print("Band:", result.get("band_score"))
    print("AI Used:", result.get("ai_used"))
    print("Feedback JSON:")
    print(json.dumps(result.get("writing_feedback", {}), ensure_ascii=False, indent=2))
    db.close()

if __name__ == "__main__":
    asyncio.run(main())
