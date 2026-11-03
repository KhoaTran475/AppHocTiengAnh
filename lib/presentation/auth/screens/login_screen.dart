import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/api_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/face_scan_dialog.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Chế độ đăng nhập: 0 = Email OTP, 1 = Mật khẩu & FaceID
  int _loginMode = 0;

  // Controllers cho Đăng nhập Mật khẩu
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFormKey = GlobalKey<FormState>();

  // Controllers cho Đăng nhập Email OTP
  final _emailOtpController = TextEditingController();
  final _otpCodeController = TextEditingController();
  bool _isOtpSent = false;
  int _countdownSeconds = 0;
  Timer? _countdownTimer;

  bool _isFaceLoggingIn = false;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    _emailOtpController.dispose();
    _otpCodeController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdownSeconds = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdownSeconds > 0) {
        setState(() => _countdownSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  // ─────────────────────────────────────────────────────────────
  // 1. ĐĂNG NHẬP TRUYỀN THỐNG (MẬT KHẨU)
  // ─────────────────────────────────────────────────────────────

  Future<void> _loginWithPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final error = await auth.login(
      _usernameController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 5),
      ));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 2. ĐĂNG NHẬP EMAIL OTP (PASSWORDLESS)
  // ─────────────────────────────────────────────────────────────

  Future<void> _handleSendLoginOtp() async {
    final email = _emailOtpController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vui lòng nhập địa chỉ Email hợp lệ'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final error = await auth.sendOtp(email, type: 'login');
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: Colors.redAccent,
      ));
    } else {
      setState(() => _isOtpSent = true);
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Mã OTP đã được gửi tới $email. Vui lòng kiểm tra hộp thư!'),
        backgroundColor: Colors.green,
      ));
    }
  }

  Future<void> _handleVerifyLoginOtp() async {
    final otp = _otpCodeController.text.trim();
    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vui lòng nhập đủ 6 chữ số mã OTP'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final error = await auth.loginWithOtp(
      email: _emailOtpController.text.trim(),
      otp: otp,
    );

    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
      ));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 3. ĐĂNG NHẬP FACEID (ML KIT + ONNX)
  // ─────────────────────────────────────────────────────────────

  Future<void> _loginWithFaceId() async {
    setState(() => _isFaceLoggingIn = true);

    try {
      final String nonce = await ApiService.instance.getFaceNonce();
      if (!mounted) return;

      final scanResult = await FaceScanDialog.show(
        context,
        mode: FaceScanMode.login,
        title: 'Xác thực FaceID',
        subtitle: 'Đưa gương mặt vào khung tròn để đăng nhập',
      );

      if (scanResult == null) {
        if (mounted) setState(() => _isFaceLoggingIn = false);
        return;
      }

      if (!mounted) return;

      final auth = Provider.of<AuthProvider>(context, listen: false);
      final usernameHint = _usernameController.text.trim();

      final error = await auth.loginWithFace(
        imageBase64: scanResult.imageBase64,
        nonce: nonce,
        usernameHint: usernameHint.isNotEmpty ? usernameHint : null,
      );

      if (!mounted) return;

      if (error != null) {
        ScaffoldMessenger.of(context).clearMaterialBanners();
        ScaffoldMessenger.of(context).showMaterialBanner(
          MaterialBanner(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: const Icon(Icons.error_outline_rounded, color: Colors.white, size: 28),
            backgroundColor: const Color(0xFFE11D48),
            content: Text(
              error,
              style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            actions: [
              TextButton(
                onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
                child: const Text('ĐÓNG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: Colors.redAccent,
      ));
    } finally {
      if (mounted) setState(() => _isFaceLoggingIn = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CẤU HÌNH SERVER
  // ─────────────────────────────────────────────────────────────

  void _showServerConfigDialog(BuildContext context) {
    final controller = TextEditingController(text: ApiEndpoints.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.dns_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text('Cấu hình Server Backend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nhập địa chỉ máy tính đang chạy server FastAPI:', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Base URL', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 16),
              const Text('Gợi ý cấu hình nhanh:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.wifi, size: 16),
                    label: const Text('Wi-Fi: ${ApiEndpoints.serverHost}'),
                    onPressed: () => controller.text = 'http://${ApiEndpoints.serverHost}:8000/api/v1',
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.phone_android, size: 16),
                    label: const Text('Giả lập: 10.0.2.2'),
                    onPressed: () => controller.text = 'http://10.0.2.2:8000/api/v1',
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.computer, size: 16),
                    label: const Text('Local: 127.0.0.1'),
                    onPressed: () => controller.text = 'http://127.0.0.1:8000/api/v1',
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                ApiClient.instance.setBaseUrl(newUrl);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ Đã lưu máy chủ: $newUrl'), backgroundColor: Colors.green[700]),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Lưu & Áp dụng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            tooltip: 'Cài đặt IP Máy chủ Backend',
            onPressed: () => _showServerConfigDialog(context),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.surfaceGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.language_rounded, size: 68, color: AppColors.primary),
                  const SizedBox(height: 12),
                  const Text(
                    'IELTS Vision',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Master English with AI',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 28),

                  // Thanh chọn chế độ đăng nhập (Email OTP vs Mật khẩu)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _loginMode = 0),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _loginMode == 0 ? const Color(0xFF4F46E5) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.mail_outline_rounded,
                                      size: 18, color: _loginMode == 0 ? Colors.white : Colors.white60),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Email OTP',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: _loginMode == 0 ? Colors.white : Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _loginMode = 1),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _loginMode == 1 ? const Color(0xFF4F46E5) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock_outline_rounded,
                                      size: 18, color: _loginMode == 1 ? Colors.white : Colors.white60),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Mật khẩu & FaceID',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: _loginMode == 1 ? Colors.white : Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Nội dung Form tùy thuộc Tab được chọn
                  if (_loginMode == 0) _buildEmailOtpForm(isLoading) else _buildPasswordForm(isLoading),

                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    },
                    child: const Text(
                      'Chưa có tài khoản? Đăng ký Học viên ngay',
                      style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Giao diện Đăng nhập qua Email OTP
  Widget _buildEmailOtpForm(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _emailOtpController,
          enabled: !_isOtpSent,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'Nhập địa chỉ Email học viên',
            prefixIcon: const Icon(Icons.email_outlined),
            suffixIcon: _isOtpSent
                ? IconButton(
                    icon: const Icon(Icons.edit, size: 18, color: Colors.white70),
                    onPressed: () => setState(() => _isOtpSent = false),
                    tooltip: 'Đổi email',
                  )
                : null,
          ),
        ),
        if (!_isOtpSent) ...[
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: isLoading ? null : _handleSendLoginOtp,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('GỬI MÃ OTP ĐĂNG NHẬP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
          ),
        ] else ...[
          const SizedBox(height: 18),
          TextField(
            controller: _otpCodeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30,
              letterSpacing: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF38BDF8),
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '------',
              hintStyle: const TextStyle(fontSize: 30, letterSpacing: 10, color: Colors.white24),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF6366F1)),
              ),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: isLoading ? null : _handleVerifyLoginOtp,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text(
                    'XÁC NHẬN & ĐĂNG NHẬP',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Colors.white),
                  ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: (_countdownSeconds == 0 && !isLoading) ? _handleSendLoginOtp : null,
            icon: Icon(
              Icons.refresh_rounded,
              size: 16,
              color: _countdownSeconds == 0 ? const Color(0xFF38BDF8) : Colors.white38,
            ),
            label: Text(
              _countdownSeconds > 0 ? 'Gửi lại mã OTP ($_countdownSeconds s)' : 'Gửi lại mã OTP',
              style: TextStyle(
                color: _countdownSeconds == 0 ? const Color(0xFF38BDF8) : Colors.white38,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Giao diện Đăng nhập qua Mật khẩu & FaceID
  Widget _buildPasswordForm(bool isLoading) {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              hintText: 'Tên đăng nhập hoặc Email',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) => v!.isEmpty ? 'Vui lòng nhập tên đăng nhập hoặc email' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Mật khẩu',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (v) => v!.isEmpty ? 'Vui lòng nhập mật khẩu' : null,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: (isLoading || _isFaceLoggingIn) ? null : _loginWithPassword,
            child: isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text('ĐĂNG NHẬP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.25))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'HOẶC',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.25))),
            ],
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: (isLoading || _isFaceLoggingIn) ? null : _loginWithFaceId,
            icon: _isFaceLoggingIn
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
                  )
                : const Icon(Icons.face_retouching_natural_rounded, color: Colors.cyanAccent, size: 22),
            label: Text(
              _isFaceLoggingIn ? 'ĐANG XÁC THỰC FACEID...' : 'ĐĂNG NHẬP BẰNG FACEID',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.6), width: 1.5),
              backgroundColor: Colors.cyanAccent.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}
