import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/home/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Firebase 임시 제거 - 나중에 추가
  // await Firebase.initializeApp();

  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool(AppConstants.keyOnboardingDone) ?? false;

  runApp(ProviderScope(child: AurisApp(onboardingDone: onboardingDone)));
}

class AurisApp extends StatelessWidget {
  final bool onboardingDone;
  const AurisApp({super.key, required this.onboardingDone});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: AppConstants.appName,
    theme: AppTheme.light,
    debugShowCheckedModeBanner: false,
    home: onboardingDone ? const MainShell() : const OnboardingScreen(),
  );
}
