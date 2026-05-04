import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

final recordIntensityProvider = StateProvider<int>((ref) => 5);
final recordMoodProvider      = StateProvider<int>((ref) => 2);
final recordSleepHoursProvider = StateProvider<double>((ref) => 7.0);
final recordStressProvider    = StateProvider<double>((ref) => 3.0);
final recordTagsProvider      = StateProvider<List<String>>((ref) => []);
final recordCaffeineProvider  = StateProvider<bool>((ref) => false);
final recordExerciseProvider  = StateProvider<bool>((ref) => false);
final recordOutdoorProvider   = StateProvider<bool>((ref) => false);
final recordNoiseProvider     = StateProvider<bool>((ref) => false);

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});
  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  final _memoController = TextEditingController();
  bool _isSaving = false;
  bool _savedToday = false;

  @override
  void initState() {
    super.initState();
    _checkTodaySaved();
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _checkTodaySaved() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSaved = prefs.getString('last_record_date') ?? '';
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    if (lastSaved == todayStr) setState(() => _savedToday = true);
  }

  Future<void> _saveRecord() async {
    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month}-${today.day}';

      final record = {
        'date': todayStr,
        'intensity': ref.read(recordIntensityProvider),
        'tags': ref.read(recordTagsProvider),
        'mood': ref.read(recordMoodProvider),
        'stress': ref.read(recordStressProvider),
        'sleepHours': ref.read(recordSleepHoursProvider),
        'caffeine': ref.read(recordCaffeineProvider),
        'exercise': ref.read(recordExerciseProvider),
        'outdoor': ref.read(recordOutdoorProvider),
        'noise': ref.read(recordNoiseProvider),
        'memo': _memoController.text,
      };

      // 로컬 저장
      final records = jsonDecode(prefs.getString('records') ?? '[]') as List;
      records.removeWhere((r) => r['date'] == todayStr);
      records.add(record);
      await prefs.setString('records', jsonEncode(records));
      await prefs.setString('last_record_date', todayStr);

      setState(() => _savedToday = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('오늘 기록이 저장됐어요! ✅'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('오늘 기록'),
        actions: [
          if (_savedToday)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.greenLight, borderRadius: BorderRadius.circular(20)),
              child: const Text('오늘 완료 ✅',
                style: TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // 이명 강도
          _SectionCard(title: '이명 강도', child: Column(children: [
            Row(children: [
              Consumer(builder: (_, ref, __) {
                final v = ref.watch(recordIntensityProvider);
                return Text('$v', style: TextStyle(
                  fontSize: 40, fontWeight: FontWeight.w700,
                  color: AppColors.intensityColor(v)));
              }),
              const SizedBox(width: 12),
              Expanded(child: Consumer(builder: (_, ref, __) {
                final v = ref.watch(recordIntensityProvider);
                return SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.intensityColor(v),
                    thumbColor: AppColors.intensityColor(v),
                    inactiveTrackColor: AppColors.greenLight,
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: v.toDouble(), min: 1, max: 10, divisions: 9,
                    onChanged: (val) =>
                      ref.read(recordIntensityProvider.notifier).state = val.round(),
                  ),
                );
              })),
              const Text('/10', style: TextStyle(color: AppColors.textLight, fontSize: 14)),
            ]),
            const SizedBox(height: 8),
            Consumer(builder: (_, ref, __) {
              final v = ref.watch(recordIntensityProvider);
              return Text(
                v <= 3 ? '편안한 편이에요' : v <= 6 ? '보통 수준이에요' : '많이 힘드시겠어요',
                style: TextStyle(fontSize: 12, color: AppColors.intensityColor(v)));
            }),
          ])),

          // 소리 특성
          _SectionCard(title: '소리 특성', child: Consumer(builder: (_, ref, __) {
            final selected = ref.watch(recordTagsProvider);
            return Wrap(spacing: 8, runSpacing: 8,
              children: AppConstants.tinnitusTypes.map((tag) {
                final isOn = selected.contains(tag);
                return GestureDetector(
                  onTap: () {
                    final list = List<String>.from(selected);
                    isOn ? list.remove(tag) : list.add(tag);
                    ref.read(recordTagsProvider.notifier).state = list;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isOn ? AppColors.green : AppColors.cream2,
                      borderRadius: BorderRadius.circular(20)),
                    child: Text(tag, style: TextStyle(
                      fontSize: 13,
                      color: isOn ? Colors.white : AppColors.textSecond,
                      fontWeight: isOn ? FontWeight.w600 : FontWeight.w400)),
                  ),
                );
              }).toList(),
            );
          })),

          // 기분
          _SectionCard(title: '기분', child: Consumer(builder: (_, ref, __) {
            final mood = ref.watch(recordMoodProvider);
            return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _MoodBtn(emoji: '😊', label: '좋음', selected: mood == 1,
                onTap: () => ref.read(recordMoodProvider.notifier).state = 1),
              _MoodBtn(emoji: '😐', label: '보통', selected: mood == 2,
                onTap: () => ref.read(recordMoodProvider.notifier).state = 2),
              _MoodBtn(emoji: '😔', label: '나쁨', selected: mood == 3,
                onTap: () => ref.read(recordMoodProvider.notifier).state = 3),
            ]);
          })),

          // 수면
          _SectionCard(title: '수면', child: Consumer(builder: (_, ref, __) {
            final hours = ref.watch(recordSleepHoursProvider);
            return Row(children: [
              const Text('수면시간', style: TextStyle(fontSize: 13, color: AppColors.textSecond)),
              const SizedBox(width: 12),
              Expanded(child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.green,
                  thumbColor: AppColors.green,
                  inactiveTrackColor: AppColors.greenLight,
                  trackHeight: 3,
                ),
                child: Slider(
                  value: hours, min: 0, max: 12, divisions: 24,
                  onChanged: (v) => ref.read(recordSleepHoursProvider.notifier).state = v,
                ),
              )),
              Text('${hours.toStringAsFixed(1)}h',
                style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600)),
            ]);
          })),

          // 스트레스
          _SectionCard(title: '스트레스 수준', child: Consumer(builder: (_, ref, __) {
            final stress = ref.watch(recordStressProvider);
            return Row(children: [
              const Text('낮음', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
              Expanded(child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.gold,
                  thumbColor: AppColors.gold,
                  inactiveTrackColor: AppColors.greenLight,
                  trackHeight: 3,
                ),
                child: Slider(
                  value: stress, min: 1, max: 5, divisions: 4,
                  onChanged: (v) => ref.read(recordStressProvider.notifier).state = v,
                ),
              )),
              const Text('높음', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
            ]);
          })),

          // 생활 요인
          _SectionCard(title: '생활 요인', child: Wrap(spacing: 8, runSpacing: 8, children: [
            _FactorChip(label: '☕ 카페인', provider: recordCaffeineProvider),
            _FactorChip(label: '🏃 운동', provider: recordExerciseProvider),
            _FactorChip(label: '🌳 야외활동', provider: recordOutdoorProvider),
            _FactorChip(label: '🔊 소음 노출', provider: recordNoiseProvider),
          ])),

          // 메모
          _SectionCard(title: '메모 (선택)', child: TextField(
            controller: _memoController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '오늘 특이사항을 자유롭게 기록하세요...',
              border: InputBorder.none,
              hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
            ),
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          )),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveRecord,
              child: _isSaving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_savedToday ? '다시 저장하기' : '오늘 기록 저장'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.greenLight)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w600,
        color: AppColors.textLight, letterSpacing: 0.5)),
      const SizedBox(height: 12),
      child,
    ]),
  );
}

class _MoodBtn extends StatelessWidget {
  final String emoji, label;
  final bool selected;
  final VoidCallback onTap;
  const _MoodBtn({required this.emoji, required this.label,
    required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      Text(emoji, style: TextStyle(fontSize: selected ? 36 : 28)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11,
        color: selected ? AppColors.green : AppColors.textLight,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
    ]),
  );
}

class _FactorChip extends ConsumerWidget {
  final String label;
  final StateProvider<bool> provider;
  const _FactorChip({required this.label, required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOn = ref.watch(provider);
    return GestureDetector(
      onTap: () => ref.read(provider.notifier).state = !isOn,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isOn ? AppColors.greenLight : AppColors.cream2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isOn ? AppColors.green : Colors.transparent)),
        child: Text(label, style: TextStyle(fontSize: 13,
          color: isOn ? AppColors.green : AppColors.textSecond,
          fontWeight: isOn ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }
}
