import 'package:flutter/material.dart';

class AppColors {
  // Primary IELTS Red
  static const Color primary = Color(0xFFD61C2C);
  // Deep Navy for text and premium feel
  static const Color navy = Color(0xFF1E293B);
  static const Color darkBackground = Color(0xFF0F172A);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFE11D48), Color(0xFF9F1239)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.navy,
        surface: Colors.grey[50]!,
      ),
      fontFamily: 'Inter', // Giả định dùng font Inter (cần cấu hình thêm nếu dùng thực tế)
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
        headlineMedium: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy),
        titleLarge: TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}
