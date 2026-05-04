import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import 'sound_generator.dart';

final soundVolumesProvider = StateProvider<Map<String, double>>(
  (ref) => {for (final s in AppConstants.soundLayers) s['id'] as String: 0.0},
);
final isPlayingProvider = StateProvider<bool>((ref) => false);
final timerMinutesProvider = StateProvider<int?>((ref) => null);
final timerSecondsLeftProvider = StateProvider<int?>((ref) => null);

class SoundScreen extends ConsumerStatefulWidget {
  const SoundScreen({super.key});

  @override
  ConsumerState<SoundScreen> createState() => _SoundScreenState();
}

class _SoundScreenState extends ConsumerState<SoundScreen> with WidgetsBindingObserver {
  final SoundMixerPlayer _mixer = SoundMixerPlayer();
  Timer? _sleepTimer;
  bool _isStopping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sleepTimer?.cancel();
    unawaited(_mixer.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_stopAll(resetSliders: false));
    }
  }

  Future<bool> _onWillPop() async {
    await _stopAll(resetSliders: true);
    return true;
  }

  bool _hasActiveLayer(Map<String, double> volumes) => volumes.values.any((v) => v > 0.001);

  Future<void> _setLayerVolume(String soundId, double volume) async {
    if (!mounted) return;

    final safeVolume = volume.clamp(0.0, 1.0).toDouble();
    final updated = Map<String, double>.from(ref.read(soundVolumesProvider));
    updated[soundId] = safeVolume;
    ref.read(soundVolumesProvider.notifier).state = updated;

    await _mixer.setVolume(soundId, safeVolume);

    if (!mounted) return;

    if (safeVolume > 0.001 && !ref.read(isPlayingProvider)) {
      await _mixer.play();
      if (mounted) ref.read(isPlayingProvider.notifier).state = true;
      return;
    }

    if (!_hasActiveLayer(updated)) {
      await _mixer.stop(disposePlayers: true);
      if (mounted) ref.read(isPlayingProvider.notifier).state = false;
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isStopping) return;
    final volumes = ref.read(soundVolumesProvider);
    if (!_hasActiveLayer(volumes)) {
      ref.read(isPlayingProvider.notifier).state = false;
      return;
    }

    final isPlaying = ref.read(isPlayingProvider);
    if (isPlaying) {
      await _mixer.pause();
      if (mounted) ref.read(isPlayingProvider.notifier).state = false;
    } else {
      await _mixer.play();
      if (mounted) ref.read(isPlayingProvider.notifier).state = true;
    }
  }

  Future<void> _stopAll({bool resetSliders = true}) async {
    if (_isStopping) return;
    _isStopping = true;
    _sleepTimer?.cancel();
    _sleepTimer = null;

    await _mixer.resetAll();

    if (mounted) {
      if (resetSliders) {
        ref.read(soundVolumesProvider.notifier).state = {
          for (final s in AppConstants.soundLayers) s['id'] as String: 0.0,
        };
      }
      ref.read(isPlayingProvider.notifier).state = false;
      ref.read(timerMinutesProvider.notifier).state = null;
    }

    _isStopping = false;
  }

  Future<void> _setTimer(int minutes, bool selected) async {
    _sleepTimer?.cancel();
    _sleepTimer = null;

    if (selected) {
      ref.read(timerMinutesProvider.notifier).state = null;
      return;
    }

    ref.read(timerMinutesProvider.notifier).state = minutes;
    _sleepTimer = Timer(Duration(minutes: minutes), () {
      unawaited(_stopAll(resetSliders: false));
    });
  }

  Future<void> _applyPreset(Map<String, double> presetVolumes) async {
    await _stopAll(resetSliders: true);
    if (!mounted) return;

    final updated = {for (final s in AppConstants.soundLayers) s['id'] as String: 0.0};
    updated.addAll(presetVolumes);
    ref.read(soundVolumesProvider.notifier).state = updated;

    for (final entry in presetVolumes.entries) {
      await _mixer.setVolume(entry.key, entry.value);
    }

    await _mixer.play();
    if (mounted) ref.read(isPlayingProvider.notifier).state = true;
  }

  void _savePreset() {
    final volumes = ref.read(soundVolumesProvider);
    if (!_hasActiveLayer(volumes)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('슬라이더를 올려 소리를 선택하세요')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('조합이 저장됐어요 ✅'), backgroundColor: AppColors.green),
    );
  }

  void _showTimer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final selectedTimer = ref.watch(timerMinutesProvider);
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('수면 타이머', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [15, 30, 45, 60, 90, 120].map((min) {
                      final selected = selectedTimer == min;
                      return GestureDetector(
                        onTap: () async {
                          await _setTimer(min, selected);
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.green : AppColors.cream2,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$min분',
                            style: TextStyle(
                              color: selected ? Colors.white : AppColors.textSecond,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () async {
                      _sleepTimer?.cancel();
                      _sleepTimer = null;
                      ref.read(timerMinutesProvider.notifier).state = null;
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    child: const Text('타이머 해제'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showPresets() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PresetsSheet(onPresetSelected: _applyPreset),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = ref.watch(isPlayingProvider);
    final volumes = ref.watch(soundVolumesProvider);
    final timer = ref.watch(timerMinutesProvider);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          title: const Text('사운드 믹서'),
          actions: [
            TextButton.icon(
              onPressed: _showPresets,
              icon: const Icon(Icons.bookmark_outline, size: 18),
              label: const Text('프리셋'),
            ),
          ],
        ),
        body: Column(
          children: [
            _PlayControl(
              isPlaying: isPlaying,
              hasActiveLayer: _hasActiveLayer(volumes),
              onToggle: _togglePlayPause,
              onStopAll: () => _stopAll(resetSliders: true),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  _cat('🎯 이명 마스킹'),
                  _layer('masking_8k'),
                  _cat('🌫 노이즈'),
                  _layer('pink_noise'),
                  _layer('brown_noise'),
                  _cat('🌿 자연음'),
                  _layer('rain'),
                  _layer('waves'),
                  _layer('forest'),
                  _layer('cricket'),
                  _cat('🏠 생활음'),
                  _layer('cafe'),
                  _layer('fan'),
                  _cat('🧘 이완 사운드'),
                  _layer('binaural_alpha'),
                ],
              ),
            ),
            _BottomActions(
              timer: timer,
              onShowTimer: _showTimer,
              onSavePreset: _savePreset,
              onStopAll: () => _stopAll(resetSliders: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cat(String label) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textLight,
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _layer(String id) => _SoundLayer(soundId: id, onVolumeChanged: _setLayerVolume);
}

class _PlayControl extends StatelessWidget {
  final bool isPlaying;
  final bool hasActiveLayer;
  final Future<void> Function() onToggle;
  final Future<void> Function() onStopAll;

  const _PlayControl({
    required this.isPlaying,
    required this.hasActiveLayer,
    required this.onToggle,
    required this.onStopAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.greenDark, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isPlaying ? '재생 중' : '재생 준비', style: const TextStyle(color: AppColors.greenLight, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  hasActiveLayer ? '선택한 소리를 재생할 수 있어요' : '슬라이더를 올려 소리를 선택하세요',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '전체 끄기',
            onPressed: onStopAll,
            icon: const Icon(Icons.stop_circle_outlined, color: Colors.white, size: 30),
          ),
          GestureDetector(
            onTap: hasActiveLayer ? onToggle : null,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: hasActiveLayer ? AppColors.green : AppColors.greenMid,
                shape: BoxShape.circle,
              ),
              child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundLayer extends ConsumerWidget {
  final String soundId;
  final Future<void> Function(String soundId, double volume) onVolumeChanged;

  const _SoundLayer({required this.soundId, required this.onVolumeChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumes = ref.watch(soundVolumesProvider);
    final volume = volumes[soundId] ?? 0.0;
    final isActive = volume > 0.001;
    final info = AppConstants.soundLayers.firstWhere((s) => s['id'] == soundId);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? AppColors.white : AppColors.cream2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isActive ? AppColors.green : Colors.transparent, width: 1.5),
      ),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text(info['icon'] as String, style: const TextStyle(fontSize: 18))),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              info['name'] as String,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.greenDark : AppColors.textLight,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.green,
                inactiveTrackColor: AppColors.greenLight,
                thumbColor: AppColors.green,
                overlayColor: AppColors.green.withOpacity(0.1),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: volume.clamp(0.0, 1.0).toDouble(),
                onChanged: (value) => unawaited(onVolumeChanged(soundId, value)),
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '${(volume * 100).round()}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? AppColors.green : AppColors.textHint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final int? timer;
  final VoidCallback onShowTimer;
  final VoidCallback onSavePreset;
  final Future<void> Function() onStopAll;

  const _BottomActions({
    required this.timer,
    required this.onShowTimer,
    required this.onSavePreset,
    required this.onStopAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.greenLight)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onShowTimer,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: timer != null ? AppColors.greenLight : AppColors.cream2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: timer != null ? AppColors.green : Colors.transparent),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: timer != null ? AppColors.green : AppColors.textLight),
                  const SizedBox(width: 4),
                  Text(
                    timer != null ? '$timer분 후 종료' : '타이머',
                    style: TextStyle(
                      fontSize: 13,
                      color: timer != null ? AppColors.green : AppColors.textLight,
                      fontWeight: timer != null ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onSavePreset,
              icon: const Icon(Icons.bookmark_add_outlined, size: 16),
              label: const Text('이 조합 저장'),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: '전체 끄기',
            onPressed: () => unawaited(onStopAll()),
            icon: const Icon(Icons.volume_off_outlined, color: AppColors.greenDark),
          ),
        ],
      ),
    );
  }
}

class _PresetsSheet extends StatelessWidget {
  final Future<void> Function(Map<String, double> volumes) onPresetSelected;

  const _PresetsSheet({required this.onPresetSelected});

  static const List<Map<String, Object>> presets = [
    {
      'name': '나의 조합',
      'desc': '8kHz 마스킹 + 핑크노이즈 + 빗소리',
      'icon': '⭐',
      'volumes': {'masking_8k': 0.45, 'pink_noise': 0.25, 'rain': 0.30},
    },
    {
      'name': '수면 모드',
      'desc': '브라운노이즈 + 파도 + 선풍기',
      'icon': '🌙',
      'volumes': {'brown_noise': 0.45, 'waves': 0.28, 'fan': 0.20},
    },
    {
      'name': '스트레스 완화',
      'desc': '알파파 + 숲소리 + 빗소리',
      'icon': '🧘',
      'volumes': {'binaural_alpha': 0.25, 'forest': 0.35, 'rain': 0.25},
    },
    {
      'name': '집중 모드',
      'desc': '카페 소음 + 핑크노이즈',
      'icon': '☕',
      'volumes': {'cafe': 0.35, 'pink_noise': 0.22},
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('저장된 조합', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...presets.map(
              (preset) => GestureDetector(
                onTap: () async {
                  final volumes = Map<String, double>.from(preset['volumes'] as Map);
                  await onPresetSelected(volumes);
                  if (context.mounted) Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.greenLight),
                  ),
                  child: Row(
                    children: [
                      Text(preset['icon'] as String, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(preset['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            Text(preset['desc'] as String, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.textLight),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
