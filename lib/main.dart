import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/onboarding_screen.dart';
import 'main_shell.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // Use FFI web implementation for sqflite on web
    databaseFactory = databaseFactoryFfiWeb;
  }

  final prefs = await SharedPreferences.getInstance();
  final isFirstTime = prefs.getBool('is_first_time') ?? true;

  runApp(MainApp(isFirstTime: isFirstTime));
}

class MainApp extends StatelessWidget {
  final bool isFirstTime;

  const MainApp({super.key, required this.isFirstTime});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'School Finance App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.backgroundLight,
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: isFirstTime ? const OnboardingScreen() : const MainShell(),
    );
  }
}
