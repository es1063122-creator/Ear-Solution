import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/session_manager.dart';
import '../home/home_screen.dart';
import 'desync_screen.dart';
import 'haptic_screen.dart';
import 'frequency_matcher.dart' as fm;

class TherapyScreen extends ConsumerStatefulWidget {
  const TherapyScreen({super.key});
  @override
  ConsumerState<TherapyScreen> createState() => _TherapyScreenState();
}

class _TherapyScreenState extends ConsumerState<TherapyScreen> {
  int _todaySecs = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadTodaySeconds();
    // 1초마다 갱신
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) => _loadTodaySeconds());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTodaySeconds() async {
    final secs = await SessionManager.getTodaySeconds();
    if (mounted) setState(() => _todaySecs = secs);
  }

  DayStatus get _todayStatus => _todaySecs >= 3600
    ? DayStatus.done
    : _todaySecs >= 1800
      ? DayStatus.partial
      : DayStatus.none;

  @override
  Widget build(BuildContext context) {
    final progress = (_todaySecs / 3600).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('6주 사운드 케어'),
        backgroundColor: AppColors.cream,
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // 오늘 진행 상황
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.greenDark, AppColors.green],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('오늘 세션', style: TextStyle(color: AppColors.greenLight, fontSize: 13)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _todayStatus == DayStatus.done ? AppColors.green
                      : _todayStatus == DayStatus.partial ? AppColors.gold
                      : Colors.white24,
                    borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    _todayStatus == DayStatus.done ? '✅ 완료'
                      : _todayStatus == DayStatus.partial ? '🔶 부분완료'
                      : '⬜ 미완료',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 8),
              Text(SessionManager.formatTime(_todaySecs),
                style: const TextStyle(color: Colors.white, fontSize: 26,
                  fontWeight: FontWeight.w300, letterSpacing: 2)),
              const SizedBox(height: 4),
              const Text('목표: 60:00 / 부분완료: 30:00',
                style: TextStyle(color: AppColors.greenLight, fontSize: 11)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white24,
                  color: _todayStatus == DayStatus.done ? AppColors.green : AppColors.gold,
                  minHeight: 6),
              ),
              const SizedBox(height: 4),
              Text('${(progress * 100).round()}% 완료',
                style: const TextStyle(color: AppColors.greenLight, fontSize: 11)),
            ]),
          ),
          const SizedBox(height: 10),

          // 안내
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.greenLight.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12)),
            child: const Text(
              '💡 소리를 들으면 자동으로 시간이 쌓입니다\n처음엔 3~10분부터 시작해도 됩니다',
              style: TextStyle(fontSize: 12, color: AppColors.greenDark, height: 1.5)),
          ),
          const SizedBox(height: 12),

          // 핵심: 신경 디싱크
          _SectionLabel(label: '핵심 사운드', badge: '뉴캐슬대학 2025'),
          _TherapyCard(
            icon: '🧠',
            title: '신경 디싱크 세션',
            description: '논문 참고 변조 사운드를 낮은 볼륨으로 편안하게 들어보세요\n30분~1시간 · 6주 루틴',
            tag: '뉴캐슬대학 2025',
            tagColor: AppColors.gold,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const DesyncScreen()))
              .then((_) => _loadTodaySeconds()),
          ),
          const SizedBox(height: 12),

          // 보조 이완
          const _SectionLabel(label: '이완 도움'),
          _TherapyCard(
            icon: '📳',
            title: '햅틱 이완 세션',
            description: '소리와 진동으로 이완을 돕는 보조 기능\n의료적 치료가 아닙니다 · 15분',
            tag: '이완 도움',
            tagColor: AppColors.green,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const HapticScreen()))
              .then((_) => _loadTodaySeconds()),
          ),
          const SizedBox(height: 8),
          _TherapyCard(
            icon: '🌬️',
            title: '4-7-8 호흡법',
            description: '긴장과 불편감을 낮추는 데 도움이 될 수 있어요\n2분 이완',
            tag: '이완 도움',
            tagColor: AppColors.textSecond,
            onTap: () => _showBreathing(context),
          ),
          const SizedBox(height: 20),

          // 이명 주파수 설정

        ]),
      ),
    );
  }

  void _showBreathing(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _BreathingSheet(),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final String? badge;
  const _SectionLabel({required this.label, this.badge});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Text(label, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600,
        color: AppColors.textLight, letterSpacing: 0.5)),
      if (badge != null) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.gold, borderRadius: BorderRadius.circular(10)),
          child: Text(badge!, style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600))),
      ],
    ]),
  );
}

class _TherapyCard extends StatelessWidget {
  final String icon, title, description, tag;
  final Color tagColor;
  final VoidCallback onTap;
  const _TherapyCard({required this.icon, required this.title,
    required this.description, required this.tag,
    required this.tagColor, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.greenLight)),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.greenDark)),
          const SizedBox(height: 3),
          Text(description, style: const TextStyle(
            fontSize: 11, color: AppColors.textLight, height: 1.4)),
        ])),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: tagColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6)),
          child: Text(tag, style: TextStyle(
            fontSize: 9, color: tagColor, fontWeight: FontWeight.w600))),
        const Icon(Icons.chevron_right, color: AppColors.textLight),
      ]),
    ),
  );
}

// 4-7-8 호흡
class _BreathingSheet extends StatefulWidget {
  const _BreathingSheet();
  @override
  State<_BreathingSheet> createState() => _BreathingSheetState();
}

class _BreathingSheetState extends State<_BreathingSheet> {
  final steps = [
    {'label': '들이쉬기', 'duration': 4, 'color': AppColors.green},
    {'label': '참기', 'duration': 7, 'color': AppColors.gold},
    {'label': '내쉬기', 'duration': 8, 'color': AppColors.greenDark},
  ];
  int _step = 0, _count = 0, _round = 0;
  bool _running = false;
  Timer? _timer;

  void _start() {
    setState(() { _running = true; _step = 0; _count = 0; _round = 0; });
    _tick();
  }

  void _tick() {
    final dur = steps[_step]['duration'] as int;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _count++);
      if (_count >= dur) {
        t.cancel();
        if (_step == 2) {
          setState(() { _round++; _step = 0; _count = 0; });
          if (_round < 3) _tick();
          else setState(() => _running = false);
        } else {
          setState(() { _step++; _count = 0; });
          _tick();
        }
      }
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final step = steps[_step];
    final dur = step['duration'] as int;
    final color = step['color'] as Color;

    return SafeArea(
      child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('4-7-8 호흡법', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('자율신경계 안정 · 3회 반복',
          style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 24),
        if (_running) ...[
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3),
              color: color.withOpacity(0.1)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(step['label'] as String,
                style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 4),
              Text('${dur - _count}초',
                style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w300)),
            ]),
          ),
          const SizedBox(height: 16),
          Text('${_round + 1} / 3 라운드',
            style: Theme.of(context).textTheme.bodySmall),
        ] else
          Text(_round >= 3 ? '완료! 🎉 수고하셨어요' : '준비되면 시작하세요',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _round >= 3 ? () => Navigator.pop(context) : _start,
            child: Text(_round >= 3 ? '닫기' : '시작')),
        ),
      ]),
      ),
    );
  }
}
