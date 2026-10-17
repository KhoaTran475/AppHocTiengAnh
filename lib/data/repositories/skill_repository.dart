import '../models/skill_models.dart';

/// Kho dữ liệu bài tập IELTS Reading & Listening mẫu chuẩn học thuật.
class SkillRepository {
  /// Danh sách bài đọc IELTS Reading
  static final List<ReadingPassageModel> sampleReadingPassages = [
    ReadingPassageModel(
      id: 'r1',
      title: 'Artificial Intelligence in Modern Education',
      category: 'Technology & Education',
      bandScoreTarget: '7.5',
      paragraphs: {
        'A':
            'Artificial Intelligence (AI) is rapidly altering the landscape of modern education. By leveraging advanced machine learning algorithms, educational platforms can tailor learning materials to match the individual pacing and cognitive strengths of each student. This adaptive learning technology ensures that learners absorb complex academic concepts efficiently without feeling overwhelmed.',
        'B':
            'Furthermore, smart computer vision systems enable mobile applications to recognize real-world objects instantaneously. When a student points a smartphone camera at an everyday item, AI models analyze the visual features and map them to specialized IELTS academic vocabulary, collocations, and contextual Speaking samples.',
        'C':
            'Critics argue that over-reliance on artificial intelligence might diminish human interaction and critical thinking skills. However, educators emphasize that AI tools are designed to augment traditional pedagogy rather than replace teachers. Educators can focus on mentorship and emotional support while AI handles automated vocabulary drills and performance analytics.',
      },
      questions: [
        ReadingQuestion(
          id: 1,
          questionText:
              'What primary benefit of AI in education is highlighted in Paragraph A?',
          options: [
            'Replacing human teachers completely',
            'Tailoring learning materials to individual student pacing',
            'Reducing tuition fees significantly',
            'Eliminating all academic examinations'
          ],
          correctAnswer:
              'Tailoring learning materials to individual student pacing',
          explanation:
              'Paragraph A explicitly states: "By leveraging advanced machine learning algorithms, educational platforms can tailor learning materials to match the individual pacing... of each student."',
          paragraphRef: 'Đoạn A',
        ),
        ReadingQuestion(
          id: 2,
          questionText:
              'How does computer vision enhance vocabulary learning according to Paragraph B?',
          options: [
            'By writing essay assignments automatically',
            'By mapping camera-scanned objects to academic vocabulary',
            'By generating fake images for testing',
            'By translating entire textbooks into audio files'
          ],
          correctAnswer:
              'By mapping camera-scanned objects to academic vocabulary',
          explanation:
              'Paragraph B mentions: "When a student points a smartphone camera... AI models analyze visual features and map them to specialized IELTS academic vocabulary."',
          paragraphRef: 'Đoạn B',
        ),
        ReadingQuestion(
          id: 3,
          questionText:
              'What view do educators hold regarding AI tools in Paragraph C?',
          options: [
            'AI tools should completely replace traditional schools',
            'AI tools augment pedagogy rather than replace human teachers',
            'AI tools are detrimental to student progress',
            'AI tools are too expensive to implement'
          ],
          correctAnswer:
              'AI tools augment pedagogy rather than replace human teachers',
          explanation:
              'Paragraph C states: "educators emphasize that AI tools are designed to augment traditional pedagogy rather than replace teachers."',
          paragraphRef: 'Đoạn C',
        ),
      ],
    ),
    ReadingPassageModel(
      id: 'r2',
      title: 'Climate Change and Biodiversity Conservation',
      category: 'Environment & Biology',
      bandScoreTarget: '8.0',
      paragraphs: {
        'A':
            'Global climate shifts pose unprecedented threats to global ecosystem stability. Rising surface temperatures accelerate natural habitat degradation, forcing species to adapt rapidly or face potential extinction. Conservationists are implementing innovative ecological monitoring strategies to preserve fragile biomes.',
        'B':
            'Preserving biological diversity requires international cooperation and sustainable environmental policies. Urban green spaces and reforestation projects mitigate carbon dioxide emissions while providing vital sanctuaries for native wildlife species.',
      },
      questions: [
        ReadingQuestion(
          id: 1,
          questionText:
              'What primary challenge to ecosystems is described in Paragraph A?',
          options: [
            'Overpopulation in urban areas',
            'Habitat degradation caused by rising temperatures',
            'Lack of international tourism',
            'Excessive industrial recycling'
          ],
          correctAnswer: 'Habitat degradation caused by rising temperatures',
          explanation:
              'Paragraph A highlights that rising surface temperatures accelerate habitat degradation and force species to adapt or face extinction.',
          paragraphRef: 'Đoạn A',
        ),
      ],
    ),
  ];

