import logging
from datetime import datetime
from typing import List, Optional, Dict, Any
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.user import User
from app.models.skill import SkillLesson, PracticeHistory, UserStageProgress
from app.schemas.skill import (
    SkillSubmissionRequest,
    SkillSubmissionResponse,
    ListeningProgressResponse,
    StageItemProgress,
    SkillLessonCreateRequest,
    SkillLessonUpdateRequest,
)
from app.core.supabase import get_supabase_admin

logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────────────────────
# 1. KHO DỮ LIỆU BÀI HỌC 4 KỸ NĂNG CHUẨN IELTS (5 ẢI GAMIFICATION CHO MỖI KỸ NĂNG)
# ─────────────────────────────────────────────────────────────

SAMPLE_SKILL_LESSONS = [
    # ═════════════════════════════════════════════════════════════
    # ── READING (5 ẢI VƯỢT CẤP) ──
    # ═════════════════════════════════════════════════════════════
    {
        "id": "r1",
        "skill_type": "reading",
        "stage_number": 1,
        "difficulty_label": "Ải 1: Cơ bản (Band 6.0)",
        "title": "Artificial Intelligence in Modern Education",
        "category_or_topic": "Technology & Education",
        "band_score_target": "6.5",
        "pass_score_required": 2,
        "content_json": {
            "paragraphs": {
                "A": "Artificial Intelligence (AI) is rapidly altering the landscape of modern education. By leveraging advanced machine learning algorithms, educational platforms can tailor learning materials to match the individual pacing and cognitive strengths of each student. This adaptive learning technology ensures that learners absorb complex academic concepts efficiently without feeling overwhelmed.",
                "B": "Furthermore, smart computer vision systems enable mobile applications to recognize real-world objects instantaneously. When a student points a smartphone camera at an everyday item, AI models analyze the visual features and map them to specialized IELTS academic vocabulary, collocations, and contextual Speaking samples.",
                "C": "Critics argue that over-reliance on artificial intelligence might diminish human interaction and critical thinking skills. However, educators emphasize that AI tools are designed to augment traditional pedagogy rather than replace teachers. Educators can focus on mentorship and emotional support while AI handles automated vocabulary drills and performance analytics.",
            },
            "questions": [
                {
                    "id": 1,
                    "questionText": "What primary benefit of AI in education is highlighted in Paragraph A?",
                    "options": [
                        "Replacing human teachers completely",
                        "Tailoring learning materials to individual student pacing",
                        "Reducing tuition fees significantly",
                        "Eliminating all academic examinations",
                    ],
                    "correctAnswer": "Tailoring learning materials to individual student pacing",
                    "explanation": "Paragraph A explicitly states: 'By leveraging advanced machine learning algorithms, educational platforms can tailor learning materials to match the individual pacing... of each student.'",
                    "paragraphRef": "Đoạn A",
                },
                {
                    "id": 2,
                    "questionText": "How does computer vision enhance vocabulary learning according to Paragraph B?",
                    "options": [
                        "By writing essay assignments automatically",
                        "By mapping camera-scanned objects to academic vocabulary",
                        "By generating fake images for testing",
                        "By translating entire textbooks into audio files",
                    ],
                    "correctAnswer": "By mapping camera-scanned objects to academic vocabulary",
                    "explanation": "Paragraph B mentions: 'When a student points a smartphone camera... AI models analyze visual features and map them to specialized IELTS academic vocabulary.'",
                    "paragraphRef": "Đoạn B",
                },
                {
                    "id": 3,
                    "questionText": "What view do educators hold regarding AI tools in Paragraph C?",
                    "options": [
                        "AI tools should completely replace traditional schools",
                        "AI tools augment pedagogy rather than replace human teachers",
                        "AI tools are detrimental to student progress",
                        "AI tools are too expensive to implement",
                    ],
                    "correctAnswer": "AI tools augment pedagogy rather than replace human teachers",
                    "explanation": "Paragraph C states: 'educators emphasize that AI tools are designed to augment traditional pedagogy rather than replace teachers.'",
                    "paragraphRef": "Đoạn C",
                },
            ],
        },
    },
    {
        "id": "r2",
        "skill_type": "reading",
        "stage_number": 2,
        "difficulty_label": "Ải 2: Trung cấp (Band 7.0)",
        "title": "Climate Change and Biodiversity Conservation",
        "category_or_topic": "Environment & Biology",
        "band_score_target": "7.0",
        "pass_score_required": 2,
        "content_json": {
            "paragraphs": {
                "A": "Global climate shifts pose unprecedented threats to ecosystem stability. Rising surface temperatures accelerate natural habitat degradation, forcing species to adapt rapidly or face extinction. Conservationists are implementing innovative ecological monitoring strategies to preserve fragile biomes.",
                "B": "Preserving biological diversity requires international cooperation and sustainable environmental policies. Urban green spaces and reforestation projects mitigate carbon dioxide emissions while providing vital sanctuaries for native wildlife species.",
                "C": "Community-based conservation initiatives have shown remarkable promise in developing nations. By incentivizing local populations through eco-tourism revenue and agroforestry programs, governments can align economic survival with wildlife protection.",
            },
            "questions": [
                {
                    "id": 1,
                    "questionText": "What primary challenge to ecosystems is described in Paragraph A?",
                    "options": [
                        "Overpopulation in urban areas",
                        "Habitat degradation caused by rising temperatures",
                        "Lack of international tourism",
                        "Excessive industrial recycling",
                    ],
                    "correctAnswer": "Habitat degradation caused by rising temperatures",
                    "explanation": "Paragraph A highlights that rising surface temperatures accelerate habitat degradation.",
                    "paragraphRef": "Đoạn A",
                },
                {
                    "id": 2,
                    "questionText": "What dual advantage of urban green spaces is mentioned in Paragraph B?",
                    "options": [
                        "Reducing city taxes and increasing car traffic",
                        "Mitigating carbon emissions and providing wildlife sanctuaries",
                        "Supplying timber for construction and boosting electricity",
                        "Eliminating the need for national parks",
                    ],
                    "correctAnswer": "Mitigating carbon emissions and providing wildlife sanctuaries",
                    "explanation": "Paragraph B explains that urban green spaces mitigate carbon emissions while providing sanctuaries for wildlife.",
                    "paragraphRef": "Đoạn B",
                },
                {
                    "id": 3,
                    "questionText": "According to Paragraph C, how can governments foster local conservation?",
                    "options": [
                        "By banning all agricultural activities",
                        "By offering eco-tourism revenue and agroforestry incentives",
                        "By relocating indigenous communities to urban centers",
                        "By privatizing all national forests",
                    ],
                    "correctAnswer": "By offering eco-tourism revenue and agroforestry incentives",
                    "explanation": "Paragraph C notes that incentivizing local populations through eco-tourism and agroforestry aligns economic needs with conservation.",
                    "paragraphRef": "Đoạn C",
                },
            ],
        },
    },
    {
        "id": "r3",
        "skill_type": "reading",
        "stage_number": 3,
        "difficulty_label": "Ải 3: Nâng cao (Band 7.5)",
        "title": "Urban Architecture & Sustainable Smart Cities",
        "category_or_topic": "Urban Planning & Architecture",
        "band_score_target": "7.5",
        "pass_score_required": 2,
        "content_json": {
            "paragraphs": {
                "A": "Rapid urbanization has compelled contemporary civil engineers to rethink urban infrastructure. Modern skyscrapers now integrate vertical gardens, photothermal glass facades, and automated waste reclamation channels to reduce their overall ecological footprints.",
                "B": "Smart energy grids powered by Internet-of-Things (IoT) sensors distribute municipal electricity dynamically based on real-time consumption patterns. This localized energy harvesting prevents power surges during peak hours and minimizes transmission dissipation.",
                "C": "Nevertheless, critics caution that high-tech smart cities risk exacerbating socioeconomic stratification. When energy-efficient autonomous neighborhoods cater exclusively to affluent residents, lower-income communities remain exposed to degraded municipal infrastructure.",
            },
            "questions": [
                {
                    "id": 1,
                    "questionText": "Which technological integration in skyscrapers is noted in Paragraph A?",
                    "options": [
                        "Coal furnaces and exterior neon billboards",
                        "Vertical gardens and photothermal glass facades",
                        "Underground nuclear micro-reactors",
                        "Manual rainwater drainage buckets",
                    ],
                    "correctAnswer": "Vertical gardens and photothermal glass facades",
                    "explanation": "Paragraph A states modern skyscrapers incorporate vertical gardens and photothermal glass facades.",
                    "paragraphRef": "Đoạn A",
                },
                {
                    "id": 2,
                    "questionText": "How do IoT-enabled smart grids optimize energy distribution in Paragraph B?",
                    "options": [
                        "By shutting down public streetlights at night",
                        "By dynamically distributing power based on consumption patterns",
                        "By tripling municipal electricity tariffs during weekends",
                        "By storing excess electricity in lead-acid automotive batteries",
                    ],
                    "correctAnswer": "By dynamically distributing power based on consumption patterns",
                    "explanation": "Paragraph B states smart grids distribute electricity dynamically based on real-time consumption patterns.",
                    "paragraphRef": "Đoạn B",
                },
                {
                    "id": 3,
                    "questionText": "What socioeconomic risk of smart cities is warned about in Paragraph C?",
                    "options": [
                        "Excessive immigration of rural farmers",
                        "Exacerbating socioeconomic stratification between affluent and lower-income residents",
                        "A complete collapse of municipal internet connectivity",
                        "The total elimination of public healthcare centers",
                    ],
                    "correctAnswer": "Exacerbating socioeconomic stratification between affluent and lower-income residents",
                    "explanation": "Paragraph C cautions that smart cities risk widening the gap if green tech only serves affluent residents.",
                    "paragraphRef": "Đoạn C",
                },
            ],
        },
    },
    {
        "id": "r4",
        "skill_type": "reading",
        "stage_number": 4,
        "difficulty_label": "Ải 4: Chuyên sâu (Band 8.0)",
        "title": "Global Economics, Automation & Future Labor Markets",
        "category_or_topic": "Economics & Society",
        "band_score_target": "8.0",
        "pass_score_required": 2,
        "content_json": {
            "paragraphs": {
                "A": "The accelerating proliferation of robotic process automation and large language models is restructuring global employment paradigms. Routine analytical tasks in auditing, paralegal documentation, and commercial logistics are increasingly automated, causing structural friction in white-collar sectors.",
                "B": "Historically, technological disruptions have displaced localized job categories while simultaneously generating novel occupational sectors. Economists predict that human-centric competencies, such as empathetic negotiation, complex cross-disciplinary synthesis, and ethical decision-making, will appreciate substantially in market value.",
                "C": "To prevent widespread labor displacement, macroeconomic policymakers advocate lifelong reskilling subsidies and universal baseline digital literacy frameworks. Failure to proactively upskill the domestic workforce could result in protracted economic stagnation and rising income disparity.",
            },
            "questions": [
                {
                    "id": 1,
                    "questionText": "What sector is facing structural friction due to automation according to Paragraph A?",
                    "options": [
                        "Manual agricultural harvesting",
                        "White-collar sectors involving routine analytical tasks",
                        "Traditional artisanal blacksmithing",
                        "Deep-sea commercial fishing",
                    ],
                    "correctAnswer": "White-collar sectors involving routine analytical tasks",
                    "explanation": "Paragraph A identifies structural friction in white-collar sectors such as auditing and paralegal documentation.",
                    "paragraphRef": "Đoạn A",
                },
                {
                    "id": 2,
                    "questionText": "Which human skills are expected to gain market value in Paragraph B?",
                    "options": [
                        "Rapid mechanical arithmetic and manual typing",
                        "Empathetic negotiation, synthesis, and ethical decision-making",
                        "Physical stamina and assembly line speed",
                        "Memorization of legal encyclopedias",
                    ],
                    "correctAnswer": "Empathetic negotiation, synthesis, and ethical decision-making",
                    "explanation": "Paragraph B outlines that human-centric competencies like empathetic negotiation and ethical decision-making will appreciate.",
                    "paragraphRef": "Đoạn B",
                },
                {
                    "id": 3,
                    "questionText": "What policy recommendation is suggested in Paragraph C to mitigate unemployment?",
                    "options": [
                        "Banning all robotic manufacturing machinery",
                        "Lifelong reskilling subsidies and universal digital literacy",
                        "Lowering mandatory retirement ages to thirty-five",
                        "Eliminating international corporate income taxation",
                    ],
                    "correctAnswer": "Lifelong reskilling subsidies and universal digital literacy",
                    "explanation": "Paragraph C advises policymakers to implement lifelong reskilling subsidies and digital literacy frameworks.",
                    "paragraphRef": "Đoạn C",
                },
            ],
        },
    },
    {
        "id": "r5",
        "skill_type": "reading",
        "stage_number": 5,
        "difficulty_label": "Ải 5: Bậc thầy (Band 8.5+ - Boss Stage)",
        "title": "Neuroscience, Cognitive Resilience & Machine Consciousness",
        "category_or_topic": "Cognitive Science & Neuroscience",
        "band_score_target": "8.5+",
        "pass_score_required": 3,
        "content_json": {
            "paragraphs": {
                "A": "Neuroplasticity—the nervous system\'s intrinsic capacity to reorganize synaptic architecture in response to cognitive stimuli—has fundamentally overturned earlier deterministic assumptions regarding cerebral decline. Recent neuroimaging breakthroughs indicate that rigorous multilingual acquisition and musical training cultivate structural neuroprotective reserves against neurodegenerative pathologies.",
                "B": "Simultaneously, cognitive neuroscientists and synthetic intelligence theoreticians are fiercely debating the ontological boundaries of machine consciousness. While deep neural networks emulate phenomenological pattern recognition with superhuman proficiency, they fundamentally lack subjective sentience, qualia, and intrinsic teleological intention.",
                "C": "The synthesis of biological neural interfaces and neuromorphic computation may soon dissolve the dichotomy between organic cognition and synthetic computation. However, ethical philosophers caution that engineering semi-sentient bio-computational hybrid architectures without comprehensive moral consensus risks precipitating unprecedented existential dilemmas.",
            },
            "questions": [
                {
                    "id": 1,
                    "questionText": "How does Paragraph A define the fundamental nature of neuroplasticity?",
                    "options": [
                        "The predetermined and irreversible deterioration of human brain cells",
                        "The nervous system\'s intrinsic capacity to reorganize synaptic architecture",
                        "The mechanical replacement of damaged neurons with silicon microchips",
                        "The inherited genetic resistance to external psychological stress",
                    ],
                    "correctAnswer": "The nervous system\'s intrinsic capacity to reorganize synaptic architecture",
                    "explanation": "Paragraph A defines neuroplasticity as the intrinsic capacity to reorganize synaptic architecture in response to cognitive stimuli.",
                    "paragraphRef": "Đoạn A",
                },
                {
                    "id": 2,
                    "questionText": "What critical human cognitive attributes are deep neural networks cited as lacking in Paragraph B?",
                    "options": [
                        "Algorithmic speed and statistical vector processing",
                        "Subjective sentience, qualia, and intrinsic teleological intention",
                        "Optical pattern recognition and data storage bandwidth",
                        "Mathematical calculation and chess-playing capability",
                    ],
                    "correctAnswer": "Subjective sentience, qualia, and intrinsic teleological intention",
                    "explanation": "Paragraph B emphasizes that synthetic networks lack subjective sentience, qualia, and intrinsic intention.",
                    "paragraphRef": "Đoạn B",
                },
                {
                    "id": 3,
                    "questionText": "What profound warning is delivered by ethical philosophers in Paragraph C?",
                    "options": [
                        "Neuromorphic computation will bankrupt global tech conglomerates",
                        "Bio-computational hybrid architectures without moral consensus create existential dilemmas",
                        "Organic neurons will rapidly overheat when exposed to fiber-optic cables",
                        "Multilingual learning should be restricted to children under age ten",
                    ],
                    "correctAnswer": "Bio-computational hybrid architectures without moral consensus create existential dilemmas",
                    "explanation": "Paragraph C concludes that engineering semi-sentient bio-computational hybrids without moral consensus threatens existential dilemmas.",
                    "paragraphRef": "Đoạn C",
                },
            ],
        },
    },

    # ═════════════════════════════════════════════════════════════
    # ── LISTENING (5 ẢI VƯỢT CẤP) ──
    # ═════════════════════════════════════════════════════════════
    {
        "id": "l1",
        "skill_type": "listening",
        "stage_number": 1,
        "difficulty_label": "Ải 1: Cơ bản (Band 6.0)",
        "title": "Campus Library Orientation & AI Resources",
        "category_or_topic": "Education & Student Support",
        "band_score_target": "6.5",
        "pass_score_required": 2,
        "content_json": {
            "audioScript": "Welcome to the Central University Library orientation. My name is Sarah, and I am the senior academic coordinator. Today, I will guide you through our newly upgraded digital resources. On the first floor, you will find our interactive study pods equipped with automated speech recognition and camera scanners. Students can practice IELTS speaking drills and instantly record their pronunciations. The library is open from 8:00 AM to 10:00 PM on weekdays, and 9:00 AM to 5:00 PM on weekends. Please ensure you carry your university ID card at all times to gain access to the digital laboratories.",
            "questions": [
                {
                    "id": 1,
                    "questionText": "What is the speaker\'s official role at the university library?",
                    "options": [
                        "IT Technical Support Specialist",
                        "Senior Academic Coordinator",
                        "Head of Security",
                        "Student Union President",
                    ],
                    "correctAnswer": "Senior Academic Coordinator",
                    "explanation": "Sarah states: \'My name is Sarah, and I am the senior academic coordinator.\'",
                },
                {
                    "id": 2,
                    "questionText": "What opening hours are specified for weekday access?",
                    "options": [
                        "7:00 AM to 9:00 PM",
                        "8:00 AM to 10:00 PM",
                        "9:00 AM to 5:00 PM",
                        "24 hours continuous access",
                    ],
                    "correctAnswer": "8:00 AM to 10:00 PM",
                    "explanation": "The audio script states: \'The library is open from 8:00 AM to 10:00 PM on weekdays.\'",
                },
                {
                    "id": 3,
                    "questionText": "What item is required to enter the digital laboratories?",
                    "options": [
                        "A printed paper ticket",
                        "University ID card",
                        "Driver\'s license",
                        "Library membership fee receipt",
                    ],
                    "correctAnswer": "University ID card",
                    "explanation": "Sarah states: \'Please ensure you carry your university ID card at all times to gain access to the digital laboratories.\'",
                },
            ],
        },
    },
    {
        "id": "l2",
        "skill_type": "listening",
        "stage_number": 2,
        "difficulty_label": "Ải 2: Trung cấp (Band 7.0)",
        "title": "International Technology Conference Discussion",
        "category_or_topic": "Technology & Innovation",
        "band_score_target": "7.0",
        "pass_score_required": 2,
        "content_json": {
            "audioScript": "Good afternoon delegates. In this session, Dr. Marcus from the Robotics Institute will discuss edge artificial intelligence. Traditional deep learning pipelines rely extensively on cloud data centers, which introduces transmission latency and bandwidth vulnerability. Edge AI, however, executes mathematical inference locally on low-power mobile microprocessors. For instance, smartphone object detection operates at over 30 frames per second directly on-device without internet access. This technological transition dramatically protects user biometric privacy while enabling instantaneous situational awareness.",
            "questions": [
                {
                    "id": 1,
                    "questionText": "What major limitation of cloud-based AI is emphasized by Dr. Marcus?",
                    "options": [
                        "Excessive battery life on smartphones",
                        "Transmission latency and bandwidth vulnerability",
                        "Total lack of neural network accuracy",
                        "Expensive desktop monitor costs",
                    ],
                    "correctAnswer": "Transmission latency and bandwidth vulnerability",
                    "explanation": "The speaker mentions: \'Traditional deep learning pipelines rely extensively on cloud data centers, which introduces transmission latency and bandwidth vulnerability.\'",
                },
                {
                    "id": 2,
                    "questionText": "At what frame rate does on-device object detection execute on modern smartphones?",
                    "options": ["10 frames per second", "Over 30 frames per second", "60 to 120 frames per second", "Less than 5 frames per second"],
                    "correctAnswer": "Over 30 frames per second",
                    "explanation": "Dr. Marcus states: \'smartphone object detection operates at over 30 frames per second directly on-device.\'",
                },
                {
                    "id": 3,
                    "questionText": "What key user benefit is achieved by processing AI inferences locally?",
                    "options": [
                        "Elimination of all smartphone hardware updates",
                        "Protection of biometric privacy and instantaneous awareness",
                        "Free mobile phone cellular data contracts",
                        "Lower screen resolution for reading",
                    ],
                    "correctAnswer": "Protection of biometric privacy and instantaneous awareness",
                    "explanation": "The conclusion points out: \'This technological transition dramatically protects user biometric privacy while enabling instantaneous situational awareness.\'",
                },
            ],
        },
    },
    {
        "id": "l3",
        "skill_type": "listening",
        "stage_number": 3,
        "difficulty_label": "Ải 3: Nâng cao (Band 7.5)",
        "title": "Environmental Science & Renewable Energy Lecture",
        "category_or_topic": "Ecology & Sustainable Energy",
        "band_score_target": "7.5",
        "pass_score_required": 2,
        "content_json": {
            "audioScript": "In today\'s environmental science seminar, we analyze offshore wind farm infrastructure in the North Sea. The latest turbine models possess rotor diameters exceeding 220 meters, generating up to 15 megawatts per unit. A critical engineering bottleneck lies in subsea electrical transmission. High-voltage direct current cables are deployed to transmit bulk energy across hundreds of kilometers with less than 3% transmission loss. The environmental impact assessment indicates marine mammal habitats adapt positively to artificial turbine foundation reefs within 18 months of installation.",
            "questions": [
                {
                    "id": 1,
                    "questionText": "What is the maximum power generation capacity of the newest offshore turbine models?",
                    "options": ["5 megawatts", "10 megawatts", "Up to 15 megawatts", "50 megawatts"],
                    "correctAnswer": "Up to 15 megawatts",
                    "explanation": "The lecturer explicitly states: \'generating up to 15 megawatts per unit.\'",
                },
                {
                    "id": 2,
                    "questionText": "Why are high-voltage direct current cables utilized for subsea energy transmission?",
                    "options": [
                        "They are made from recycled plastic materials",
                        "They reduce energy transmission loss to under 3%",
                        "They do not require physical seafloor placement",
                        "They double the wind speed around turbine blades",
                    ],
                    "correctAnswer": "They reduce energy transmission loss to under 3%",
                    "explanation": "The lecture explains cables are deployed: \'to transmit bulk energy across hundreds of kilometers with less than 3% transmission loss.\'",
                },
                {
                    "id": 3,
                    "questionText": "How long does it take for marine mammal habitats to adapt to artificial foundation reefs?",
                    "options": ["Within 6 weeks", "Within 18 months", "At least 5 years", "Over a decade"],
                    "correctAnswer": "Within 18 months",
                    "explanation": "The assessment indicates marine habitats adapt positively \'within 18 months of installation.\'",
                },
            ],
        },
    },
    {
        "id": "l4",
        "skill_type": "listening",
        "stage_number": 4,
        "difficulty_label": "Ải 4: Chuyên sâu (Band 8.0)",
        "title": "Global Economics & International Business Dialogue",
        "category_or_topic": "Macroeconomics & Trade Finance",
        "band_score_target": "8.0",
        "pass_score_required": 2,
        "content_json": {
            "audioScript": "Welcome to the Global Monetary Forum podcast. Today we examine international trade settlement diversification. For nearly eight decades, the United States dollar served as the undisputed primary reserve currency, representing approximately 58% of global foreign exchange reserves in 2023. However, bilateral trade agreements utilizing sovereign currencies and distributed ledger payment systems have accelerated significantly. Central banks in emerging economies increased gold acquisitions by 32% year-on-year to hedge against inflationary currency depreciation and sovereign sanctions.",
            "questions": [
                {
                    "id": 1,
                    "questionText": "What percentage of global foreign exchange reserves was represented by the US Dollar in 2023?",
                    "options": ["Approximately 45%", "Approximately 58%", "Over 75%", "Exactly 90%"],
                    "correctAnswer": "Approximately 58%",
                    "explanation": "The speaker mentions: \'representing approximately 58% of global foreign exchange reserves in 2023.\'",
                },
                {
                    "id": 2,
                    "questionText": "What financial technology has accelerated bilateral currency settlements?",
                    "options": ["Distributed ledger payment systems", "Paper credit vouchers", "Commodity barter exchanges", "Automated teller machines"],
                    "correctAnswer": "Distributed ledger payment systems",
                    "explanation": "The dialogue highlights: \'bilateral trade agreements utilizing sovereign currencies and distributed ledger payment systems have accelerated.\'",
                },
                {
                    "id": 3,
                    "questionText": "By what percentage did emerging central banks increase their gold acquisitions?",
                    "options": ["12% year-on-year", "25% year-on-year", "32% year-on-year", "50% year-on-year"],
                    "correctAnswer": "32% year-on-year",
                    "explanation": "The economist notes: \'Central banks in emerging economies increased gold acquisitions by 32% year-on-year.\'",
                },
            ],
        },
    },
    {
        "id": "l5",
        "skill_type": "listening",
        "stage_number": 5,
        "difficulty_label": "Ải 5: Bậc thầy (Band 8.5+ - Boss Stage)",
        "title": "AI Neural Networks & Healthcare Innovations",
        "category_or_topic": "Medical Science & Biotechnology",
        "band_score_target": "8.5+",
        "pass_score_required": 3,
        "content_json": {
            "audioScript": "Distinguished scholars, welcome to the Medical Artificial Intelligence Symposium. Our research laboratory has successfully developed a convolutional neural network capable of detecting early-stage pulmonary abnormalities with an unprecedented 98.4% diagnostic accuracy. Unlike conventional radiological screenings that require hours of human radiologist review, this algorithmic pipeline generates diagnostic heatmaps within 12 seconds. Clinical trials involving 15,000 anonymized patient scans across seven teaching hospitals demonstrated a 40% reduction in false-positive conclusions. The chief regulatory obstacle currently centers around data privacy compliance and international algorithmic transparency standards.",
            "questions": [
                {
                    "id": 1,
                    "questionText": "What diagnostic accuracy rate did the new neural network achieve in trials?",
                    "options": ["89.2%", "94.5%", "98.4%", "99.8%"],
                    "correctAnswer": "98.4%",
                    "explanation": "The speaker highlights: \'with an unprecedented 98.4% diagnostic accuracy.\'",
                },
                {
                    "id": 2,
                    "questionText": "How quickly does the system generate diagnostic heatmaps?",
                    "options": ["Within 5 seconds", "Within 12 seconds", "Within 45 seconds", "Within 2 minutes"],
                    "correctAnswer": "Within 12 seconds",
                    "explanation": "The script states: \'this algorithmic pipeline generates diagnostic heatmaps within 12 seconds.\'",
                },
                {
                    "id": 3,
                    "questionText": "What primary regulatory challenge was highlighted by the symposium presenter?",
                    "options": ["Software licensing fees", "Data privacy and algorithmic transparency", "Lack of hospital server equipment", "Shortage of medical students"],
                    "correctAnswer": "Data privacy and algorithmic transparency",
                    "explanation": "The presenter concludes: \'The chief regulatory obstacle currently centers around data privacy compliance and international algorithmic transparency standards.\'",
                },
            ],
        },
    },

    # ═════════════════════════════════════════════════════════════
    # ── WRITING (5 ẢI VƯỢT CẤP) ──
    # ═════════════════════════════════════════════════════════════
    {
        "id": "w1",
        "skill_type": "writing",
        "stage_number": 1,
        "difficulty_label": "Ải 1: Cơ bản - Task 1 Bar Chart (Band 6.0)",
        "title": "Internet Access in Households (2015 - 2025)",
        "category_or_topic": "Technology & Demographics",
        "band_score_target": "6.5",
        "pass_score_required": 6,
        "content_json": {
            "taskType": "Task 1",
            "prompt": "The chart illustrates the percentage of households with internet access across urban and rural areas from 2015 to 2025. Summarise the information by selecting and reporting the main features, and make comparisons where relevant. Write at least 120 words.",
            "minWordCount": 120,
            "suggestedTimeMinutes": 20,
            "keyOutline": [
                "Introduction: Paraphrase đề bài (The chart delineates...)",
                "Overview: Nêu 2 xu hướng chính (Tăng trưởng cả hai khu vực, khoảng cách thu hẹp)",
                "Body 1: Phân tích số liệu khu vực đô thị (Từ 65% lên 92%)",
                "Body 2: Phân tích số liệu khu vực nông thôn (Từ 30% vọt lên 78%)",
            ],
            "sampleEssay": "The line graph delineates the proportion of households possessing internet connectivity across metropolitan and rural districts over a ten-year span from 2015 to 2025.\n\nOverall, it is manifest that both sectors experienced a noticeable upward trajectory throughout the examined timeline. Furthermore, while urban regions consistently registered higher connectivity rates, the disparity between the two categories narrowed considerably towards the end of the period.\n\nIn 2015, approximately 65% of urban dwellings were equipped with online access, compared to a modest 30% in rural vicinities. Over the subsequent five years, urban adoption surged steadily, surpassing 80% by 2020. Simultaneously, rural connectivity witnessed exponential growth, climbing to nearly 55% as telecommunication infrastructure expanded.\n\nBy 2025, internet penetration in cities plateaued at an impressive 92%. In contrast, rural areas continued their accelerated ascent to reach 78%, thereby significantly reducing the digital divide to merely 14 percentage points.",
            "academicVocabulary": [
                "delineates (mô tả chi tiết)",
                "upward trajectory (quỹ đạo đi lên)",
                "metropolitan districts (khu vực đô thị)",
                "disparity narrowed (khoảng cách thu hẹp)",
                "plateaued (đạt mức bão hòa ổn định)",
                "digital divide (khoảng cách số)",
            ],
        },
    },
    {
        "id": "w2",
        "skill_type": "writing",
        "stage_number": 2,
        "difficulty_label": "Ải 2: Trung cấp - Task 1 Line Graph (Band 7.0)",
        "title": "Renewable Energy Consumption Across Three Continents",
        "category_or_topic": "Energy & Environment",
        "band_score_target": "7.0",
        "pass_score_required": 7,
        "content_json": {
            "taskType": "Task 1",
            "prompt": "The line graph shows changes in the consumption of renewable energy (in terawatt-hours) across Europe, North America, and Asia between 2010 and 2024. Summarise the main trends and make comparisons. Write at least 150 words.",
            "minWordCount": 150,
            "suggestedTimeMinutes": 20,
            "keyOutline": [
                "Introduction: Rephrase line graph topic",
                "Overview: Significant growth in Asia and Europe, slight increase in North America",
                "Body 1: Detail Asia\'s exponential rise after 2016",
                "Body 2: Compare Europe\'s steady increase with North America\'s stabilization",
            ],
            "sampleEssay": "The provided line graph illustrates the consumption patterns of renewable power measured in terawatt-hours across three key geographical zones—Europe, North America, and Asia—from 2010 to 2024.\n\nOverall, renewable energy utilization witnessed an upward trend across all surveyed continents. Notably, Asia transitioned from being the lowest consumer to the preeminent contributor by the conclusion of the timeline, whereas North America recorded comparatively moderate expansion.\n\nIn 2010, Europe spearheaded clean energy consumption with 450 TWh, followed closely by North America at roughly 380 TWh. Over the initial four-year span, European usage climbed incrementally, whereas North American consumption fluctuated mildly before plateauing near 500 TWh.\n\nIn marked contrast, Asian consumption was initially modest at 220 TWh. However, following aggressive green energy subsidies in 2016, Asian demand surged exponentially to surpass both competing regions, reaching an astonishing peak of 950 TWh by 2024.",
            "academicVocabulary": [
                "illustrates (minh họa)",
                "consumption patterns (mô hình tiêu thụ)",
                "preeminent contributor (nguồn đóng góp hàng đầu)",
                "incremental climb (sự gia tăng từng bước)",
                "exponential surge (sự bùng nổ theo cấp số nhân)",
                "marked contrast (sự tương phản rõ rệt)",
            ],
        },
    },
    {
        "id": "w3",
        "skill_type": "writing",
        "stage_number": 3,
        "difficulty_label": "Ải 3: Nâng cao - Task 2 Opinion Essay (Band 7.5)",
        "title": "Remote Work & Its Socioeconomic Influence on Cities",
        "category_or_topic": "Society & Employment",
        "band_score_target": "7.5",
        "pass_score_required": 7,
        "content_json": {
            "taskType": "Task 2",
            "prompt": "Some people believe that telecommuting (working remotely from home) brings enormous benefits to workers and society, while others argue it leads to social isolation and economic decline in central business districts. Discuss both views and give your opinion. Write at least 200 words.",
            "minWordCount": 200,
            "suggestedTimeMinutes": 40,
            "keyOutline": [
                "Introduction: Present both sides of remote work and state balanced stance",
                "Body 1: Advantages: Reduced commuting stress, flexible work-life balance, lowered emissions",
                "Body 2: Drawbacks: Blurred work boundaries, loneliness, retail downturn in downtown areas",
                "Conclusion: Reiterate that hybrid models offer the optimal compromise",
            ],
            "sampleEssay": "The widespread adoption of remote telecommuting has fundamentally reshaped contemporary working dynamics. While proponents emphasize flexibility and commuter stress reduction, skeptics highlight psychological isolation and commercial downturns in urban centers. In my estimation, while both arguments possess merit, a hybrid paradigm constitutes the most sustainable path forward.\n\nOn the one hand, teleworking confers undeniable advantages upon employees and the environment. Eliminating prolonged daily commutes affords individuals valuable personal time, fostering higher work-life equilibrium. Furthermore, decreased vehicular transit translates directly into reduced carbon emissions, thereby supporting municipal ecological targets.\n\nConversely, prolonged isolation from physical office spaces can induce professional alienation and stifle spontaneous collaborative innovation. Additionally, metropolitan central business districts face substantial revenue deficits when hospitality and retail businesses lose their daily office patronage.\n\nTo conclude, remote employment provides profound flexibility, but unmitigated detachment compromises social cohesion. Therefore, institutionalizing hybrid arrangements delivers the benefits of telecommuting while preserving vital collaborative bonds.",
            "academicVocabulary": [
                "telecommuting (làm việc từ xa)",
                "reshaped contemporary dynamics (định hình lại bối cảnh đương đại)",
                "hybrid paradigm (mô hình kết hợp)",
                "work-life equilibrium (sự cân bằng công việc - đời sống)",
                "spontaneous collaborative innovation (sự sáng tạo hợp tác tự nhiên)",
                "commercial downturns (sự sụt giảm thương mại)",
            ],
        },
    },
    {
        "id": "w4",
        "skill_type": "writing",
        "stage_number": 4,
        "difficulty_label": "Ải 4: Chuyên sâu - Task 2 Problem & Solution (Band 8.0)",
        "title": "Digital Overload & Mental Well-being in Adolescents",
        "category_or_topic": "Psychology & Public Health",
        "band_score_target": "8.0",
        "pass_score_required": 8,
        "content_json": {
            "taskType": "Task 2",
            "prompt": "Excessive screen time and digital media consumption are causing severe mental health challenges and sleep deprivation among teenagers worldwide. What are the root causes of this phenomenon, and what actionable solutions can be implemented by parents and schools? Write at least 250 words.",
            "minWordCount": 250,
            "suggestedTimeMinutes": 40,
            "keyOutline": [
                "Introduction: Acknowledge digital addiction among adolescents as a global public health crisis",
                "Body 1: Root Causes: Dopamine-driven recommendation algorithms, peer validation, FOMO",
                "Body 2: Practical Solutions: Institutional screen-free policies in schools, parental digital hygiene",
                "Conclusion: Emphasize that technological balance requires systemic collaboration",
            ],
            "sampleEssay": "In recent years, the ubiquity of smartphones and algorithmic social media platforms has precipitated an unprecedented psychological crisis among teenagers. Adolescent anxiety, clinical depression, and chronic sleep deprivation have surged concurrently with screen consumption. This essay explores the primary catalysts behind this troubling trend and proposes multifaceted remediations.\n\nThe paramount etiology of teenage digital dependency stems from the sophisticated engineering of addictive algorithms. Social networking corporations deliberately design notification loops that trigger dopamine surges, exploiting youthful vulnerability to social validation and the fear of missing out (FOMO). Consequently, adolescents become trapped in compulsive nocturnal scrolling, which disrupts circadian sleep rhythms.\n\nTo remediate this crisis, synchronized interventions across educational institutions and domestic households are indispensable. Pedagogical authorities must enforce strict screen-free mandates during school operating hours, replacing passive screen time with vigorous physical education and creative workshops. Concurrently, parents should establish digital curfews, such as designating bedrooms as device-free zones after 9:00 PM.\n\nIn conclusion, teenage digital addiction is driven by algorithmic manipulation and psychological vulnerability. Combating this epidemic requires strict regulatory frameworks in academic environments and conscious parenting to cultivate healthy digital boundaries.",
            "academicVocabulary": [
                "ubiquity of smartphones (sự phổ biến khắp nơi của điện thoại thông minh)",
                "precipitated an unprecedented crisis (gây ra một cuộc khủng hoảng chưa từng có)",
                "paramount etiology (nguyên nhân căn bản hàng đầu)",
                "dopamine loops (vòng lặp kích thích dopamine)",
                "circadian sleep rhythms (nhịp sinh học giấc ngủ)",
                "synchronized interventions (các biện pháp can thiệp đồng bộ)",
            ],
        },
    },
    {
        "id": "w5",
        "skill_type": "writing",
        "stage_number": 5,
        "difficulty_label": "Ải 5: Bậc thầy - Task 2 Discussion & Solution (Band 8.5+ - Boss Stage)",
        "title": "Artificial Superintelligence: Existential Threat vs Planetary Prosperity",
        "category_or_topic": "Science Ethics & Future Tech",
        "band_score_target": "8.5+",
        "pass_score_required": 8,
        "content_json": {
            "taskType": "Task 2",
            "prompt": "Many leading technologists argue that artificial general intelligence (AGI) poses an existential catastrophe to humanity, while others maintain that it will cure incurable diseases and reverse ecological destruction. Discuss both viewpoints and articulate your own reasoned perspective. Write at least 250 words.",
            "minWordCount": 250,
            "suggestedTimeMinutes": 40,
            "keyOutline": [
                "Introduction: Introduce the philosophical debate surrounding AGI development",
                "Body 1: Arguments for Existential Risk: Alignment problem, loss of cognitive agency, algorithmic autonomy",
                "Body 2: Arguments for Planetary Prosperity: Climate modeling, genomic drug discovery, poverty alleviation",
                "Conclusion & Stance: Advocate stringent international regulatory oversight as a safeguard",
            ],
            "sampleEssay": "The inexorable advancement towards artificial general intelligence (AGI) represents the most consequential juncture in anthropogenic history. While techno-optimists envision unprecedented therapeutic breakthroughs and planetary ecological rejuvenation, prominent ethicists caution against potential existential annihilation. This essay evaluates both paradigms before asserting that proactive global governance is paramount to harnessing AGI safely.\n\nOn the one hand, unregulated superintelligence presents profound existential hazards. The crux of the dilemma lies in the alignment problem—ensuring autonomous entities share human moral axioms. Should superintelligent algorithms prioritize mathematical efficiency over human welfare, unintended catastrophic consequences could ensue. Furthermore, the potential weaponization of autonomous drone swarms presents destabilizing geopolitical risks.\n\nConversely, the potential merits of benevolent AGI are transformative. In biomedical research, synthetic intelligence has deciphered complex protein folding geometries, drastically accelerating pharmacological cures for neurodegenerative ailments. Furthermore, quantum-assisted AI models can optimize global supply chains and atmospheric carbon sequestration far beyond human analytical limitations.\n\nIn conclusion, artificial superintelligence embodies both supreme opportunity and profound peril. Humanity must not succumb to fatalism nor hubris; rather, establishing stringent international non-proliferation treaties and ethical safety verifications will dictate whether AGI serves as our ultimate savior or our final invention.",
            "academicVocabulary": [
                "inexorable advancement (sự phát triển không thể ngăn cản)",
                "consequential juncture (bước ngoặt mang tính quyết định)",
                "anthropogenic history (lịch sử loài người)",
                "alignment problem (bài toán căn chỉnh đạo đức trí tuệ nhân tạo)",
                "existential annihilation (sự diệt vong mang tính tồn vong)",
                "carbon sequestration (thu giữ carbon khí quyển)",
            ],
        },
    },

    # ═════════════════════════════════════════════════════════════
    # ── SPEAKING (5 ẢI VƯỢT CẤP) ──
    # ═════════════════════════════════════════════════════════════
    {
        "id": "s1",
        "skill_type": "speaking",
        "stage_number": 1,
        "difficulty_label": "Ải 1: Cơ bản - Part 1 Daily Routine (Band 6.0)",
        "title": "Daily Routine, Time Management & Morning Habits",
        "category_or_topic": "Personal Lifestyle",
        "band_score_target": "6.5",
        "pass_score_required": 6,
        "content_json": {
            "part1Questions": [
                {
                    "question": "What is the typical sequence of your morning routine?",
                    "sampleAnswer": "Generally speaking, I wake up at around 6:30 AM, hydrate immediately, and spend twenty minutes doing light stretching exercises. Afterwards, I prepare a nutritious breakfast while reviewing my daily schedule.",
                    "translation": "Nhìn chung, tôi thức dậy lúc khoảng 6:30 sáng, uống nước ngay lập tức và dành hai mươi phút tập các bài giãn cơ nhẹ. Sau đó, tôi chuẩn bị bữa sáng bổ dưỡng trong khi xem lại lịch trình hàng ngày.",
                    "keyVocabulary": ["generally speaking (nhìn chung)", "hydrate immediately (uống nước ngay)", "nutritious breakfast (bữa sáng bổ dưỡng)", "daily schedule (lịch trình hàng ngày)"],
                },
                {
                    "question": "Do you prefer to organize your daily activities meticulously or stay spontaneous?",
                    "sampleAnswer": "I definitely lean towards meticulous scheduling because it prevents procrastination and minimizes stress. However, I always leave a buffer period in the afternoon for unexpected emergencies.",
                    "translation": "Tôi chắc chắn thiên về việc lên lịch tỉ mỉ vì nó ngăn chặn sự trì hoãn và giảm thiểu căng thẳng. Tuy nhiên, tôi luôn chừa một khoảng thời gian trống vào buổi chiều cho những việc đột xuất.",
                    "keyVocabulary": ["lean towards (thiên về)", "meticulous scheduling (lên lịch tỉ mỉ)", "prevent procrastination (ngăn chặn sự trì hoãn)", "buffer period (khoảng thời gian dự phòng)"],
                },
            ],
            "part2CueCardPrompt": "Describe a productive morning habit that you consistently follow.",
            "part2BulletPoints": [
                "What the habit is",
                "When and how you started it",
                "Why it requires discipline",
                "And explain how it influences your daily mood and efficiency.",
            ],
            "part2SampleAnswer": "I would like to elaborate on my habit of morning journaling and priority setting. I initiated this practice approximately two years ago when I felt inundated with academic deadlines. Every morning before looking at my smartphone, I jot down three core objectives for the day. This simple ritual anchors my focus, mitigates cognitive clutter, and instills a sense of purpose throughout my workday.",
            "part2SampleTranslation": "Tôi muốn chia sẻ về thói quen viết nhật ký buổi sáng và sắp xếp việc ưu tiên. Tôi bắt đầu thói quen này khoảng hai năm trước khi cảm thấy quá tải với các hạn nộp bài. Mỗi sáng trước khi nhìn vào điện thoại, tôi ghi lại ba mục tiêu cốt lõi trong ngày. Nghi thức đơn giản này neo giữ sự tập trung, giải tỏa tâm trí và truyền cảm giác có mục tiêu suốt ngày làm việc.",
            "part2Collocations": [
                "anchor focus (neo giữ sự tập trung)",
                "cognitive clutter (sự lộn xộn trong suy nghĩ)",
                "inundated with deadlines (quá tải với hạn nộp)",
                "instills a sense of purpose (truyền cảm giác có mục tiêu)",
            ],
        },
    },
    {
        "id": "s2",
        "skill_type": "speaking",
        "stage_number": 2,
        "difficulty_label": "Ải 2: Trung cấp - Part 1 Technology & Study (Band 7.0)",
        "title": "Artificial Intelligence in Everyday Life & Study",
        "category_or_topic": "Technology & Education",
        "band_score_target": "7.0",
        "pass_score_required": 7,
        "content_json": {
            "part1Questions": [
                {
                    "question": "Do you frequently utilize artificial intelligence in your academic pursuits?",
                    "sampleAnswer": "To be completely candid, I incorporate AI-powered applications almost daily, particularly for proofreading academic essays and discovering relevant research literature. It notably streamlines my workflow.",
                    "translation": "Thành thật mà nói, tôi kết hợp các ứng dụng hỗ trợ AI gần như mỗi ngày, đặc biệt là để hiệu đính bài luận học thuật và tìm tài liệu nghiên cứu liên quan. Nó giúp tinh giản rõ rệt quy trình làm việc của tôi.",
                    "keyVocabulary": ["to be completely candid (thành thật mà nói)", "incorporate daily (áp dụng hàng ngày)", "proofreading (hiệu đính)", "streamline workflow (tinh giản quy trình làm việc)"],
                },
                {
                    "question": "Do you believe artificial intelligence might replace conventional educators in the near future?",
                    "sampleAnswer": "I strongly disagree with that proposition. While AI excels at automated grading and personalized drill delivery, human mentors provide empathy, moral guidance, and psychological encouragement that algorithms cannot replicate.",
                    "translation": "Tôi hoàn toàn không đồng ý với nhận định đó. Mặc dù AI xuất sắc trong việc chấm điểm tự động và cung cấp bài luyện tập cá nhân hóa, những người thầy con người mang lại sự đồng cảm, định hướng đạo đức và khích lệ tâm lý mà các thuật toán không thể sao chép được.",
                    "keyVocabulary": ["strongly disagree (hoàn toàn không đồng ý)", "excels at (xuất sắc ở)", "moral guidance (định hướng đạo đức)", "cannot replicate (không thể sao chép)"],
                },
            ],
            "part2CueCardPrompt": "Describe a technological device or application that drastically enhanced your learning capacity.",
            "part2BulletPoints": [
                "What the device or application is",
                "How you learned to navigate it",
                "What distinctive features it possesses",
                "And explain why it made your learning experience considerably more pleasant.",
            ],
            "part2SampleAnswer": "I would be delighted to share details regarding an innovative mobile vision application I downloaded while preparing for the IELTS exam. By employing computer vision neural networks, the app allows users to scan ordinary physical objects and instantly reveals high-band IELTS terminology, contextual collocations, and acoustic pronunciation samples. This visual method drastically accelerated my lexical retention compared to tedious flashcards.",
            "part2SampleTranslation": "Tôi rất vui được chia sẻ chi tiết về một ứng dụng thị giác di động sáng tạo mà tôi đã tải về khi ôn thi IELTS. Bằng việc áp dụng mạng nơ-ron thị giác máy tính, ứng dụng cho phép người dùng quét các vật thể ngoài đời thực và ngay lập tức hiển thị thuật ngữ IELTS band cao, các cụm collocation theo ngữ cảnh và phát âm mẫu. Phương pháp trực quan này đã đẩy nhanh đáng kể khả năng ghi nhớ từ vựng so với flashcard đơn điệu.",
            "part2Collocations": [
                "delighted to share (rất vui được chia sẻ)",
                "computer vision networks (mạng thị giác máy tính)",
                "lexical retention (khả năng ghi nhớ từ vựng)",
                "drastically accelerated (đẩy nhanh đáng kể)",
            ],
        },
    },
    {
        "id": "s3",
        "skill_type": "speaking",
        "stage_number": 3,
        "difficulty_label": "Ải 3: Nâng cao - Part 2 Cue Card Monologue (Band 7.5)",
        "title": "A Life-Changing Academic or Professional Decision",
        "category_or_topic": "Personal Achievement",
        "band_score_target": "7.5",
        "pass_score_required": 7,
        "content_json": {
            "part1Questions": [
                {
                    "question": "Do you find it difficult to make significant long-term commitments?",
                    "sampleAnswer": "Admittedly yes, especially when facing irreversible life milestones. However, I usually conduct exhaustive comparative research and consult seasoned mentors before arriving at a definitive verdict.",
                    "translation": "Phải thừa nhận là có, đặc biệt khi đứng trước những cột mốc không thể đảo ngược. Tuy nhiên, tôi thường nghiên cứu so sánh cẩn thận và hỏi ý kiến các cố vấn giàu kinh nghiệm trước khi đưa ra phán quyết cuối cùng.",
                    "keyVocabulary": ["admittedly yes (thừa nhận là có)", "irreversible milestones (cột mốc không thể đảo ngược)", "exhaustive research (nghiên cứu cẩn thận)", "definitive verdict (kết luận dứt khoát)"],
                },
                {
                    "question": "Should young adults rely more on parental guidance or their personal intuition?",
                    "sampleAnswer": "In my perspective, a balanced amalgamation is ideal. Parental advice offers pragmatic historical wisdom, whereas personal intuition guarantees authentic commitment and intrinsic motivation.",
                    "translation": "Theo quan điểm của tôi, sự kết hợp cân bằng là lý tưởng nhất. Lời khuyên của cha mẹ mang lại sự thông thái thực tế, trong khi trực giác cá nhân đảm bảo sự cam kết chân thực và động lực tự thân.",
                    "keyVocabulary": ["balanced amalgamation (sự kết hợp cân bằng)", "pragmatic wisdom (sự thông thái thực tế)", "intrinsic motivation (động lực tự thân)"],
                },
            ],
            "part2CueCardPrompt": "Describe a pivotal academic decision that reshaped your educational trajectory.",
            "part2BulletPoints": [
                "What decision you made",
                "When you made it and who influenced you",
                "What initial hesitations you had to conquer",
                "And explain why this choice proved exceptionally rewarding in hindsight.",
            ],
            "part2SampleAnswer": "I would like to speak about my decision to switch my academic specialization from conventional marketing towards data science and computational linguistics during my sophomore university year. Initially, I was terrified by the intimidating mathematical prerequisites. However, under the inspiring mentorship of my faculty advisor, I embraced the transition. Looking back in hindsight, this audacious leap unlocked lucrative internship opportunities and endowed me with analytical capabilities that set me apart.",
            "part2SampleTranslation": "Tôi muốn nói về quyết định chuyển chuyên ngành đại học từ tiếp thị truyền thống sang khoa học dữ liệu và ngôn ngữ học tính toán vào năm thứ hai. Ban đầu, tôi rất lo sợ trước các môn toán học tiên quyết đầy thách thức. Tuy nhiên, dưới sự cố vấn truyền cảm hứng của giáo viên khoa, tôi đã đón nhận sự chuyển hướng. Nhìn lại, bước nhảy vọt táo bạo này đã mở ra các cơ hội thực tập hấp dẫn và trang bị cho tôi năng lực phân tích vượt trội.",
            "part2Collocations": [
                "pivotal decision (quyết định mang tính then chốt)",
                "sophomore university year (năm thứ hai đại học)",
                "audacious leap (bước nhảy táo bạo)",
                "in hindsight (khi nhìn nhận lại)",
            ],
        },
    },
    {
        "id": "s4",
        "skill_type": "speaking",
        "stage_number": 4,
        "difficulty_label": "Ải 4: Chuyên sâu - Part 3 Abstract Discussion (Band 8.0)",
        "title": "Socioeconomic Ramifications of Global Automation",
        "category_or_topic": "Sociology & Economics",
        "band_score_target": "8.0",
        "pass_score_required": 8,
        "content_json": {
            "part1Questions": [
                {
                    "question": "How will widespread industrial automation influence wealth distribution worldwide?",
                    "sampleAnswer": "Undoubtedly, unchecked automation threatens to accentuate wealth polarization. Owners of proprietary algorithms will capture disproportionate capital yields, whereas non-specialized laborers risk wage stagnation unless progressive taxation models are instituted.",
                    "translation": "Chắc chắn việc tự động hóa tràn lan đe dọa làm trầm trọng thêm sự phân cực giàu nghèo. Các chủ sở hữu thuật toán độc quyền sẽ chiếm giữ lợi suất tư bản vượt trội, trong khi người lao động không chuyên môn đối mặt với sự trì trệ tiền lương trừ khi các mô hình thuế lũy tiến được ban hành.",
                    "keyVocabulary": ["accentuate polarization (làm trầm trọng sự phân cực)", "proprietary algorithms (thuật toán độc quyền)", "disproportionate yields (lợi suất vượt trội)", "progressive taxation (thuế lũy tiến)"],
                },
                {
                    "question": "Can technological education alone safeguard future generations against employment redundancy?",
                    "sampleAnswer": "Technological literacy is certainly a prerequisite, but by no means an exhaustive panacea. Educational curricula must prioritize philosophical discernment, emotional adaptability, and complex rhetoric—attributes that remain resilient to algorithmic imitation.",
                    "translation": "Sự hiểu biết về công nghệ chắc chắn là điều kiện tiên quyết, nhưng hoàn toàn không phải là phương thuốc vạn năng. Giáo trình phải ưu tiên sự sáng suốt triết học, sự thích ứng cảm xúc và kỹ năng hùng biện phức tạp - những thuộc tính vẫn bền vững trước sự sao chép của thuật toán.",
                    "keyVocabulary": ["exhaustive panacea (phương thuốc vạn năng)", "philosophical discernment (sự thấu suốt triết học)", "resilient to imitation (bền vững trước sự bắt chước)"],
                },
            ],
            "part2CueCardPrompt": "Describe a global socioeconomic issue resulting from rapid technological evolution.",
            "part2BulletPoints": [
                "What the issue is",
                "Which demographics are most vulnerable",
                "Why conventional governmental policies struggle to address it",
                "And propose feasible international countermeasures.",
            ],
            "part2SampleAnswer": "I wish to address the pressing dilemma of technological obsolescence among mid-career blue-collar workforces. As autonomous heavy machinery becomes commercially ubiquitous across transportation and warehousing, millions of workers face sudden livelihood displacement. Traditional governmental social safety nets are ill-equipped for this exponential transition. I propose an international transition sovereign fund, financed through automation levies, to underwrite multi-year reskilling stipends.",
            "part2SampleTranslation": "Tôi muốn đề cập đến vấn đề cấp bách về sự lỗi thời kỹ năng của lực lượng lao động tay chân trung niên. Khi máy móc hạng nặng tự hành trở nên phổ biến thương mại trong vận tải và kho bãi, hàng triệu công nhân đối mặt với mất sinh kế đột ngột. Lưới an sinh xã hội truyền thống của chính phủ không đủ sức ứng phó với sự chuyển dịch theo cấp số nhân này. Tôi đề xuất một quỹ chuyển tiếp quốc tế, tài trợ từ thuế tự động hóa, để chi trả phụ cấp đào tạo lại kỹ năng trong nhiều năm.",
            "part2Collocations": [
                "pressing dilemma (song đề cấp bách)",
                "technological obsolescence (sự lỗi thời công nghệ)",
                "ill-equipped (không đủ trang bị)",
                "automation levies (thuế tự động hóa)",
            ],
        },
    },
    {
        "id": "s5",
        "skill_type": "speaking",
        "stage_number": 5,
        "difficulty_label": "Ải 5: Bậc thầy - Full Mock Interview (Band 8.5+ - Boss Stage)",
        "title": "IELTS Master Mock: Innovation, Ethics & Humanity",
        "category_or_topic": "Comprehensive Mock Exam",
        "band_score_target": "8.5+",
        "pass_score_required": 8,
        "content_json": {
            "part1Questions": [
                {
                    "question": "In what ways has your personal worldview transformed over the past decade?",
                    "sampleAnswer": "I have gravitated from a naive reductionist mindset towards embracing systemic multidimensional complexity. I now perceive global dilemmas not as isolated technical glitches, but as intricate ecological, moral, and cultural symbioses.",
                    "translation": "Tôi đã chuyển từ lối tư duy giản lược ngây thơ sang việc đón nhận sự phức tạp đa chiều mang tính hệ thống. Giờ đây tôi nhìn nhận các vấn đề toàn cầu không phải là các lỗi kỹ thuật cô lập, mà là sự cộng sinh phức tạp giữa sinh thái, đạo đức và văn hóa.",
                    "keyVocabulary": ["naive reductionist mindset (tư duy giản lược ngây thơ)", "systemic complexity (sự phức tạp mang tính hệ thống)", "intricate symbioses (sự cộng sinh phức tạp)"],
                },
                {
                    "question": "Do you believe humanity possesses sufficient philosophical maturity to govern synthetic intelligence?",
                    "sampleAnswer": "That constitutes the seminal question of our epoch. While our technological velocity is breathtaking, our ethical governance mechanisms remain regrettably fragmented. Establishing binding multilateral oversight is the ultimate civilizational litmus test.",
                    "translation": "Đó là câu hỏi mang tính then chốt của thời đại chúng ta. Trong khi tốc độ công nghệ của chúng ta đáng kinh ngạc, các cơ chế quản trị đạo đức vẫn đáng tiếc bị phân mảnh. Việc thiết lập sự giám sát đa phương mang tính ràng buộc là bài kiểm tra bản lĩnh văn minh tối thượng.",
                    "keyVocabulary": ["seminal question of our epoch (câu hỏi then chốt của thời đại)", "technological velocity (tốc độ công nghệ)", "civilizational litmus test (bài kiểm tra bản lĩnh văn minh)"],
                },
            ],
            "part2CueCardPrompt": "Deliver an impromptu 2-minute academic discourse on how humanity should maintain its moral compass in an algorithmic civilization.",
            "part2BulletPoints": [
                "What moral challenges algorithmic governance introduces",
                "Why purely computational logic is insufficient for ethical dilemmas",
                "How philosophical humanities education must be revived",
                "And synthesize your vision for a symbiotic human-centric future.",
            ],
            "part2SampleAnswer": "Standing at the threshold of synthetic superintelligence, humanity faces an existential imperative: we must preserve human empathy and philosophical discernment as our immutable moral compass. Algorithms optimize purely for mathematical utility, but utility must never be conflated with justice. We must revitalize classical humanities, cultivate ethical deliberation in engineering curricula, and insist that technology remains an instrument of universal human flourishing rather than an autonomous master.",
            "part2SampleTranslation": "Đứng trước ngưỡng cửa của siêu trí tuệ nhân tạo, nhân loại đối mặt với một mệnh lệnh sống còn: chúng ta phải bảo tồn sự đồng cảm và sự thấu suốt triết học như một la bàn đạo đức bất biến. Các thuật toán tối ưu hóa hoàn toàn cho tiện ích toán học, nhưng tiện ích không bao giờ được đồng nhất với công lý. Chúng ta phải hồi sinh các ngành khoa học nhân văn cổ điển, bồi dưỡng sự thảo luận đạo đức trong giáo trình kỹ thuật và kiên quyết rằng công nghệ phải là công cụ phục vụ sự hưng thịnh toàn cầu của con người chứ không phải là một ông chủ tự trị.",
            "part2Collocations": [
                "threshold of superintelligence (ngưỡng cửa siêu trí tuệ)",
                "existential imperative (mệnh lệnh sống còn)",
                "immutable moral compass (la bàn đạo đức bất biến)",
                "universal human flourishing (sự hưng thịnh toàn cầu của con người)",
            ],
        },
    },
]


