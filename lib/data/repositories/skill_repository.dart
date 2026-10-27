import '../models/skill_models.dart';

/// Kho dữ liệu bài tập chuẩn học thuật cho 4 kỹ năng IELTS (5 Ải Vượt cấp cho mỗi kỹ năng).
class SkillRepository {
  // ═════════════════════════════════════════════════════════════
  // ── 1. READING (5 ẢI VƯỢT CẤP) ──
  // ═════════════════════════════════════════════════════════════
  static final List<ReadingPassageModel> sampleReadingPassages = [
    ReadingPassageModel(
      id: 'r1',
      stageNumber: 1,
      difficultyLabel: 'Ải 1: Cơ bản (Band 6.0)',
      title: 'Artificial Intelligence in Modern Education',
      category: 'Technology & Education',
      bandScoreTarget: '6.5',
      passScoreRequired: 2,
      paragraphs: {
        'A': 'Artificial Intelligence (AI) is rapidly altering the landscape of modern education. By leveraging advanced machine learning algorithms, educational platforms can tailor learning materials to match the individual pacing and cognitive strengths of each student. This adaptive learning technology ensures that learners absorb complex academic concepts efficiently without feeling overwhelmed.',
        'B': 'Furthermore, smart computer vision systems enable mobile applications to recognize real-world objects instantaneously. When a student points a smartphone camera at an everyday item, AI models analyze the visual features and map them to specialized IELTS academic vocabulary, collocations, and contextual Speaking samples.',
        'C': 'Critics argue that over-reliance on artificial intelligence might diminish human interaction and critical thinking skills. However, educators emphasize that AI tools are designed to augment traditional pedagogy rather than replace teachers. Educators can focus on mentorship and emotional support while AI handles automated vocabulary drills and performance analytics.',
      },
      questions: [
        ReadingQuestion(
          id: 1,
          questionText: 'What primary benefit of AI in education is highlighted in Paragraph A?',
          options: [
            'Replacing human teachers completely',
            'Tailoring learning materials to individual student pacing',
            'Reducing tuition fees significantly',
            'Eliminating all academic examinations'
          ],
          correctAnswer: 'Tailoring learning materials to individual student pacing',
          explanation: 'Paragraph A explicitly states: "By leveraging advanced machine learning algorithms, educational platforms can tailor learning materials to match the individual pacing... of each student."',
          paragraphRef: 'Đoạn A',
        ),
        ReadingQuestion(
          id: 2,
          questionText: 'How does computer vision enhance vocabulary learning according to Paragraph B?',
          options: [
            'By writing essay assignments automatically',
            'By mapping camera-scanned objects to academic vocabulary',
            'By generating fake images for testing',
            'By translating entire textbooks into audio files'
          ],
          correctAnswer: 'By mapping camera-scanned objects to academic vocabulary',
          explanation: 'Paragraph B mentions: "When a student points a smartphone camera... AI models analyze visual features and map them to specialized IELTS academic vocabulary."',
          paragraphRef: 'Đoạn B',
        ),
        ReadingQuestion(
          id: 3,
          questionText: 'What view do educators hold regarding AI tools in Paragraph C?',
          options: [
            'AI tools should completely replace traditional schools',
            'AI tools augment pedagogy rather than replace human teachers',
            'AI tools are detrimental to student progress',
            'AI tools are too expensive to implement'
          ],
          correctAnswer: 'AI tools augment pedagogy rather than replace human teachers',
          explanation: 'Paragraph C states: "educators emphasize that AI tools are designed to augment traditional pedagogy rather than replace teachers."',
          paragraphRef: 'Đoạn C',
        ),
      ],
    ),
    ReadingPassageModel(
      id: 'r2',
      stageNumber: 2,
      difficultyLabel: 'Ải 2: Trung cấp (Band 7.0)',
      title: 'Climate Change and Biodiversity Conservation',
      category: 'Environment & Biology',
      bandScoreTarget: '7.0',
      passScoreRequired: 2,
      paragraphs: {
        'A': 'Global climate shifts pose unprecedented threats to ecosystem stability. Rising surface temperatures accelerate natural habitat degradation, forcing species to adapt rapidly or face extinction. Conservationists are implementing innovative ecological monitoring strategies to preserve fragile biomes.',
        'B': 'Preserving biological diversity requires international cooperation and sustainable environmental policies. Urban green spaces and reforestation projects mitigate carbon dioxide emissions while providing vital sanctuaries for native wildlife species.',
        'C': 'Community-based conservation initiatives have shown remarkable promise in developing nations. By incentivizing local populations through eco-tourism revenue and agroforestry programs, governments can align economic survival with wildlife protection.',
      },
      questions: [
        ReadingQuestion(
          id: 1,
          questionText: 'What primary challenge to ecosystems is described in Paragraph A?',
          options: [
            'Overpopulation in urban areas',
            'Habitat degradation caused by rising temperatures',
            'Lack of international tourism',
            'Excessive industrial recycling'
          ],
          correctAnswer: 'Habitat degradation caused by rising temperatures',
          explanation: 'Paragraph A highlights that rising surface temperatures accelerate habitat degradation.',
          paragraphRef: 'Đoạn A',
        ),
        ReadingQuestion(
          id: 2,
          questionText: 'What dual advantage of urban green spaces is mentioned in Paragraph B?',
          options: [
            'Reducing city taxes and increasing car traffic',
            'Mitigating carbon emissions and providing wildlife sanctuaries',
            'Supplying timber for construction and boosting electricity',
            'Eliminating the need for national parks'
          ],
          correctAnswer: 'Mitigating carbon emissions and providing wildlife sanctuaries',
          explanation: 'Paragraph B explains that urban green spaces mitigate carbon emissions while providing sanctuaries for wildlife.',
          paragraphRef: 'Đoạn B',
        ),
        ReadingQuestion(
          id: 3,
          questionText: 'According to Paragraph C, how can governments foster local conservation?',
          options: [
            'By banning all agricultural activities',
            'By offering eco-tourism revenue and agroforestry incentives',
            'By relocating indigenous communities to urban centers',
            'By privatizing all national forests'
          ],
          correctAnswer: 'By offering eco-tourism revenue and agroforestry incentives',
          explanation: 'Paragraph C notes that incentivizing local populations through eco-tourism and agroforestry aligns economic needs with conservation.',
          paragraphRef: 'Đoạn C',
        ),
      ],
    ),
    ReadingPassageModel(
      id: 'r3',
      stageNumber: 3,
      difficultyLabel: 'Ải 3: Nâng cao (Band 7.5)',
      title: 'Urban Architecture & Sustainable Smart Cities',
      category: 'Urban Planning & Architecture',
      bandScoreTarget: '7.5',
      passScoreRequired: 2,
      paragraphs: {
        'A': 'Rapid urbanization has compelled contemporary civil engineers to rethink urban infrastructure. Modern skyscrapers now integrate vertical gardens, photothermal glass facades, and automated waste reclamation channels to reduce their overall ecological footprints.',
        'B': 'Smart energy grids powered by Internet-of-Things (IoT) sensors distribute municipal electricity dynamically based on real-time consumption patterns. This localized energy harvesting prevents power surges during peak hours and minimizes transmission dissipation.',
        'C': 'Nevertheless, critics caution that high-tech smart cities risk exacerbating socioeconomic stratification. When energy-efficient autonomous neighborhoods cater exclusively to affluent residents, lower-income communities remain exposed to degraded municipal infrastructure.',
      },
      questions: [
        ReadingQuestion(
          id: 1,
          questionText: 'Which technological integration in skyscrapers is noted in Paragraph A?',
          options: [
            'Coal furnaces and exterior neon billboards',
            'Vertical gardens and photothermal glass facades',
            'Underground nuclear micro-reactors',
            'Manual rainwater drainage buckets'
          ],
          correctAnswer: 'Vertical gardens and photothermal glass facades',
          explanation: 'Paragraph A states modern skyscrapers incorporate vertical gardens and photothermal glass facades.',
          paragraphRef: 'Đoạn A',
        ),
        ReadingQuestion(
          id: 2,
          questionText: 'How do IoT-enabled smart grids optimize energy distribution in Paragraph B?',
          options: [
            'By shutting down public streetlights at night',
            'By dynamically distributing power based on consumption patterns',
            'By tripling municipal electricity tariffs during weekends',
            'By storing excess electricity in lead-acid automotive batteries'
          ],
          correctAnswer: 'By dynamically distributing power based on consumption patterns',
          explanation: 'Paragraph B states smart grids distribute electricity dynamically based on real-time consumption patterns.',
          paragraphRef: 'Đoạn B',
        ),
        ReadingQuestion(
          id: 3,
          questionText: 'What socioeconomic risk of smart cities is warned about in Paragraph C?',
          options: [
            'Excessive immigration of rural farmers',
            'Exacerbating socioeconomic stratification between affluent and lower-income residents',
            'A complete collapse of municipal internet connectivity',
            'The total elimination of public healthcare centers'
          ],
          correctAnswer: 'Exacerbating socioeconomic stratification between affluent and lower-income residents',
          explanation: 'Paragraph C cautions that smart cities risk widening the gap if green tech only serves affluent residents.',
          paragraphRef: 'Đoạn C',
        ),
      ],
    ),
    ReadingPassageModel(
      id: 'r4',
      stageNumber: 4,
      difficultyLabel: 'Ải 4: Chuyên sâu (Band 8.0)',
      title: 'Global Economics, Automation & Future Labor Markets',
      category: 'Economics & Society',
      bandScoreTarget: '8.0',
      passScoreRequired: 2,
      paragraphs: {
        'A': 'The accelerating proliferation of robotic process automation and large language models is restructuring global employment paradigms. Routine analytical tasks in auditing, paralegal documentation, and commercial logistics are increasingly automated, causing structural friction in white-collar sectors.',
        'B': 'Historically, technological disruptions have displaced localized job categories while simultaneously generating novel occupational sectors. Economists predict that human-centric competencies, such as empathetic negotiation, complex cross-disciplinary synthesis, and ethical decision-making, will appreciate substantially in market value.',
        'C': 'To prevent widespread labor displacement, macroeconomic policymakers advocate lifelong reskilling subsidies and universal baseline digital literacy frameworks. Failure to proactively upskill the domestic workforce could result in protracted economic stagnation and rising income disparity.',
      },
      questions: [
        ReadingQuestion(
          id: 1,
          questionText: 'What sector is facing structural friction due to automation according to Paragraph A?',
          options: [
            'Manual agricultural harvesting',
            'White-collar sectors involving routine analytical tasks',
            'Traditional artisanal blacksmithing',
            'Deep-sea commercial fishing'
          ],
          correctAnswer: 'White-collar sectors involving routine analytical tasks',
          explanation: 'Paragraph A identifies structural friction in white-collar sectors such as auditing and paralegal documentation.',
          paragraphRef: 'Đoạn A',
        ),
        ReadingQuestion(
          id: 2,
          questionText: 'Which human skills are expected to gain market value in Paragraph B?',
          options: [
            'Rapid mechanical arithmetic and manual typing',
            'Empathetic negotiation, synthesis, and ethical decision-making',
            'Physical stamina and assembly line speed',
            'Memorization of legal encyclopedias'
          ],
          correctAnswer: 'Empathetic negotiation, synthesis, and ethical decision-making',
          explanation: 'Paragraph B outlines that human-centric competencies like empathetic negotiation and ethical decision-making will appreciate.',
          paragraphRef: 'Đoạn B',
        ),
        ReadingQuestion(
          id: 3,
          questionText: 'What policy recommendation is suggested in Paragraph C to mitigate unemployment?',
          options: [
            'Banning all robotic manufacturing machinery',
            'Lifelong reskilling subsidies and universal digital literacy',
            'Lowering mandatory retirement ages to thirty-five',
            'Eliminating international corporate income taxation'
          ],
          correctAnswer: 'Lifelong reskilling subsidies and universal digital literacy',
          explanation: 'Paragraph C advises policymakers to implement lifelong reskilling subsidies and digital literacy frameworks.',
          paragraphRef: 'Đoạn C',
        ),
      ],
    ),
    ReadingPassageModel(
      id: 'r5',
      stageNumber: 5,
      difficultyLabel: 'Ải 5: Bậc thầy (Band 8.5+ - Boss Stage)',
      title: 'Neuroscience, Cognitive Resilience & Machine Consciousness',
      category: 'Cognitive Science & Neuroscience',
      bandScoreTarget: '8.5+',
      passScoreRequired: 3,
      paragraphs: {
        'A': 'Neuroplasticity—the nervous system\'s intrinsic capacity to reorganize synaptic architecture in response to cognitive stimuli—has fundamentally overturned earlier deterministic assumptions regarding cerebral decline. Recent neuroimaging breakthroughs indicate that rigorous multilingual acquisition and musical training cultivate structural neuroprotective reserves against neurodegenerative pathologies.',
        'B': 'Simultaneously, cognitive neuroscientists and synthetic intelligence theoreticians are fiercely debating the ontological boundaries of machine consciousness. While deep neural networks emulate phenomenological pattern recognition with superhuman proficiency, they fundamentally lack subjective sentience, qualia, and intrinsic teleological intention.',
        'C': 'The synthesis of biological neural interfaces and neuromorphic computation may soon dissolve the dichotomy between organic cognition and synthetic computation. However, ethical philosophers caution that engineering semi-sentient bio-computational hybrid architectures without comprehensive moral consensus risks precipitating unprecedented existential dilemmas.',
      },
      questions: [
        ReadingQuestion(
          id: 1,
          questionText: 'How does Paragraph A define the fundamental nature of neuroplasticity?',
          options: [
            'The predetermined and irreversible deterioration of human brain cells',
            'The nervous system\'s intrinsic capacity to reorganize synaptic architecture',
            'The mechanical replacement of damaged neurons with silicon microchips',
            'The inherited genetic resistance to external psychological stress'
          ],
          correctAnswer: 'The nervous system\'s intrinsic capacity to reorganize synaptic architecture',
          explanation: 'Paragraph A defines neuroplasticity as the intrinsic capacity to reorganize synaptic architecture in response to cognitive stimuli.',
          paragraphRef: 'Đoạn A',
        ),
        ReadingQuestion(
          id: 2,
          questionText: 'What critical human cognitive attributes are deep neural networks cited as lacking in Paragraph B?',
          options: [
            'Algorithmic speed and statistical vector processing',
            'Subjective sentience, qualia, and intrinsic teleological intention',
            'Optical pattern recognition and data storage bandwidth',
            'Mathematical calculation and chess-playing capability'
          ],
          correctAnswer: 'Subjective sentience, qualia, and intrinsic teleological intention',
          explanation: 'Paragraph B emphasizes that synthetic networks lack subjective sentience, qualia, and intrinsic intention.',
          paragraphRef: 'Đoạn B',
        ),
        ReadingQuestion(
          id: 3,
          questionText: 'What profound warning is delivered by ethical philosophers in Paragraph C?',
          options: [
            'Neuromorphic computation will bankrupt global tech conglomerates',
            'Bio-computational hybrid architectures without moral consensus create existential dilemmas',
            'Organic neurons will rapidly overheat when exposed to fiber-optic cables',
            'Multilingual learning should be restricted to children under age ten'
          ],
          correctAnswer: 'Bio-computational hybrid architectures without moral consensus create existential dilemmas',
          explanation: 'Paragraph C concludes that engineering semi-sentient bio-computational hybrids without moral consensus threatens existential dilemmas.',
          paragraphRef: 'Đoạn C',
        ),
      ],
    ),
  ];