  /// Danh sách bài nghe IELTS Listening theo lộ trình Vượt ải (Gamified Stages)
  static final List<ListeningLessonModel> sampleListeningLessons = [
    ListeningLessonModel(
      id: 'l1',
      stageNumber: 1,
      difficultyLabel: 'Ải 1: Cơ bản (Band 6.0)',
      title: 'Campus Library Orientation & AI Resources',
      topic: 'Education & Student Support',
      bandScoreTarget: '6.5',
      passScoreRequired: 2, // Cần đúng ít nhất 2/3 câu để vượt ải
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
          'Good afternoon, delegates. Welcome to the 15th Annual International Technology Forum. '
          'Our keynote speaker today will discuss recent breakthroughs in mobile neural processing units and on-device machine learning models. '
          'The keynote session will commence at 2:30 PM in Auditorium B. '
          'Please be advised that all attendees are required to wear their conference badges during technical demonstrations. '
          'Following the keynote, interactive workshops on edge computing will take place in Hall C from 4:00 PM.',
      questions: [
        ListeningQuestion(
          id: 1,
          questionText: 'At what time does the keynote session begin?',
          options: ['1:00 PM', '2:30 PM', '3:45 PM', '5:00 PM'],
          correctAnswer: '2:30 PM',
          explanation:
              'The script explicitly states: "The keynote session will commence at 2:30 PM in Auditorium B."',
        ),
        ListeningQuestion(
          id: 2,
          questionText: 'Where will the keynote speech take place?',
          options: ['Hall C', 'Auditorium B', 'Main Plaza', 'Computer Lab 1'],
          correctAnswer: 'Auditorium B',
          explanation:
              'The announcement specifies: "in Auditorium B."',
        ),
        ListeningQuestion(
          id: 3,
          questionText: 'What topic will be covered in the workshops starting from 4:00 PM?',
          options: ['Quantum encryption', 'Edge computing', 'Web development', 'Cybersecurity law'],
          correctAnswer: 'Edge computing',
          explanation:
              'The script states: "interactive workshops on edge computing will take place in Hall C from 4:00 PM."',
        ),
      ],
    ),
    ListeningLessonModel(
      id: 'l3',
      stageNumber: 3,
      difficultyLabel: 'Ải 3: Nâng cao (Band 7.5)',
      title: 'Renewable Energy & Sustainable Campus Plan',
      topic: 'Environment & Engineering',
      bandScoreTarget: '7.5',
      passScoreRequired: 2,
      audioScript:
          'Good morning everyone. As part of our green campus transformation, the university council has approved a comprehensive renewable energy roadmap. '
          'By the end of this academic year, 60% of our electricity will be derived from rooftop solar photovoltaic panels installed on the engineering complex. '
          'Furthermore, our food waste composting project will convert campus dining scraps into organic fertilizer for botanical gardens. '
          'Students participating in the eco-ambassador program will receive certificate recognition and 15 credit hours towards sustainability fieldwork.',
      questions: [
        ListeningQuestion(
          id: 1,
          questionText: 'What percentage of campus electricity will come from solar panels by year-end?',
          options: ['30%', '45%', '60%', '85%'],
          correctAnswer: '60%',
          explanation:
              'The speaker announces: "60% of our electricity will be derived from rooftop solar photovoltaic panels."',
        ),
        ListeningQuestion(
          id: 2,
          questionText: 'What will food waste from campus dining halls be converted into?',
          options: ['Biofuel for buses', 'Organic fertilizer', 'Animal feed', 'Recycled packaging'],
          correctAnswer: 'Organic fertilizer',
          explanation:
              'The script mentions: "convert campus dining scraps into organic fertilizer for botanical gardens."',
        ),
        ListeningQuestion(
          id: 3,
          questionText: 'How many fieldwork credit hours do eco-ambassador students receive?',
          options: ['5 credit hours', '10 credit hours', '15 credit hours', '20 credit hours'],
          correctAnswer: '15 credit hours',
          explanation:
              'The speaker states: "receive certificate recognition and 15 credit hours towards sustainability fieldwork."',
        ),
      ],
    ),
    ListeningLessonModel(
      id: 'l4',
      stageNumber: 4,
      difficultyLabel: 'Ải 4: Chuyên sâu (Band 8.0)',
      title: 'University Accommodation & Student Welfare Services',
      topic: 'Campus Living & Support',
      bandScoreTarget: '8.0',
      passScoreRequired: 2,
      audioScript:
          'Hello incoming postgraduates, this is an advisory briefing from Student Residential Services. '
          'For students residing in North Hall apartments, high-speed fiber internet and water utilities are fully inclusive within your weekly rental tariff. '
          'However, laundry tokens must be purchased via the resident mobile portal at 2.50 pounds per cycle. '
          'A quiet study curfew is strictly enforced across all residential corridors from 11:00 PM until 7:00 AM daily. '
          'Should you require mental health counseling or peer mentoring, our 24-hour welfare reception desk is situated in Block E.',
      questions: [
        ListeningQuestion(
          id: 1,
          questionText: 'Which utility is explicitly included in the weekly rental tariff?',
          options: ['Laundry tokens', 'High-speed fiber internet', 'Gym membership', 'Parking permit'],
          correctAnswer: 'High-speed fiber internet',
          explanation:
              'The speaker notes: "high-speed fiber internet and water utilities are fully inclusive within your weekly rental tariff."',
        ),
        ListeningQuestion(
          id: 2,
          questionText: 'What are the quiet curfew hours observed in the residential halls?',
          options: [
            '10:00 PM to 6:00 AM',
            '11:00 PM to 7:00 AM',
            '12:00 AM to 8:00 AM',
            '9:00 PM to 5:00 AM'
          ],
          correctAnswer: '11:00 PM to 7:00 AM',
          explanation:
              'The script states: "A quiet study curfew is strictly enforced across all residential corridors from 11:00 PM until 7:00 AM daily."',
        ),
        ListeningQuestion(
          id: 3,
          questionText: 'Where is the 24-hour welfare reception desk located?',
          options: ['Block A', 'Block C', 'Block E', 'Block G'],
          correctAnswer: 'Block E',
          explanation:
              'The briefing mentions: "our 24-hour welfare reception desk is situated in Block E."',
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
      passScoreRequired: 3, // Cần đúng 3/3 câu để vượt qua Boss Stage!
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
          explanation:
              'The speaker highlights: "with an unprecedented 98.4% diagnostic accuracy."',
        ),
        ListeningQuestion(
          id: 2,
          questionText: 'How quickly does the system generate diagnostic heatmaps?',
          options: ['Within 5 seconds', 'Within 12 seconds', 'Within 45 seconds', 'Within 2 minutes'],
          correctAnswer: 'Within 12 seconds',
          explanation:
              'The script states: "this algorithmic pipeline generates diagnostic heatmaps within 12 seconds."',
        ),
        ListeningQuestion(
          id: 3,
          questionText: 'What primary regulatory challenge was highlighted by the symposium presenter?',
          options: [
            'Software licensing fees',
            'Data privacy and algorithmic transparency',
            'Lack of hospital server equipment',
            'Shortage of medical students'
          ],
          correctAnswer: 'Data privacy and algorithmic transparency',
          explanation:
              'The presenter concludes: "The chief regulatory obstacle currently centers around data privacy compliance and international algorithmic transparency standards."',
        ),
      ],
    ),
  ];