# ─────────────────────────────────────────────────────────────
# 2. SEED VÀ TRUY VẤN BÀI HỌC
# ─────────────────────────────────────────────────────────────

def seed_default_skill_lessons(db: Session):
    """Nạp kho bài tập 4 kỹ năng chuẩn IELTS vào Database (20 ải toàn diện)."""
    logger.info("Đang kiểm tra và đồng bộ kho 20 ải bài học 4 kỹ năng IELTS vào Database...")
    for item in SAMPLE_SKILL_LESSONS:
        existing = db.query(SkillLesson).filter(SkillLesson.id == item["id"]).first()
        raw_band = item.get("band_score_target", "7.0")
        try:
            target_band = float(str(raw_band).replace("+", ""))
        except Exception:
            target_band = 7.0
        
        pass_req = item.get("pass_score_required", 2)
        skill_type = item["skill_type"]
        if skill_type in ["reading", "listening"]:
            pass_condition = {"min_correct": pass_req}
        elif skill_type == "writing":
            pass_condition = {"min_words": 150, "min_band": 6.0}
        else:
            pass_condition = {"min_band": 6.0}

        if not existing:
            lesson = SkillLesson(
                id=item["id"],
                skill_type=item["skill_type"],
                title=item["title"],
                category_or_topic=item.get("category_or_topic"),
                band_score_target=str(raw_band),
                stage_number=item.get("stage_number"),
                difficulty_label=item.get("difficulty_label"),
                pass_score_required=pass_req,
                target_band=target_band,
                pass_condition=pass_condition,
                content_json=item["content_json"],
            )
            db.add(lesson)
        else:
            # Cập nhật thông tin mới nhất nếu có thay đổi
            existing.stage_number = item.get("stage_number")
            existing.difficulty_label = item.get("difficulty_label")
            existing.pass_score_required = pass_req
            existing.band_score_target = str(raw_band)
            existing.target_band = target_band
            if not existing.pass_condition:
                existing.pass_condition = pass_condition
            existing.category_or_topic = item.get("category_or_topic")
            existing.content_json = item["content_json"]
    db.commit()
    logger.info(f"Đã đồng bộ thành công {len(SAMPLE_SKILL_LESSONS)} bài học 4 kỹ năng!")


