import 'package:supabase_flutter/supabase_flutter.dart';

/// Class cấu hình và quản lý kết nối Supabase toàn cục.
class SupabaseConfig {
  static const String url = 'https://tcbcmzfdidcwblvfmckb.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRjYmNtemZkaWRjd2JsdmZtY2tiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEyNzE4NTQsImV4cCI6MjEwNjg0Nzg1NH0.0nVR69yNJhNMDFXRpED4R6qHfsNMfMlcKJOURYojn6c';

  /// Khởi tạo kết nối Supabase khi ứng dụng bắt đầu
  static Future<void> init() async {
    await Supabase.initialize(
      url: url,
      publishableKey: anonKey,
    );
  }

  /// Getter lấy đối tượng SupabaseClient
  static SupabaseClient get client => Supabase.instance.client;
}