  /// Danh sách bài luyện IELTS Speaking
  static final List<SpeakingLessonModel> sampleSpeakingLessons = [
    SpeakingLessonModel(
      id: 's1',
      title: 'Artificial Intelligence in Everyday Life',
      topic: 'Technology & Daily Routine',
      bandScoreTarget: '7.5',
      part1Questions: [
        SpeakingPart1Item(
          question: 'Do you frequently use artificial intelligence in your daily routine?',
          sampleAnswer:
              'To be completely honest, I utilize AI-powered applications on a daily basis, especially when organizing my study schedule and translating academic materials. It notably enhances my learning productivity.',
          translation:
              'Thành thật mà nói, tôi sử dụng các ứng dụng hỗ trợ AI hàng ngày, đặc biệt là khi sắp xếp lịch học và dịch tài liệu học thuật. Nó giúp nâng cao rõ rệt hiệu suất học tập của tôi.',
          keyVocabulary: [
            'utilize (sử dụng)',
            'AI-powered (vận hành bởi AI)',
            'notably enhances (nâng cao rõ rệt)',
            'productivity (hiệu suất làm việc)',
          ],
        ),
        SpeakingPart1Item(
          question: 'Do you think AI will alter the future of classroom education?',
          sampleAnswer:
              'Undoubtedly yes. I firmly believe adaptive learning platforms will provide personalized education tailored to individual cognitive paces, though traditional teachers remain indispensable.',
          translation:
              'Chắc chắn là có. Tôi tin chắc rằng các nền tảng học tập thích ứng sẽ mang lại nền giáo dục được cá nhân hóa phù hợp với nhịp độ nhận thức của từng người, dù thầy cô giáo truyền thống vẫn không thể thiếu.',
          keyVocabulary: [
            'undoubtedly (chắc chắn)',
            'adaptive learning (học tập thích ứng)',
            'tailored to (được điều chỉnh theo)',
            'indispensable (không thể thiếu)',
          ],
        ),
      ],
      part2CueCardPrompt:
          'Describe a piece of technology that you find extremely useful in your studies.',
      part2BulletPoints: [
        'What the technology is',
        'How often you use it',
        'What you use it for',
        'And explain why you consider it invaluable to your academic progress.',
      ],
      part2SampleAnswer:
          'I would like to talk about an AI-driven vision application that I use almost every single day. '
          'This cutting-edge tool allows me to point my smartphone camera at real-world objects to instantly retrieve their academic English equivalents, collocations, and pronunciation models. '
          'I initially discovered it when preparing for the IELTS examination, and it has revolutionized the way I acquire vocabulary. '
          'Rather than memorizing monotonous word lists, I can now contextualize new terminology visually. '
          'Ultimately, this interactive methodology has substantially boosted my lexical retention and confidence in academic discourse.',
      part2SampleTranslation:
          'Tôi muốn chia sẻ về một ứng dụng thị giác điều khiển bởi AI mà tôi sử dụng gần như mỗi ngày. '
          'Công cụ tiên tiến này cho phép tôi hướng camera điện thoại vào các đồ vật ngoài đời thực để nhận diện ngay các từ vựng học thuật tiếng Anh tương đương, các cụm collocations và ngữ điệu phát âm mẫu. '
          'Ban đầu tôi biết đến nó khi ôn thi IELTS, và nó đã cách mạng hóa cách tôi tiếp thu từ vựng. '
          'Thay vì học vẹt danh sách từ đơn điệu, giờ đây tôi có thể ghi nhớ thuật ngữ trực quan. '
          'Nhờ phương pháp tương tác này, khả năng ghi nhớ từ vựng và sự tự tin trong giao tiếp học thuật của tôi đã tăng lên đáng kể.',
      part2Collocations: [
        'cutting-edge tool (công cụ tiên tiến nhất)',
        'contextualize visually (ghi nhớ trực quan theo ngữ cảnh)',
        'lexical retention (sự ghi nhớ từ vựng dài hạn)',
        'academic discourse (giao tiếp học thuật chuẩn mực)',
      ],
    ),
    SpeakingLessonModel(
      id: 's2',
      title: 'Environmental Protection & Sustainable Living',
      topic: 'Environment & Nature',
      bandScoreTarget: '8.0',
      part1Questions: [
        SpeakingPart1Item(
          question: 'What do you personally do to help protect the environment?',
          sampleAnswer:
              'I consistently strive to minimize my carbon footprint by opting for public transportation and strictly avoiding single-use plastics in my grocery shopping.',
          translation:
              'Tôi luôn nỗ lực giảm thiểu lượng khí thải carbon bằng cách ưu tiên phương tiện công cộng và kiên quyết không dùng đồ nhựa một lần khi đi mua sắm.',
          keyVocabulary: [
            'carbon footprint (dấu chân carbon)',
            'opting for (lựa chọn ưu tiên)',
            'single-use plastics (nhựa dùng một lần)',
          ],
        ),
      ],
      part2CueCardPrompt:
          'Describe an environmental law or initiative that you believe is effective.',
      part2BulletPoints: [
        'What the initiative is',
        'Where it is implemented',
        'How people react to it',
        'And explain why you think it contributes to environmental conservation.',
      ],
      part2SampleAnswer:
          'I would like to highlight the municipal ban on non-biodegradable plastic bags introduced in major cities. '
          'This initiative encourages consumers to adopt reusable canvas totes when frequenting supermarkets. '
          'While initially met with slight reluctance, citizens have gradually embraced this sustainable habit. '
          'In my view, such policy interventions are paramount in curbing urban landfill saturation and mitigating marine pollution.',
      part2SampleTranslation:
          'Tôi muốn nói về lệnh cấm túi nilon khó phân hủy tại các thành phố lớn. Sáng kiến này khuyến khích người tiêu dùng chuyển sang dùng túi vải tái sử dụng khi đi siêu thị. Dù ban đầu còn chút bỡ ngỡ, người dân đã dần hình thành thói quen sống xanh này. Theo tôi, chính sách này vô cùng then chốt để hạn chế rác thải đô thị và bảo vệ đại dương.',
      part2Collocations: [
        'non-biodegradable (khó phân hủy sinh học)',
        'sustainable habit (thói quen sống bền vững)',
        'policy intervention (sự can thiệp chính sách)',
        'mitigating pollution (giảm thiểu ô nhiễm)',
      ],
    ),
  ];

