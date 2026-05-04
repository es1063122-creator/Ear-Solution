import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';

final selectedFreqProvider = StateProvider<double>((ref) => 8000.0);
final testTonePlayingProvider = StateProvider<bool>((ref) => false);

class FrequencyMatcherScreen extends ConsumerStatefulWidget {
  const FrequencyMatcherScreen({super.key});
  @override
  ConsumerState<FrequencyMatcherScreen> createState() => _FrequencyMatcherScreenState();
}

class _FrequencyMatcherScreenState extends ConsumerState<FrequencyMatcherScreen> {
  AudioPlayer? _tonePlayer;
  bool _isGenerating = false;

  // 1kHz ~ 12kHz, 250Hz 단위
  static const double minFreq = 1000;
  static const double maxFreq = 12000;
  static const double step = 250;
  static const int divisions = 44; // (12000 - 1000) / 250 = 44단계

  @override
  void dispose() {
    _tonePlayer?.dispose();
    super.dispose();
  }

  Future<void> _playTestTone(double freq) async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    try {
      await _tonePlayer?.stop();
      _tonePlayer?.dispose();
      _tonePlayer = AudioPlayer();

      // 파일로 저장 후 재생
      final wav = _generateSineWav(freq, durationSeconds: 3);
      final dir = await getTemporaryDirectory();
      final filePath = dir.path + '/freq_test_' + DateTime.now().millisecondsSinceEpoch.toString() + '.wav';
      final file = File(filePath);
      await file.writeAsBytes(wav);

      await _tonePlayer!.setFilePath(file.path);
      await _tonePlayer!.setVolume(0.18); // 이명 사용자 안전 볼륨
      await _tonePlayer!.play();
      ref.read(testTonePlayingProvider.notifier).state = true;

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _tonePlayer?.stop();
          ref.read(testTonePlayingProvider.notifier).state = false;
        }
      });
    } catch (e) {
      debugPrint('테스트 톤 오류: ' + e.toString());
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _stopTestTone() async {
    await _tonePlayer?.stop();
    ref.read(testTonePlayingProvider.notifier).state = false;
  }

  // 순수 사인파 WAV 생성
  List<int> _generateSineWav(double freq, {int durationSeconds = 3}) {
    const sampleRate = 44100;
    final totalSamples = sampleRate * durationSeconds;
    final fadeLen = sampleRate ~/ 4; // 0.25초 페이드

    final pcm = <int>[];
    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      double sample = sin(2 * pi * freq * t);

      // 페이드인/아웃
      if (i < fadeLen) sample *= i / fadeLen;
      if (i > totalSamples - fadeLen) sample *= (totalSamples - i) / fadeLen;

      final pcmVal = (sample * 20000).round().clamp(-32768, 32767);
      pcm.add(pcmVal & 0xFF);
      pcm.add((pcmVal >> 8) & 0xFF);
    }

    // WAV 헤더
    final dataSize = pcm.length;
    final header = <int>[
      0x52,0x49,0x46,0x46, // RIFF
      ...intToBytes(36 + dataSize, 4),
      0x57,0x41,0x56,0x45, // WAVE
      0x66,0x6D,0x74,0x20, // fmt
      ...intToBytes(16, 4),
      ...intToBytes(1, 2),  // PCM
      ...intToBytes(1, 2),  // mono
      ...intToBytes(sampleRate, 4),
      ...intToBytes(sampleRate * 2, 4),
      ...intToBytes(2, 2),
      ...intToBytes(16, 2),
      0x64,0x61,0x74,0x61, // data
      ...intToBytes(dataSize, 4),
    ];
    return [...header, ...pcm];
  }

  List<int> intToBytes(int value, int byteCount) {
    final result = <int>[];
    for (int i = 0; i < byteCount; i++) {
      result.add((value >> (8 * i)) & 0xFF);
    }
    return result;
  }

  String _freqLabel(double freq) {
    if (freq >= 1000) return '${(freq / 1000).toStringAsFixed(freq % 1000 == 0 ? 0 : 1)}kHz';
    return '${freq.round()}Hz';
  }

  String _freqDescription(double freq) {
    if (freq < 2000) return '저음 이명 (웅— 기계음)';
    if (freq < 4000) return '중저음 이명';
    if (freq < 6000) return '중고음 이명';
    if (freq < 8000) return '고음 이명 (삐— 전자음)';
    if (freq < 10000) return '고음 이명 (8kHz Flosser 범위)';
    return '초고음 이명';
  }

  Future<void> _saveAndApply(double freq) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppConstants.keyTinnitusFreq, freq);
    if (mounted) Navigator.pop(context, freq);
  }

  @override
  Widget build(BuildContext context) {
    final freq = ref.watch(selectedFreqProvider);
    final isPlaying = ref.watch(testTonePlayingProvider);

    return Scaffold(
      backgroundColor: AppColors.greenDark,
      appBar: AppBar(
        backgroundColor: AppColors.greenDark,
        foregroundColor: Colors.white,
        title: const Text('이명 주파수 찾기',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: Column(children: [

        // 안내
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            '🎧 이어폰을 착용하고\n"내 이명 소리와 가장 비슷한 음"을 찾으세요\n\n볼륨은 낮게 유지하세요. 불편하면 즉시 중단하세요.',
            style: TextStyle(color: AppColors.greenLight, fontSize: 13, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ),

        // 주파수 표시
        Expanded(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // 현재 주파수 큰 표시
            Text(_freqLabel(freq), style: const TextStyle(
              color: Colors.white, fontSize: 64,
              fontWeight: FontWeight.w200, letterSpacing: 2)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.green.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_freqDescription(freq),
                style: const TextStyle(color: AppColors.greenLight, fontSize: 13)),
            ),
            const SizedBox(height: 40),

            // 슬라이더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.green,
                    inactiveTrackColor: Colors.white.withOpacity(0.2),
                    thumbColor: AppColors.green,
                    overlayColor: AppColors.green.withOpacity(0.2),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                  ),
                  child: Slider(
                    value: freq,
                    min: minFreq,
                    max: maxFreq,
                    divisions: divisions,
                    onChanged: (v) {
                      // 250Hz 단위로 스냅
                      final snapped = (v / step).round() * step;
                      ref.read(selectedFreqProvider.notifier).state = snapped.toDouble();
                      _stopTestTone();
                    },
                  ),
                ),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('1kHz', style: TextStyle(color: AppColors.textLight, fontSize: 11)),
                  const Text('저음 ←────────→ 고음',
                    style: TextStyle(color: AppColors.textLight, fontSize: 11)),
                  const Text('12kHz', style: TextStyle(color: AppColors.textLight, fontSize: 11)),
                ]),
              ]),
            ),
            const SizedBox(height: 32),

            // 빠른 선택 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8, runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [1000, 2000, 3000, 4000, 6000, 8000, 10000, 12000].map((f) {
                  final isSelected = freq == f.toDouble();
                  return GestureDetector(
                    onTap: () {
                      ref.read(selectedFreqProvider.notifier).state = f.toDouble();
                      _stopTestTone();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.green : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.green : Colors.white.withOpacity(0.2)),
                      ),
                      child: Text(_freqLabel(f.toDouble()),
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.greenLight,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 32),

            // 테스트 톤 재생 버튼
            GestureDetector(
              onTap: isPlaying ? _stopTestTone : () => _playTestTone(freq),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: isPlaying ? Colors.white.withOpacity(0.15) : AppColors.green,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isPlaying ? Icons.stop : Icons.volume_up,
                    color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    isPlaying ? '정지' : '이 소리 들어보기',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),

            const SizedBox(height: 8),
            const Text('⚠️ 볼륨을 낮게 유지하세요 (3초 재생)',
              style: TextStyle(color: AppColors.textLight, fontSize: 11)),
          ],
        )),

        // 안전 경고 + 적용 버튼
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Text(
                '⚠️ 통증, 어지러움, 이명 악화 느껴지면 즉시 중단하고 이비인후과 상담',
                style: TextStyle(color: Colors.orange, fontSize: 11, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _saveAndApply(freq),
                child: Text('${_freqLabel(freq)} 로 설정'),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// 앱 상수 임시 참조
class AppConstants {
  static const String keyTinnitusFreq = 'tinnitus_frequency';
}


