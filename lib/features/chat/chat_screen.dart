import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.cream,
    appBar: AppBar(title: const Text('Auris와 대화')),
    body: const Center(child: Text('AI 대화 화면 — 6단계에서 구현')),
  );
}