  /// Danh sách bài luyện IELTS Writing
  static final List<WritingLessonModel> sampleWritingLessons = [
    WritingLessonModel(
      id: 'w1',
      taskType: 'Task 1',
      title: 'Internet Access in Households (2015 - 2025)',
      topic: 'Technology & Demographics',
      bandScoreTarget: '7.5',
      prompt:
          'The chart illustrates the percentage of households with internet access across urban and rural areas from 2015 to 2025. Summarise the information by selecting and reporting the main features, and make comparisons where relevant. Write at least 150 words.',
      minWordCount: 150,
      suggestedTimeMinutes: 20,
      keyOutline: [
        'Introduction: Paraphrase đề bài (The line graph delineates...)',
        'Overview: Nêu 2 xu hướng chính (Cả 2 khu vực đều tăng mạnh, khoảng cách thu hẹp)',
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
          'Nhìn chung, cả hai khu vực đều ghi nhận xu hướng tăng trưởng rõ rệt. Đáng chú ý, mặc dù khu vực thành thị luôn duy trì tỷ lệ kết nối cao hơn, khoảng cách giữa hai nhóm đã được thu hẹp đáng kể vào cuối giai đoạn.\n\n'
          'Vào năm 2015, khoảng 65% hộ gia đình ở thành thị có internet, trong khi tỷ lệ này ở nông thôn chỉ khiêm tốn ở mức 30%. Trong 5 năm tiếp theo, tỷ lệ này ở thành thị tăng đều đặn vượt mốc 80% vào năm 2020. Cùng lúc đó, nông thôn chứng kiến bước nhảy vọt lên gần 55% nhờ hạ tầng viễn thông mở rộng.\n\n'
          'Đến năm 2025, mức độ phủ sóng internet ở đô thị đạt mức đỉnh ấn tượng 92%. Ngược lại, nông thôn tiếp tục tăng tốc đạt 78%, qua đó thu hẹp đáng kể khoảng cách số xuống chỉ còn 14 điểm phần trăm.',
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
      taskType: 'Task 2',
      title: 'Will AI and Automation Replace Human Teachers?',
      topic: 'Education & Future Society',
      bandScoreTarget: '8.0',
      prompt:
          'Some people believe that advancements in artificial intelligence and automation will eventually render human teachers obsolete in classrooms. To what extent do you agree or disagree? Write at least 250 words.',
      minWordCount: 250,
      suggestedTimeMinutes: 40,
      keyOutline: [
        'Introduction: Dẫn dắt vấn đề & khẳng định quan điểm kịch liệt phản đối (Strongly Disagree)',
        'Body 1: Thừa nhận thế mạnh của AI trong việc cá nhân hóa bài tập và chấm điểm tự động',
        'Body 2: Khẳng định vai trò không thể thay thế của giáo viên (truyền cảm hứng, đạo đức, thấu cảm)',
        'Conclusion: Khẳng định AI chỉ là công cụ bổ trợ (augment), không thể thay thế con người',
      ],
      sampleEssay:
          'In recent years, the rapid proliferation of artificial intelligence has sparked widespread debate regarding whether automated platforms will eventually replace human educators in academic institutions. While I acknowledge the immense computational benefits of AI, I firmly disagree with the assertion that human teachers will ever become obsolete.\n\n'
          'On the one hand, AI-powered tools offer undeniable pedagogical advantages in optimizing individualized learning. Algorithms can instantaneously diagnose a student’s cognitive weaknesses, customize practice modules, and deliver real-time feedback on repetitive grammatical drills. This computational efficiency significantly relieves educators from administrative burdens and ensures that learners absorb fundamental concepts at their own unique pacing.\n\n'
          'On the other hand, education transcends mere information dissemination; it is fundamentally a social and emotional journey. Human teachers impart critical life virtues such as empathy, resilience, and ethical discernment—qualities that no synthesized algorithm can replicate. Furthermore, an inspirational teacher possesses the emotional intelligence to perceive subtle signs of anxiety or frustration in a struggling student, providing timely mentorship and motivation that machines are fundamentally incapable of offering.\n\n'
          'In conclusion, although artificial intelligence will undoubtedly transform modern pedagogy by automating routine instructional tasks, it should function as an augmenting tool rather than a replacement. The profound emotional bond and moral guidance provided by human teachers remain irreplaceable in holistic education.',
      sampleTranslation:
          'Những năm gần đây, sự phát triển bùng nổ của trí tuệ nhân tạo đã làm dấy lên những tranh luận về việc liệu máy móc có thể thay thế giáo viên trong tương lai hay không. Mặc dù công nhận những lợi ích to lớn của AI, tôi hoàn toàn phản đối quan điểm cho rằng giáo viên con người sẽ trở nên lỗi thời.\n\n'
          'Một mặt, các công cụ AI mang lại lợi thế sư phạm rõ rệt trong việc cá nhân hóa việc học. Thuật toán có thể chẩn đoán ngay điểm yếu nhận thức của học sinh, tùy biến bài tập và phản hồi tức thì. Điều này giúp giải phóng giáo viên khỏi gánh nặng hành chính và giúp học sinh học tập theo đúng nhịp độ của mình.\n\n'
          'Mặt khác, giáo dục không chỉ đơn thuần là truyền thụ thông tin mà còn là một hành trình cảm xúc và xã hội. Thầy cô giáo dạy cho học sinh lòng trắc ẩn, tính kiên cường và các giá trị đạo đức—những điều mà không thuật toán nào có thể mô phỏng. Hơn nữa, giáo viên có trí tuệ cảm xúc để thấu hiểu sự lo âu của học trò và động viên kịp thời.\n\n'
          'Tóm lại, dù AI sẽ làm thay đổi giáo dục bằng việc tự động hóa các tác vụ lặp đi lặp lại, nó chỉ nên đóng vai trò là công cụ bổ trợ thay vì thay thế. Sự gắn kết cảm xúc và sự dẫn dắt đạo đức của thầy cô vẫn luôn là điều vô giá và không thể thay thế.',
      academicVocabulary: [
        'proliferation (sự bùng nổ phát triển)',
        'obsolete (lỗi thời, bị đào thải)',
        'pedagogical advantages (lợi thế sư phạm)',
        'transcends mere information (vượt lên trên thông tin đơn thuần)',
        'ethical discernment (sự nhận thức đạo đức)',
        'holistic education (giáo dục toàn diện)',
      ],
    ),
  ];
}

