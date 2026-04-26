import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.cream,
    appBar: AppBar(title: const Text('오늘 기록')),
    body: const Center(child: Text('기록 화면 — 5단계에서 구현')),
  );
}