  // ═════════════════════════════════════════════════════════════
  // ── 2. LISTENING (5 ẢI VƯỢT CẤP) ──
  // ═════════════════════════════════════════════════════════════
  static final List<ListeningLessonModel> sampleListeningLessons = [
    ListeningLessonModel(
      id: 'l1',
      stageNumber: 1,
      difficultyLabel: 'Ải 1: Cơ bản (Band 6.0)',
      title: 'Campus Library Orientation & AI Resources',
      topic: 'Education & Student Support',
      bandScoreTarget: '6.5',
      passScoreRequired: 2,
      audioScript:
          'Welcome to the Central University Library orientation. My name is Sarah, and I am the senior academic coordinator. Today, I will guide you through our newly upgraded digital resources. '
          'On the first floor, you will find our interactive study pods equipped with automated speech recognition and camera scanners. '
          'Students can practice IELTS speaking drills and instantly record their pronunciations. '
          'The library is open from 8:00 AM to 10:00 PM on weekdays, and 9:00 AM to 5:00 PM on weekends. '
          'Please ensure you carry your university ID card at all times to gain access to the digital laboratories.',
      questions: [
        ListeningQuestion(
          id: 1,
          questionText: 'What is the speaker\'s official role at the university library?',
          options: [
            'IT Technical Support Specialist',
            'Senior Academic Coordinator',
            'Head of Security',
            'Student Union President'
          ],
          correctAnswer: 'Senior Academic Coordinator',
          explanation:
              'In the script, Sarah introduces herself: "My name is Sarah, and I am the senior academic coordinator."',
        ),
        ListeningQuestion(
          id: 2,
          questionText: 'What opening hours are specified for weekday access?',
          options: [
            '7:00 AM to 9:00 PM',
            '8:00 AM to 10:00 PM',
            '9:00 AM to 5:00 PM',
            '24 hours continuous access'
          ],
          correctAnswer: '8:00 AM to 10:00 PM',
          explanation:
              'The audio script states: "The library is open from 8:00 AM to 10:00 PM on weekdays."',
        ),
        ListeningQuestion(
          id: 3,
          questionText: 'What item is required to enter the digital laboratories?',
          options: [
            'A printed paper ticket',
            'University ID card',
            'Driver\'s license',
            'Library membership fee receipt'
          ],
          correctAnswer: 'University ID card',
          explanation:
              'Sarah states: "Please ensure you carry your university ID card at all times to gain access to the digital laboratories."',
        ),
      ],
    ),
    ListeningLessonModel(
      id: 'l2',
      stageNumber: 2,
      difficultyLabel: 'Ải 2: Trung cấp (Band 7.0)',
      title: 'International Technology Conference Discussion',
      topic: 'Technology & Innovation',
      bandScoreTarget: '7.0',
      passScoreRequired: 2,
      audioScript:
          'Good afternoon delegates. In this session, Dr. Marcus from the Robotics Institute will discuss edge artificial intelligence. '
          'Traditional deep learning pipelines rely extensively on cloud data centers, which introduces transmission latency and bandwidth vulnerability. '
          'Edge AI, however, executes mathematical inference locally on low-power mobile microprocessors. '
          'For instance, smartphone object detection operates at over 30 frames per second directly on-device without internet access. '
          'This technological transition dramatically protects user biometric privacy while enabling instantaneous situational awareness.',
      questions: [
        ListeningQuestion(
          id: 1,
          questionText: 'What major limitation of cloud-based AI is emphasized by Dr. Marcus?',
          options: [
            'Excessive battery life on smartphones',
            'Transmission latency and bandwidth vulnerability',
            'Total lack of neural network accuracy',
            'Expensive desktop monitor costs'
          ],
          correctAnswer: 'Transmission latency and bandwidth vulnerability',
          explanation:
              'Dr. Marcus explains that traditional deep learning relies on cloud data centers, introducing latency and bandwidth vulnerability.',
        ),
        ListeningQuestion(
          id: 2,
          questionText: 'At what frame rate does on-device object detection execute on modern smartphones?',
          options: [
            '10 frames per second',
            'Over 30 frames per second',
            '60 to 120 frames per second',
            'Less than 5 frames per second'
          ],
          correctAnswer: 'Over 30 frames per second',
          explanation:
              'The script states: "smartphone object detection operates at over 30 frames per second directly on-device."',
        ),
        ListeningQuestion(
          id: 3,
          questionText: 'What key user benefit is achieved by processing AI inferences locally?',
          options: [
            'Elimination of all smartphone hardware updates',
            'Protection of biometric privacy and instantaneous awareness',
            'Free mobile phone cellular data contracts',
            'Lower screen resolution for reading'
          ],
          correctAnswer: 'Protection of biometric privacy and instantaneous awareness',
          explanation:
              'The speaker concludes that on-device processing dramatically protects user biometric privacy while enabling instantaneous awareness.',
        ),
      ],
    ),
    ListeningLessonModel(
      id: 'l3',
      stageNumber: 3,
      difficultyLabel: 'Ải 3: Nâng cao (Band 7.5)',
      title: 'Environmental Science & Renewable Energy Lecture',
      topic: 'Ecology & Sustainable Energy',
      bandScoreTarget: '7.5',
      passScoreRequired: 2,
      audioScript:
          'In today\'s environmental science seminar, we analyze offshore wind farm infrastructure in the North Sea. '
          'The latest turbine models possess rotor diameters exceeding 220 meters, generating up to 15 megawatts per unit. '
          'A critical engineering bottleneck lies in subsea electrical transmission. '
          'High-voltage direct current cables are deployed to transmit bulk energy across hundreds of kilometers with less than 3% transmission loss. '
          'The environmental impact assessment indicates marine mammal habitats adapt positively to artificial turbine foundation reefs within 18 months of installation.',
      questions: [
        ListeningQuestion(
          id: 1,
          questionText: 'What is the maximum power generation capacity of the newest offshore turbine models?',
          options: ['5 megawatts', '10 megawatts', 'Up to 15 megawatts', '50 megawatts'],
          correctAnswer: 'Up to 15 megawatts',
          explanation: 'The lecturer states that units generate up to 15 megawatts each.',
        ),
        ListeningQuestion(
          id: 2,
          questionText: 'Why are high-voltage direct current cables utilized for subsea energy transmission?',
          options: [
            'They are made from recycled plastic materials',
            'They reduce energy transmission loss to under 3%',
            'They do not require physical seafloor placement',
            'They double the wind speed around turbine blades'
          ],
          correctAnswer: 'They reduce energy transmission loss to under 3%',
          explanation: 'The lecture explains cables transmit energy with less than 3% transmission loss.',
        ),
        ListeningQuestion(
          id: 3,
          questionText: 'How long does it take for marine mammal habitats to adapt to artificial foundation reefs?',
          options: ['Within 6 weeks', 'Within 18 months', 'At least 5 years', 'Over a decade'],
          correctAnswer: 'Within 18 months',
          explanation: 'The assessment notes habitats adapt positively within 18 months of installation.',
        ),
      ],
    ),
    ListeningLessonModel(
      id: 'l4',
      stageNumber: 4,
      difficultyLabel: 'Ải 4: Chuyên sâu (Band 8.0)',
      title: 'Global Economics & International Business Dialogue',
      topic: 'Macroeconomics & Trade Finance',
      bandScoreTarget: '8.0',
      passScoreRequired: 2,
      audioScript:
          'Welcome to the Global Monetary Forum podcast. Today we examine international trade settlement diversification. '
          'For nearly eight decades, the United States dollar served as the undisputed primary reserve currency, representing approximately 58% of global foreign exchange reserves in 2023. '
          'However, bilateral trade agreements utilizing sovereign currencies and distributed ledger payment systems have accelerated significantly. '
          'Central banks in emerging economies increased gold acquisitions by 32% year-on-year to hedge against inflationary currency depreciation and sovereign sanctions.',
      questions: [
        ListeningQuestion(
          id: 1,
          questionText: 'What percentage of global foreign exchange reserves was represented by the US Dollar in 2023?',
          options: ['Approximately 45%', 'Approximately 58%', 'Over 75%', 'Exactly 90%'],
          correctAnswer: 'Approximately 58%',
          explanation: 'The speaker notes the dollar represented approximately 58% of reserves in 2023.',
        ),
        ListeningQuestion(
          id: 2,
          questionText: 'What financial technology has accelerated bilateral currency settlements?',
          options: ['Distributed ledger payment systems', 'Paper credit vouchers', 'Commodity barter exchanges', 'Automated teller machines'],
          correctAnswer: 'Distributed ledger payment systems',
          explanation: 'The dialogue highlights distributed ledger payment systems as accelerating settlements.',
        ),
        ListeningQuestion(
          id: 3,
          questionText: 'By what percentage did emerging central banks increase their gold acquisitions?',
          options: ['12% year-on-year', '25% year-on-year', '32% year-on-year', '50% year-on-year'],
          correctAnswer: '32% year-on-year',
          explanation: 'Central banks increased gold acquisitions by 32% year-on-year.',
        ),
      ],
    ),
    ListeningLessonModel(
      id: 'l5',
      stageNumber: 5,
      difficultyLabel: 'Ải 5: Bậc thầy (Band 8.5+ - Boss Stage)',
      title: 'AI Neural Networks & Healthcare Innovations',
      topic: 'Medical Science & Biotechnology',
      bandScoreTarget: '8.5+',
      passScoreRequired: 3,
      audioScript:
          'Distinguished scholars, welcome to the Medical Artificial Intelligence Symposium. '
          'Our research laboratory has successfully developed a convolutional neural network capable of detecting early-stage pulmonary abnormalities with an unprecedented 98.4% diagnostic accuracy. '
          'Unlike conventional radiological screenings that require hours of human radiologist review, this algorithmic pipeline generates diagnostic heatmaps within 12 seconds. '
          'Clinical trials involving 15,000 anonymized patient scans across seven teaching hospitals demonstrated a 40% reduction in false-positive conclusions. '
          'The chief regulatory obstacle currently centers around data privacy compliance and international algorithmic transparency standards.',
      questions: [
        ListeningQuestion(
          id: 1,
          questionText: 'What diagnostic accuracy rate did the new neural network achieve in trials?',
          options: ['89.2%', '94.5%', '98.4%', '99.8%'],
          correctAnswer: '98.4%',
          explanation: 'The speaker highlights an unprecedented 98.4% diagnostic accuracy rate.',
        ),
        ListeningQuestion(
          id: 2,
          questionText: 'How quickly does the system generate diagnostic heatmaps?',
          options: ['Within 5 seconds', 'Within 12 seconds', 'Within 45 seconds', 'Within 2 minutes'],
          correctAnswer: 'Within 12 seconds',
          explanation: 'The script indicates the pipeline generates heatmaps within 12 seconds.',
        ),
        ListeningQuestion(
          id: 3,
          questionText: 'What primary regulatory challenge was highlighted by the symposium presenter?',
          options: ['Software licensing fees', 'Data privacy and algorithmic transparency', 'Lack of hospital server equipment', 'Shortage of medical students'],
          correctAnswer: 'Data privacy and algorithmic transparency',
          explanation: 'The chief obstacle centers around data privacy compliance and algorithmic transparency.',
        ),
      ],
    ),
  ];

