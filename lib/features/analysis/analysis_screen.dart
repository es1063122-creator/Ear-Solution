import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.cream,
    appBar: AppBar(title: const Text('패턴 분석')),
    body: const Center(child: Text('분석 화면 — 5단계에서 구현')),
  );
}
