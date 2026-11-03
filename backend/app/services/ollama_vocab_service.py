import os
import re
import json
import uuid
import random
import logging
import math
import time
from datetime import datetime
from typing import List, Optional, Tuple, Dict, Any

import httpx
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.supabase import get_supabase_admin
from app.services.notebook_service import resolve_user_uuid
from app.models.user import User
from app.models.skill import PracticeHistory, UserStageProgress
from app.models.vocab_learning import VocabLearningCard, UserVocabMastery, SystemVocabConfig
from app.schemas.vocab_learning import (
    VocabCardWithMasteryResponse,
    VocabLevelInfoResponse,
    VocabRoadmapResponse,
    OllamaStatusResponse,
    OllamaGenerateVocabResponse,
    OllamaSentenceEvaluateResponse,
    MasteryUpdateResponse,
    VocabQuizQuestionSchema,
    VocabQuizResponse,
    VocabQuizSubmitRequest,
    VocabQuizSubmitResponse,
    SystemVocabConfigResponse,
    SystemVocabConfigUpdate,
)

logger = logging.getLogger(__name__)

OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", settings.OLLAMA_BASE_URL)
DEFAULT_QWEN_MODEL = os.getenv("OLLAMA_VOCAB_MODEL", settings.OLLAMA_VOCAB_MODEL)

# ─────────────────────────────────────────────────────────────────────────────
# 1. CẤU HÌNH 5 CẤP ĐỘ LỘ TRÌNH HỌC TỪ VỰNG (CƠ BẢN -> NÂNG CAO)
# ─────────────────────────────────────────────────────────────────────────────

LEVEL_METADATA: Dict[int, Dict[str, Any]] = {
    1: {
        "level": 1,
        "title": "Cấp độ 1: Cơ bản (Foundation)",
        "subtitle": "Từ vựng nền tảng giao tiếp & đời sống hàng ngày",
        "cefr_level": "A2-B1",
        "band_target": "4.5 - 5.5",
        "pass_score_required": 3,
    },
    2: {
        "level": 2,
        "title": "Cấp độ 2: Trung cấp (Intermediate)",
        "subtitle": "Từ vựng xã hội, giáo dục, công nghệ & môi trường",
        "cefr_level": "B1-B2",
        "band_target": "6.0 - 6.5",
        "pass_score_required": 3,
    },
    3: {
        "level": 3,
        "title": "Cấp độ 3: Nâng cao (Upper-Intermediate)",
        "subtitle": "Từ vựng học thuật (AWL) & Collocations tự nhiên",
        "cefr_level": "B2-C1",
        "band_target": "7.0",
        "pass_score_required": 4,
    },
    4: {
        "level": 4,
        "title": "Cấp độ 4: Học thuật Chuyên sâu (Advanced)",
        "subtitle": "Từ đồng nghĩa học thuật cao cấp cho Writing & Speaking",
        "cefr_level": "C1",
        "band_target": "7.5 - 8.0",
        "pass_score_required": 4,
    },
    5: {
        "level": 5,
        "title": "Cấp độ 5: Bậc thầy IELTS (Master)",
        "subtitle": "Từ vựng sắc thái tinh tế & chuyên ngành học thuật đỉnh cao",
        "cefr_level": "C2",
        "band_target": "8.5+",
        "pass_score_required": 4,
    },
}


# ─────────────────────────────────────────────────────────────────────────────
# 2. KHO DỮ LIỆU HẠT GIỐNG 30 THẺ TỪ VỰNG PHÂN CẤP (LEVEL 1 -> LEVEL 5)
# ─────────────────────────────────────────────────────────────────────────────

