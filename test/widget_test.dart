import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:doancuoiki/main.dart';
import 'package:doancuoiki/presentation/auth/providers/auth_provider.dart';

void main() {
  testWidgets('IELTS Vision app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: const IeltsApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
