import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../data/datasources/api_service.dart';
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
    final token = prefs.getString('access_token');
    if (token != null && token.isNotEmpty) {
      try {
        final user = await ApiService.instance.getMe();
        if (user != null) {
          _currentUser = user;
          notifyListeners();
          return;
        }
      } catch (e) {
        log('Lỗi khôi phục phiên đăng nhập từ API: $e');
      }
    }

    final localUserId = prefs.getInt('userId');
    if (localUserId != null) {
      final allUsers = await DatabaseHelper.instance.getAllUsers();
      final match = allUsers.where((u) => u.id == localUserId);
      if (match.isNotEmpty) {
        _currentUser = match.first;
        notifyListeners();
      }
    }
  }

  Future<String?> login(String username, String password) async {
    _setLoading(true);
    try {
      final res = await ApiService.instance.login(username, password);
      final token = res['token'] as String;
      final user = res['user'] as UserModel;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);
      if (user.id != null) {
        await prefs.setInt('userId', user.id!);
      }

      _currentUser = user;
      notifyListeners();
      return null; // Thành công qua Backend
    } catch (e) {
      log('⚠️ Không thể kết nối API Server: $e. Thử đăng nhập Cục bộ...');
      
      // Fallback 1: Thử đối soát với SQLite Cục bộ
      try {
        final localUser = await DatabaseHelper.instance.getUserByCredentials(username, password);
        if (localUser != null) {
          _currentUser = localUser;
          final prefs = await SharedPreferences.getInstance();
          if (localUser.id != null) {
            await prefs.setInt('userId', localUser.id!);
          }
          notifyListeners();
          return null; // Đăng nhập offline thành công!
        }
      } catch (dbErr) {
        log('Lỗi xác thực offline: $dbErr');
      }

      final errStr = e.toString().replaceAll('Exception: ', '');
      if (errStr.contains('timeout') || errStr.contains('SocketException') || errStr.contains('connectTimeout') || errStr.contains('connection')) {
        return 'Không thể kết nối Backend (${ApiEndpoints.baseUrl}).\n\n💡 Gợi ý:\n1. Đảm bảo điện thoại và máy tính kết nối CÙNG MẠNG WI-FI.\n2. Nhấn nút ⚙️ (Cài đặt Server) góc trên để chọn đúng IP máy tính.';
      }
      return errStr;
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> register(String username, String password, {bool isAdmin = false}) async {
    _setLoading(true);
    try {
      final res = await ApiService.instance.register(username, password, isAdmin: isAdmin);
      final token = res['token'] as String;
      final user = res['user'] as UserModel;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);
      if (user.id != null) {
        await prefs.setInt('userId', user.id!);
      }

      _currentUser = user;
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> loginWithFace({
    required String imageBase64,
    required String nonce,
    String? usernameHint,
  }) async {
    _setLoading(true);
    try {
      final res = await ApiService.instance.loginWithFace(
        imageBase64: imageBase64,
        nonce: nonce,
        usernameHint: usernameHint,
      );
      final token = res['token'] as String;
      final user = res['user'] as UserModel;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);
      if (user.id != null) {
        await prefs.setInt('userId', user.id!);
      }

      _currentUser = user;
      notifyListeners();
      return null; // Đăng nhập FaceID thành công
    } catch (e) {
      log('Lỗi đăng nhập FaceID: $e');
      return e.toString().replaceAll('Exception: ', '');
    } finally {
      _setLoading(false);
    }
  }

  /// Cập nhật cờ FaceID trong user state hiện tại mà không cần re-login
  void updateFaceAuthStatus({required bool isEnabled, String? registeredAt}) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        isFaceAuthEnabled: isEnabled,
        faceRegisteredAt: registeredAt ?? (isEnabled ? DateTime.now().toIso8601String() : null),
      );
      notifyListeners();
    }
  }

  /// Làm mới thông tin user từ Backend
  Future<void> refreshCurrentUser() async {
    try {
      final user = await ApiService.instance.getMe();
      if (user != null) {
        _currentUser = user;
        notifyListeners();
      }
    } catch (e) {
      log('Lỗi làm mới user info: $e');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('userId');
    _currentUser = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