DEFAULT_VOCAB_CARDS: List[Dict[str, Any]] = [
    # ══════════════════ LEVEL 1: CƠ BẢN (A2-B1 | Band 4.5 - 5.5) ══════════════════
    {
        "level": 1,
        "cefr_level": "A2-B1",
        "band_target": "5.0",
        "topic": "Daily Life & Habits",
        "word": "essential",
        "basic_word": "important / needed",
        "intermediate_word": "essential / vital",
        "advanced_word": "indispensable / paramount",
        "ipa": "/ɪˈsen.ʃəl/",
        "part_of_speech": "adjective",
        "vietnamese_meaning": "Cần thiết, thiết yếu, vô cùng quan trọng",
        "collocations": ["essential for health", "essential skill", "play an essential role"],
        "word_family": {"noun": "essence", "adjective": "essential", "adverb": "essentially"},
        "synonyms": ["vital", "crucial", "necessary", "indispensable"],
        "example_basic": "Water is very important for our body every day.",
        "example_advanced": "Balanced nutrition and regular exercise are essential for maintaining long-term physical well-being.",
        "example_translation": "Dinh dưỡng cân bằng và tập thể dục thường xuyên là yếu tố thiết yếu để duy trì sức khỏe thể chất lâu dài.",
        "nuance_note": "Thay vì lặp lại từ 'important' ở mức A2, dùng 'essential' giúp câu văn đạt chuẩn B1-B2 tự nhiên hơn.",
    },
    {
        "level": 1,
        "cefr_level": "A2-B1",
        "band_target": "5.0",
        "topic": "Education & Learning",
        "word": "improve",
        "basic_word": "make better",
        "intermediate_word": "improve / enhance",
        "advanced_word": "ameliorate / elevate",
        "ipa": "/ɪmˈpruːv/",
        "part_of_speech": "verb",
        "vietnamese_meaning": "Cải thiện, nâng cao, làm cho tốt hơn",
        "collocations": ["improve communication skills", "improve academic performance", "room for improvement"],
        "word_family": {"noun": "improvement", "verb": "improve", "adjective": "improved"},
        "synonyms": ["enhance", "upgrade", "boost", "refine"],
        "example_basic": "I practice speaking every day to make my English better.",
        "example_advanced": "Consistent daily practice can significantly improve a learner's pronunciation and fluency.",
        "example_translation": "Luyện tập đều đặn hàng ngày có thể cải thiện đáng kể khả năng phát âm và độ trôi chảy của người học.",
        "nuance_note": "'Improve' là động từ nền tảng. Khi lên Band 6.5+, có thể nâng cấp thành 'enhance' (nâng cao giá trị/chất lượng).",
    },
    {
        "level": 1,
        "cefr_level": "A2-B1",
        "band_target": "5.5",
        "topic": "Work & Career",
        "word": "opportunity",
        "basic_word": "good chance",
        "intermediate_word": "opportunity / prospect",
        "advanced_word": "avenue / golden juncture",
        "ipa": "/ˌɒp.əˈtjuː.nə.ti/",
        "part_of_speech": "noun",
        "vietnamese_meaning": "Cơ hội, dịp thuận lợi",
        "collocations": ["equal opportunity", "seize an opportunity", "career opportunities"],
        "word_family": {"noun": "opportunity", "adjective": "opportune"},
        "synonyms": ["chance", "prospect", "opening", "possibility"],
        "example_basic": "Studying abroad gives me a good chance to get a good job.",
        "example_advanced": "Mastering a foreign language opens up numerous career opportunities in multinational corporations.",
        "example_translation": "Thành thạo ngoại ngữ mở ra vô số cơ hội nghề nghiệp tại các tập đoàn đa quốc gia.",
        "nuance_note": "Đi kèm rất tự nhiên với các động từ 'provide', 'create', 'seize' (nắm bắt cơ hội).",
    },
    {
        "level": 1,
        "cefr_level": "A2-B1",
        "band_target": "5.5",
        "topic": "Environment",
        "word": "protect",
        "basic_word": "keep safe",
        "intermediate_word": "protect / preserve",
        "advanced_word": "safeguard / conserve",
        "ipa": "/prəˈtekt/",
        "part_of_speech": "verb",
        "vietnamese_meaning": "Bảo vệ, che chở khỏi nguy hại",
        "collocations": ["protect the environment", "protect endangered species", "protective measures"],
        "word_family": {"noun": "protection", "verb": "protect", "adjective": "protective"},
        "synonyms": ["defend", "preserve", "safeguard", "conserve"],
        "example_basic": "We should keep trees and animals safe from harm.",
        "example_advanced": "Citizens and governments must work together to protect natural habitats from pollution.",
        "example_translation": "Người dân và chính phủ phải cùng nhau hợp tác để bảo vệ môi trường sống tự nhiên khỏi ô nhiễm.",
        "nuance_note": "Ở mức cơ bản dùng 'protect', mức trung cấp dùng 'preserve' (bảo tồn nguyên trạng) và nâng cao dùng 'safeguard'.",
    },
    {
        "level": 1,
        "cefr_level": "A2-B1",
        "band_target": "5.5",
        "topic": "Technology",
        "word": "convenient",
        "basic_word": "easy to use",
        "intermediate_word": "convenient / accessible",
        "advanced_word": "seamless / user-centric",
        "ipa": "/kənˈviː.ni.ənt/",
        "part_of_speech": "adjective",
        "vietnamese_meaning": "Tiện lợi, thuận tiện",
        "collocations": ["convenient location", "convenient way", "modern conveniences"],
        "word_family": {"noun": "convenience", "adjective": "convenient", "adverb": "conveniently"},
        "synonyms": ["handy", "practical", "accessible", "time-saving"],
        "example_basic": "Smartphones make online shopping very easy to use.",
        "example_advanced": "Public transportation provides a convenient and affordable commuting option for city dwellers.",
        "example_translation": "Giao thông công cộng mang lại lựa chọn di chuyển thuận tiện và tiết kiệm cho cư dân thành phố.",
        "nuance_note": "Lưu ý: Không dùng 'Rich people are convenient' (người không thể convenient, chỉ sự vật/kế hoạch mới convenient).",
    },
    {
        "level": 1,
        "cefr_level": "A2-B1",
        "band_target": "5.5",
        "topic": "Health & Lifestyle",
        "word": "benefit",
        "basic_word": "good thing",
        "intermediate_word": "benefit / advantage",
        "advanced_word": "merit / boon",
        "ipa": "/ˈben.ɪ.fɪt/",
        "part_of_speech": "noun / verb",
        "vietnamese_meaning": "Lợi ích, mang lại lợi ích",
        "collocations": ["reap the benefits", "health benefits", "mutually beneficial"],
        "word_family": {"noun": "benefit", "verb": "benefit", "adjective": "beneficial"},
        "synonyms": ["advantage", "merit", "upside", "asset"],
        "example_basic": "Reading books has many good things for children.",
        "example_advanced": "Regular outdoor activities offer tremendous psychological benefits for young children.",
        "example_translation": "Các hoạt động ngoài trời thường xuyên mang lại lợi ích tâm lý to lớn cho trẻ nhỏ.",
        "nuance_note": "Vừa là danh từ ('offer benefits') vừa là động từ ('benefit from something').",
    },

    # ══════════════════ LEVEL 2: TRUNG CẤP (B1-B2 | Band 6.0 - 6.5) ══════════════════
    {
        "level": 2,
        "cefr_level": "B1-B2",
        "band_target": "6.0",
        "topic": "Social Issues",
        "word": "significant",
        "basic_word": "big / large",
        "intermediate_word": "significant / considerable",
        "advanced_word": "substantial / profound",
        "ipa": "/sɪɡˈnɪf.ɪ.kənt/",
        "part_of_speech": "adjective",
        "vietnamese_meaning": "Đáng kể, quan trọng, có ý nghĩa lớn",
        "collocations": ["significant impact", "statistically significant", "significant proportion"],
        "word_family": {"noun": "significance", "adjective": "significant", "adverb": "significantly"},
        "synonyms": ["considerable", "notable", "marked", "substantial"],
        "example_basic": "There was a big increase in the number of online learners.",
        "example_advanced": "The chart illustrates a significant surge in renewable energy consumption over the past decade.",
        "example_translation": "Biểu đồ minh họa mức tăng trưởng đáng kể trong việc tiêu thụ năng lượng tái tạo suốt thập kỷ qua.",
        "nuance_note": "Từ khóa vàng cho IELTS Writing Task 1 & Task 2 để thay thế hoàn toàn 'big' hoặc 'a lot of'.",
    },
    {
        "level": 2,
        "cefr_level": "B1-B2",
        "band_target": "6.5",
        "topic": "Education & Technology",
        "word": "facilitate",
        "basic_word": "help / make easier",
        "intermediate_word": "facilitate / assist",
        "advanced_word": "catalyze / streamline",
        "ipa": "/fəˈsɪl.ɪ.teɪt/",
        "part_of_speech": "verb",
        "vietnamese_meaning": "Tạo điều kiện thuận lợi, thúc đẩy quá trình dễ dàng hơn",
        "collocations": ["facilitate learning", "facilitate communication", "facilitate economic growth"],
        "word_family": {"noun": "facilitation / facilitator", "verb": "facilitate"},
        "synonyms": ["assist", "ease", "promote", "expedite"],
        "example_basic": "The internet helps students find information faster.",
        "example_advanced": "Interactive digital platforms greatly facilitate collaborative learning among remote students.",
        "example_translation": "Các nền tảng kỹ thuật số tương tác tạo điều kiện vô cùng thuận lợi cho việc học tập hợp tác giữa các sinh viên từ xa.",
        "nuance_note": "Lưu ý: Tân ngữ của 'facilitate' nên là một hoạt động/quá trình (learning, trade) chứ không phải là người.",
    },
    {
        "level": 2,
        "cefr_level": "B1-B2",
        "band_target": "6.5",
        "topic": "Environment & Ecology",
        "word": "sustainable",
        "basic_word": "long-lasting / green",
        "intermediate_word": "sustainable / eco-friendly",
        "advanced_word": "ecologically viable / regenerative",
        "ipa": "/səˈsteɪ.nə.bəl/",
        "part_of_speech": "adjective",
        "vietnamese_meaning": "Bền vững, thân thiện và duy trì lâu dài",
        "collocations": ["sustainable development", "sustainable energy sources", "environmentally sustainable"],
        "word_family": {"noun": "sustainability", "verb": "sustain", "adjective": "sustainable"},
        "synonyms": ["viable", "renewable", "enduring", "eco-conscious"],
        "example_basic": "We need to use green energy that does not run out.",
        "example_advanced": "Transitioning to sustainable agricultural practices is vital for global food security.",
        "example_translation": "Chuyển đổi sang các phương thức canh tác nông nghiệp bền vững là điều sống còn đối với an ninh lương thực toàn cầu.",
        "nuance_note": "Dùng rộng rãi cho cả Môi trường ('sustainable energy') lẫn Kinh tế ('sustainable economic growth').",
    },
    {
        "level": 2,
        "cefr_level": "B1-B2",
        "band_target": "6.5",
        "topic": "Health & Psychology",
        "word": "detrimental",
        "basic_word": "bad / harmful",
        "intermediate_word": "detrimental / damaging",
        "advanced_word": "deleterious / pernicious",
        "ipa": "/ˌdet.rɪˈmen.təl/",
        "part_of_speech": "adjective",
        "vietnamese_meaning": "Có hại, gây tổn hại, bất lợi",
        "collocations": ["detrimental effect on", "detrimental to mental health", "prove detrimental"],
        "word_family": {"noun": "detriment", "adjective": "detrimental", "adverb": "detrimentally"},
        "synonyms": ["harmful", "damaging", "adverse", "deleterious"],
        "example_basic": "Too much screen time is bad for children's eyes.",
        "example_advanced": "Excessive exposure to social media can have a detrimental effect on adolescents' mental well-being.",
        "example_translation": "Việc tiếp xúc quá mức với mạng xã hội có thể gây tác động có hại đến sức khỏe tinh thần của thanh thiếu niên.",
        "nuance_note": "Luôn đi kèm giới từ 'to': 'be detrimental to something' = 'be harmful to something'.",
    },
    {
        "level": 2,
        "cefr_level": "B1-B2",
        "band_target": "6.0",
        "topic": "Career & Economy",
        "word": "perspective",
        "basic_word": "view / opinion",
        "intermediate_word": "perspective / viewpoint",
        "advanced_word": "vantage point / paradigm",
        "ipa": "/pəˈspek.tɪv/",
        "part_of_speech": "noun",
        "vietnamese_meaning": "Góc nhìn, quan điểm, viễn cảnh",
        "collocations": ["broaden one's perspective", "from a global perspective", "put into perspective"],
        "word_family": {"noun": "perspective"},
        "synonyms": ["viewpoint", "standpoint", "outlook", "angle"],
        "example_basic": "Travel helps young people have a new view of life.",
        "example_advanced": "Experiencing diverse cultures enables young people to broaden their perspective on global issues.",
        "example_translation": "Trải nghiệm các nền văn hóa đa dạng giúp người trẻ mở rộng góc nhìn về các vấn đề toàn cầu.",
        "nuance_note": "Cụm 'broaden one's perspective / horizons' rất ăn điểm trong IELTS Speaking Part 2 & Part 3.",
    },
    {
        "level": 2,
        "cefr_level": "B1-B2",
        "band_target": "6.5",
        "topic": "Urbanization",
        "word": "accommodate",
        "basic_word": "hold / give space",
        "intermediate_word": "accommodate / adapt to",
        "advanced_word": "cater to / encompass",
        "ipa": "/əˈkɒm.ə.deɪt/",
        "part_of_speech": "verb",
        "vietnamese_meaning": "Cung cấp chỗ ở, chứa được, đáp ứng nhu cầu",
        "collocations": ["accommodate growing populations", "accommodate diverse needs", "spacious accommodation"],
        "word_family": {"noun": "accommodation", "verb": "accommodate", "adjective": "accommodating"},
        "synonyms": ["house", "lodge", "adapt", "cater to"],
        "example_basic": "New cities need more buildings to hold more people.",
        "example_advanced": "Urban infrastructure must be expanded to accommodate the rapidly growing metropolitan population.",
        "example_translation": "Cơ sở hạ tầng đô thị phải được mở rộng để đáp ứng quy mô dân số đô thị đang gia tăng nhanh chóng.",
        "nuance_note": "Chú ý chính tả: có 2 chữ 'c' và 2 chữ 'm' (a-cc-o-mm-odate).",
    },

    # ══════════════════ LEVEL 3: NÂNG CAO (B2-C1 | Band 7.0) ══════════════════
    {
        "level": 3,
        "cefr_level": "B2-C1",
        "band_target": "7.0",
        "topic": "Climate & Environment",
        "word": "mitigate",
        "basic_word": "reduce / make less bad",
        "intermediate_word": "alleviate / lessen",
        "advanced_word": "mitigate / attenuate",
        "ipa": "/ˈmɪt.ɪ.ɡeɪt/",
        "part_of_speech": "verb",
        "vietnamese_meaning": "Giảm thiểu, làm dịu bớt mức độ nghiêm trọng",
        "collocations": ["mitigate climate change", "mitigate the risks", "mitigating circumstances"],
        "word_family": {"noun": "mitigation", "verb": "mitigate"},
        "synonyms": ["alleviate", "curb", "diminish", "assuage"],
        "example_basic": "Planting more trees helps reduce global warming.",
        "example_advanced": "Afforestation and carbon taxation are effective strategies to mitigate the adverse effects of climate change.",
        "example_translation": "Trồng rừng và đánh thuế carbon là những chiến lược hiệu quả nhằm giảm thiểu các tác động bất lợi của biến đổi khí hậu.",
        "nuance_note": "Cực kỳ chuẩn học thuật khi đi với các danh từ chỉ rủi ro, hậu quả: 'mitigate risks / impacts / consequences'.",
    },
    {
        "level": 3,
        "cefr_level": "B2-C1",
        "band_target": "7.0",
        "topic": "Technology & Innovation",
        "word": "ubiquitous",
        "basic_word": "everywhere / very common",
        "intermediate_word": "widespread / prevalent",
        "advanced_word": "ubiquitous / omnipresent",
        "ipa": "/juːˈbɪk.wɪ.təs/",
        "part_of_speech": "adjective",
        "vietnamese_meaning": "Có mặt ở khắp mọi nơi, phổ biến toàn diện",
        "collocations": ["become ubiquitous", "ubiquitous presence", "ubiquitous smartphones"],
        "word_family": {"noun": "ubiquity", "adjective": "ubiquitous", "adverb": "ubiquitously"},
        "synonyms": ["omnipresent", "pervasive", "everywhere", "universal"],
        "example_basic": "Today, mobile phones and Wi-Fi can be seen everywhere.",
        "example_advanced": "In the contemporary digital era, smartphones and wireless connectivity have become ubiquitous in daily life.",
        "example_translation": "Trong kỷ nguyên số đương đại, điện thoại thông minh và kết nối không dây đã trở nên phổ biến ở khắp mọi nơi trong đời sống.",
        "nuance_note": "Nâng cấp trực tiếp từ 'common / everywhere' (Band 5.0) lên 'widespread' (Band 6.5) và 'ubiquitous' (Band 7.5+).",
    },
    {
        "level": 3,
        "cefr_level": "B2-C1",
        "band_target": "7.0",
        "topic": "Economics & Society",
        "word": "disparity",
        "basic_word": "unfair difference",
        "intermediate_word": "gap / inequality",
        "advanced_word": "disparity / discrepancy",
        "ipa": "/dɪˈspær.ə.ti/",
        "part_of_speech": "noun",
        "vietnamese_meaning": "Sự chênh lệch lớn, sự bất bình đẳng",
        "collocations": ["income disparity", "wealth disparity", "growing disparity between"],
        "word_family": {"noun": "disparity", "adjective": "disparate"},
        "synonyms": ["inequality", "gap", "imbalance", "divergence"],
        "example_basic": "There is a big difference between rich and poor areas.",
        "example_advanced": "Targeted educational subsidies can help narrow the socioeconomic disparity between urban and rural regions.",
        "example_translation": "Các khoản trợ cấp giáo dục có mục tiêu có thể giúp thu hẹp sự chênh lệch kinh tế - xã hội giữa khu vực thành thị và nông thôn.",
        "nuance_note": "Trong Writing Task 1 & 2, cụm 'narrow/widen the disparity' thay thế xuất sắc cho 'make the gap smaller/bigger'.",
    },
    {
        "level": 3,
        "cefr_level": "B2-C1",
        "band_target": "7.0",
        "topic": "Education & Policy",
        "word": "incentivize",
        "basic_word": "encourage / give rewards",
        "intermediate_word": "motivate / stimulate",
        "advanced_word": "incentivize / galvanize",
        "ipa": "/ɪnˈsen.tɪ.vaɪz/",
        "part_of_speech": "verb",
        "vietnamese_meaning": "Khuyến khích bằng lợi ích hoặc động lực cụ thể",
        "collocations": ["incentivize businesses", "financial incentives", "incentivize green innovation"],
        "word_family": {"noun": "incentive", "verb": "incentivize"},
        "synonyms": ["encourage", "motivate", "spur", "stimulate"],
        "example_basic": "Governments should give money to companies that use clean energy.",
        "example_advanced": "Tax rebates can effectively incentivize corporations to invest in renewable energy technologies.",
        "example_translation": "Việc hoàn thuế có thể khuyến khích hiệu quả các tập đoàn đầu tư vào công nghệ năng lượng tái tạo.",
        "nuance_note": "Thay vì viết dài dòng 'give money to encourage', chỉ cần dùng 'incentivize' hoặc 'provide financial incentives'.",
    },
    {
        "level": 3,
        "cefr_level": "B2-C1",
        "band_target": "7.0",
        "topic": "Health & Lifestyle",
        "word": "sedentary",
        "basic_word": "sitting a lot / inactive",
        "intermediate_word": "inactive / desk-bound",
        "advanced_word": "sedentary / lethargic",
        "ipa": "/ˈsed.ən.tər.i/",
        "part_of_speech": "adjective",
        "vietnamese_meaning": "Ít vận động, ngồi nhiều một chỗ",
        "collocations": ["lead a sedentary lifestyle", "sedentary occupation", "combat sedentary habits"],
        "word_family": {"adjective": "sedentary"},
        "synonyms": ["inactive", "stationary", "desk-bound"],
        "example_basic": "Many office workers sit all day and do not exercise enough.",
        "example_advanced": "Adopting a sedentary lifestyle significantly increases susceptibility to cardiovascular diseases and obesity.",
        "example_translation": "Việc duy trì lối sống ít vận động làm tăng đáng kể nguy cơ mắc các bệnh tim mạch và béo phì.",
        "nuance_note": "Cụm collocation kinh điển trong chủ đề Health: 'lead / adopt a sedentary lifestyle'.",
    },
    {
        "level": 3,
        "cefr_level": "B2-C1",
        "band_target": "7.0",
        "topic": "Academic Research",
        "word": "corroborate",
        "basic_word": "support / prove true",
        "intermediate_word": "confirm / verify",
        "advanced_word": "corroborate / substantiate",
        "ipa": "/kəˈrɒb.ə.reɪt/",
        "part_of_speech": "verb",
        "vietnamese_meaning": "Chứng thực, củng cố bằng bằng chứng xác đáng",
        "collocations": ["corroborate a theory", "empirical evidence corroborates", "corroborating data"],
        "word_family": {"noun": "corroboration", "verb": "corroborate", "adjective": "corroborative"},
        "synonyms": ["substantiate", "validate", "confirm", "authenticate"],
        "example_basic": "New scientific tests show that the old idea is true.",
        "example_advanced": "Recent neurological experiments corroborate the hypothesis that bilingualism delays cognitive decline.",
        "example_translation": "Các thí nghiệm thần kinh học gần đây củng cố giả thuyết rằng việc sử dụng song ngữ làm chậm quá trình suy giảm nhận thức.",
        "nuance_note": "Rất phù hợp khi trích dẫn nghiên cứu hoặc lập luận trong Writing Task 2.",
    },

    # ══════════════════ LEVEL 4: HỌC THUẬT CHUYÊN SÂU (C1 | Band 7.5 - 8.0) ══════════════════
    {
        "level": 4,
        "cefr_level": "C1",
        "band_target": "7.5",
        "topic": "Socioeconomics & Policy",
        "word": "exacerbate",
        "basic_word": "make worse",
        "intermediate_word": "worsen / aggravate",
        "advanced_word": "exacerbate / compound",
        "ipa": "/ɪɡˈzæs.ə.beɪt/",
        "part_of_speech": "verb",
        "vietnamese_meaning": "Làm trầm trọng thêm (một vấn đề hoặc tình trạng xấu)",
        "collocations": ["exacerbate social inequality", "exacerbate traffic congestion", "further exacerbate the crisis"],
        "word_family": {"noun": "exacerbation", "verb": "exacerbate"},
        "synonyms": ["aggravate", "intensify", "compound", "worsen"],
        "example_basic": "Uncontrolled migration can make city traffic worse.",
        "example_advanced": "Rapid, unplanned urbanization tends to exacerbate housing shortages and environmental degradation.",
        "example_translation": "Quá trình đô thị hóa nhanh chóng nhưng thiếu quy hoạch có xu hướng làm trầm trọng thêm tình trạng thiếu hụt nhà ở và suy thoái môi trường.",
        "nuance_note": "Đối lập hoàn toàn với 'mitigate / alleviate'. Cặp từ 'exacerbate vs. mitigate' là vũ khí sắc bén cho Band 7.5+.",
    },
    {
        "level": 4,
        "cefr_level": "C1",
        "band_target": "8.0",
        "topic": "Education & Pedagogy",
        "word": "pedagogy",
        "basic_word": "teaching method",
        "intermediate_word": "instructional approach",
        "advanced_word": "pedagogy / didactic framework",
        "ipa": "/ˈped.ə.ɡɒdʒ.i/",
        "part_of_speech": "noun",
        "vietnamese_meaning": "Phương pháp sư phạm, khoa học giảng dạy",
        "collocations": ["modern pedagogy", "learner-centered pedagogy", "pedagogical innovation"],
        "word_family": {"noun": "pedagogy", "adjective": "pedagogical", "adverb": "pedagogically"},
        "synonyms": ["instruction", "educational methodology", "didactics"],
        "example_basic": "AI tools help teachers use better teaching methods in class.",
        "example_advanced": "Integrating artificial intelligence into modern pedagogy empowers educators to personalize student learning trajectories.",
        "example_translation": "Việc tích hợp trí tuệ nhân tạo vào phương pháp sư phạm hiện đại trao quyền cho nhà giáo cá nhân hóa lộ trình học tập của học sinh.",
        "nuance_note": "Tính từ 'pedagogical' (vd: 'pedagogical value') giúp bài luận chủ đề Education đạt chuẩn C1-C2 ngay lập tức.",
    },
    {
        "level": 4,
        "cefr_level": "C1",
        "band_target": "8.0",
        "topic": "Technology & AI",
        "word": "paradigm",
        "basic_word": "model / typical pattern",
        "intermediate_word": "framework / standard",
        "advanced_word": "paradigm / archetype",
        "ipa": "/ˈpær.ə.daɪm/",
        "part_of_speech": "noun",
        "vietnamese_meaning": "Hệ hình tư duy, mô hình chuẩn mực",
        "collocations": ["paradigm shift", "dominant paradigm", "redefine the paradigm"],
        "word_family": {"noun": "paradigm", "adjective": "paradigmatic"},
        "synonyms": ["model", "framework", "pattern", "archetype"],
        "example_basic": "Generative AI has completely changed the way people work.",
        "example_advanced": "The advent of generative artificial intelligence has triggered a fundamental paradigm shift in knowledge creation.",
        "example_translation": "Sự ra đời của trí tuệ nhân tạo tạo sinh đã kích hoạt một bước chuyển dịch hệ hình căn bản trong việc sáng tạo tri thức.",
        "nuance_note": "Cụm 'trigger a paradigm shift in...' (tạo ra bước ngoặt/thay đổi hệ hình tư duy) cực kỳ ấn tượng.",
    },
    {
        "level": 4,
        "cefr_level": "C1",
        "band_target": "7.5",
        "topic": "Globalization & Culture",
        "word": "homogenization",
        "basic_word": "becoming all the same",
        "intermediate_word": "standardization / uniformity",
        "advanced_word": "homogenization / assimilation",
        "ipa": "/həˌmɒdʒ.ə.naɪˈzeɪ.ʃən/",
        "part_of_speech": "noun",
        "vietnamese_meaning": "Sự đồng nhất hóa (làm mất đi bản sắc đa dạng riêng)",
        "collocations": ["cultural homogenization", "linguistic homogenization", "resist homogenization"],
        "word_family": {"noun": "homogenization", "verb": "homogenize", "adjective": "homogeneous"},
        "synonyms": ["uniformity", "standardization", "assimilation"],
        "example_basic": "Globalization makes many cultures around the world look the same.",
        "example_advanced": "Critics contend that unchecked globalization accelerates cultural homogenization at the expense of indigenous traditions.",
        "example_translation": "Giới phê bình cho rằng toàn cầu hóa thiếu kiểm soát đẩy nhanh sự đồng nhất hóa văn hóa, đánh đổi bằng các truyền thống bản địa.",
        "nuance_note": "Từ vựng Band 8.0 chủ chốt cho mọi đề thi IELTS liên quan đến Globalization, Culture & Languages.",
    },
    {
        "level": 4,
        "cefr_level": "C1",
        "band_target": "7.5",
        "topic": "Psychology & Work",
        "word": "intrinsic",
        "basic_word": "natural / inside",
        "intermediate_word": "inherent / built-in",
        "advanced_word": "intrinsic / innate",
        "ipa": "/ɪnˈtrɪn.zɪk/",
        "part_of_speech": "adjective",
        "vietnamese_meaning": "Nội tại, bản chất bên trong, vốn có",
        "collocations": ["intrinsic motivation", "intrinsic value", "intrinsically linked to"],
        "word_family": {"adjective": "intrinsic", "adverb": "intrinsically"},
        "synonyms": ["inherent", "innate", "inborn", "fundamental"],
        "example_basic": "Students learn better when they truly love learning from inside.",
        "example_advanced": "Cultivating intrinsic motivation is far more effective for lifelong learning than relying solely on external rewards.",
        "example_translation": "Nuôi dưỡng động lực nội tại hiệu quả hơn nhiều cho việc học tập suốt đời so với việc chỉ dựa vào phần thưởng bên ngoài.",
        "nuance_note": "Cặp từ đối lập kinh điển: 'intrinsic motivation' (động lực nội tại) vs. 'extrinsic rewards' (phần thưởng ngoại cảnh).",
    },
    {
        "level": 4,
        "cefr_level": "C1",
        "band_target": "8.0",
        "topic": "Environment & Policy",
        "word": "imperative",
        "basic_word": "must-do / urgent",
        "intermediate_word": "vital / compulsory",
        "advanced_word": "imperative / paramount",
        "ipa": "/ɪmˈper.ə.tɪv/",
        "part_of_speech": "adjective / noun",
        "vietnamese_meaning": "Cấp bách, bắt buộc phải làm ngay, mệnh lệnh tối cao",
        "collocations": ["it is imperative that", "moral imperative", "economic imperative"],
        "word_family": {"noun": "imperative", "adjective": "imperative"},
        "synonyms": ["crucial", "paramount", "indispensable", "obligatory"],
        "example_basic": "Governments must act now to stop plastic pollution.",
        "example_advanced": "It is imperative that policymakers enforce stringent regulations on single-use plastics before marine ecosystems collapse.",
        "example_translation": "Điều cấp bách là các nhà hoạch định chính sách phải thực thi các quy định nghiêm ngặt đối với nhựa dùng một lần trước khi hệ sinh thái biển sụp đổ.",
        "nuance_note": "Cấu trúc giả định 'It is imperative that + S + V(nguyên thể)' giúp tăng cả điểm Lexical Resource lẫn Grammatical Range.",
    },

    # ══════════════════ LEVEL 5: BẬC THẦY IELTS (C2 | Band 8.5+) ══════════════════
    {
        "level": 5,
        "cefr_level": "C2",
        "band_target": "8.5",
        "topic": "Science & Ethics",
        "word": "double-edged sword",
        "basic_word": "has good and bad sides",
        "intermediate_word": "mixed blessing",
        "advanced_word": "double-edged sword / dichotomy",
        "ipa": "/ˌdʌb.əl.edʒd ˈsɔːd/",
        "part_of_speech": "idiomatic noun phrase",
        "vietnamese_meaning": "Con dao hai lưỡi (vừa có lợi ích lớn vừa tiềm ẩn rủi ro)",
        "collocations": ["prove to be a double-edged sword", "wield a double-edged sword"],
        "word_family": {"noun": "double-edged sword"},
        "synonyms": ["mixed blessing", "paradox", "ambivalent phenomenon"],
        "example_basic": "Artificial intelligence has both good points and bad points.",
        "example_advanced": "Biotechnological engineering is a quintessential double-edged sword, promising disease eradication while raising profound ethical dilemmas.",
        "example_translation": "Kỹ thuật công nghệ sinh học là một con dao hai lưỡi điển hình, hứa hẹn xóa sổ bệnh tật nhưng đồng thời đặt ra những tiến thoái lưỡng nan sâu sắc về đạo đức.",
        "nuance_note": "Rất đắt giá cho câu Thesis Statement trong bài luận Discussion / Advantages vs. Disadvantages.",
    },
    {
        "level": 5,
        "cefr_level": "C2",
        "band_target": "8.5",
        "topic": "Macroeconomics & Policy",
        "word": "panacea",
        "basic_word": "cure-all / perfect solution",
        "intermediate_word": "universal remedy",
        "advanced_word": "panacea / silver bullet",
        "ipa": "/ˌpæn.əˈsiː.ə/",
        "part_of_speech": "noun",
        "vietnamese_meaning": "Thuốc tiên chữa bách bệnh, giải pháp vạn năng cho mọi vấn đề",
        "collocations": ["no panacea for", "viewed as a panacea", "universal panacea"],
        "word_family": {"noun": "panacea"},
        "synonyms": ["universal cure", "elixir", "silver bullet"],
        "example_basic": "Technology alone cannot solve all social problems.",
        "example_advanced": "While technological innovation is indispensable, it should not be regarded as a panacea for deep-rooted societal inequities.",
        "example_translation": "Mặc dù đổi mới công nghệ là không thể thiếu, nó không nên được coi là giải pháp vạn năng cho những bất công xã hội đã ăn sâu bén rễ.",
        "nuance_note": "Thường dùng ở dạng phủ định ('is by no means a panacea for...') để thể hiện tư duy phản biện sắc sảo ở mức Band 8.5+.",
    },
    {
        "level": 5,
        "cefr_level": "C2",
        "band_target": "8.5",
        "topic": "Environment & Health",
        "word": "pernicious",
        "basic_word": "very harmful",
        "intermediate_word": "destructive / severe",
        "advanced_word": "pernicious / insidious",
        "ipa": "/pəˈnɪʃ.əs/",
        "part_of_speech": "adjective",
        "vietnamese_meaning": "Độc hại ngầm, gây hủy hoại âm thầm nhưng cực kỳ nguy hiểm",
        "collocations": ["pernicious influence", "pernicious effect", "pernicious misinformation"],
        "word_family": {"adjective": "pernicious", "adverb": "perniciously"},
        "synonyms": ["insidious", "deleterious", "malevolent", "noxious"],
        "example_basic": "Fake news on the internet is very bad for society.",
        "example_advanced": "The algorithmic amplification of misinformation exerts a pernicious influence on public trust and democratic institutions.",
        "example_translation": "Sự khuếch đại thông tin sai lệch bằng thuật toán gây ra ảnh hưởng độc hại ngầm đối với niềm tin công chúng và các thể chế dân chủ.",
        "nuance_note": "Cao cấp hơn 'harmful' và 'detrimental' vì 'pernicious' nhấn mạnh sự nguy hại thấm dần, khó nhận biết ngay.",
    },
    {
        "level": 5,
        "cefr_level": "C2",
        "band_target": "9.0",
        "topic": "Cognitive Science & AI",
        "word": "epitomize",
        "basic_word": "be a great example of",
        "intermediate_word": "represent / typify",
        "advanced_word": "epitomize / personify",
        "ipa": "/ɪˈpɪt.ə.maɪz/",
        "part_of_speech": "verb",
        "vietnamese_meaning": "Là hiện thân hoàn hảo của, là ví dụ điển hình nhất cho",
        "collocations": ["epitomize modern innovation", "epitomize the spirit of"],
        "word_family": {"noun": "epitome", "verb": "epitomize"},
        "synonyms": ["embodiment", "exemplify", "typify", "incarnate"],
        "example_basic": "Autonomous cars are the best example of modern AI technology.",
        "example_advanced": "Autonomous vehicles epitomize the convergence of computer vision, deep learning, and robotics.",
        "example_translation": "Phương tiện tự hành là hiện thân điển hình cho sự hội tụ của thị giác máy tính, học sâu và công nghệ robot.",
        "nuance_note": "Danh từ của nó là 'the epitome of...' (/ɪˈpɪt.ə.mi/), cực kỳ sang trọng khi đưa ví dụ trong Speaking & Writing.",
    },
    {
        "level": 5,
        "cefr_level": "C2",
        "band_target": "8.5",
        "topic": "Sociology & Governance",
        "word": "egalitarian",
        "basic_word": "equal for everyone",
        "intermediate_word": "fair / democratic",
        "advanced_word": "egalitarian / equitable",
        "ipa": "/ɪˌɡæl.ɪˈteə.ri.ən/",
        "part_of_speech": "adjective / noun",
        "vietnamese_meaning": "Bình đẳng chủ nghĩa, đảm bảo quyền lợi ngang nhau cho mọi người",
        "collocations": ["egalitarian society", "egalitarian principles", "foster an egalitarian environment"],
        "word_family": {"noun": "egalitarianism", "adjective": "egalitarian"},
        "synonyms": ["equitable", "classless", "just", "unbiased"],
        "example_basic": "Universal free education helps create a fair society for all people.",
        "example_advanced": "Universal access to quality healthcare and education is the cornerstone of an egalitarian society.",
        "example_translation": "Quyền tiếp cận phổ cập đối với y tế và giáo dục chất lượng cao là nền tảng của một xã hội bình đẳng.",
        "nuance_note": "Thay vì viết 'a society where everyone is equal', chỉ cần dùng 'an egalitarian society'.",
    },
    {
        "level": 5,
        "cefr_level": "C2",
        "band_target": "9.0",
        "topic": "Sustainable Development",
        "word": "symbiotic",
        "basic_word": "helping each other",
        "intermediate_word": "mutually beneficial",
        "advanced_word": "symbiotic / synergistic",
        "ipa": "/ˌsɪm.baɪˈɒt.ɪk/",
        "part_of_speech": "adjective",
        "vietnamese_meaning": "Cộng sinh, gắn kết hỗ trợ lẫn nhau cùng phát triển",
        "collocations": ["symbiotic relationship", "symbiotic coexistence", "foster a symbiotic link"],
        "word_family": {"noun": "symbiosis", "adjective": "symbiotic", "adverb": "symbiotically"},
        "synonyms": ["synergistic", "interdependent", "mutually advantageous"],
        "example_basic": "Economic growth and nature protection can help each other.",
        "example_advanced": "Modern eco-tourism demonstrates that economic prosperity and ecological conservation can maintain a symbiotic relationship.",
        "example_translation": "Du lịch sinh thái hiện đại chứng minh rằng sự thịnh vượng kinh tế và bảo tồn sinh thái có thể duy trì mối quan hệ cộng sinh.",
        "nuance_note": "Cụm 'a symbiotic relationship between A and B' nâng tầm câu kết bài IELTS Writing lên mức Band 8.5 - 9.0.",
    },
]