  // ═════════════════════════════════════════════════════════════
  // ── 3. WRITING (5 ẢI VƯỢT CẤP) ──
  // ═════════════════════════════════════════════════════════════
  static final List<WritingLessonModel> sampleWritingLessons = [
    WritingLessonModel(
      id: 'w1',
      stageNumber: 1,
      difficultyLabel: 'Ải 1: Cơ bản - Task 1 Bar Chart (Band 6.0)',
      taskType: 'Task 1',
      title: 'Internet Access in Households (2015 - 2025)',
      topic: 'Technology & Demographics',
      bandScoreTarget: '6.5',
      passScoreRequired: 6,
      prompt:
          'The chart illustrates the percentage of households with internet access across urban and rural areas from 2015 to 2025. Summarise the information by selecting and reporting the main features, and make comparisons where relevant. Write at least 120 words.',
      minWordCount: 120,
      suggestedTimeMinutes: 20,
      keyOutline: [
        'Introduction: Paraphrase đề bài (The chart delineates...)',
        'Overview: Nêu 2 xu hướng chính (Tăng trưởng cả hai khu vực, khoảng cách thu hẹp)',
        'Body 1: Phân tích số liệu khu vực đô thị (Từ 65% lên 92%)',
        'Body 2: Phân tích số liệu khu vực nông thôn (Từ 30% vọt lên 78%)',
      ],
      sampleEssay:
          'The line graph delineates the proportion of households possessing internet connectivity across metropolitan and rural districts over a ten-year span from 2015 to 2025.\n\n'
          'Overall, it is manifest that both sectors experienced a noticeable upward trajectory throughout the examined timeline. Furthermore, while urban regions consistently registered higher connectivity rates, the disparity between the two categories narrowed considerably towards the end of the period.\n\n'
          'In 2015, approximately 65% of urban dwellings were equipped with online access, compared to a modest 30% in rural vicinities. Over the subsequent five years, urban adoption surged steadily, surpassing 80% by 2020. Simultaneously, rural connectivity witnessed exponential growth, climbing to nearly 55% as telecommunication infrastructure expanded.\n\n'
          'By 2025, internet penetration in cities plateaued at an impressive 92%. In contrast, rural areas continued their accelerated ascent to reach 78%, thereby significantly reducing the digital divide to merely 14 percentage points.',
      sampleTranslation:
          'Biểu đồ đường mô tả tỷ lệ hộ gia đình có kết nối internet ở các khu vực đô thị và nông thôn trong khoảng thời gian 10 năm từ 2015 đến 2025.\n\n'
          'Nhìn chung, cả hai khu vực đều ghi nhận xu hướng tăng trưởng rõ rệt. Đáng chú ý, khoảng cách giữa hai nhóm đã được thu hẹp đáng kể vào cuối giai đoạn.',
      academicVocabulary: [
        'delineates (mô tả chi tiết)',
        'upward trajectory (quỹ đạo đi lên)',
        'metropolitan districts (khu vực đô thị)',
        'disparity narrowed (khoảng cách thu hẹp)',
        'plateaued (đạt mức bão hòa ổn định)',
        'digital divide (khoảng cách số)',
      ],
    ),
    WritingLessonModel(
      id: 'w2',
      stageNumber: 2,
      difficultyLabel: 'Ải 2: Trung cấp - Task 1 Line Graph (Band 7.0)',
      taskType: 'Task 1',
      title: 'Renewable Energy Consumption Across Three Continents',
      topic: 'Energy & Environment',
      bandScoreTarget: '7.0',
      passScoreRequired: 7,
      prompt:
          'The line graph shows changes in the consumption of renewable energy (in terawatt-hours) across Europe, North America, and Asia between 2010 and 2024. Summarise the main trends and make comparisons. Write at least 150 words.',
      minWordCount: 150,
      suggestedTimeMinutes: 20,
      keyOutline: [
        'Introduction: Rephrase line graph topic',
        'Overview: Significant growth in Asia and Europe, slight increase in North America',
        'Body 1: Detail Asia\'s exponential rise after 2016',
        'Body 2: Compare Europe\'s steady increase with North America\'s stabilization',
      ],
      sampleEssay:
          'The provided line graph illustrates the consumption patterns of renewable power measured in terawatt-hours across three key geographical zones—Europe, North America, and Asia—from 2010 to 2024.\n\n'
          'Overall, renewable energy utilization witnessed an upward trend across all surveyed continents. Notably, Asia transitioned from being the lowest consumer to the preeminent contributor by the conclusion of the timeline, whereas North America recorded comparatively moderate expansion.\n\n'
          'In 2010, Europe spearheaded clean energy consumption with 450 TWh, followed closely by North America at roughly 380 TWh. Over the initial four-year span, European usage climbed incrementally, whereas North American consumption fluctuated mildly before plateauing near 500 TWh.\n\n'
          'In marked contrast, Asian consumption was initially modest at 220 TWh. However, following aggressive green energy subsidies in 2016, Asian demand surged exponentially to surpass both competing regions, reaching an astonishing peak of 950 TWh by 2024.',
      sampleTranslation:
          'Biểu đồ đường minh họa mô hình tiêu thụ năng lượng tái tạo tính bằng terawatt-giờ trên ba khu vực địa lý—Châu Âu, Bắc Mỹ và Châu Á—từ năm 2010 đến 2024.',
      academicVocabulary: [
        'illustrates (minh họa)',
        'consumption patterns (mô hình tiêu thụ)',
        'preeminent contributor (nguồn đóng góp hàng đầu)',
        'incremental climb (sự gia tăng từng bước)',
        'exponential surge (sự bùng nổ theo cấp số nhân)',
        'marked contrast (sự tương phản rõ rệt)',
      ],
    ),
    WritingLessonModel(
      id: 'w3',
      stageNumber: 3,
      difficultyLabel: 'Ải 3: Nâng cao - Task 2 Opinion Essay (Band 7.5)',
      taskType: 'Task 2',
      title: 'Remote Work & Its Socioeconomic Influence on Cities',
      topic: 'Society & Employment',
      bandScoreTarget: '7.5',
      passScoreRequired: 7,
      prompt:
          'Some people believe that telecommuting (working remotely from home) brings enormous benefits to workers and society, while others argue it leads to social isolation and economic decline in central business districts. Discuss both views and give your opinion. Write at least 200 words.',
      minWordCount: 200,
      suggestedTimeMinutes: 40,
      keyOutline: [
        'Introduction: Present both sides of remote work and state balanced stance',
        'Body 1: Advantages: Reduced commuting stress, flexible work-life balance, lowered emissions',
        'Body 2: Drawbacks: Blurred work boundaries, loneliness, retail downturn in downtown areas',
        'Conclusion: Reiterate that hybrid models offer the optimal compromise',
      ],
      sampleEssay:
          'The widespread adoption of remote telecommuting has fundamentally reshaped contemporary working dynamics. While proponents emphasize flexibility and commuter stress reduction, skeptics highlight psychological isolation and commercial downturns in urban centers. In my estimation, while both arguments possess merit, a hybrid paradigm constitutes the most sustainable path forward.\n\n'
          'On the one hand, teleworking confers undeniable advantages upon employees and the environment. Eliminating prolonged daily commutes affords individuals valuable personal time, fostering higher work-life equilibrium. Furthermore, decreased vehicular transit translates directly into reduced carbon emissions, thereby supporting municipal ecological targets.\n\n'
          'Conversely, prolonged isolation from physical office spaces can induce professional alienation and stifle spontaneous collaborative innovation. Additionally, metropolitan central business districts face substantial revenue deficits when hospitality and retail businesses lose their daily office patronage.\n\n'
          'To conclude, remote employment provides profound flexibility, but unmitigated detachment compromises social cohesion. Therefore, institutionalizing hybrid arrangements delivers the benefits of telecommuting while preserving vital collaborative bonds.',
      sampleTranslation:
          'Sự phổ biến của làm việc từ xa đã định hình lại căn bản bối cảnh lao động đương đại. Mô hình kết hợp là giải pháp bền vững nhất.',
      academicVocabulary: [
        'telecommuting (làm việc từ xa)',
        'reshaped contemporary dynamics (định hình lại bối cảnh đương đại)',
        'hybrid paradigm (mô hình kết hợp)',
        'work-life equilibrium (sự cân bằng công việc - đời sống)',
        'spontaneous collaborative innovation (sự sáng tạo hợp tác tự nhiên)',
        'commercial downturns (sự sụt giảm thương mại)',
      ],
    ),
    WritingLessonModel(
      id: 'w4',
      stageNumber: 4,
      difficultyLabel: 'Ải 4: Chuyên sâu - Task 2 Problem & Solution (Band 8.0)',
      taskType: 'Task 2',
      title: 'Digital Overload & Mental Well-being in Adolescents',
      topic: 'Psychology & Public Health',
      bandScoreTarget: '8.0',
      passScoreRequired: 8,
      prompt:
          'Excessive screen time and digital media consumption are causing severe mental health challenges and sleep deprivation among teenagers worldwide. What are the root causes of this phenomenon, and what actionable solutions can be implemented by parents and schools? Write at least 250 words.',
      minWordCount: 250,
      suggestedTimeMinutes: 40,
      keyOutline: [
        'Introduction: Acknowledge digital addiction among adolescents as a global public health crisis',
        'Body 1: Root Causes: Dopamine-driven recommendation algorithms, peer validation, FOMO',
        'Body 2: Practical Solutions: Institutional screen-free policies in schools, parental digital hygiene',
        'Conclusion: Emphasize that technological balance requires systemic collaboration',
      ],
      sampleEssay:
          'In recent years, the ubiquity of smartphones and algorithmic social media platforms has precipitated an unprecedented psychological crisis among teenagers. Adolescent anxiety, clinical depression, and chronic sleep deprivation have surged concurrently with screen consumption. This essay explores the primary catalysts behind this troubling trend and proposes multifaceted remediations.\n\n'
          'The paramount etiology of teenage digital dependency stems from the sophisticated engineering of addictive algorithms. Social networking corporations deliberately design notification loops that trigger dopamine surges, exploiting youthful vulnerability to social validation and the fear of missing out (FOMO). Consequently, adolescents become trapped in compulsive nocturnal scrolling, which disrupts circadian sleep rhythms.\n\n'
          'To remediate this crisis, synchronized interventions across educational institutions and domestic households are indispensable. Pedagogical authorities must enforce strict screen-free mandates during school operating hours, replacing passive screen time with vigorous physical education and creative workshops. Concurrently, parents should establish digital curfews, such as designating bedrooms as device-free zones after 9:00 PM.\n\n'
          'In conclusion, teenage digital addiction is driven by algorithmic manipulation and psychological vulnerability. Combating this epidemic requires strict regulatory frameworks in academic environments and conscious parenting to cultivate healthy digital boundaries.',
      sampleTranslation:
          'Sự phổ biến của smartphone và mạng xã hội thuật toán đã gây ra cuộc khủng hoảng tâm lý chưa từng có ở thanh thiếu niên.',
      academicVocabulary: [
        'ubiquity of smartphones (sự phổ biến khắp nơi của điện thoại)',
        'precipitated an unprecedented crisis (gây ra cuộc khủng hoảng chưa từng có)',
        'paramount etiology (nguyên nhân căn bản hàng đầu)',
        'dopamine loops (vòng lặp kích thích dopamine)',
        'circadian sleep rhythms (nhịp sinh học giấc ngủ)',
        'synchronized interventions (các biện pháp can thiệp đồng bộ)',
      ],
    ),
    WritingLessonModel(
      id: 'w5',
      stageNumber: 5,
      difficultyLabel: 'Ải 5: Bậc thầy - Task 2 Discussion & Solution (Band 8.5+ - Boss Stage)',
      taskType: 'Task 2',
      title: 'Artificial Superintelligence: Existential Threat vs Planetary Prosperity',
      topic: 'Science Ethics & Future Tech',
      bandScoreTarget: '8.5+',
      passScoreRequired: 8,
      prompt:
          'Many leading technologists argue that artificial general intelligence (AGI) poses an existential catastrophe to humanity, while others maintain that it will cure incurable diseases and reverse ecological destruction. Discuss both viewpoints and articulate your own reasoned perspective. Write at least 250 words.',
      minWordCount: 250,
      suggestedTimeMinutes: 40,
      keyOutline: [
        'Introduction: Introduce the philosophical debate surrounding AGI development',
        'Body 1: Arguments for Existential Risk: Alignment problem, loss of cognitive agency, algorithmic autonomy',
        'Body 2: Arguments for Planetary Prosperity: Climate modeling, genomic drug discovery, poverty alleviation',
        'Conclusion & Stance: Advocate stringent international regulatory oversight as a safeguard',
      ],
      sampleEssay:
          'The inexorable advancement towards artificial general intelligence (AGI) represents the most consequential juncture in anthropogenic history. While techno-optimists envision unprecedented therapeutic breakthroughs and planetary ecological rejuvenation, prominent ethicists caution against potential existential annihilation. This essay evaluates both paradigms before asserting that proactive global governance is paramount to harnessing AGI safely.\n\n'
          'On the one hand, unregulated superintelligence presents profound existential hazards. The crux of the dilemma lies in the alignment problem—ensuring autonomous entities share human moral axioms. Should superintelligent algorithms prioritize mathematical efficiency over human welfare, unintended catastrophic consequences could ensue. Furthermore, the potential weaponization of autonomous drone swarms presents destabilizing geopolitical risks.\n\n'
          'Conversely, the potential merits of benevolent AGI are transformative. In biomedical research, synthetic intelligence has deciphered complex protein folding geometries, drastically accelerating pharmacological cures for neurodegenerative ailments. Furthermore, quantum-assisted AI models can optimize global supply chains and atmospheric carbon sequestration far beyond human analytical limitations.\n\n'
          'In conclusion, artificial superintelligence embodies both supreme opportunity and profound peril. Humanity must not succumb to fatalism nor hubris; rather, establishing stringent international non-proliferation treaties and ethical safety verifications will dictate whether AGI serves as our ultimate savior or our final invention.',
      sampleTranslation:
          'Sự tiến bộ không thể đảo ngược hướng tới AGI đại diện cho bước ngoặt quan trọng nhất trong lịch sử nhân loại.',
      academicVocabulary: [
        'inexorable advancement (sự phát triển không thể ngăn cản)',
        'consequential juncture (bước ngoặt mang tính quyết định)',
        'anthropogenic history (lịch sử loài người)',
        'alignment problem (bài toán căn chỉnh đạo đức AI)',
        'existential annihilation (sự hủy diệt tồn vong)',
        'carbon sequestration (thu giữ carbon khí quyển)',
      ],
    ),
  ];

