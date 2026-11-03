import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int _currentStep = 1; // 1: Điền thông tin, 2: Nhập OTP
  int _countdownSeconds = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _otpController.dispose();
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

  /// Bước 1: Kiểm tra form & Gửi mã OTP tới Email
  Future<void> _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = _emailController.text.trim();

    final error = await auth.sendOtp(email, type: 'register');
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: Colors.redAccent,
      ));
    } else {
      setState(() => _currentStep = 2);
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Mã OTP đã được gửi tới $email. Vui lòng kiểm tra hộp thư!'),
        backgroundColor: Colors.green,
      ));
    }
  }

  /// Gửi lại mã OTP
  Future<void> _handleResendOtp() async {
    if (_countdownSeconds > 0) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = _emailController.text.trim();

    final error = await auth.sendOtp(email, type: 'register');
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: Colors.redAccent,
      ));
    } else {
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Đã gửi lại mã OTP mới!'),
        backgroundColor: Colors.green,
      ));
    }
  }

  /// Bước 2: Xác thực mã OTP và hoàn tất đăng ký
  Future<void> _handleVerifyAndRegister() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vui lòng nhập đủ 6 chữ số mã OTP'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final error = await auth.registerWithOtp(
      email: _emailController.text.trim(),
      otp: otp,
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
      ));
    } else {
      Navigator.pop(context); // Đăng ký & đăng nhập thành công
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.darkBackground,
        elevation: 0,
        title: const Text(
          'Đăng ký Học viên',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.surfaceGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: _currentStep == 1 ? _buildStep1Form(isLoading) : _buildStep2Otp(isLoading),
            ),
          ),
        ),
      ),
    );
  }

  /// Giao diện Bước 1: Nhập thông tin tài khoản & Email
  Widget _buildStep1Form(bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.school_rounded, size: 54, color: AppColors.primary),
          const SizedBox(height: 12),
          const Text(
            'Tạo tài khoản Học viên',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Xác thực email an toàn với mã OTP gửi trực tiếp',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: Colors.white70),
          ),
          const SizedBox(height: 32),
          // Email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'Địa chỉ Email nhận mã OTP',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Vui lòng nhập Email';
              if (!v.contains('@') || !v.contains('.')) return 'Email không hợp lệ';
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Username
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              hintText: 'Tên đăng nhập (username)',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Vui lòng nhập tên đăng nhập';
              if (v.trim().length < 3) return 'Tên đăng nhập ít nhất 3 ký tự';
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Password
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Mật khẩu',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (v) => (v != null && v.length < 6) ? 'Mật khẩu ít nhất 6 ký tự' : null,
          ),
          const SizedBox(height: 16),
          // Confirm Password
          TextFormField(
            controller: _confirmController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Xác nhận mật khẩu',
              prefixIcon: Icon(Icons.lock_reset_rounded),
            ),
            validator: (v) => v != _passwordController.text ? 'Mật khẩu không khớp' : null,
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: isLoading ? null : _handleSendOtp,
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
                      Text('TIẾP TỤC & GỬI MÃ OTP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Giao diện Bước 2: Nhập mã OTP 6 số
  Widget _buildStep2Otp(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mark_email_read_rounded, size: 64, color: Color(0xFF38BDF8)),
        const SizedBox(height: 16),
        const Text(
          'Xác thực mã OTP',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Chúng tôi đã gửi mã 6 chữ số tới:\n${_emailController.text.trim()}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: 32),
        // Ô nhập OTP 6 số to rõ
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 32,
            letterSpacing: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF38BDF8),
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '------',
            hintStyle: const TextStyle(fontSize: 32, letterSpacing: 12, color: Colors.white24),
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF334155), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '⏳ Mã OTP có hiệu lực trong 5 phút. Tối đa 5 lần thử.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFFF59E0B)),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: isLoading ? null : _handleVerifyAndRegister,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: const Color(0xFF4F46E5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : const Text(
                  'XÁC NHẬN & HOÀN TẤT',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
        ),
        const SizedBox(height: 16),
        // Nút Gửi lại mã kèm đếm ngược
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: (_countdownSeconds == 0 && !isLoading) ? _handleResendOtp : null,
              icon: Icon(
                Icons.refresh_rounded,
                size: 18,
                color: _countdownSeconds == 0 ? const Color(0xFF38BDF8) : Colors.white38,
              ),
              label: Text(
                _countdownSeconds > 0 ? 'Gửi lại mã ($_countdownSeconds s)' : 'Gửi lại mã OTP',
                style: TextStyle(
                  color: _countdownSeconds == 0 ? const Color(0xFF38BDF8) : Colors.white38,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Text('|', style: TextStyle(color: Colors.white24)),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () {
                      _countdownTimer?.cancel();
                      setState(() {
                        _currentStep = 1;
                        _otpController.clear();
                      });
                    },
              child: const Text('Đổi Email', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ],
    );
  }
}