# ─────────────────────────────────────────────────────────────────────────────
# 3. TIỆN ÍCH KẾT NỐI OLLAMA & NHẬN DIỆN MODEL QWEN 2.5 LOCAL
# ─────────────────────────────────────────────────────────────────────────────


def _clean_json_text(raw_text: str) -> str:
    """Làm sạch markdown code fences và trích xuất khối JSON hợp lệ."""
    text = raw_text.strip()
    text = re.sub(r"^```(?:json)?\s*", "", text, flags=re.IGNORECASE)
    text = re.sub(r"\s*```$", "", text)
    text = text.strip()

    start_brace = text.find("{")
    end_brace = text.rfind("}")
    if start_brace != -1 and end_brace != -1 and end_brace > start_brace:
        return text[start_brace : end_brace + 1]
    return text


# ─────────────────────────────────────────────────────────────────────────────
# 3. QUẢN TRỊ CẤU HÌNH ĐỘNG HỌC TỪ VỰNG & MÔ HÌNH AI (OLLAMA QWEN)
# ─────────────────────────────────────────────────────────────────────────────

def get_or_create_system_vocab_config(db: Session) -> SystemVocabConfig:
    """Lấy hoặc tự động tạo cấu hình hệ thống mặc định cho học từ vựng và AI Qwen."""
    cfg = db.query(SystemVocabConfig).filter(SystemVocabConfig.id == 1).first()
    if not cfg:
        cfg = SystemVocabConfig(
            id=1,
            active_model="qwen2.5:7b",
            temperature=3,
            default_gen_count=5,
            quiz_question_count=5,
            pass_percentage=60,
            star_thresholds={"star1": 60, "star2": 80, "star3": 100},
            auto_cache_enabled=1,
        )
        db.add(cfg)
        try:
            db.commit()
            db.refresh(cfg)
        except Exception:
            db.rollback()
            cfg = db.query(SystemVocabConfig).filter(SystemVocabConfig.id == 1).first() or cfg
    return cfg