def get_lessons_by_skill(db: Session, skill_type: str) -> List[SkillLesson]:
    """Lấy danh sách bài học theo kỹ năng (reading, listening, speaking, writing) theo thứ tự ải."""
    norm = skill_type.strip().lower()
    return db.query(SkillLesson).filter(SkillLesson.skill_type == norm).order_by(SkillLesson.stage_number.asc(), SkillLesson.id.asc()).all()


def get_lesson_by_id(db: Session, lesson_id: str) -> Optional[SkillLesson]:
    """Lấy chi tiết một bài học theo ID."""
    return db.query(SkillLesson).filter(SkillLesson.id == lesson_id).first()


def create_skill_lesson(db: Session, req: SkillLessonCreateRequest) -> SkillLesson:
    """Tạo mới một bài học / ải cho kỹ năng bất kỳ."""
    norm_skill = req.skill_type.strip().lower()
    lesson_id = req.id
    if not lesson_id or not lesson_id.strip():
        prefix = norm_skill[0]
        timestamp = int(datetime.utcnow().timestamp())
        lesson_id = f"{prefix}{req.stage_number}_{timestamp}"
    
    existing = db.query(SkillLesson).filter(SkillLesson.id == lesson_id).first()
    if existing:
        raise ValueError(f"Bài học với ID '{lesson_id}' đã tồn tại trong hệ thống!")

    target_band = req.target_band or float(str(req.band_score_target or "7.0").replace("+", ""))
    pass_cond = req.pass_condition or {}
    pass_score = req.pass_score_required
    if not pass_cond and pass_score:
        pass_cond = {"min_correct": pass_score}

    new_lesson = SkillLesson(
        id=lesson_id,
        skill_type=norm_skill,
        title=req.title,
        category_or_topic=req.category_or_topic,
        band_score_target=req.band_score_target or str(target_band),
        stage_number=req.stage_number,
        difficulty_label=req.difficulty_label or f"Ải {req.stage_number}",
        pass_score_required=pass_score or pass_cond.get("min_correct"),
        target_band=target_band,
        pass_condition=pass_cond,
        content_json=req.content_json,
    )
    db.add(new_lesson)
    db.commit()
    db.refresh(new_lesson)
    return new_lesson


