import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/session_manager.dart';
import '../../core/constants/app_constants.dart';
import '../sound/frequency_matcher.dart' as fm;
import '../home/main_shell.dart';

final todayIntensityProvider = StateProvider<int?>((ref) => null);
final calendarProvider = FutureProvider<List<Map<String,dynamic>>>((ref) =>
  SessionManager.getCalendarData());
final todaySecondsProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final secs = await SessionManager.getTodaySeconds();
    if (mounted) ref.read(todaySecondsProvider.notifier).state = secs;
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt('today_intensity');
    if (mounted && v != null) ref.read(todayIntensityProvider.notifier).state = v;
  }

  Future<void> _saveIntensity(int v) async {
    ref.read(todayIntensityProvider.notifier).state = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('today_intensity', v);
  }

  @override
  Widget build(BuildContext context) {
    final intensity = ref.watch(todayIntensityProvider);
    final todaySecs = ref.watch(todaySecondsProvider);
    final calAsync = ref.watch(calendarProvider);
    final todayStatus = todaySecs >= 3600 ? 'done'
      : todaySecs >= 1800 ? 'partial' : 'none';

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.green,
          onRefresh: () async { ref.invalidate(calendarProvider); await _load(); },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // 헤더
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Auris', style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.greenDark)),
                calAsync.when(
                  data: (cal) {
                    final done = cal.where((d) => d['status'] == 'done').length;
                    final partial = cal.where((d) => d['status'] == 'partial').length;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.greenLight, borderRadius: BorderRadius.circular(20)),
                      child: Text('$done완료 · $partial부분',
                        style: const TextStyle(color: AppColors.greenDark,
                          fontSize: 12, fontWeight: FontWeight.w600)),
                    );
                  },
                  loading: () => const SizedBox(),
                  error: (_,__) => const SizedBox(),
                ),
              ]),
              const SizedBox(height: 20),

              // ── 오늘의 미션 (가장 중요한 카드) ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3932), Color(0xFF00704A)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('오늘의 사운드 케어', style: TextStyle(
                      color: AppColors.greenLight, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: todayStatus == 'done' ? AppColors.green
                          : todayStatus == 'partial' ? AppColors.gold
                          : Colors.white24,
                        borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        todayStatus == 'done' ? '✅ 완료'
                          : todayStatus == 'partial' ? '🔶 부분완료 (${(todaySecs/60).round()}분)'
                          : '⬜ ${todaySecs > 0 ? "${(todaySecs/60).round()}분 진행 중" : "시작 전"}',
                        style: const TextStyle(color: Colors.white,
                          fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  const Text('🧠 디싱크 사운드 세션', style: TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('소리를 들으면 자동으로 기록됩니다\n처음엔 3~10분부터 시작해도 됩니다',
                    style: TextStyle(color: AppColors.greenLight, fontSize: 13, height: 1.5)),
                  const SizedBox(height: 16),
                  // 진행 바
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (todaySecs / 3600).clamp(0.0, 1.0),
                      backgroundColor: Colors.white24,
                      color: todayStatus == 'done' ? AppColors.green : AppColors.gold,
                      minHeight: 6)),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(SessionManager.formatTime(todaySecs),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    const Text('목표 60:00',
                      style: TextStyle(color: AppColors.greenLight, fontSize: 12)),
                  ]),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => ref.read(currentTabProvider.notifier).state = 1,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.greenDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                      child: Text(
                        todaySecs == 0 ? '지금 들어보기 →'
                          : todayStatus == 'done' ? '오늘 완료! 내일 또 만나요 😊'
                          : '이어서 듣기 →',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // ── 잘 때 도움 카드 ──
              GestureDetector(
                onTap: () => ref.read(currentTabProvider.notifier).state = 2,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.greenLight)),
                  child: Row(children: [
                    const Text('😴', style: TextStyle(fontSize: 32)),
                    const SizedBox(width: 14),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('잠들기 어려우세요?', style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.greenDark)),
                      SizedBox(height: 4),
                      Text('수면 모드 → 브라운노이즈 + 타이머\n소리가 자동으로 꺼집니다',
                        style: TextStyle(fontSize: 12, color: AppColors.textLight, height: 1.4)),
                    ])),
                    const Icon(Icons.chevron_right, color: AppColors.textLight),
                  ]),
                ),
              ),
              const SizedBox(height: 12),

              // ── 내 이명 주파수 ──
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push<double>(context,
                    MaterialPageRoute(builder: (_) => const fm.FrequencyMatcherScreen()));
                  if (result != null) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setDouble(AppConstants.keyTinnitusFreq, result);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(
                          '주파수가 ${(result/1000).toStringAsFixed(1)}kHz로 설정됐어요'),
                          backgroundColor: AppColors.green));
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.greenLight)),
                  child: Row(children: [
                    const Text('🎯', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('내 이명 주파수 다시 찾기',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.greenDark)),
                      const SizedBox(height: 2),
                      const Text('슬라이더 + 테스트 톤으로 정확하게',
                        style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                    ])),
                    const Icon(Icons.chevron_right, color: AppColors.textLight),
                  ]),
                ),
              ),
              const SizedBox(height: 12),

              // ── 이명 강도 기록 ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.greenLight)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('오늘 이명 강도', style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.greenDark)),
                    if (intensity != null)
                      Text('$intensity / 10', style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.intensityColor(intensity))),
                  ]),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: intensity != null
                        ? AppColors.intensityColor(intensity) : AppColors.green,
                      inactiveTrackColor: AppColors.greenLight,
                      thumbColor: intensity != null
                        ? AppColors.intensityColor(intensity) : AppColors.green,
                      trackHeight: 4),
                    child: Slider(
                      value: (intensity ?? 5).toDouble(),
                      min: 1, max: 10, divisions: 9,
                      onChanged: (v) => _saveIntensity(v.round()),
                    ),
                  ),
                  Text(
                    intensity == null ? '👆 슬라이더를 움직여 기록하세요'
                      : intensity <= 3 ? '😊 오늘은 편안한 편이에요'
                      : intensity <= 6 ? '😐 보통 수준이에요'
                      : '😔 많이 힘드시겠어요. 호흡법이 도움될 수 있어요',
                    style: TextStyle(
                      fontSize: 12,
                      color: intensity != null ? AppColors.intensityColor(intensity) : AppColors.textLight)),
                ]),
              ),
              const SizedBox(height: 20),

              // ── 6주 달력 ──
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('6주 루틴', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.greenDark)),
                TextButton(
                  onPressed: () => ref.read(currentTabProvider.notifier).state = 1,
                  child: const Text('케어 탭에서 자세히 →',
                    style: TextStyle(fontSize: 12, color: AppColors.green))),
              ]),
              const SizedBox(height: 8),
              calAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.green)),
                error: (e,_) => Text('$e'),
                data: (cal) => _CalendarWidget(calendar: cal),
              ),
              const SizedBox(height: 8),

              // 범례
              Row(children: [
                _LegDot(color: AppColors.green, label: '완료'),
                const SizedBox(width: 10),
                _LegDot(color: AppColors.gold, label: '부분완료', opacity: 0.3),
                const SizedBox(width: 10),
                _LegDot(color: AppColors.greenDark, label: '오늘', border: AppColors.gold),
                const SizedBox(width: 10),
                _LegDot(color: AppColors.cream2, label: '미완료', border: Colors.redAccent),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _CalendarWidget extends StatelessWidget {
  final List<Map<String,dynamic>> calendar;
  const _CalendarWidget({required this.calendar});

  @override
  Widget build(BuildContext context) {
    final weeks = <List<Map<String,dynamic>>>[];
    for (int i = 0; i < 6; i++) {
      final s = i * 7;
      final e = (s + 7).clamp(0, calendar.length);
      if (s < calendar.length) weeks.add(calendar.sublist(s, e));
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.greenLight)),
      child: Column(children: [
        // 요일 헤더
        Row(children: ['월','화','수','목','금','토','일'].map((d) => Expanded(
          child: Text(d, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: AppColors.textLight,
              fontWeight: FontWeight.w500))
        )).toList()),
        const SizedBox(height: 8),
        ...weeks.map((week) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(children: [
            ...week.map((day) => Expanded(child: _DayCell(day: day))),
            if (week.length < 7)
              ...List.generate(7 - week.length, (_) => const Expanded(child: SizedBox())),
          ]),
        )),
      ]),
    );
  }
}