def update_system_vocab_config(db: Session, update_data: SystemVocabConfigUpdate) -> SystemVocabConfig:
    """Cập nhật cấu hình quản trị học từ vựng & AI Qwen từ Web Admin Portal."""
    cfg = get_or_create_system_vocab_config(db)
    if update_data.active_model is not None and update_data.active_model.strip():
        cfg.active_model = update_data.active_model.strip()
    if update_data.temperature is not None:
        cfg.temperature = int(round(update_data.temperature * 10))
    if update_data.default_gen_count is not None:
        cfg.default_gen_count = max(1, min(15, update_data.default_gen_count))
    if update_data.quiz_question_count is not None:
        cfg.quiz_question_count = max(3, min(20, update_data.quiz_question_count))
    if update_data.pass_percentage is not None:
        cfg.pass_percentage = max(50, min(100, update_data.pass_percentage))
    if update_data.star_thresholds is not None:
        cfg.star_thresholds = update_data.star_thresholds
    if update_data.auto_cache_enabled is not None:
        cfg.auto_cache_enabled = 1 if update_data.auto_cache_enabled else 0
    cfg.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(cfg)
    return cfg


async def test_ollama_model_benchmark(
    model_name: str,
    test_prompt: Optional[str] = None,
) -> Tuple[bool, int, str, Optional[str]]:
    """Kiểm tra độ trễ và khả năng sinh JSON của model Ollama được chọn (timeout 30s)."""
    start_time = time.time()
    prompt = (
        test_prompt
        or 'Generate a JSON object with 1 IELTS vocabulary word containing exact keys: "word", "meaning", "example". Example: {"word": "resilient", "meaning": "kiên cường, có khả năng phục hồi", "example": "She remained resilient in the face of difficulties."}. Output JSON only, no markdown, no other text.'
    )
    payload = {
        "model": model_name,
        "prompt": prompt,
        "format": "json",
        "stream": False,
        "options": {
            "temperature": 0.2,
            "num_predict": 256,
        },
    }
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(f"{OLLAMA_BASE_URL}/api/generate", json=payload)
            resp.raise_for_status()
            latency_ms = int((time.time() - start_time) * 1000)
            data = resp.json()
            raw_text = data.get("response", "").strip()

            # Xác thực JSON trả về có parse được không
            try:
                parsed_json = json.loads(raw_text)
                formatted_json = json.dumps(parsed_json, indent=2, ensure_ascii=False)
                return True, latency_ms, f"Model '{model_name}' phản hồi thành công và trả về JSON chuẩn ({latency_ms}ms).", formatted_json
            except json.JSONDecodeError as jde:
                return False, latency_ms, f"Model '{model_name}' phản hồi ({latency_ms}ms) nhưng JSON không hợp lệ: {jde}", raw_text
    except httpx.TimeoutException:
        latency_ms = int((time.time() - start_time) * 1000)
        return False, latency_ms, f"Timeout quá 30 giây khi gửi prompt tới model '{model_name}'.", None
    except Exception as e:
        latency_ms = int((time.time() - start_time) * 1000)
        return False, latency_ms, f"Không thể kết nối hoặc model '{model_name}' gặp lỗi: {str(e)}", None