def update_skill_lesson(db: Session, lesson_id: str, req: SkillLessonUpdateRequest) -> Optional[SkillLesson]:
    """Cập nhật bài học / ải hiện có."""
    lesson = db.query(SkillLesson).filter(SkillLesson.id == lesson_id).first()
    if not lesson:
        return None

    if req.title is not None:
        lesson.title = req.title
    if req.category_or_topic is not None:
        lesson.category_or_topic = req.category_or_topic
    if req.stage_number is not None:
        lesson.stage_number = req.stage_number
    if req.difficulty_label is not None:
        lesson.difficulty_label = req.difficulty_label
    if req.target_band is not None:
        lesson.target_band = req.target_band
        lesson.band_score_target = str(req.target_band)
    elif req.band_score_target is not None:
        lesson.band_score_target = req.band_score_target
        try:
            lesson.target_band = float(str(req.band_score_target).replace("+", ""))
        except Exception:
            pass
    if req.pass_score_required is not None:
        lesson.pass_score_required = req.pass_score_required
    if req.pass_condition is not None:
        lesson.pass_condition = req.pass_condition
        if "min_correct" in req.pass_condition:
            lesson.pass_score_required = req.pass_condition["min_correct"]
    if req.content_json is not None:
        lesson.content_json = req.content_json

    db.commit()
    db.refresh(lesson)
    return lesson


