import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../home/main_shell.dart';
import '../sound/desync_screen.dart';
import '../sound/desync_engine.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Auris', style: Theme.of(context).textTheme.headlineMedium),
                    Text('오늘도 편안한 하루 되세요', style: Theme.of(context).textTheme.bodySmall),
                  ]),
                  const CircleAvatar(
                    backgroundColor: AppColors.greenLight,
                    child: Icon(Icons.person_outline, color: AppColors.green),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 오늘 상태 카드
              _TodayStatusCard(),
              const SizedBox(height: 12),

              // 지금 소리 켜기
              _QuickSoundButton(onTap: () => ref.read(currentTabProvider.notifier).state = 1),
              const SizedBox(height: 12),

              // 신경 디싱크 프로그램 (핵심 차별화)
              _DesyncProgramCard(onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DesyncScreen()));
              }),
              const SizedBox(height: 16),

              // 빠른 이완
              Text('빠른 이완', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _QuickRelaxCard(icon: Icons.air, label: '4-7-8 호흡', onTap: () {})),
                const SizedBox(width: 10),
                Expanded(child: _QuickRelaxCard(icon: Icons.self_improvement, label: '근육 이완', onTap: () {})),
              ]),
              const SizedBox(height: 16),

              // 이번 주 요약
              _WeeklySummaryCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayStatusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.greenDark, borderRadius: BorderRadius.circular(16)),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('오늘 이명 강도', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.greenLight)),
        const SizedBox(height: 4),
        Text('기록 전', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white)),
        const SizedBox(height: 6),
        Text('오늘 기록을 남겨보세요', style: const TextStyle(color: AppColors.greenLight, fontSize: 12)),
      ])),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.edit_note, color: Colors.white, size: 28),
      ),
    ]),
  );
}

class _QuickSoundButton extends StatelessWidget {
  final VoidCallback onTap;
  const _QuickSoundButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(16)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.graphic_eq, color: Colors.white),
        const SizedBox(width: 8),
        Text('지금 소리 켜기', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
      ]),
    ),
  );
}

class _DesyncProgramCard extends StatelessWidget {
  final VoidCallback onTap;
  const _DesyncProgramCard({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3932), Color(0xFF00704A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('뉴캐슬대학 2025 연구',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          const Icon(Icons.chevron_right, color: AppColors.greenLight, size: 20),
        ]),
        const SizedBox(height: 10),
        const Text('신경 디싱크 세션',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('이명을 일으키는 뇌 신경 동기화를 깨뜨려요\n하루 1시간 · 6주 프로그램',
          style: TextStyle(color: AppColors.greenLight, fontSize: 12, height: 1.5)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: const LinearProgressIndicator(
            value: 0,
            backgroundColor: Colors.white24,
            color: AppColors.gold,
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 6),
        const Text('0 / 42일 완료',
          style: TextStyle(color: AppColors.greenLight, fontSize: 11)),
      ]),
    ),
  );
}

class _QuickRelaxCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickRelaxCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.greenLight),
      ),
      child: Column(children: [
        Icon(icon, color: AppColors.green, size: 26),
        const SizedBox(height: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
      ]),
    ),
  );
}

class _WeeklySummaryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.greenLight),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('이번 주 요약', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 10),
      Text('기록이 쌓이면 패턴 분석을 시작할 수 있어요',
        style: Theme.of(context).textTheme.bodySmall),
    ]),
  );
}