async def resolve_qwen_model(db: Optional[Session] = None) -> Tuple[bool, str, List[str]]:
    """
    Kiểm tra Ollama server tại OLLAMA_BASE_URL và tự động chọn đúng tag model Qwen 2.5 đã cài trên máy.
    Ưu tiên:
      1. Model cấu hình trong Bảng SystemVocabConfig (do Admin chọn trên Web Portal).
      2. Model cấu hình trong OLLAMA_VOCAB_MODEL (mặc định: qwen2.5:latest).
      3. Bất kỳ model nào có chữ 'qwen2.5' (vd: qwen2.5:7b, qwen2.5:3b, qwen2.5:1.5b, qwen2.5:14b).
      4. Bất kỳ model nào có chữ 'qwen'.
      5. Model đầu tiên có sẵn trên Ollama nếu có.
    """
    target_model = DEFAULT_QWEN_MODEL
    if db is not None:
        try:
            cfg = get_or_create_system_vocab_config(db)
            if cfg and cfg.active_model:
                target_model = cfg.active_model.strip()
        except Exception as e:
            logger.debug(f"Không thể nạp SystemVocabConfig từ DB: {e}")

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(f"{OLLAMA_BASE_URL}/api/tags")
            resp.raise_for_status()
            data = resp.json()
            models_raw = data.get("models", [])
            available = [m.get("name", "") for m in models_raw if m.get("name")]

            if not available:
                return True, target_model, []

            # 1. Khớp chính xác với model chỉ định bởi Admin / Config
            if target_model in available:
                return True, target_model, available

            # 2. Tìm model khớp tương đối với target_model
            for m in available:
                if target_model.lower() in m.lower():
                    return True, m, available

            # 3. Tìm model bắt đầu bằng qwen2.5 hoặc chứa qwen2.5
            for m in available:
                if "qwen2.5" in m.lower():
                    return True, m, available

            # 4. Tìm model chứa qwen
            for m in available:
                if "qwen" in m.lower():
                    return True, m, available

            # 5. Fallback sang model text khả dụng đầu tiên
            return True, available[0], available
    except Exception as e:
        logger.warning(f"Không thể kết nối Ollama tại {OLLAMA_BASE_URL}: {e}")
        return False, target_model, []


async def check_ollama_qwen_status(db: Optional[Session] = None) -> OllamaStatusResponse:
    """Kiểm tra trạng thái hoạt động của Ollama Qwen 2.5 local."""
    online, resolved_model, available = await resolve_qwen_model(db=db)
    if online:
        msg = f"Đã kết nối Ollama thành công. Đang sử dụng model: {resolved_model}"
    else:
        msg = (
            f"Chưa kết nối được Ollama tại {OLLAMA_BASE_URL}. "
            "Hệ thống đang sử dụng Kho dữ liệu chuẩn & Chế độ Fallback thông minh."
        )
    return OllamaStatusResponse(
        online=online,
        base_url=OLLAMA_BASE_URL,
        configured_model=DEFAULT_QWEN_MODEL,
        resolved_model=resolved_model,
        available_models=available,
        message=msg,
    )


# ─────────────────────────────────────────────────────────────────────────────
# 4. KHỞI TẠO HẠT GIỐNG DỮ LIỆU 5 CẤP ĐỘ (AUTO-SEED)
# ─────────────────────────────────────────────────────────────────────────────


def seed_default_vocab_learning(db: Session) -> int:
    """
    Khởi tạo 30 thẻ từ vựng chuẩn (Level 1 -> Level 5) vào bảng vocab_learning_cards
    nếu bảng đang trống hoặc thiếu dữ liệu gốc.
    """
    existing_count = db.query(func.count(VocabLearningCard.id)).scalar() or 0
    if existing_count >= len(DEFAULT_VOCAB_CARDS):
        return 0

    added = 0
    for item in DEFAULT_VOCAB_CARDS:
        exists = (
            db.query(VocabLearningCard)
            .filter(
                func.lower(VocabLearningCard.word) == item["word"].lower(),
                VocabLearningCard.level == item["level"],
            )
            .first()
        )
        if not exists:
            card = VocabLearningCard(
                level=item["level"],
                cefr_level=item["cefr_level"],
                band_target=item["band_target"],
                topic=item["topic"],
                word=item["word"],
                basic_word=item["basic_word"],
                intermediate_word=item["intermediate_word"],
                advanced_word=item["advanced_word"],
                ipa=item.get("ipa", ""),
                part_of_speech=item.get("part_of_speech", "noun"),
                vietnamese_meaning=item["vietnamese_meaning"],
                collocations=item.get("collocations", []),
                word_family=item.get("word_family", {}),
                synonyms=item.get("synonyms", []),
                example_basic=item.get("example_basic", ""),
                example_advanced=item.get("example_advanced", ""),
                example_translation=item.get("example_translation", ""),
                nuance_note=item.get("nuance_note", ""),
                source="seed",
            )
            db.add(card)
            added += 1

    if added > 0:
        db.commit()
        logger.info(f"Đã khởi tạo {added} thẻ từ vựng phân cấp (Level 1 -> 5) vào cơ sở dữ liệu.")
    return added


# ─────────────────────────────────────────────────────────────────────────────
# 5. TRUY VẤN LỘ TRÌNH 5 CẤP ĐỘ & DANH SÁCH THẺ TỪ VỰNG
# ─────────────────────────────────────────────────────────────────────────────


def _attach_user_mastery(
    cards: List[VocabLearningCard],
    user_id: Optional[int],
    db: Session,
) -> List[VocabCardWithMasteryResponse]:
    """Đính kèm thông tin tiến độ thuộc từ (SRS mastery) của học viên vào danh sách thẻ."""
    mastery_map: Dict[int, UserVocabMastery] = {}
    if user_id and cards:
        card_ids = [c.id for c in cards]
        records = (
            db.query(UserVocabMastery)
            .filter(
                UserVocabMastery.user_id == user_id,
                UserVocabMastery.card_id.in_(card_ids),
            )
            .all()
        )
        for r in records:
            mastery_map[r.card_id] = r

    results: List[VocabCardWithMasteryResponse] = []
    for c in cards:
        m = mastery_map.get(c.id)
        results.append(
            VocabCardWithMasteryResponse(
                id=c.id,
                level=c.level,
                cefr_level=c.cefr_level,
                band_target=c.band_target,
                topic=c.topic,
                word=c.word,
                basic_word=c.basic_word,
                intermediate_word=c.intermediate_word,
                advanced_word=c.advanced_word,
                ipa=c.ipa or "",
                part_of_speech=c.part_of_speech or "noun",
                vietnamese_meaning=c.vietnamese_meaning,
                collocations=c.collocations if isinstance(c.collocations, list) else [],
                word_family=c.word_family if isinstance(c.word_family, dict) else {},
                synonyms=c.synonyms if isinstance(c.synonyms, list) else [],
                example_basic=c.example_basic or "",
                example_advanced=c.example_advanced or "",
                example_translation=c.example_translation or "",
                nuance_note=c.nuance_note or "",
                source=c.source or "seed",
                created_at=c.created_at,
                mastery_level=m.mastery_level if m else 0,
                review_count=m.review_count if m else 0,
                correct_streak=m.correct_streak if m else 0,
            )
        )
    return results


def get_vocab_roadmap(db: Session, user_id: int) -> VocabRoadmapResponse:
    """Lấy toàn bộ lộ trình 5 Cấp độ từ Cơ bản đến Nâng cao kèm tiến độ Sao & SRS của học viên."""
    seed_default_vocab_learning(db)

    all_cards = db.query(VocabLearningCard).all()
    mastery_records = (
        db.query(UserVocabMastery)
        .filter(UserVocabMastery.user_id == user_id)
        .all()
    )
    mastery_by_card: Dict[int, int] = {m.card_id: m.mastery_level for m in mastery_records}

    stage_records = (
        db.query(UserStageProgress)
        .filter(
            UserStageProgress.user_id == user_id,
            UserStageProgress.skill_type == "vocabulary",
        )
        .all()
    )
    stage_map: Dict[int, UserStageProgress] = {s.stage_number: s for s in stage_records}

    highest_unlocked = 1
    for lvl in range(1, 6):
        st = stage_map.get(lvl)
        if st and st.is_unlocked and lvl > highest_unlocked:
            highest_unlocked = lvl
        if st and st.stars > 0 and lvl < 5 and (lvl + 1) > highest_unlocked:
            highest_unlocked = lvl + 1

    levels_info: List[VocabLevelInfoResponse] = []
    total_mastered = 0
    total_learning = 0

    for lvl in range(1, 6):
        meta = LEVEL_METADATA[lvl]
        lvl_cards = [c for c in all_cards if c.level == lvl]
        mastered_cnt = sum(1 for c in lvl_cards if mastery_by_card.get(c.id, 0) >= 3)
        learning_cnt = sum(1 for c in lvl_cards if 1 <= mastery_by_card.get(c.id, 0) <= 2)
        total_mastered += mastered_cnt
        total_learning += learning_cnt

        topics = sorted(list({c.topic for c in lvl_cards if c.topic}))
        st = stage_map.get(lvl)

        levels_info.append(
            VocabLevelInfoResponse(
                level=lvl,
                title=meta["title"],
                subtitle=meta["subtitle"],
                cefr_level=meta["cefr_level"],
                band_target=meta["band_target"],
                total_cards=len(lvl_cards),
                mastered_cards=mastered_cnt,
                learning_cards=learning_cnt,
                stars=st.stars if st else 0,
                best_score=st.best_score if st else 0,
                is_unlocked=(lvl <= highest_unlocked),
                topics=topics,
            )
        )

    return VocabRoadmapResponse(
        highest_unlocked_level=highest_unlocked,
        total_cards_in_system=len(all_cards),
        total_mastered_by_user=total_mastered,
        total_learning_by_user=total_learning,
        ollama_model=DEFAULT_QWEN_MODEL,
        levels=levels_info,
    )