def delete_skill_lesson(db: Session, lesson_id: str) -> bool:
    """Xóa bài học khỏi hệ thống."""
    lesson = db.query(SkillLesson).filter(SkillLesson.id == lesson_id).first()
    if not lesson:
        return False
    db.delete(lesson)
    db.commit()
    return True


def import_skill_lessons_from_data(
    db: Session,
    items: List[Dict[str, Any]],
    default_skill_type: Optional[str] = None,
) -> Dict[str, Any]:
    """Import hàng loạt đề thi từ JSON hoặc dữ liệu Excel đã parse."""
    imported_count = 0
    errors = []
    fallback_skill = (default_skill_type or "reading").strip().lower()
    
    for idx, item in enumerate(items):
        try:
            skill_type = str(item.get("skill_type") or fallback_skill).strip().lower()
            if skill_type not in ["reading", "listening", "speaking", "writing"]:
                errors.append(f"Mục {idx+1}: Kỹ năng '{skill_type}' không hợp lệ.")
                continue

            stage_number = int(item.get("stage_number", 1))
            title = str(item.get("title", f"Bài học Ải {stage_number}")).strip()
            lesson_id = item.get("id") or f"{skill_type[0]}{stage_number}_{int(datetime.utcnow().timestamp())}_{idx}"
            
            raw_target_band = item.get("target_band", item.get("band_score_target", 7.0))
            try:
                target_band = float(str(raw_target_band).replace("+", ""))
            except Exception:
                target_band = 7.0
                
            pass_cond = item.get("pass_condition") or {}
            pass_score = item.get("pass_score_required")
            if not pass_cond and pass_score:
                pass_cond = {"min_correct": pass_score}

            content_json = item.get("content_json")
            if not content_json or not isinstance(content_json, dict):
                content_json = {}
                for k, v in item.items():
                    if k not in [
                        "id", "skill_type", "title", "category_or_topic",
                        "stage_number", "difficulty_label", "target_band",
                        "band_score_target", "pass_score_required", "pass_condition"
                    ]:
                        content_json[k] = v

            existing = db.query(SkillLesson).filter(SkillLesson.id == lesson_id).first()
            if existing:
                existing.title = title
                existing.skill_type = skill_type
                existing.stage_number = stage_number
                existing.category_or_topic = item.get("category_or_topic")
                existing.difficulty_label = item.get("difficulty_label") or f"Ải {stage_number}"
                existing.target_band = target_band
                existing.band_score_target = str(target_band)
                existing.pass_condition = pass_cond
                existing.pass_score_required = pass_score or pass_cond.get("min_correct", 2)
                existing.content_json = content_json
            else:
                new_lesson = SkillLesson(
                    id=lesson_id,
                    skill_type=skill_type,
                    title=title,
                    category_or_topic=item.get("category_or_topic"),
                    band_score_target=str(target_band),
                    stage_number=stage_number,
                    difficulty_label=item.get("difficulty_label") or f"Ải {stage_number}",
                    pass_score_required=pass_score or pass_cond.get("min_correct", 2),
                    target_band=target_band,
                    pass_condition=pass_cond,
                    content_json=content_json,
                )
                db.add(new_lesson)
            imported_count += 1
        except Exception as e:
            errors.append(f"Mục {idx+1}: {str(e)}")

    db.commit()
    return {
        "success": imported_count > 0,
        "imported_count": imported_count,
        "message": f"Đã nhập thành công {imported_count} đề thi/ải bài học!",
        "errors": errors if errors else None,
    }


