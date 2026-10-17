import 'dart:convert';
import 'dart:developer';
import 'dart:io';

class DictionaryEntry {
  final String word;
  final String ipa;
  final String vietnameseMeaning;
  final String partOfSpeech;
  final String? bandScore;
  final String? example;

  const DictionaryEntry({
    required this.word,
    required this.ipa,
    required this.vietnameseMeaning,
    this.partOfSpeech = 'academic word',
    this.bandScore = '7.0+',
    this.example,
  });
}

/// Dịch vụ tra cứu từ điển học thuật IELTS: Hỗ trợ Offline Local Dictionary + Online Fallback
class DictionaryService {
  static final Map<String, DictionaryEntry> _memoryCache = {};

  /// Bộ từ điển cục bộ các thuật ngữ học thuật thường gặp trong IELTS Reading
  static final Map<String, DictionaryEntry> _localDictionary = {
    'intelligence': const DictionaryEntry(
      word: 'intelligence',
      ipa: '/ɪnˈtel.ɪ.dʒəns/',
      vietnameseMeaning: 'Trí thông minh, sự hiểu biết, năng lực trí tuệ',
      partOfSpeech: 'noun',
      bandScore: '7.5',
      example: 'Artificial Intelligence is revolutionizing modern education.',
    ),
    'artificial': const DictionaryEntry(
      word: 'artificial',
      ipa: '/ˌɑː.tɪˈfɪʃ.əl/',
      vietnameseMeaning: 'Nhân tạo, do con người chế tạo',
      partOfSpeech: 'adjective',
      bandScore: '7.0',
    ),
    'education': const DictionaryEntry(
      word: 'education',
      ipa: '/ˌedʒ.ʊˈkeɪ.ʃən/',
      vietnameseMeaning: 'Nền giáo dục, sự đào tạo, rèn luyện',
      partOfSpeech: 'noun',
      bandScore: '6.5',
    ),
    'altering': const DictionaryEntry(
      word: 'altering',
      ipa: '/ˈɔːl.tər.ɪŋ/',
      vietnameseMeaning: 'Đang thay đổi, làm biến đổi',
      partOfSpeech: 'verb',
      bandScore: '7.5',
    ),
    'alter': const DictionaryEntry(
      word: 'alter',
      ipa: '/ˈɔːl.tər/',
      vietnameseMeaning: 'Thay đổi, biến đổi bản chất',
      partOfSpeech: 'verb',
      bandScore: '7.5',
    ),
    'landscape': const DictionaryEntry(
      word: 'landscape',
      ipa: '/ˈlænd.skeɪp/',
      vietnameseMeaning: 'Bối cảnh, diện mạo, cảnh quan',
      partOfSpeech: 'noun',
      bandScore: '7.0',
    ),
    'leveraging': const DictionaryEntry(
      word: 'leveraging',
      ipa: '/ˈliː.vər.ɪdʒ.ɪŋ/',
      vietnameseMeaning: 'Tận dụng, phát huy tối đa sức mạnh',
      partOfSpeech: 'verb',
      bandScore: '8.0',
    ),
    'leverage': const DictionaryEntry(
      word: 'leverage',
      ipa: '/ˈliː.vər.ɪdʒ/',
      vietnameseMeaning: 'Tận dụng, sử dụng đòn bẩy',
      partOfSpeech: 'verb / noun',
      bandScore: '8.0',
    ),
    'advanced': const DictionaryEntry(
      word: 'advanced',
      ipa: '/ədˈvɑːnst/',
      vietnameseMeaning: 'Tiên tiến, nâng cao, cấp cao',
      partOfSpeech: 'adjective',
      bandScore: '7.0',
    ),
    'machine': const DictionaryEntry(
      word: 'machine',
      ipa: '/məˈʃiːn/',
      vietnameseMeaning: 'Máy móc, cơ cấu máy',
      partOfSpeech: 'noun',
      bandScore: '6.5',
    ),
    'learning': const DictionaryEntry(
      word: 'learning',
      ipa: '/ˈlɜː.nɪŋ/',
      vietnameseMeaning: 'Sự học tập, sự tiếp thu kiến thức',
      partOfSpeech: 'noun',
      bandScore: '6.5',
    ),
    'algorithm': const DictionaryEntry(
      word: 'algorithm',
      ipa: '/ˈæl.ɡə.rɪ.ðəm/',
      vietnameseMeaning: 'Thuật toán, giải thuật tính toán',
      partOfSpeech: 'noun',
      bandScore: '7.5',
    ),
    'algorithms': const DictionaryEntry(
      word: 'algorithms',
      ipa: '/ˈæl.ɡə.rɪ.ðəmz/',
      vietnameseMeaning: 'Các thuật toán, giải thuật',
      partOfSpeech: 'noun',
      bandScore: '7.5',
    ),
    'platforms': const DictionaryEntry(
      word: 'platforms',
      ipa: '/ˈplæt.fɔːmz/',
      vietnameseMeaning: 'Các nền tảng, hệ thống phần mềm',
      partOfSpeech: 'noun',
      bandScore: '7.0',
    ),
    'platform': const DictionaryEntry(
      word: 'platform',
      ipa: '/ˈplæt.fɔːm/',
      vietnameseMeaning: 'Nền tảng, diễn đàn',
      partOfSpeech: 'noun',
      bandScore: '7.0',
    ),
    'tailor': const DictionaryEntry(
      word: 'tailor',
      ipa: '/ˈteɪ.lər/',
      vietnameseMeaning: 'May đo, điều chỉnh thiết kế theo yêu cầu riêng',
      partOfSpeech: 'verb',
      bandScore: '7.5',
    ),
    'materials': const DictionaryEntry(
      word: 'materials',
      ipa: '/məˈtɪə.ri.əlz/',
      vietnameseMeaning: 'Tài liệu, giáo trình, học liệu',
      partOfSpeech: 'noun',
      bandScore: '6.5',
    ),
    'individual': const DictionaryEntry(
      word: 'individual',
      ipa: '/ˌɪn.dɪˈvɪdʒ.u.əl/',
      vietnameseMeaning: 'Cá nhân, riêng biệt từng người',
      partOfSpeech: 'adjective / noun',
      bandScore: '7.0',
    ),
    'pacing': const DictionaryEntry(
      word: 'pacing',
      ipa: '/ˈpeɪ.sɪŋ/',
      vietnameseMeaning: 'Nhịp độ, tốc độ tiếp thu',
      partOfSpeech: 'noun',
      bandScore: '7.5',
    ),
    'cognitive': const DictionaryEntry(
      word: 'cognitive',
      ipa: '/ˈkɒɡ.nə.tɪv/',
      vietnameseMeaning: 'Thuộc về nhận thức, tư duy trí tuệ',
      partOfSpeech: 'adjective',
      bandScore: '8.0',
    ),
    'strengths': const DictionaryEntry(
      word: 'strengths',
      ipa: '/streŋkθs/',
      vietnameseMeaning: 'Thế mạnh, điểm mạnh',
      partOfSpeech: 'noun',
      bandScore: '7.0',
    ),
    'adaptive': const DictionaryEntry(
      word: 'adaptive',
      ipa: '/əˈdæp.tɪv/',
      vietnameseMeaning: 'Có khả năng thích ứng, tự điều chỉnh',
      partOfSpeech: 'adjective',
      bandScore: '7.5',
    ),
    'technology': const DictionaryEntry(
      word: 'technology',
      ipa: '/tekˈnɒl.ə.dʒi/',
      vietnameseMeaning: 'Công nghệ, kỹ thuật hiện đại',
      partOfSpeech: 'noun',
      bandScore: '6.5',
    ),
    'ensures': const DictionaryEntry(
      word: 'ensures',
      ipa: '/ɪnˈʃʊəz/',
      vietnameseMeaning: 'Đảm bảo, chắc chắn đem lại',
      partOfSpeech: 'verb',
      bandScore: '7.0',
    ),
    'absorb': const DictionaryEntry(
      word: 'absorb',
      ipa: '/əbˈzɔːb/',
      vietnameseMeaning: 'Hấp thu, tiếp thu kiến thức',
      partOfSpeech: 'verb',
      bandScore: '7.5',
    ),
    'complex': const DictionaryEntry(
      word: 'complex',
      ipa: '/ˈkɒm.pleks/',
      vietnameseMeaning: 'Phức tạp, chuyên sâu, đa thành phần',
      partOfSpeech: 'adjective',
      bandScore: '7.0',
    ),
    'academic': const DictionaryEntry(
      word: 'academic',
      ipa: '/ˌæk.əˈdem.ɪk/',
      vietnameseMeaning: 'Thuộc học thuật, viện hàn lâm',
      partOfSpeech: 'adjective',
      bandScore: '7.0',
    ),
    'concepts': const DictionaryEntry(
      word: 'concepts',
      ipa: '/ˈkɒn.septs/',
      vietnameseMeaning: 'Các khái niệm, nguyên lý cơ bản',
      partOfSpeech: 'noun',
      bandScore: '7.0',
    ),
    'efficiently': const DictionaryEntry(
      word: 'efficiently',
      ipa: '/ɪˈfɪʃ.ənt.li/',
      vietnameseMeaning: 'Một cách hiệu quả, tối ưu thời gian',
      partOfSpeech: 'adverb',
      bandScore: '7.5',
    ),
    'overwhelmed': const DictionaryEntry(
      word: 'overwhelmed',
      ipa: '/ˌəʊ.vəˈwelmd/',
      vietnameseMeaning: 'Bị choáng ngợp, quá tải',
      partOfSpeech: 'adjective',
      bandScore: '7.5',
    ),
    'vision': const DictionaryEntry(
      word: 'vision',
      ipa: '/ˈvɪʒ.ən/',
      vietnameseMeaning: 'Thị giác, tầm nhìn',
      partOfSpeech: 'noun',
      bandScore: '7.0',
    ),
    'instantaneously': const DictionaryEntry(
      word: 'instantaneously',
      ipa: '/ˌɪn.stənˈteɪ.ni.əs.li/',
      vietnameseMeaning: 'Ngay lập tức, tức thời',
      partOfSpeech: 'adverb',
      bandScore: '8.0',
    ),
    'collocations': const DictionaryEntry(
      word: 'collocations',
      ipa: '/ˌkɒl.əˈkeɪ.ʃənz/',
      vietnameseMeaning: 'Các cụm từ cố định tự nhiên',
      partOfSpeech: 'noun',
      bandScore: '7.5',
    ),
    'pedagogy': const DictionaryEntry(
      word: 'pedagogy',
      ipa: '/ˈped.ə.ɡɒdʒ.i/',
      vietnameseMeaning: 'Khoa học giáo dục, phương pháp sư phạm',
      partOfSpeech: 'noun',
      bandScore: '8.5',
    ),
    'mentorship': const DictionaryEntry(
      word: 'mentorship',
      ipa: '/ˈmen.tɔː.ʃɪp/',
      vietnameseMeaning: 'Sự cố vấn, hướng dẫn cá nhân',
      partOfSpeech: 'noun',
      bandScore: '7.5',
    ),
    'augment': const DictionaryEntry(
      word: 'augment',
      ipa: '/ɔːɡˈment/',
      vietnameseMeaning: 'Gia tăng, tăng cường, bổ trợ',
      partOfSpeech: 'verb',
      bandScore: '8.0',
    ),
    'reliance': const DictionaryEntry(
      word: 'reliance',
      ipa: '/rɪˈlaɪ.əns/',
      vietnameseMeaning: 'Sự phụ thuộc, dựa dẫm',
      partOfSpeech: 'noun',
      bandScore: '7.5',
    ),
    'diminish': const DictionaryEntry(
      word: 'diminish',
      ipa: '/dɪˈmɪn.ɪʃ/',
      vietnameseMeaning: 'Làm suy giảm, thu nhỏ lại',
      partOfSpeech: 'verb',
      bandScore: '7.5',
    ),
    'critical': const DictionaryEntry(
      word: 'critical',
      ipa: '/ˈkrɪt.ɪ.kəl/',
      vietnameseMeaning: 'Tư duy phản biện, then chốt',
      partOfSpeech: 'adjective',
      bandScore: '7.5',
    ),
    'climate': const DictionaryEntry(
      word: 'climate',
      ipa: '/ˈklaɪ.mət/',
      vietnameseMeaning: 'Khí hậu',
      partOfSpeech: 'noun',
      bandScore: '6.5',
    ),
    'biodiversity': const DictionaryEntry(
      word: 'biodiversity',
      ipa: '/ˌbaɪ.əʊ.daɪˈvɜː.sə.ti/',
      vietnameseMeaning: 'Sự đa dạng sinh học',
      partOfSpeech: 'noun',
      bandScore: '8.0',
    ),
    'conservation': const DictionaryEntry(
      word: 'conservation',
      ipa: '/ˌkɒn.səˈveɪ.ʃən/',
      vietnameseMeaning: 'Sự bảo tồn, gìn giữ môi trường',
      partOfSpeech: 'noun',
      bandScore: '7.5',
    ),
    'ecosystem': const DictionaryEntry(
      word: 'ecosystem',
      ipa: '/ˈiː.kəʊˌsɪs.təm/',
      vietnameseMeaning: 'Hệ sinh thái tự nhiên',
      partOfSpeech: 'noun',
      bandScore: '7.5',
    ),
    'degradation': const DictionaryEntry(
      word: 'degradation',
      ipa: '/ˌdeɡ.rəˈdeɪ.ʃən/',
      vietnameseMeaning: 'Sự suy thoái, xuống cấp môi trường',
      partOfSpeech: 'noun',
      bandScore: '8.0',
    ),
    'extinction': const DictionaryEntry(
      word: 'extinction',
      ipa: '/ɪkˈstɪŋk.ʃən/',
      vietnameseMeaning: 'Sự tuyệt chủng của loài',
      partOfSpeech: 'noun',
      bandScore: '7.5',
    ),
    'strategies': const DictionaryEntry(
      word: 'strategies',
      ipa: '/ˈstræt.ə.dʒiz/',
      vietnameseMeaning: 'Các chiến lược, phương sách',
      partOfSpeech: 'noun',
      bandScore: '7.0',
    ),
    'sustainable': const DictionaryEntry(
      word: 'sustainable',
      ipa: '/səˈsteɪ.nə.bəl/',
      vietnameseMeaning: 'Bền vững, duy trì lâu dài',
      partOfSpeech: 'adjective',
      bandScore: '7.5',
    ),
    'emissions': const DictionaryEntry(
      word: 'emissions',
      ipa: '/iˈmɪʃ.ənz/',
      vietnameseMeaning: 'Khí thải, sự phóng thích chất thải',
      partOfSpeech: 'noun',
      bandScore: '7.5',
    ),
    'sanctuaries': const DictionaryEntry(
      word: 'sanctuaries',
      ipa: '/ˈsæŋk.tʃu.ə.riz/',
      vietnameseMeaning: 'Các khu bảo tồn, nơi trú ẩn an toàn',
      partOfSpeech: 'noun',
      bandScore: '8.0',
    ),
    'wildlife': const DictionaryEntry(
      word: 'wildlife',
      ipa: '/ˈwaɪld.laɪf/',
      vietnameseMeaning: 'Đời sống động thực vật hoang dã',
      partOfSpeech: 'noun',
      bandScore: '7.0',
    ),
    'species': const DictionaryEntry(
      word: 'species',
      ipa: '/ˈspiː.ʃiːz/',
      vietnameseMeaning: 'Loài sinh vật',
      partOfSpeech: 'noun',
      bandScore: '7.0',
    ),
  };