def get_level_cards_for_user(
    db: Session,
    user_id: Optional[int],
    level: Optional[int] = None,
    topic: Optional[str] = None,
    search: Optional[str] = None,
) -> List[VocabCardWithMasteryResponse]:
    """Lấy danh sách thẻ từ vựng theo cấp độ, chủ đề hoặc từ khóa tìm kiếm."""
    seed_default_vocab_learning(db)

    query = db.query(VocabLearningCard)
    if level is not None:
        query = query.filter(VocabLearningCard.level == level)
    if topic and topic.strip() and topic.strip().lower() != "tất cả":
        query = query.filter(VocabLearningCard.topic.ilike(f"%{topic.strip()}%"))
    if search and search.strip():
        kw = f"%{search.strip()}%"
        query = query.filter(
            (VocabLearningCard.word.ilike(kw))
            | (VocabLearningCard.basic_word.ilike(kw))
            | (VocabLearningCard.intermediate_word.ilike(kw))
            | (VocabLearningCard.advanced_word.ilike(kw))
            | (VocabLearningCard.vietnamese_meaning.ilike(kw))
        )

    cards = query.order_by(VocabLearningCard.level.asc(), VocabLearningCard.id.desc()).all()
    return _attach_user_mastery(cards, user_id, db)


# ─────────────────────────────────────────────────────────────────────────────
# 6. SINH TỪ VỰNG PHÂN CẤP BẰNG OLLAMA QWEN 2.5 LOCAL (CÓ CACHE 2 TẦNG)
# ─────────────────────────────────────────────────────────────────────────────


async def generate_vocab_with_qwen(
    topic: str,
    level: int,
    count: int,
    user_id: Optional[int],
    db: Session,
) -> OllamaGenerateVocabResponse:
    """
    Gọi mô hình Ollama Qwen 2.5 local để sinh từ vựng theo Chủ đề (topic) và Cấp độ (level 1..5).
    Tự động áp dụng Model & Cấu hình số lượng từ Bảng SystemVocabConfig.
    Tự động lưu các thẻ mới vào bảng vocab_learning_cards (Cache 2 tầng nếu auto_cache_enabled).
    """
    cfg = get_or_create_system_vocab_config(db)
    actual_count = count if count and count > 0 else cfg.default_gen_count
    meta = LEVEL_METADATA.get(level, LEVEL_METADATA[2])
    cefr = meta["cefr_level"]
    band = meta["band_target"]
    clean_topic = topic.strip()

    online, model_to_use, _ = await resolve_qwen_model(db=db)
    if not online:
        # Nếu Ollama đang tắt, kiểm tra trong DB xem có thẻ thuộc chủ đề/cấp độ này chưa
        cached_cards = get_level_cards_for_user(db, user_id=user_id, level=level, topic=clean_topic)
        if not cached_cards:
            cached_cards = get_level_cards_for_user(db, user_id=user_id, level=level)
        return OllamaGenerateVocabResponse(
            source="cache",
            model_used=f"{model_to_use} (offline-cache)",
            topic=clean_topic,
            level=level,
            cards=cached_cards[:actual_count],
        )

    # Lấy các từ đã có trong level này để yêu cầu Qwen 2.5 không sinh trùng
    existing_words = [
        r[0]
        for r in db.query(VocabLearningCard.word)
        .filter(VocabLearningCard.level == level)
        .limit(40)
        .all()
    ]
    avoid_str = ", ".join(existing_words[:25]) if existing_words else "none"

    prompt = f"""You are an expert IELTS lexicographer and English teacher for Vietnamese learners.
Generate {actual_count} distinct English vocabulary items for the topic "{clean_topic}" tailored to:
- Level {level}/5 ({meta['title']})
- CEFR Level: {cefr}
- IELTS Target Band: {band}
- Do NOT repeat these existing words: [{avoid_str}]

For EACH vocabulary item, provide a "Word Upgrade Ladder" showing how a learner upgrades from a Basic word (A2-B1) -> Intermediate word (B1-B2) -> Advanced Academic word (C1-C2), while setting "word" to match Level {level} ({cefr}).

You MUST return ONLY a valid JSON object matching this exact schema:
{{
  "cards": [
    {{
      "word": "primary vocabulary word for Level {level}",
      "basic_word": "simple A2-B1 equivalent",
      "intermediate_word": "B1-B2 Band 6.0-6.5 equivalent",
      "advanced_word": "C1-C2 Band 7.5-8.5+ academic equivalent",
      "ipa": "/accurate IPA/",
      "part_of_speech": "noun | verb | adjective | adverb",
      "vietnamese_meaning": "Nghĩa tiếng Việt tự nhiên, chính xác",
      "collocations": ["collocation 1", "collocation 2", "collocation 3"],
      "word_family": {{"noun": "...", "verb": "...", "adjective": "...", "adverb": "..."}},
      "synonyms": ["synonym 1", "synonym 2", "synonym 3"],
      "example_basic": "A simple, clear English sentence at basic level.",
      "example_advanced": "A natural, high-scoring IELTS sentence using the word in the context of {clean_topic}.",
      "example_translation": "Bản dịch tiếng Việt tự nhiên của câu example_advanced.",
      "nuance_note": "Giải thích ngắn gọn bằng tiếng Việt về cách dùng và sắc thái nâng cấp từ cơ bản lên nâng cao."
    }}
  ]
}}
Output purely the JSON object without markdown code blocks."""

    model_temp = (cfg.temperature / 10.0) if cfg and cfg.temperature is not None else 0.3
    payload = {
        "model": model_to_use,
        "prompt": prompt,
        "format": "json",
        "stream": False,
        "options": {
            "temperature": model_temp,
            "num_predict": 2048,
        },
    }

    created_or_fetched: List[VocabLearningCard] = []

    try:
        async with httpx.AsyncClient(timeout=90.0) as client:
            logger.info(f"Đang gọi Ollama Qwen ({model_to_use}) sinh {actual_count} từ vựng chủ đề '{clean_topic}' (Level {level}, temp={model_temp})...")
            resp = await client.post(f"{OLLAMA_BASE_URL}/api/generate", json=payload)
            resp.raise_for_status()
            raw_text = resp.json().get("response", "")
            cleaned = _clean_json_text(raw_text)
            parsed = json.loads(cleaned)

            items = parsed.get("cards") if isinstance(parsed, dict) else (parsed if isinstance(parsed, list) else [])
            if not isinstance(items, list):
                items = []

            for item in items:
                if not isinstance(item, dict):
                    continue
                word_val = str(item.get("word") or "").strip()
                if not word_val:
                    continue

                # Kiểm tra Cache DB xem từ này đã có ở level hiện tại chưa
                existing = (
                    db.query(VocabLearningCard)
                    .filter(
                        func.lower(VocabLearningCard.word) == word_val.lower(),
                        VocabLearningCard.level == level,
                    )
                    .first()
                )
                if existing:
                    created_or_fetched.append(existing)
                    continue

                collocations = item.get("collocations")
                if not isinstance(collocations, list):
                    collocations = [str(collocations)] if collocations else []

                word_family = item.get("word_family")
                if not isinstance(word_family, dict):
                    word_family = {}

                synonyms = item.get("synonyms")
                if not isinstance(synonyms, list):
                    synonyms = [str(synonyms)] if synonyms else []

                new_card = VocabLearningCard(
                    level=level,
                    cefr_level=cefr,
                    band_target=band.split("-")[0].strip().replace("+", ""),
                    topic=clean_topic,
                    word=word_val,
                    basic_word=str(item.get("basic_word") or word_val).strip(),
                    intermediate_word=str(item.get("intermediate_word") or word_val).strip(),
                    advanced_word=str(item.get("advanced_word") or word_val).strip(),
                    ipa=str(item.get("ipa") or "").strip(),
                    part_of_speech=str(item.get("part_of_speech") or "noun").strip(),
                    vietnamese_meaning=str(item.get("vietnamese_meaning") or word_val).strip(),
                    collocations=[str(c) for c in collocations[:5]],
                    word_family={str(k): str(v) for k, v in word_family.items() if v},
                    synonyms=[str(s) for s in synonyms[:5]],
                    example_basic=str(item.get("example_basic") or "").strip(),
                    example_advanced=str(item.get("example_advanced") or "").strip(),
                    example_translation=str(item.get("example_translation") or "").strip(),
                    nuance_note=str(item.get("nuance_note") or "").strip(),
                    source="qwen2.5",
                )
                db.add(new_card)
                db.commit()
                db.refresh(new_card)
                created_or_fetched.append(new_card)

    except Exception as e:
        db.rollback()
        logger.warning(f"Lỗi khi gọi Ollama Qwen 2.5 sinh từ vựng: {e}")
        # Fallback sang thẻ trong DB nếu có lỗi
        fallback_cards = get_level_cards_for_user(db, user_id=user_id, level=level, topic=clean_topic)
        if not fallback_cards:
            fallback_cards = get_level_cards_for_user(db, user_id=user_id, level=level)
        return OllamaGenerateVocabResponse(
            source="cache",
            model_used=model_to_use,
            topic=clean_topic,
            level=level,
            cards=fallback_cards[:count],
        )

    if not created_or_fetched:
        fallback_cards = get_level_cards_for_user(db, user_id=user_id, level=level)
        return OllamaGenerateVocabResponse(
            source="cache",
            model_used=model_to_use,
            topic=clean_topic,
            level=level,
            cards=fallback_cards[:count],
        )

    return OllamaGenerateVocabResponse(
        source="qwen2.5",
        model_used=model_to_use,
        topic=clean_topic,
        level=level,
        cards=_attach_user_mastery(created_or_fetched, user_id, db),
    )


# ─────────────────────────────────────────────────────────────────────────────
# 7. CHẤM ĐIỂM ĐẶT CÂU & NÂNG CẤP CÂU BẰNG OLLAMA QWEN 2.5 (AI SENTENCE LAB)
# ─────────────────────────────────────────────────────────────────────────────