def get_skill_template_data(skill_type: Optional[str] = None) -> List[Dict[str, Any]]:
    """Trả về dữ liệu mẫu chuẩn (Template) cho khách hàng tham khảo và điền đề thi."""
    templates = {
        "reading": [
            {
                "skill_type": "reading",
                "stage_number": 1,
                "difficulty_label": "Ải 1: Cơ bản (Band 6.0)",
                "title": "Bài đọc mẫu: Công nghệ & Môi trường",
                "category_or_topic": "Technology & Environment",
                "target_band": 6.5,
                "band_score_target": "6.5",
                "pass_condition": {"min_correct": 2},
                "pass_score_required": 2,
                "content_json": {
                    "paragraphs": {
                        "A": "Nội dung đoạn văn A bài đọc học thuật IELTS...",
                        "B": "Nội dung đoạn văn B bài đọc học thuật IELTS..."
                    },
                    "questions": [
                        {
                            "id": 1,
                            "questionText": "Nội dung câu hỏi trắc nghiệm số 1?",
                            "options": ["Đáp án A", "Đáp án B", "Đáp án C", "Đáp án D"],
                            "correctAnswer": "Đáp án B",
                            "explanation": "Giải thích chi tiết vì sao đáp án B đúng.",
                            "paragraphRef": "Đoạn A"
                        },
                        {
                            "id": 2,
                            "questionText": "Nội dung câu hỏi trắc nghiệm số 2?",
                            "options": ["Lựa chọn 1", "Lựa chọn 2", "Lựa chọn 3", "Lựa chọn 4"],
                            "correctAnswer": "Lựa chọn 1",
                            "explanation": "Giải thích câu 2",
                            "paragraphRef": "Đoạn B"
                        }
                    ]
                }
            }
        ],
        "listening": [
            {
                "skill_type": "listening",
                "stage_number": 1,
                "difficulty_label": "Ải 1: Nhập môn (Band 6.0)",
                "title": "Bài nghe mẫu: Sinh viên Quốc tế",
                "category_or_topic": "Campus Life",
                "target_band": 6.0,
                "band_score_target": "6.0",
                "pass_condition": {"min_correct": 2},
                "pass_score_required": 2,
                "content_json": {
                    "audioScript": "Kịch bản bài nghe hội thoại (hoặc link mp3)...",
                    "questions": [
                        {
                            "id": 1,
                            "questionText": "Người nói thứ nhất đang làm gì?",
                            "options": ["Đăng ký môn học", "Tìm phòng trọ", "Hỏi đường", "Mua sách"],
                            "correctAnswer": "Đăng ký môn học",
                            "explanation": "Dựa vào kịch bản đoạn đầu..."
                        }
                    ]
                }
            }
        ],
        "writing": [
            {
                "skill_type": "writing",
                "stage_number": 1,
                "difficulty_label": "Ải 1: Task 2 Cơ bản",
                "title": "Luyện viết Task 2: Remote Working",
                "category_or_topic": "Work & Society",
                "target_band": 7.0,
                "band_score_target": "7.0",
                "pass_condition": {"min_words": 150, "min_band": 6.0},
                "content_json": {
                    "taskType": "Task 2",
                    "prompt": "Some people believe that remote working brings more benefits than drawbacks. Discuss both views and give your opinion.",
                    "minWordCount": 250,
                    "suggestedTimeMinutes": 40,
                    "keyOutline": ["Introduction & Thesis statement", "Body 1: Advantages of remote work", "Body 2: Drawbacks & isolation", "Conclusion"],
                    "sampleEssay": "In recent years, remote employment has transformed...",
                    "sampleTranslation": "Trong những năm gần đây, làm việc từ xa đã thay đổi...",
                    "academicVocabulary": ["telecommuting", "work-life balance", "productivity enhancement", "social isolation"]
                }
            }
        ],
        "speaking": [
            {
                "skill_type": "speaking",
                "stage_number": 1,
                "difficulty_label": "Ải 1: Part 1 Giới thiệu",
                "title": "Luyện nói Speaking: Quê hương & Sở thích",
                "category_or_topic": "Hometown & Hobbies",
                "target_band": 6.5,
                "band_score_target": "6.5",
                "pass_condition": {"min_band": 6.0},
                "content_json": {
                    "part1Questions": [
                        {
                            "question": "Where is your hometown located?",
                            "sampleAnswer": "My hometown is situated in the central region of Vietnam...",
                            "translation": "Quê tôi nằm ở miền Trung Việt Nam...",
                            "keyVocabulary": ["situated", "coastal city", "picturesque scenery"]
                        }
                    ],
                    "part2CueCardPrompt": "Describe a place in your hometown that you love to visit.",
                    "part2BulletPoints": ["Where it is", "How often you go there", "What you do there", "Explain why you like it"],
                    "part2SampleAnswer": "One of my absolute favorite spots is...",
                    "part2SampleTranslation": "Một trong những địa điểm yêu thích nhất của tôi là...",
                    "part2Collocations": ["bustling atmosphere", "escape the hustle and bustle"]
                }
            }
        ]
    }
    
    if skill_type and skill_type.lower() in templates:
        return templates[skill_type.lower()]
    
    # Return all templates combined
    res = []
    for k, v in templates.items():
        res.extend(v)
    return res