  /// Tra cứu từ vựng: Local Dict -> Memory Cache -> Online API Fallback
  static Future<DictionaryEntry> lookup(String rawWord) async {
    final cleanWord = rawWord.replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();
    if (cleanWord.isEmpty) {
      return DictionaryEntry(
        word: rawWord,
        ipa: '/${rawWord.toLowerCase()}/',
        vietnameseMeaning: 'Không có dữ liệu',
      );
    }

    // 1. Kiểm tra trong bộ từ điển cục bộ
    if (_localDictionary.containsKey(cleanWord)) {
      return _localDictionary[cleanWord]!;
    }

    // 2. Kiểm tra bộ nhớ đệm tạm thời
    if (_memoryCache.containsKey(cleanWord)) {
      return _memoryCache[cleanWord]!;
    }

    // 3. Fallback trực tuyến: Tra IPA và Dịch nghĩa tự động
    String ipa = '';
    String meaning = '';
    String partOfSpeech = 'vocabulary';

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);

    try {
      // 3.1. Tra IPA từ Free Dictionary API
      try {
        final dictUrl = Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/$cleanWord');
        final dictReq = await client.getUrl(dictUrl);
        final dictRes = await dictReq.close();
        if (dictRes.statusCode == 200) {
          final resStr = await dictRes.transform(utf8.decoder).join();
          final data = jsonDecode(resStr);
          if (data is List && data.isNotEmpty) {
            final firstEntry = data[0] as Map<String, dynamic>;
            ipa = firstEntry['phonetic'] as String? ?? '';
            if (ipa.isEmpty && firstEntry['phonetics'] is List) {
              for (final p in firstEntry['phonetics'] as List) {
                if (p is Map && p['text'] != null && (p['text'] as String).isNotEmpty) {
                  ipa = p['text'] as String;
                  break;
                }
              }
            }
            if (firstEntry['meanings'] is List && (firstEntry['meanings'] as List).isNotEmpty) {
              final m = firstEntry['meanings'][0] as Map<String, dynamic>;
              partOfSpeech = m['partOfSpeech'] as String? ?? 'vocabulary';
            }
          }
        }
      } catch (e) {
        log('Lỗi tra IPA từ Dictionary API: $e');
      }

      // 3.2. Tra nghĩa tiếng Việt từ Google Translate API endpoint
      try {
        final transUrl = Uri.parse(
          'https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=vi&dt=t&q=${Uri.encodeComponent(cleanWord)}',
        );
        final transReq = await client.getUrl(transUrl);
        final transRes = await transReq.close();
        if (transRes.statusCode == 200) {
          final resStr = await transRes.transform(utf8.decoder).join();
          final data = jsonDecode(resStr);
          if (data is List && data.isNotEmpty && data[0] is List) {
            final transParts = <String>[];
            for (final part in data[0] as List) {
              if (part is List && part.isNotEmpty && part[0] is String) {
                transParts.add(part[0] as String);
              }
            }
            meaning = transParts.join(' ').trim();
          }
        }
      } catch (e) {
        log('Lỗi dịch tiếng Việt: $e');
      }
    } catch (e) {
      log('Lỗi kết nối tra từ trực tuyến: $e');
    } finally {
      client.close();
    }

    if (ipa.isEmpty) {
      ipa = '/$cleanWord/';
    }
    if (meaning.isEmpty) {
      meaning = cleanWord;
    }

    final entry = DictionaryEntry(
      word: cleanWord,
      ipa: ipa,
      vietnameseMeaning: meaning,
      partOfSpeech: partOfSpeech,
      bandScore: '7.0+',
    );

    _memoryCache[cleanWord] = entry;
    return entry;
  }
}