async def evaluate_sentence_with_qwen(
    word: str,
    level: int,
    user_sentence: str,
    db: Session,
) -> OllamaSentenceEvaluateResponse:
    """
    Chấm điểm câu do học viên đặt với từ vựng `word` bằng mô hình Ollama Qwen 2.5 local.
    Trả về nhận xét tiếng Việt, câu sửa lỗi ngữ pháp và 3 phiên bản nâng cấp câu (Cơ bản -> Trung cấp -> Nâng cao).
    """
    clean_word = word.strip()
    clean_sentence = user_sentence.strip()
    online, model_to_use, _ = await resolve_qwen_model()

    if online:
        prompt = f"""You are a strict, professional IELTS Examiner and Academic English Professor.
A Vietnamese learner is practicing the target vocabulary word "{clean_word}" (Level {level}/5) and submitted this sentence:
"{clean_sentence}"

### STRICT EVALUATION RUBRIC (Score 0 - 100 & IELTS Band):
1. **0 - 35 points (Band 2.5 - 3.5) - SEVERELY BROKEN / INCORRECT**:
   - Incoherent sentence, severe grammar breakdown, word salad, wrong part of speech, or the target word is used nonsensically (e.g. "i am data share people", "she data go home").
   - MUST set `is_correct_usage: false` and `score <= 35`, `estimated_band: "3.0"` or `"3.5"`. NEVER give a passing score (>50) to broken English!
2. **36 - 54 points (Band 4.0 - 4.5) - WEAK / PROBLEMATIC**:
   - Has basic subject-verb but major grammatical errors, wrong prepositions, incorrect word form, or awkward phrasing.
3. **55 - 69 points (Band 5.0 - 5.5) - BASIC / SIMPLE ACCURACY**:
   - Grammatically correct simple sentence, conveys clear meaning, but lacks complexity or natural academic collocations.
4. **70 - 82 points (Band 6.0 - 6.5) - GOOD / COMPETENT**:
   - Well-structured complex/compound sentence, natural usage of the target word with appropriate context.
5. **83 - 92 points (Band 7.0 - 7.5) - ADVANCED / ACADEMIC**:
   - Sophisticated sentence structure (relative clauses, participle clauses, passive voice), excellent collocations.
6. **93 - 100 points (Band 8.0 - 9.0) - NATIVE / MASTER**:
   - Impeccable academic IELTS style, nuanced vocabulary, native-level flow.

### CRITICAL RULES:
- Be realistic and strictly objective. DO NOT be overly polite or inflate scores for broken sentences.
- If the sentence lacks basic grammar or uses the target word in a nonsensical way, `is_correct_usage` MUST be `false` and score MUST be below 40.
- All rewritten sentences (`corrected_sentence`, `upgraded_basic`, `upgraded_intermediate`, `upgraded_advanced`) and `key_collocations_used` MUST BE IN ENGLISH.
- ONLY `feedback_vi` is written in Vietnamese (constructive, honest explanation of grammar/meaning errors).

Return ONLY a valid JSON object matching this schema:
{{
  "is_correct_usage": true,
  "score": 75,
  "estimated_band": "6.5",
  "corrected_sentence": "<Grammatically correct English sentence using target word '{clean_word}'>",
  "feedback_vi": "<Detailed constructive Vietnamese feedback explaining errors and how to fix them>",
  "upgraded_basic": "<Simple Band 5.0-5.5 correct English sentence>",
  "upgraded_intermediate": "<Natural Band 6.5 compound/complex English sentence>",
  "upgraded_advanced": "<Academic Band 8.0+ IELTS English sentence with strong collocations>",
  "key_collocations_used": ["<English collocation 1>", "<English collocation 2>"]
}}
Output purely the JSON object without markdown formatting."""

        payload = {
            "model": model_to_use,
            "prompt": prompt,
            "format": "json",
            "stream": False,
            "options": {
                "temperature": 0.2,
                "num_predict": 1024,
            },
        }

        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                resp = await client.post(f"{OLLAMA_BASE_URL}/api/generate", json=payload)
                resp.raise_for_status()
                raw_text = resp.json().get("response", "")
                cleaned = _clean_json_text(raw_text)
                data = json.loads(cleaned)

                colls = data.get("key_collocations_used")
                if not isinstance(colls, list):
                    colls = [str(colls)] if colls else []

                is_correct = bool(data.get("is_correct_usage", True))
                score_val = int(data.get("score", 70))
                band_val = str(data.get("estimated_band") or "6.0")

                # Guardrail: nếu câu sai cấu trúc / sai từ (is_correct_usage = False), điểm không vượt quá 40
                if not is_correct:
                    score_val = min(score_val, 40)
                    try:
                        band_num = float(band_val.replace("Band", "").strip())
                        if band_num > 4.0:
                            band_val = "3.5"
                    except Exception:
                        band_val = "3.5"

                score_val = max(0, min(100, score_val))

                return OllamaSentenceEvaluateResponse(
                    word=clean_word,
                    user_sentence=clean_sentence,
                    is_correct_usage=is_correct,
                    score=score_val,
                    estimated_band=band_val,
                    corrected_sentence=str(data.get("corrected_sentence") or clean_sentence),
                    feedback_vi=str(
                        data.get("feedback_vi")
                        or f"Bạn đã vận dụng từ '{clean_word}' vào câu. Hãy chú ý kết hợp thêm các cụm collocations học thuật để nâng cao Band điểm!"
                    ),
                    upgraded_basic=str(data.get("upgraded_basic") or clean_sentence),
                    upgraded_intermediate=str(data.get("upgraded_intermediate") or clean_sentence),
                    upgraded_advanced=str(data.get("upgraded_advanced") or clean_sentence),
                    key_collocations_used=[str(c) for c in colls[:4]],
                    model_used=model_to_use,
                )
        except Exception as e:
            logger.warning(f"Lỗi khi chấm câu bằng Ollama Qwen 2.5: {e}. Chuyển sang đánh giá nội bộ.")

    # Fallback đánh giá thông minh khi Ollama tắt hoặc timeout
    card = (
        db.query(VocabLearningCard)
        .filter(func.lower(VocabLearningCard.word) == clean_word.lower())
        .first()
    )
    has_word = clean_word.lower() in clean_sentence.lower()
    word_count = len(clean_sentence.split())

    if not has_word or word_count < 4:
        score = 30
        band = "3.5"
        is_correct = False
    elif word_count >= 7:
        score = 75
        band = "6.5"
        is_correct = True
    else:
        score = 55
        band = "5.0"
        is_correct = True

    ex_basic = card.example_basic if (card and card.example_basic) else clean_sentence
    ex_adv = card.example_advanced if (card and card.example_advanced) else clean_sentence
    colls = (card.collocations if (card and isinstance(card.collocations, list)) else [])[:3]

    feedback = (
        f"Bạn đã sử dụng từ '{clean_word}' đúng ngữ cảnh với độ dài câu tốt ({word_count} từ). "
        "Hãy tham khảo phiên bản nâng cấp Band 8.0+ bên dưới để mở rộng cấu trúc câu học thuật!"
        if has_word
        else f"Câu của bạn chưa xuất hiện từ khóa mục tiêu '{clean_word}'. Hãy thử đưa từ '{clean_word}' trực tiếp vào câu nhé!"
    )

    return OllamaSentenceEvaluateResponse(
        word=clean_word,
        user_sentence=clean_sentence,
        is_correct_usage=is_correct,
        score=score,
        estimated_band=band,
        corrected_sentence=clean_sentence,
        feedback_vi=feedback,
        upgraded_basic=ex_basic,
        upgraded_intermediate=clean_sentence if has_word else ex_basic,
        upgraded_advanced=ex_adv,
        key_collocations_used=colls,
        model_used=f"{model_to_use} (fallback)",
    )


# ─────────────────────────────────────────────────────────────────────────────
# 8. TẠO BÀI TẬP KIỂM TRA VƯỢT CẤP (QUIZ GENERATOR VỚI QWEN 2.5 & FALLBACK)
# ─────────────────────────────────────────────────────────────────────────────


def _build_local_quiz_from_cards(
    cards: List[VocabLearningCard],
    level: int,
    topic: str,
    question_count: int,
    pass_percentage: int = 60,
) -> VocabQuizResponse:
    """Tạo bộ câu hỏi kiểm tra đa dạng từ danh sách thẻ từ vựng trong Database."""
    pool = list(cards)
    random.shuffle(pool)
    selected = pool[:question_count]
    all_words = [c.word for c in cards]
    all_meanings = [c.vietnamese_meaning for c in cards]

    questions: List[VocabQuizQuestionSchema] = []
    for idx, card in enumerate(selected, start=1):
        q_mode = idx % 3
        if q_mode == 1:
            # Dạng 1: Nâng cấp từ (Word Upgrade Ladder)
            distractors = [w for w in all_words if w.lower() != card.word.lower()]
            random.shuffle(distractors)
            opts = [card.word] + distractors[:3]
            while len(opts) < 4:
                opts.append(f"option_{len(opts)}")
            random.shuffle(opts)
            questions.append(
                VocabQuizQuestionSchema(
                    id=idx,
                    question_type="word_upgrade",
                    prompt=(
                        f"[Nâng cấp từ vựng] Từ vựng nào ở Cấp độ {level} ({card.cefr_level}) "
                        f"nâng cấp trực tiếp cho từ cơ bản '{card.basic_word}' "
                        f"(nghĩa: {card.vietnamese_meaning})?"
                    ),
                    target_word=card.word,
                    options=opts,
                    correct_answer=card.word,
                    explanation_vi=(
                        f"Thang nâng cấp chuẩn: '{card.basic_word}' (Cơ bản) -> "
                        f"'{card.intermediate_word}' (Trung cấp) -> '{card.advanced_word}' (Nâng cao)."
                    ),
                )
            )
        elif q_mode == 2 and card.example_advanced:
            # Dạng 2: Điền từ vào ngữ cảnh học thuật (Cloze / Fill-in-the-blank)
            pattern = re.compile(re.escape(card.word), re.IGNORECASE)
            blanked = pattern.sub("________", card.example_advanced, count=1)
            if "________" not in blanked:
                blanked = f"{card.example_advanced} (Từ khóa: ________)"
            distractors = [w for w in all_words if w.lower() != card.word.lower()]
            random.shuffle(distractors)
            opts = [card.word] + distractors[:3]
            random.shuffle(opts)
            questions.append(
                VocabQuizQuestionSchema(
                    id=idx,
                    question_type="fill_blank",
                    prompt=f"[Điền từ ngữ cảnh] Chọn từ phù hợp nhất để điền vào chỗ trống:\n\"{blanked}\"",
                    target_word=card.word,
                    options=opts,
                    correct_answer=card.word,
                    explanation_vi=f"'{card.word}' ({card.ipa}) có nghĩa là '{card.vietnamese_meaning}'. Dịch câu: {card.example_translation}",
                )
            )
        else:
            # Dạng 3: Trắc nghiệm nghĩa & sắc thái trong ngữ cảnh
            distractors = [m for m in all_meanings if m != card.vietnamese_meaning]
            random.shuffle(distractors)
            opts = [card.vietnamese_meaning] + distractors[:3]
            random.shuffle(opts)
            questions.append(
                VocabQuizQuestionSchema(
                    id=idx,
                    question_type="contextual_mcq",
                    prompt=(
                        f"[Ngữ cảnh IELTS] Từ '{card.word}' ({card.part_of_speech}, {card.ipa}) "
                        f"trong cụm '{(card.collocations[0] if card.collocations else card.word)}' mang nghĩa nào sau đây?"
                    ),
                    target_word=card.word,
                    options=opts,
                    correct_answer=card.vietnamese_meaning,
                    explanation_vi=card.nuance_note or f"'{card.word}' đồng nghĩa với {card.intermediate_word} / {card.advanced_word}.",
                )
            )

    pass_score_required = max(1, math.ceil(len(questions) * (pass_percentage / 100.0)))
    return VocabQuizResponse(
        level=level,
        topic=topic or "Tổng hợp",
        source="database",
        pass_score_required=pass_score_required,
        questions=questions,
    )