class _DayCell extends StatelessWidget {
  final Map<String,dynamic> day;
  const _DayCell({required this.day});

  @override
  Widget build(BuildContext context) {
    final status = day['status'] as String;
    final dayNum = day['day'] as int;
    final secs = day['seconds'] as int;

    Color bg; Color tc; Border? border;
    switch (status) {
      case 'done':    bg = AppColors.green;  tc = Colors.white; break;
      case 'partial': bg = AppColors.gold.withOpacity(0.2); tc = AppColors.greenDark;
        border = Border.all(color: AppColors.gold, width: 1.5); break;
      case 'today':   bg = AppColors.greenDark; tc = Colors.white;
        border = Border.all(color: AppColors.gold, width: 2); break;
      case 'missed':  bg = AppColors.cream2; tc = AppColors.textLight;
        border = Border.all(color: Colors.redAccent.withOpacity(0.4)); break;
      default:        bg = AppColors.cream2; tc = AppColors.textHint;
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(8), border: border),
      child: AspectRatio(
        aspectRatio: 1,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$dayNum', style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600, color: tc)),
          if (status == 'done')
            const Text('✓', style: TextStyle(fontSize: 7, color: Colors.white))
          else if (status == 'partial')
            Text('${(secs/60).round()}m', style: TextStyle(fontSize: 7, color: tc))
          else if (status == 'today')
            const Text('▶', style: TextStyle(fontSize: 7, color: AppColors.gold)),
        ]),
      ),
    );
  }
}

class _LegDot extends StatelessWidget {
  final Color color; final String label;
  final Color? border; final double opacity;
  const _LegDot({required this.color, required this.label,
    this.border, this.opacity = 1.0});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 12, height: 12,
      decoration: BoxDecoration(
        color: color.withOpacity(opacity),
        borderRadius: BorderRadius.circular(3),
        border: border != null ? Border.all(color: border!, width: 1.5) : null)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
  ]);
}
