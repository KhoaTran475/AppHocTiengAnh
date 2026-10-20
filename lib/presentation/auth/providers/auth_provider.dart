import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/database_helper.dart';
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

      final newUser = {
        'username': username,
        'password': password,
        'role': isAdmin ? 'admin' : 'learner',
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      final id = await db.insert('Users', newUser);
      
      _currentUser = UserModel(
        id: id,
        username: username,
        role: newUser['role'] as String,
        createdAt: newUser['createdAt'] as String,
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('userId', id);
      
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