async def generate_quiz_with_qwen(
    level: int,
    topic: Optional[str],
    question_count: int,
    use_ai_qwen: bool,
    db: Session,
) -> VocabQuizResponse:
    """
    Sinh bài kiểm tra vượt cấp cho `level` bằng Ollama Qwen 2.5 hoặc từ kho thẻ từ trong DB.
    Tự động áp dụng Model và Cấu hình số lượng câu hỏi & tỷ lệ vượt ải từ Bảng SystemVocabConfig.
    """
    cfg = get_or_create_system_vocab_config(db)
    actual_q_count = question_count if question_count and question_count > 0 else cfg.quiz_question_count
    pass_percentage = cfg.pass_percentage

    seed_default_vocab_learning(db)
    query = db.query(VocabLearningCard).filter(VocabLearningCard.level == level)
    if topic and topic.strip() and topic.strip().lower() != "tất cả":
        query = query.filter(VocabLearningCard.topic.ilike(f"%{topic.strip()}%"))
    cards = query.all()
    if len(cards) < 4:
        cards = db.query(VocabLearningCard).filter(VocabLearningCard.level == level).all()

    if not use_ai_qwen:
        return _build_local_quiz_from_cards(cards, level, topic or "Tổng hợp", actual_q_count, pass_percentage)

    online, model_to_use, _ = await resolve_qwen_model(db=db)
    if not online or not cards:
        return _build_local_quiz_from_cards(cards, level, topic or "Tổng hợp", actual_q_count, pass_percentage)

    sample_cards = random.sample(cards, min(len(cards), actual_q_count))
    words_summary = [
        {
            "word": c.word,
            "basic_word": c.basic_word,
            "advanced_word": c.advanced_word,
            "meaning_vi": c.vietnamese_meaning,
        }
        for c in sample_cards
    ]

    prompt = f"""You are an IELTS Vocabulary Test Designer.
Create {len(sample_cards)} multiple-choice quiz questions for Level {level}/5 based on these target words:
{json.dumps(words_summary, ensure_ascii=False)}

Mix question types:
- "word_upgrade": Ask which higher-level word best upgrades a basic word in an IELTS sentence.
- "fill_blank": Provide an academic sentence with "________" and 4 English word options.
- "contextual_mcq": Ask for the English definition, closest synonym, or contextual usage of the target word in an academic IELTS sentence.

IMPORTANT CRITERIA:
1. ALL question prompts and ALL 4 options MUST be strictly in English. Do NOT provide Vietnamese translations or Vietnamese text in the prompts or options.
2. ONLY the field "explanation_vi" must be in clear, helpful Vietnamese to explain the answer to the learner after submitting.
3. "correct_answer" must exactly match one of the 4 strings in "options".

Return ONLY a valid JSON object with this structure:
{{
  "questions": [
    {{
      "id": 1,
      "question_type": "word_upgrade",
      "prompt": "Question text in English...",
      "target_word": "target word",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correct_answer": "Exact string matching one of the 4 options",
      "explanation_vi": "Giải thích ngắn gọn, dễ hiểu bằng tiếng Việt."
    }}
  ]
}}
Output purely the JSON object."""

    payload = {
        "model": model_to_use,
        "prompt": prompt,
        "format": "json",
        "stream": False,
        "options": {
            "temperature": 0.2,
            "num_predict": 1536,
        },
    }

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(f"{OLLAMA_BASE_URL}/api/generate", json=payload)
            resp.raise_for_status()
            raw = resp.json().get("response", "")
            cleaned = _clean_json_text(raw)
            parsed = json.loads(cleaned)
            q_list = parsed.get("questions", [])

            validated_questions: List[VocabQuizQuestionSchema] = []
            for idx, q in enumerate(q_list, start=1):
                if not isinstance(q, dict):
                    continue
                opts = [str(o) for o in q.get("options", []) if o]
                ans = str(q.get("correct_answer") or "").strip()
                if len(opts) < 2 or not ans:
                    continue
                if ans not in opts:
                    opts[0] = ans
                validated_questions.append(
                    VocabQuizQuestionSchema(
                        id=idx,
                        question_type=str(q.get("question_type") or "contextual_mcq"),
                        prompt=str(q.get("prompt") or ""),
                        target_word=str(q.get("target_word") or ""),
                        options=opts[:4],
                        correct_answer=ans,
                        explanation_vi=str(q.get("explanation_vi") or ""),
                    )
                )

            if len(validated_questions) >= 3:
                pass_score_required = max(1, math.ceil(len(validated_questions) * (pass_percentage / 100.0)))
                return VocabQuizResponse(
                    level=level,
                    topic=topic or "Tổng hợp",
                    source=f"qwen2.5 ({model_to_use})",
                    pass_score_required=pass_score_required,
                    questions=validated_questions,
                )
    except Exception as e:
        logger.warning(f"Fallback về bộ câu hỏi DB do lỗi tạo quiz từ Qwen 2.5: {e}")

    return _build_local_quiz_from_cards(cards, level, topic or "Tổng hợp", actual_q_count, pass_percentage)


# ─────────────────────────────────────────────────────────────────────────────
# 9. CẬP NHẬT MỨC ĐỘ THUỘC TỪ (SRS) & NỘP BÀI VƯỢT CẤP (STAGE PROGRESS)
# ─────────────────────────────────────────────────────────────────────────────


def update_card_mastery(
    db: Session,
    user_id: int,
    card_id: int,
    mastery_level: int,
) -> MasteryUpdateResponse:
    """Cập nhật mức độ thuộc từ (0: Chưa học, 1: Quên, 2: Nhớ sơ, 3: Đã thuộc) cho học viên."""
    record = (
        db.query(UserVocabMastery)
        .filter(
            UserVocabMastery.user_id == user_id,
            UserVocabMastery.card_id == card_id,
        )
        .first()
    )
    if not record:
        record = UserVocabMastery(
            user_id=user_id,
            card_id=card_id,
            mastery_level=mastery_level,
            review_count=1,
            correct_streak=1 if mastery_level >= 2 else 0,
            last_reviewed_at=datetime.utcnow(),
        )
        db.add(record)
    else:
        record.mastery_level = mastery_level
        record.review_count = (record.review_count or 0) + 1
        if mastery_level >= 2:
            record.correct_streak = (record.correct_streak or 0) + 1
        else:
            record.correct_streak = 0
        record.last_reviewed_at = datetime.utcnow()

    db.commit()
    db.refresh(record)

    labels = {
        0: "Chưa học",
        1: "Cần ôn lại (Quên)",
        2: "Nhớ mang máng",
        3: "Đã thuộc lòng!",
    }
    return MasteryUpdateResponse(
        card_id=card_id,
        mastery_level=record.mastery_level,
        review_count=record.review_count,
        correct_streak=record.correct_streak,
        message=f"Đã cập nhật trạng thái: {labels.get(mastery_level, 'Đã lưu')}",
    )


def submit_vocab_quiz(
    db: Session,
    user: User,
    req: VocabQuizSubmitRequest,
) -> VocabQuizSubmitResponse:
    """
    Chấm điểm bài kiểm tra vượt cấp từ vựng:
    - Tính số sao (1⭐ - 3⭐) và kết quả vượt ải theo Cấu hình SystemVocabConfig.
    - Mở khóa cấp độ tiếp theo nếu đạt yêu cầu.
    - Cập nhật trạng thái thuộc lòng cho các thẻ từ đã trả lời đúng.
    - Lưu vào lịch sử luyện tập (PracticeHistory).
    """
    cfg = get_or_create_system_vocab_config(db)
    meta = LEVEL_METADATA.get(req.level, LEVEL_METADATA[1])
    ratio = req.score / max(1, req.total_questions)
    percentage = int(round(ratio * 100))
    passed = percentage >= cfg.pass_percentage
    pass_required = max(1, math.ceil(req.total_questions * (cfg.pass_percentage / 100.0)))

    star_rules = cfg.star_thresholds or {"star1": 60, "star2": 80, "star3": 100}
    star3_min = int(star_rules.get("star3", 100))
    star2_min = int(star_rules.get("star2", 80))

    if not passed:
        stars = 0
    elif percentage >= star3_min:
        stars = 3
    elif percentage >= star2_min:
        stars = 2
    else:
        stars = 1

    # Cập nhật tiến độ ải hiện tại
    current_stage = (
        db.query(UserStageProgress)
        .filter(
            UserStageProgress.user_id == user.id,
            UserStageProgress.skill_type == "vocabulary",
            UserStageProgress.stage_number == req.level,
        )
        .first()
    )
    if not current_stage:
        current_stage = UserStageProgress(
            user_id=user.id,
            skill_type="vocabulary",
            stage_number=req.level,
            stars=stars,
            best_score=req.score,
            is_unlocked=True,
        )
        db.add(current_stage)
    else:
        current_stage.is_unlocked = True
        if stars > current_stage.stars:
            current_stage.stars = stars
        if req.score > current_stage.best_score:
            current_stage.best_score = req.score

    unlocked_next = False
    if passed and req.level < 5:
        next_lvl = req.level + 1
        next_stage = (
            db.query(UserStageProgress)
            .filter(
                UserStageProgress.user_id == user.id,
                UserStageProgress.skill_type == "vocabulary",
                UserStageProgress.stage_number == next_lvl,
            )
            .first()
        )
        if not next_stage:
            next_stage = UserStageProgress(
                user_id=user.id,
                skill_type="vocabulary",
                stage_number=next_lvl,
                stars=0,
                best_score=0,
                is_unlocked=True,
            )
            db.add(next_stage)
            unlocked_next = True
        elif not next_stage.is_unlocked:
            next_stage.is_unlocked = True
            unlocked_next = True

    # Cập nhật SRS mastery cho các thẻ trả lời đúng trong bài quiz
    for cid in req.mastered_card_ids:
        update_card_mastery(db, user_id=user.id, card_id=cid, mastery_level=3)

    # Lưu lịch sử luyện tập (PracticeHistory yêu cầu user_id kiểu UUID)
    band_eq = meta["band_target"]
    raw_uuid = resolve_user_uuid(db, user)
    try:
        user_uuid = uuid.UUID(str(raw_uuid))
    except (ValueError, TypeError):
        user_uuid = uuid.uuid5(uuid.NAMESPACE_DNS, f"user_{user.id}_{user.username}")
        user.supabase_uuid = str(user_uuid)
        db.commit()

    history = PracticeHistory(
        user_id=user_uuid,
        skill_type="vocabulary",
        lesson_id=f"vocab_lvl_{req.level}",
        lesson_title=meta["title"],
        score=req.score,
        total_questions=req.total_questions,
        band_score=band_eq,
    )
    db.add(history)
    db.commit()

    # Tính cấp độ mở khóa cao nhất hiện tại
    all_stages = (
        db.query(UserStageProgress)
        .filter(
            UserStageProgress.user_id == user.id,
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

    if passed:
        feedback = (
            f"Xuất sắc! Bạn đạt {req.score}/{req.total_questions} câu ({stars}⭐) ở {meta['title']}. "
            + (f"Đã mở khóa Cấp độ {req.level + 1}!" if req.level < 5 else "Bạn đã chinh phục đỉnh cao Bậc thầy C2!")
        )
    else:
        feedback = (
            f"Bạn đạt {req.score}/{req.total_questions} câu. Cần tối thiểu {pass_required} câu đúng để vượt qua {meta['title']}. "
            "Hãy ôn lại các thẻ Flashcard và thử lại nhé!"
        )

    return VocabQuizSubmitResponse(
        level=req.level,
        score=req.score,
        total_questions=req.total_questions,
        passed=passed,
        stars_earned=stars,
        band_equivalent=band_eq,
        unlocked_next_level=unlocked_next,
        highest_unlocked_level=highest,
        feedback=feedback,
    )