# ─────────────────────────────────────────────────────────────
# 3. CHẤM ĐIỂM (GRADING ENGINES) CHO CẢ 4 KỸ NĂNG VƯỢT ẢI
# ─────────────────────────────────────────────────────────────

def grade_reading(lesson: SkillLesson, user_answers: Dict[str, str]) -> Dict[str, Any]:
    """Chấm điểm bài đọc IELTS Reading theo cơ chế Vượt ải."""
    questions = lesson.content_json.get("questions", [])
    total = len(questions)
    pass_cond = lesson.pass_condition if isinstance(lesson.pass_condition, dict) else {}
    pass_req = int(pass_cond.get("min_correct") or lesson.pass_score_required or max(1, total - 1))
    score = 0
    question_results = []

    for q in questions:
        q_id = str(q.get("id"))
        user_choice = user_answers.get(q_id) or user_answers.get(int(q_id) if q_id.isdigit() else q_id)
        is_correct = (user_choice == q.get("correctAnswer"))
        if is_correct:
            score += 1

        question_results.append({
            "question_id": q.get("id"),
            "user_choice": user_choice,
            "correct_answer": q.get("correctAnswer"),
            "is_correct": is_correct,
            "explanation": q.get("explanation"),
            "paragraph_ref": q.get("paragraphRef"),
        })

    passed = score >= pass_req
    stars = 3 if (total > 0 and score == total) else (2 if passed else (1 if score > 0 else 0))

    if total > 0 and score == total:
        band = lesson.band_score_target
    elif passed:
        band = str(max(5.5, float(lesson.band_score_target.replace("+", "")) - 0.5))
    else:
        band = "5.5"

    feedback = f"🎉 Chúc mừng bạn đã vượt qua {lesson.difficulty_label or 'ải Reading'}!" if passed else f"Cần đúng ít nhất {pass_req}/{total} câu để vượt ải này. Hãy cố gắng luyện tập lại!"

    return {
        "score": score,
        "total_questions": total,
        "band_score": band,
        "passed": passed,
        "stars": stars,
        "question_results": question_results,
        "feedback": feedback,
    }


def grade_listening(lesson: SkillLesson, user_answers: Dict[str, str]) -> Dict[str, Any]:
    """Chấm điểm bài nghe IELTS Listening theo cơ chế Vượt ải."""
    questions = lesson.content_json.get("questions", [])
    total = len(questions)
    pass_cond = lesson.pass_condition if isinstance(lesson.pass_condition, dict) else {}
    pass_req = int(pass_cond.get("min_correct") or lesson.pass_score_required or 2)
    score = 0
    question_results = []

    for q in questions:
        q_id = str(q.get("id"))
        user_choice = user_answers.get(q_id) or user_answers.get(int(q_id) if q_id.isdigit() else q_id)
        is_correct = (user_choice == q.get("correctAnswer"))
        if is_correct:
            score += 1

        question_results.append({
            "question_id": q.get("id"),
            "user_choice": user_choice,
            "correct_answer": q.get("correctAnswer"),
            "is_correct": is_correct,
            "explanation": q.get("explanation"),
        })

    passed = score >= pass_req
    stars = 3 if (total > 0 and score == total) else (2 if passed else (1 if score > 0 else 0))

    if total > 0 and score == total:
        band = lesson.band_score_target
    elif passed:
        band = str(max(5.5, float(lesson.band_score_target.replace("+", "")) - 0.5))
    else:
        band = "5.5"

    feedback = f"🎉 Chúc mừng bạn đã vượt qua {lesson.difficulty_label or 'ải Listening'}!" if passed else f"Cần đúng ít nhất {pass_req}/{total} câu để vượt ải này. Hãy cố gắng luyện tập lại!"

    return {
        "score": score,
        "total_questions": total,
        "band_score": band,
        "passed": passed,
        "stars": stars,
        "question_results": question_results,
        "feedback": feedback,
    }


