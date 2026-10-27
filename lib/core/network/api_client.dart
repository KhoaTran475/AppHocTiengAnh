import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_endpoints.dart';

/// Client mạng trung tâm sử dụng Dio với Auth Interceptor tự động gắn JWT Token
class ApiClient {
  static final ApiClient instance = ApiClient._init();
  late final Dio dio;

  ApiClient._init() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 7),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _loadSavedBaseUrl();

    // Bổ sung Auth Interceptor tự động nạp Token từ SharedPreferences
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('access_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          log('🌐 [DIO REQ] ${options.method} ${options.uri}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          log('✅ [DIO RES] ${response.statusCode} ${response.requestOptions.path}');
          return handler.next(response);
        },
        onError: (DioException error, handler) async {
          log('❌ [DIO ERR] ${error.response?.statusCode} ${error.requestOptions.path}: ${error.message}');
          if (error.response?.statusCode == 401) {
            // Token hết hạn -> Xóa token lưu trữ
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('access_token');
            await prefs.remove('userId');
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<void> _loadSavedBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final customUrl = prefs.getString('custom_base_url');
    if (customUrl != null && customUrl.isNotEmpty) {
      setBaseUrl(customUrl, persist: false);
    }
  }

  /// Cập nhật Base URL khi đổi môi trường
  void setBaseUrl(String newUrl, {bool persist = true}) {
    ApiEndpoints.baseUrl = newUrl;
    dio.options.baseUrl = newUrl;
    if (persist) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('custom_base_url', newUrl);
      });
    }
  }
}
