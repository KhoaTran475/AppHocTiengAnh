import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/supabase_config.dart';
import '../../../core/services/notebook_service.dart';
import '../../../data/models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    if (userId != null) {
      final db = await DatabaseHelper.instance.database;
      final maps = await db.query(
        'Users',
        where: 'id = ?',
        whereArgs: [userId],
      );
      if (maps.isNotEmpty) {
        _currentUser = UserModel.fromMap(maps.first);
        notifyListeners();
      }
    }

    // Tự động đồng bộ các tài khoản nội bộ lên Supabase profiles
    await DatabaseHelper.instance.syncAllUsersToSupabase();

    // Tự động đồng bộ Sổ tay từ vựng lên Supabase Cloud nếu đã đăng nhập
    if (_currentUser != null && _currentUser!.id != null) {
      NotebookService.syncNotebook(
        localUserId: _currentUser!.id!,
        username: _currentUser!.username,
      );
    }
  }

  Future<String?> login(String username, String password) async {
    _setLoading(true);
    try {
      final db = await DatabaseHelper.instance.database;
      final maps = await db.query(
        'Users',
        where: 'username = ? AND password = ?',
        whereArgs: [username, password],
      );

      if (maps.isNotEmpty) {
        _currentUser = UserModel.fromMap(maps.first);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('userId', _currentUser!.id!);

        // Đồng bộ sổ tay ngay sau khi đăng nhập thành công
        NotebookService.syncNotebook(
          localUserId: _currentUser!.id!,
          username: _currentUser!.username,
        );

        return null; // Không có lỗi
      } else {
        return 'Tài khoản hoặc mật khẩu không chính xác';
      }
    } catch (e) {
      return 'Có lỗi xảy ra: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> register(String username, String password, {bool isAdmin = false}) async {
    _setLoading(true);
    try {
      final db = await DatabaseHelper.instance.database;
      // Kiểm tra trùng username
      final check = await db.query('Users', where: 'username = ?', whereArgs: [username]);
      if (check.isNotEmpty) return 'Tên đăng nhập đã tồn tại';

      final roleStr = isAdmin ? 'admin' : 'learner';
      final nowStr = DateTime.now().toIso8601String();

      final newUser = {
        'username': username,
        'password': password,
        'role': roleStr,
        'createdAt': nowStr,
      };
      
      final id = await db.insert('Users', newUser);
      
      _currentUser = UserModel(
        id: id,
        username: username,
        role: roleStr,
        createdAt: nowStr,
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('userId', id);

      // 🌐 ĐỒNG BỘ ĐẨY DỮ LIỆU TÀI KHOẢN ĐĂNG KÝ LÊN SUPABASE (PROFILES)
      try {
        // 1. Thử đăng ký Supabase Auth (tạo user trong auth.users)
        try {
          await SupabaseConfig.client.auth.signUp(
            email: '$username@app.com',
            password: password,
            data: {'username': username, 'role': roleStr},
          );
        } catch (_) {}

        // 2. Thử upsert trực tiếp vào bảng public.profiles
        await SupabaseConfig.client.from('profiles').upsert({
          'username': username,
          'role': roleStr,
          'created_at': nowStr,
          'updated_at': nowStr,
        }, onConflict: 'username');
        log('✅ Đã đồng bộ tài khoản "$username" ($roleStr) lên Supabase profiles!');
      } catch (e) {
        log('⚠️ Lỗi đồng bộ tài khoản lên Supabase: $e');
      }

      return null;
    } catch (e) {
      return 'Có lỗi xảy ra: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    _currentUser = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
