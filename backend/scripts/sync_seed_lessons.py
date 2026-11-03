import sys
import os
sys.path.insert(0, os.path.abspath('backend'))

from app.db.session import SessionLocal
from app.services.skill_service import seed_default_skill_lessons, SAMPLE_SKILL_LESSONS
from app.models.skill import SkillLesson

db = SessionLocal()
seed_default_skill_lessons(db)
w1 = db.query(SkillLesson).filter(SkillLesson.id == 'w1').first()
print("W1 updated successfully!")
print("Has chart_data:", 'chart_data' in w1.content_json)
if 'chart_data' in w1.content_json:
    print("chart_data:", w1.content_json['chart_data'])
db.close()