  // ═════════════════════════════════════════════════════════════
  // ── 4. SPEAKING (5 ẢI VƯỢT CẤP) ──
  // ═════════════════════════════════════════════════════════════
  static final List<SpeakingLessonModel> sampleSpeakingLessons = [
    SpeakingLessonModel(
      id: 's1',
      stageNumber: 1,
      difficultyLabel: 'Ải 1: Cơ bản - Part 1 Daily Routine (Band 6.0)',
      title: 'Daily Routine, Time Management & Morning Habits',
      topic: 'Personal Lifestyle',
      bandScoreTarget: '6.5',
      passScoreRequired: 6,
      part1Questions: [
        SpeakingPart1Item(
          question: 'What is the typical sequence of your morning routine?',
          sampleAnswer:
              'Generally speaking, I wake up at around 6:30 AM, hydrate immediately, and spend twenty minutes doing light stretching exercises. Afterwards, I prepare a nutritious breakfast while reviewing my daily schedule.',
          translation:
              'Nhìn chung, tôi thức dậy lúc khoảng 6:30 sáng, uống nước ngay lập tức và dành hai mươi phút tập các bài giãn cơ nhẹ. Sau đó, tôi chuẩn bị bữa sáng bổ dưỡng trong khi xem lại lịch trình hàng ngày.',
          keyVocabulary: ['generally speaking (nhìn chung)', 'hydrate immediately (uống nước ngay)', 'nutritious breakfast (bữa sáng bổ dưỡng)', 'daily schedule (lịch trình hàng ngày)'],
        ),
        SpeakingPart1Item(
          question: 'Do you prefer to organize your daily activities meticulously or stay spontaneous?',
          sampleAnswer:
              'I definitely lean towards meticulous scheduling because it prevents procrastination and minimizes stress. However, I always leave a buffer period in the afternoon for unexpected emergencies.',
          translation:
              'Tôi chắc chắn thiên về việc lên lịch tỉ mỉ vì nó ngăn chặn sự trì hoãn và giảm thiểu căng thẳng. Tuy nhiên, tôi luôn chừa một khoảng thời gian trống vào buổi chiều cho những việc đột xuất.',
          keyVocabulary: ['lean towards (thiên về)', 'meticulous scheduling (lên lịch tỉ mỉ)', 'prevent procrastination (ngăn chặn sự trì hoãn)', 'buffer period (khoảng thời gian dự phòng)'],
        ),
      ],
      part2CueCardPrompt: 'Describe a productive morning habit that you consistently follow.',
      part2BulletPoints: [
        'What the habit is',
        'When and how you started it',
        'Why it requires discipline',
        'And explain how it influences your daily mood and efficiency.',
      ],
      part2SampleAnswer:
          'I would like to elaborate on my habit of morning journaling and priority setting. I initiated this practice approximately two years ago when I felt inundated with academic deadlines. Every morning before looking at my smartphone, I jot down three core objectives for the day. This simple ritual anchors my focus, mitigates cognitive clutter, and instills a sense of purpose throughout my workday.',
      part2SampleTranslation:
          'Tôi muốn chia sẻ về thói quen viết nhật ký buổi sáng và sắp xếp việc ưu tiên. Nghi thức đơn giản này neo giữ sự tập trung, giải tỏa tâm trí và truyền cảm giác có mục tiêu suốt ngày làm việc.',
      part2Collocations: [
        'anchor focus (neo giữ sự tập trung)',
        'cognitive clutter (sự lộn xộn trong suy nghĩ)',
        'inundated with deadlines (quá tải với hạn nộp)',
        'instills a sense of purpose (truyền cảm giác có mục tiêu)',
      ],
    ),
    SpeakingLessonModel(
      id: 's2',
      stageNumber: 2,
      difficultyLabel: 'Ải 2: Trung cấp - Part 1 Technology & Study (Band 7.0)',
      title: 'Artificial Intelligence in Everyday Life & Study',
      topic: 'Technology & Education',
      bandScoreTarget: '7.0',
      passScoreRequired: 7,
      part1Questions: [
        SpeakingPart1Item(
          question: 'Do you frequently utilize artificial intelligence in your academic pursuits?',
          sampleAnswer:
              'To be completely candid, I incorporate AI-powered applications almost daily, particularly for proofreading academic essays and discovering relevant research literature. It notably streamlines my workflow.',
          translation:
              'Thành thật mà nói, tôi kết hợp các ứng dụng hỗ trợ AI gần như mỗi ngày, đặc biệt là để hiệu đính bài luận học thuật và tìm tài liệu nghiên cứu liên quan. Nó giúp tinh giản rõ rệt quy trình làm việc của tôi.',
          keyVocabulary: ['to be completely candid (thành thật mà nói)', 'incorporate daily (áp dụng hàng ngày)', 'proofreading (hiệu đính)', 'streamline workflow (tinh giản quy trình)'],
        ),
        SpeakingPart1Item(
          question: 'Do you believe artificial intelligence might replace conventional educators in the near future?',
          sampleAnswer:
              'I strongly disagree with that proposition. While AI excels at automated grading and personalized drill delivery, human mentors provide empathy, moral guidance, and psychological encouragement that algorithms cannot replicate.',
          translation:
              'Tôi hoàn toàn không đồng ý với nhận định đó. Mặc dù AI xuất sắc trong việc chấm điểm tự động và bài luyện tập cá nhân hóa, những người thầy con người mang lại sự đồng cảm, định hướng đạo đức và khích lệ tâm lý.',
          keyVocabulary: ['strongly disagree (hoàn toàn không đồng ý)', 'excels at (xuất sắc ở)', 'moral guidance (định hướng đạo đức)', 'cannot replicate (không thể sao chép)'],
        ),
      ],
      part2CueCardPrompt: 'Describe a technological device or application that drastically enhanced your learning capacity.',
      part2BulletPoints: [
        'What the device or application is',
        'How you learned to navigate it',
        'What distinctive features it possesses',
        'And explain why it made your learning experience considerably more pleasant.',
      ],
      part2SampleAnswer:
          'I would be delighted to share details regarding an innovative mobile vision application I downloaded while preparing for the IELTS exam. By employing computer vision neural networks, the app allows users to scan ordinary physical objects and instantly reveals high-band IELTS terminology, contextual collocations, and acoustic pronunciation samples. This visual method drastically accelerated my lexical retention compared to tedious flashcards.',
      part2SampleTranslation:
          'Tôi rất vui được chia sẻ chi tiết về ứng dụng thị giác di động sáng tạo. Phương pháp trực quan này đã đẩy nhanh đáng kể khả năng ghi nhớ từ vựng so với flashcard đơn điệu.',
      part2Collocations: [
        'delighted to share (rất vui được chia sẻ)',
        'computer vision networks (mạng thị giác máy tính)',
        'lexical retention (khả năng ghi nhớ từ vựng)',
        'drastically accelerated (đẩy nhanh đáng kể)',
      ],
    ),
    SpeakingLessonModel(
      id: 's3',
      stageNumber: 3,
      difficultyLabel: 'Ải 3: Nâng cao - Part 2 Cue Card Monologue (Band 7.5)',
      title: 'A Life-Changing Academic Decision You Made',
      topic: 'Personal Achievement',
      bandScoreTarget: '7.5',
      passScoreRequired: 7,
      part1Questions: [
        SpeakingPart1Item(
          question: 'Do you find it difficult to make significant long-term commitments?',
          sampleAnswer:
              'Admittedly yes, especially when facing irreversible life milestones. However, I usually conduct exhaustive comparative research and consult seasoned mentors before arriving at a definitive verdict.',
          translation:
              'Phải thừa nhận là có, đặc biệt khi đứng trước những cột mốc không thể đảo ngược. Tuy nhiên, tôi thường nghiên cứu so sánh cẩn thận và hỏi ý kiến các cố vấn giàu kinh nghiệm.',
          keyVocabulary: ['admittedly yes (thừa nhận là có)', 'irreversible milestones (cột mốc không thể đảo ngược)', 'exhaustive research (nghiên cứu cẩn thận)', 'definitive verdict (phán quyết dứt khoát)'],
        ),
        SpeakingPart1Item(
          question: 'Should young adults rely more on parental guidance or their personal intuition?',
          sampleAnswer:
              'In my perspective, a balanced amalgamation is ideal. Parental advice offers pragmatic historical wisdom, whereas personal intuition guarantees authentic commitment and intrinsic motivation.',
          translation:
              'Theo quan điểm của tôi, sự kết hợp cân bằng là lý tưởng nhất. Lời khuyên của cha mẹ mang lại sự thông thái thực tế, trong khi trực giác cá nhân đảm bảo động lực tự thân.',
          keyVocabulary: ['balanced amalgamation (sự kết hợp cân bằng)', 'pragmatic wisdom (sự thông thái thực tế)', 'intrinsic motivation (động lực tự thân)'],
        ),
      ],
      part2CueCardPrompt: 'Describe a pivotal academic decision that reshaped your educational trajectory.',
      part2BulletPoints: [
        'What decision you made',
        'When you made it and who influenced you',
        'What initial hesitations you had to conquer',
        'And explain why this choice proved exceptionally rewarding in hindsight.',
      ],
      part2SampleAnswer:
          'I would like to speak about my decision to switch my academic specialization from conventional marketing towards data science and computational linguistics during my sophomore university year. Initially, I was terrified by the intimidating mathematical prerequisites. However, under the inspiring mentorship of my faculty advisor, I embraced the transition. Looking back in hindsight, this audacious leap unlocked lucrative internship opportunities and endowed me with analytical capabilities that set me apart.',
      part2SampleTranslation:
          'Tôi muốn nói về quyết định chuyển chuyên ngành đại học sang khoa học dữ liệu và ngôn ngữ học tính toán vào năm thứ hai. Bước nhảy vọt táo bạo này đã mở ra các cơ hội thực tập hấp dẫn và trang bị năng lực phân tích vượt trội.',
      part2Collocations: [
        'pivotal decision (quyết định then chốt)',
        'sophomore university year (năm thứ hai đại học)',
        'audacious leap (bước nhảy táo bạo)',
        'in hindsight (khi nhìn nhận lại)',
      ],
    ),
    SpeakingLessonModel(
      id: 's4',
      stageNumber: 4,
      difficultyLabel: 'Ải 4: Chuyên sâu - Part 3 Abstract Discussion (Band 8.0)',
      title: 'Socioeconomic Ramifications of Global Automation',
      topic: 'Sociology & Economics',
      bandScoreTarget: '8.0',
      passScoreRequired: 8,
      part1Questions: [
        SpeakingPart1Item(
          question: 'How will widespread industrial automation influence wealth distribution worldwide?',
          sampleAnswer:
              'Undoubtedly, unchecked automation threatens to accentuate wealth polarization. Owners of proprietary algorithms will capture disproportionate capital yields, whereas non-specialized laborers risk wage stagnation unless progressive taxation models are instituted.',
          translation:
              'Chắc chắn việc tự động hóa tràn lan đe dọa làm trầm trọng thêm sự phân cực giàu nghèo. Các chủ sở hữu thuật toán độc quyền sẽ chiếm giữ lợi suất tư bản vượt trội.',
          keyVocabulary: ['accentuate polarization (làm trầm trọng sự phân cực)', 'proprietary algorithms (thuật toán độc quyền)', 'disproportionate yields (lợi suất vượt trội)', 'progressive taxation (thuế lũy tiến)'],
        ),
        SpeakingPart1Item(
          question: 'Can technological education alone safeguard future generations against employment redundancy?',
          sampleAnswer:
              'Technological literacy is certainly a prerequisite, but by no means an exhaustive panacea. Educational curricula must prioritize philosophical discernment, emotional adaptability, and complex rhetoric—attributes that remain resilient to algorithmic imitation.',
          translation:
              'Sự hiểu biết về công nghệ chắc chắn là điều kiện tiên quyết, nhưng không phải là phương thuốc vạn năng. Giáo trình phải ưu tiên sự thấu suốt triết học, sự thích ứng cảm xúc và kỹ năng hùng biện phức tạp.',
          keyVocabulary: ['exhaustive panacea (phương thuốc vạn năng)', 'philosophical discernment (sự thấu suốt triết học)', 'resilient to imitation (bền vững trước sự bắt chước)'],
        ),
      ],
      part2CueCardPrompt: 'Describe a global socioeconomic issue resulting from rapid technological evolution.',
      part2BulletPoints: [
        'What the issue is',
        'Which demographics are most vulnerable',
        'Why conventional governmental policies struggle to address it',
        'And propose feasible international countermeasures.',
      ],
      part2SampleAnswer:
          'I wish to address the pressing dilemma of technological obsolescence among mid-career blue-collar workforces. As autonomous heavy machinery becomes commercially ubiquitous across transportation and warehousing, millions of workers face sudden livelihood displacement. Traditional governmental social safety nets are ill-equipped for this exponential transition. I propose an international transition sovereign fund, financed through automation levies, to underwrite multi-year reskilling stipends.',
      part2SampleTranslation:
          'Tôi muốn đề cập đến vấn đề cấp bách về sự lỗi thời kỹ năng của lực lượng lao động tay chân trung niên khi máy móc tự hành trở nên phổ biến.',
      part2Collocations: [
        'pressing dilemma (song đề cấp bách)',
        'technological obsolescence (sự lỗi thời công nghệ)',
        'ill-equipped (không đủ trang bị)',
        'automation levies (thuế tự động hóa)',
      ],
    ),
    SpeakingLessonModel(
      id: 's5',
      stageNumber: 5,
      difficultyLabel: 'Ải 5: Bậc thầy - Full Mock Interview (Band 8.5+ - Boss Stage)',
      title: 'IELTS Master Mock: Innovation, Ethics & Humanity',
      topic: 'Comprehensive Mock Exam',
      bandScoreTarget: '8.5+',
      passScoreRequired: 8,
      part1Questions: [
        SpeakingPart1Item(
          question: 'In what ways has your personal worldview transformed over the past decade?',
          sampleAnswer:
              'I have gravitated from a naive reductionist mindset towards embracing systemic multidimensional complexity. I now perceive global dilemmas not as isolated technical glitches, but as intricate ecological, moral, and cultural symbioses.',
          translation:
              'Tôi đã chuyển từ lối tư duy giản lược ngây thơ sang việc đón nhận sự phức tạp đa chiều mang tính hệ thống. Giờ đây tôi nhìn nhận các vấn đề toàn cầu như sự cộng sinh phức tạp.',
          keyVocabulary: ['naive reductionist mindset (tư duy giản lược)', 'systemic complexity (sự phức tạp hệ thống)', 'intricate symbioses (sự cộng sinh phức tạp)'],
        ),
        SpeakingPart1Item(
          question: 'Do you believe humanity possesses sufficient philosophical maturity to govern synthetic intelligence?',
          sampleAnswer:
              'That constitutes the seminal question of our epoch. While our technological velocity is breathtaking, our ethical governance mechanisms remain regrettably fragmented. Establishing binding multilateral oversight is the ultimate civilizational litmus test.',
          translation:
              'Đó là câu hỏi mang tính then chốt của thời đại chúng ta. Trong khi tốc độ công nghệ đáng kinh ngạc, các cơ chế quản trị đạo đức vẫn bị phân mảnh.',
          keyVocabulary: ['seminal question of our epoch (câu hỏi then chốt)', 'technological velocity (tốc độ công nghệ)', 'civilizational litmus test (bài kiểm tra văn minh)'],
        ),
      ],
      part2CueCardPrompt: 'Deliver an impromptu 2-minute academic discourse on how humanity should maintain its moral compass in an algorithmic civilization.',
      part2BulletPoints: [
        'What moral challenges algorithmic governance introduces',
        'Why purely computational logic is insufficient for ethical dilemmas',
        'How philosophical humanities education must be revived',
        'And synthesize your vision for a symbiotic human-centric future.',
      ],
      part2SampleAnswer:
          'Standing at the threshold of synthetic superintelligence, humanity faces an existential imperative: we must preserve human empathy and philosophical discernment as our immutable moral compass. Algorithms optimize purely for mathematical utility, but utility must never be conflated with justice. We must revitalize classical humanities, cultivate ethical deliberation in engineering curricula, and insist that technology remains an instrument of universal human flourishing rather than an autonomous master.',
      part2SampleTranslation:
          'Đứng trước ngưỡng cửa của siêu trí tuệ nhân tạo, nhân loại đối mặt với mệnh lệnh sống còn: bảo tồn sự đồng cảm và sự thấu suốt triết học như la bàn đạo đức bất biến.',
      part2Collocations: [
        'threshold of superintelligence (ngưỡng cửa siêu trí tuệ)',
        'existential imperative (mệnh lệnh sống còn)',
        'immutable moral compass (la bàn đạo đức bất biến)',
        'universal human flourishing (sự hưng thịnh toàn cầu)',
      ],
    ),
  ];
}
