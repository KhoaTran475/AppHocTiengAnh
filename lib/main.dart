import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'presentation/auth/providers/auth_provider.dart';
import 'presentation/auth/screens/login_screen.dart';
import 'presentation/learner/screens/learner_home_screen.dart';
import 'presentation/admin/screens/admin_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IELTS Vision',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          if (auth.currentUser == null) {
            return const LoginScreen();
          }
          
          if (auth.currentUser!.role == 'admin') {
            return const AdminDashboardScreen();
          } else {
            return const LearnerHomeScreen();
          }
        },
      ),
    );
  }
}
