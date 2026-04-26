import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import 'sound_generator.dart';

final soundVolumesProvider = StateProvider<Map<String, double>>((ref) =>
  {for (var s in AppConstants.soundLayers) s['id'] as String: 0.0});

final isPlayingProvider = StateProvider<bool>((ref) => false);
final timerMinutesProvider = StateProvider<int?>((ref) => null);

// 전역 믹서 플레이어
final _mixerPlayer = SoundMixerPlayer();

class SoundScreen extends ConsumerWidget {
  const SoundScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(isPlayingProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('사운드 믹서'),
        actions: [
          TextButton.icon(
            onPressed: () => _showPresets(context, ref),
            icon: const Icon(Icons.bookmark_outline, size: 18),
            label: const Text('프리셋'),
          ),
        ],
      ),
      body: Column(children: [
        _PlayControl(isPlaying: isPlaying, ref: ref),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              _CategoryLabel('🎯 이명 마스킹'),
              _SoundLayer(soundId: 'masking_8k'),
              _CategoryLabel('🌫 노이즈'),
              _SoundLayer(soundId: 'pink_noise'),
              _SoundLayer(soundId: 'brown_noise'),
              _CategoryLabel('🌿 자연음'),
              _SoundLayer(soundId: 'rain'),
              _SoundLayer(soundId: 'waves'),
              _SoundLayer(soundId: 'forest'),
              _SoundLayer(soundId: 'cricket'),
              _CategoryLabel('🏠 생활음'),
              _SoundLayer(soundId: 'cafe'),
              _SoundLayer(soundId: 'fan'),
              _CategoryLabel('🧠 뇌파'),
              _SoundLayer(soundId: 'binaural_alpha'),
            ],
          ),
        ),
        _BottomActions(),
      ]),
    );
  }

  void _showPresets(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PresetsSheet(),
    );
  }
}

class _PlayControl extends ConsumerWidget {
  final bool isPlaying;
  final WidgetRef ref;
  const _PlayControl({required this.isPlaying, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumes = ref.watch(soundVolumesProvider);
    final activeCount = volumes.values.where((v) => v > 0).length;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.greenDark, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isPlaying ? '재생 중' : '재생 준비',
            style: const TextStyle(color: AppColors.greenLight, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            activeCount == 0 ? '슬라이더를 올려 소리를 선택하세요' : '${activeCount}개 레이어 활성',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        ])),
        GestureDetector(
          onTap: () async {
            if (activeCount == 0) return;
            final playing = ref.read(isPlayingProvider);
            if (playing) {
              await _mixerPlayer.pause();
              ref.read(isPlayingProvider.notifier).state = false;
            } else {
              await _mixerPlayer.play();
              ref.read(isPlayingProvider.notifier).state = true;
            }
          },
          child: Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: activeCount > 0 ? AppColors.green : AppColors.greenMid,
              shape: BoxShape.circle,
            ),
            child: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white, size: 28),
          ),
        ),
      ]),
    );
  }
}

class _CategoryLabel extends StatelessWidget {
  final String label;
  const _CategoryLabel(this.label);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w600, letterSpacing: 0.5)),
  );
}