def grade_writing(lesson: SkillLesson, essay_text: str) -> Dict[str, Any]:
    """Chấm điểm bài viết IELTS Writing tự động theo cơ chế Vượt ải."""
    words = len(essay_text.strip().split()) if essay_text else 0
    pass_cond = lesson.pass_condition if isinstance(lesson.pass_condition, dict) else {}
    min_words = int(pass_cond.get("min_words") or lesson.content_json.get("minWordCount", 150))
    academic_vocab = lesson.content_json.get("academicVocabulary", [])

    if words < 25:
        raise ValueError("Bài viết quá ngắn (dưới 25 từ), vui lòng hoàn thiện thêm trước khi nộp bài!")

    # Đếm từ học thuật xuất hiện
    text_lower = essay_text.lower()
    matched_vocab = []
    for v in academic_vocab:
        clean = v.split("(")[0].strip().lower()
        if clean and clean in text_lower:
            matched_vocab.append(clean)

    bonus = len(matched_vocab)

    target_band_num = float(lesson.band_score_target.replace("+", ""))
    pass_band_req = float(pass_cond.get("min_band") or lesson.pass_score_required or 6.0)

    # Thuật toán tính band score
    if words < min_words * 0.7:
        band_num = 5.5
    elif words < min_words:
        band_num = 6.0
    elif bonus >= 3:
        band_num = min(target_band_num, 8.5)
    elif bonus >= 1:
        band_num = max(6.5, target_band_num - 0.5)
    else:
        band_num = max(6.0, target_band_num - 1.0)

    band = f"{band_num:0.1f}" if band_num < 8.5 else "8.5+"
    passed = words >= min_words and band_num >= pass_band_req

    if band_num >= target_band_num and words >= min_words:
        stars = 3
    elif passed:
        stars = 2
    else:
        stars = 1 if words >= min_words * 0.7 else 0

    feedback = f"Độ dài: {words} từ (Yêu cầu: {min_words} từ). Sử dụng {bonus} cụm từ học thuật chuẩn IELTS ({', '.join(matched_vocab) if matched_vocab else 'chưa có'}). Ước tính Band: {band}"
    if passed:
        feedback = f"🎉 Vượt ải thành công! {feedback}"
    else:
        feedback = f"Chưa đủ điều kiện qua ải (Cần >= {min_words} từ và Band >= {pass_band_req}). {feedback}"

    return {
        "score": words,
        "total_questions": min_words,
        "band_score": band,
        "passed": passed,
        "stars": stars,
        "feedback": feedback,
    }


def grade_speaking(lesson: SkillLesson, ratings: Dict[str, int]) -> Dict[str, Any]:
    """Ghi nhận và tính Band điểm hoàn thành bài nói IELTS Speaking theo cơ chế Vượt ải."""
    fluency = ratings.get("fluency", 7)
    vocab = ratings.get("vocabulary", 7)
    pron = ratings.get("pronunciation", 7)

    avg = (fluency + vocab + pron) / 3.0
    band = str(round(avg, 1))

    pass_cond = lesson.pass_condition if isinstance(lesson.pass_condition, dict) else {}
    target_band_num = float(lesson.band_score_target.replace("+", ""))
    pass_band_req = float(pass_cond.get("min_band") or lesson.pass_score_required or 6.0)

    passed = avg >= pass_band_req

    if avg >= target_band_num:
        stars = 3
    elif passed:
        stars = 2
    else:
        stars = 1 if avg >= 5.0 else 0

    feedback = f"Hoàn thành bài luyện nói Speaking! Điểm Fluency: {fluency}, Vocab: {vocab}, Pronunciation: {pron}. Band trung bình: {band}"
    if passed:
        feedback = f"🎉 Vượt ải thành công! {feedback}"
    else:
        feedback = f"Chưa đạt yêu cầu qua ải (Cần Band >= {pass_band_req}). {feedback}"

    return {
        "score": int(avg * 3),
        "total_questions": 30,
        "band_score": band,
        "passed": passed,
        "stars": stars,
        "feedback": feedback,
    }


# ─────────────────────────────────────────────────────────────
# 4. LƯU LỊCH SỬ THI VÀ TIẾN ĐỘ VƯỢT ẢI (CHO CẢ 4 KỸ NĂNG)
# ─────────────────────────────────────────────────────────────

def submit_lesson(
    db: Session,
    user: User,
    req: SkillSubmissionRequest,
    sync_supabase: bool = True,
) -> SkillSubmissionResponse:
    """Xử lý nộp bài, chấm điểm, lưu lịch sử và cập nhật tiến độ vượt ải cho cả 4 kỹ năng."""
    lesson = get_lesson_by_id(db, req.lesson_id)
    if not lesson:
        raise ValueError(f"Không tìm thấy bài học có ID '{req.lesson_id}'")

    # 1. Chấm điểm theo kỹ năng
    if req.skill_type == "reading":
        result = grade_reading(lesson, req.answers or {})
    elif req.skill_type == "listening":
        result = grade_listening(lesson, req.answers or {})
    elif req.skill_type == "writing":
        result = grade_writing(lesson, req.essay_text or "")
    elif req.skill_type == "speaking":
        result = grade_speaking(lesson, req.ratings or {})
    else:
        raise ValueError(f"Kỹ năng '{req.skill_type}' không được hỗ trợ")

    # 2. Lưu vào bảng practice_history cục bộ
    history_entry = PracticeHistory(
        user_id=user.id,
        skill_type=req.skill_type,
        lesson_id=lesson.id,
        lesson_title=lesson.title,
        score=result["score"],
        total_questions=result["total_questions"],
        band_score=result["band_score"],
    )
    db.add(history_entry)

    # 3. Cập nhật tiến độ Vượt ải (Gamified Stages) cho KỸ NĂNG BẤT KỲ nếu bài có stage_number
    if lesson.stage_number:
        current_stage = lesson.stage_number
        progress = (
            db.query(UserStageProgress)
            .filter(
                UserStageProgress.user_id == user.id,
                UserStageProgress.skill_type == req.skill_type,
                UserStageProgress.stage_number == current_stage,
            )
            .first()
        )

        if not progress:
            progress = UserStageProgress(
                user_id=user.id,
                skill_type=req.skill_type,
                stage_number=current_stage,
                stars=result["stars"],
                best_score=result["score"],
                is_unlocked=True,
            )
            db.add(progress)
        else:
            if result["stars"] > progress.stars:
                progress.stars = result["stars"]
            if result["score"] > progress.best_score:
                progress.best_score = result["score"]

        # Nếu vượt ải thành công, tự động mở khóa ải tiếp theo (không giới hạn 5)!
        max_stage = (
            db.query(func.max(SkillLesson.stage_number))
            .filter(SkillLesson.skill_type == req.skill_type)
            .scalar()
            or 5
        )
        if result["passed"] and current_stage < max_stage:
            next_stage = current_stage + 1
            next_progress = (
                db.query(UserStageProgress)
                .filter(
                    UserStageProgress.user_id == user.id,
                    UserStageProgress.skill_type == req.skill_type,
                    UserStageProgress.stage_number == next_stage,
                )
                .first()
            )
            if not next_progress:
                next_progress = UserStageProgress(
                    user_id=user.id,
                    skill_type=req.skill_type,
                    stage_number=next_stage,
                    stars=0,
                    best_score=0,
                    is_unlocked=True,
                )
                db.add(next_progress)
            else:
                next_progress.is_unlocked = True

    db.commit()

    # 4. Đồng bộ kết quả lên Supabase bảng practice_history
    if sync_supabase:
        try:
            supabase = get_supabase_admin()
            target_user_id = user.supabase_uuid

            if not target_user_id:
                prof = supabase.from_("profiles").select("id").eq("username", user.username).maybe_single().execute()
                if prof.data:
                    target_user_id = prof.data.get("id")
                    user.supabase_uuid = target_user_id
                    db.commit()

            if target_user_id:
                supabase.table("practice_history").insert({
                    "user_id": target_user_id,
                    "skill_type": req.skill_type,
                    "lesson_id": lesson.id,
                    "lesson_title": lesson.title,
                    "score": result["score"],
                    "total_questions": result["total_questions"],
                    "band_score": result["band_score"],
                }).execute()
                logger.info(f"Đã sync kết quả {req.skill_type} ({result['band_score']}) lên Supabase practice_history!")
        except Exception as e:
            logger.warning(f"Lỗi khi sync practice_history lên Supabase: {e}")

    return SkillSubmissionResponse(
        lesson_id=lesson.id,
        skill_type=req.skill_type,
        score=result["score"],
        total_questions=result["total_questions"],
        band_score=result["band_score"],
        passed=result["passed"],
        stars=result["stars"],
        feedback=result["feedback"],
        question_results=result.get("question_results"),
    )


def get_user_practice_history(
    db: Session,
    user_id: int,
    skill_type: Optional[str] = None,
) -> List[PracticeHistory]:
    """Lấy lịch sử làm bài thi của học viên."""
    q = db.query(PracticeHistory).filter(PracticeHistory.user_id == user_id)
    if skill_type:
        q = q.filter(PracticeHistory.skill_type == skill_type.strip().lower())
    return q.order_by(PracticeHistory.created_at.desc()).all()


def get_user_skill_progress(db: Session, user_id: int, skill_type: str = "listening") -> ListeningProgressResponse:
    """Lấy thông tin tiến độ các ải của học viên cho bất kỳ kỹ năng nào (reading, listening, writing, speaking)."""
    norm_skill = skill_type.strip().lower()
    progress_map: Dict[int, UserStageProgress] = {
        p.stage_number: p for p in db.query(UserStageProgress).filter(
            UserStageProgress.user_id == user_id,
            UserStageProgress.skill_type == norm_skill
        ).all()
    }

    # Tính tổng số ải khả dụng cho kỹ năng này (tối thiểu 5)
    max_stage = (
        db.query(func.max(SkillLesson.stage_number))
        .filter(SkillLesson.skill_type == norm_skill)
        .scalar()
        or 5
    )
    max_user_stage = max(progress_map.keys(), default=1)
    total_stages = max(5, max_stage, max_user_stage)

    highest = 1
    stages: List[StageItemProgress] = []

    for s in range(1, total_stages + 1):
        prog = progress_map.get(s)
        unlocked = (s == 1) or (prog.is_unlocked if prog else False)
        stars = prog.stars if prog else 0
        best_score = prog.best_score if prog else 0

        if unlocked and s > highest:
            highest = s

        stages.append(
            StageItemProgress(
                stage_number=s,
                stars=stars,
                best_score=best_score,
                is_unlocked=unlocked,
            )
        )

    return ListeningProgressResponse(
        highest_unlocked_stage=highest,
        stages=stages,
    )



def get_user_listening_progress(db: Session, user_id: int) -> ListeningProgressResponse:
    """Hàm wrapper tương thích ngược cho Listening."""
    return get_user_skill_progress(db, user_id, "listening")