class _SoundLayer extends ConsumerWidget {
  final String soundId;
  const _SoundLayer({required this.soundId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumes = ref.watch(soundVolumesProvider);
    final volume = volumes[soundId] ?? 0.0;
    final isActive = volume > 0;
    final soundInfo = AppConstants.soundLayers.firstWhere((s) => s['id'] == soundId);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? AppColors.white : AppColors.cream2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppColors.green : Colors.transparent, width: 1.5),
      ),
      child: Row(children: [
        SizedBox(width: 28, child: Text(soundInfo['icon'] as String,
          style: const TextStyle(fontSize: 18))),
        const SizedBox(width: 8),
        SizedBox(width: 80,
          child: Text(soundInfo['name'] as String,
            style: TextStyle(fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? AppColors.greenDark : AppColors.textLight))),
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
              value: volume,
              onChanged: (v) async {
                final updated = Map<String, double>.from(ref.read(soundVolumesProvider));
                updated[soundId] = v;
                ref.read(soundVolumesProvider.notifier).state = updated;
                await _mixerPlayer.setVolume(soundId, v);
                // 슬라이더 올리면 자동 재생
                if (v > 0 && !ref.read(isPlayingProvider)) {
                  await _mixerPlayer.play();
                  ref.read(isPlayingProvider.notifier).state = true;
                }
              },
            ),
          ),
        ),
        SizedBox(width: 32,
          child: Text('${(volume * 100).round()}',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12,
              color: isActive ? AppColors.green : AppColors.textHint,
              fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class _BottomActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(timerMinutesProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.greenLight))),
      child: Row(children: [
        GestureDetector(
          onTap: () => _showTimerPicker(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: timer != null ? AppColors.greenLight : AppColors.cream2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: timer != null ? AppColors.green : Colors.transparent)),
            child: Row(children: [
              Icon(Icons.timer_outlined, size: 16,
                color: timer != null ? AppColors.green : AppColors.textLight),
              const SizedBox(width: 4),
              Text(timer != null ? '$timer분 후 종료' : '타이머',
                style: TextStyle(fontSize: 13,
                  color: timer != null ? AppColors.green : AppColors.textLight,
                  fontWeight: timer != null ? FontWeight.w600 : FontWeight.w400)),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _savePreset(context, ref),
            icon: const Icon(Icons.bookmark_add_outlined, size: 16),
            label: const Text('이 조합 저장'),
          ),
        ),
      ]),
    );
  }

  void _showTimerPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('수면 타이머', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('설정한 시간 후 소리가 꺼집니다', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: [15, 30, 45, 60, 90, 120].map((min) {
              final selected = ref.watch(timerMinutesProvider) == min;
              return GestureDetector(
                onTap: () {
                  ref.read(timerMinutesProvider.notifier).state = selected ? null : min;
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.green : AppColors.cream2,
                    borderRadius: BorderRadius.circular(20)),
                  child: Text('$min분', style: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecond,
                    fontWeight: FontWeight.w500)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  void _savePreset(BuildContext context, WidgetRef ref) {
    final volumes = ref.read(soundVolumesProvider);
    final activeCount = volumes.values.where((v) => v > 0).length;
    if (activeCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('슬라이더를 올려 소리를 선택하세요')));
      return;
    }
    final ctrl = TextEditingController(text: '내 조합');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cream,
        title: const Text('조합 이름'),
        content: TextField(controller: ctrl, autofocus: true,
          decoration: const InputDecoration(hintText: '이름을 입력하세요')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("'${ctrl.text}' 저장됐어요")));
            },
            child: const Text('저장')),
        ],
      ),
    );
  }
}

class _PresetsSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = [
      {'name': '나의 조합', 'desc': '8kHz 마스킹 + 핑크노이즈 + 빗소리', 'icon': '⭐',
        'volumes': {'masking_8k': 0.7, 'pink_noise': 0.4, 'rain': 0.5}},
      {'name': '수면 모드', 'desc': '브라운노이즈 + 파도 + 선풍기', 'icon': '🌙',
        'volumes': {'brown_noise': 0.6, 'waves': 0.4, 'fan': 0.3}},
      {'name': '스트레스 완화', 'desc': '알파파 + 숲소리 + 빗소리', 'icon': '🧘',
        'volumes': {'binaural_alpha': 0.5, 'forest': 0.6, 'rain': 0.3}},
      {'name': '집중 모드', 'desc': '카페 소음 + 핑크노이즈', 'icon': '☕',
        'volumes': {'cafe': 0.6, 'pink_noise': 0.3}},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('저장된 조합', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        ...presets.map((p) => GestureDetector(
          onTap: () async {
            final vols = {for (var s in AppConstants.soundLayers) s['id'] as String: 0.0};
            final presetVols = p['volumes'] as Map<String, double>;
            vols.addAll(presetVols);
            ref.read(soundVolumesProvider.notifier).state = vols;
            for (final e in presetVols.entries) {
              await _mixerPlayer.setVolume(e.key, e.value);
            }
            await _mixerPlayer.play();
            ref.read(isPlayingProvider.notifier).state = true;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("'${p['name']}' 불러왔어요")));
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.greenLight)),
            child: Row(children: [
              Text(p['icon'] as String, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(p['desc'] as String,
                  style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
              ])),
              const Icon(Icons.chevron_right, color: AppColors.textLight),
            ]),
          ),
        )),
      ]),
    );
  }
}
