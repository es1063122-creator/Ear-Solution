import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import 'sound_generator.dart';
import 'package:just_audio/just_audio.dart';

enum HapticSessionState { idle, running, paused, completed }

final hapticStateProvider     = StateProvider<HapticSessionState>((ref) => HapticSessionState.idle);
final hapticElapsedProvider   = StateProvider<int>((ref) => 0);
final hapticTotalDaysProvider = StateProvider<int>((ref) => 0);
final hapticSoftModeProvider  = StateProvider<bool>((ref) => true); // 햅틱은 기본 부드러움

const int hapticTargetSeconds = 900; // 15분

class HapticScreen extends ConsumerStatefulWidget {
  const HapticScreen({super.key});
  @override
  ConsumerState<HapticScreen> createState() => _HapticScreenState();
}

class _HapticScreenState extends ConsumerState<HapticScreen>
    with SingleTickerProviderStateMixin {

  Timer? _sessionTimer;
  Timer? _hapticTimer;
  AnimationController? _pulseController;
  AudioPlayer? _audioPlayer;

  @override
  void initState() {
    super.initState();
    _initAudio();
    _initAnimation();
  }

  void _initAudio() {
    // 오디오는 세션 시작 시 생성
  }

  void _initAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _hapticTimer?.cancel();
    _pulseController?.dispose();
    _pulseController = null;
    _audioPlayer?.dispose();
    super.dispose();
  }

  // 햅틱 패턴 — 타이머 기반 반복 진동
  void _startHapticPattern() {
    _hapticTimer?.cancel();
    _scheduleNextVibration();
  }

  // 기기 지원 여부 체크 후 진동
  Future<void> _vibrateOnce() async {
    try {
      HapticFeedback.heavyImpact();
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (!hasVibrator) {
        debugPrint('❌ 진동 모터 없음');
        return;
      }
      final hasAmplitude = await Vibration.hasAmplitudeControl() ?? false;
      if (hasAmplitude) {
        await Vibration.vibrate(duration: 180, amplitude: 96);
      } else {
        await Vibration.vibrate(duration: 300);
      }
      debugPrint('✅ 진동 실행됨');
    } catch (e) {
      debugPrint('❌ 진동 오류: $e');
      HapticFeedback.heavyImpact();
    }
  }

  void _scheduleNextVibration() {
    if (!mounted) return;
    if (ref.read(hapticStateProvider) != HapticSessionState.running) return;

    _vibrateOnce();

    _hapticTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      if (ref.read(hapticStateProvider) != HapticSessionState.running) return;
      _scheduleNextVibration();
    });
  }

  void _stopHapticPattern() {
    _hapticTimer?.cancel();
    _hapticTimer = null;
    // Vibration.cancel() 제거 - 오히려 진동 유발함
  }

  Future<void> _startSession() async {
    await _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _audioPlayer = AudioPlayer();

    ref.read(hapticElapsedProvider.notifier).state = 0;
    ref.read(hapticStateProvider.notifier).state = HapticSessionState.running;

    // 진동 먼저 테스트
    await _vibrateOnce();

    // 반복 진동 시작
    _startHapticPattern();

    // 부드러운 사운드 재생 (브라운노이즈 + 알파파 혼합)
    try {
      final isSoft = ref.read(hapticSoftModeProvider);
      final soundId = isSoft ? 'brown_noise' : 'masking_8k';
      // 캐시 삭제 후 새로 생성

      final file = await SoundGenerator.generateSound(soundId, volume: 1.0);
      await _audioPlayer?.stop();
      _audioPlayer?.dispose();
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setFilePath(file.path);
      await _audioPlayer!.setLoopMode(LoopMode.one);
      await _audioPlayer!.setVolume(0.85);
      await _audioPlayer!.play();
      debugPrint('햅틱 오디오 시작');
    } catch (e) {
      debugPrint('햅틱 오디오 오류: $e');
    }

    if (_pulseController == null || !(_pulseController!.isAnimating)) {
      _pulseController?.repeat(reverse: true);
    }

    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = ref.read(hapticElapsedProvider) + 1;
      ref.read(hapticElapsedProvider.notifier).state = elapsed;
      if (elapsed >= hapticTargetSeconds) _completeSession();
    });
  }

  Future<void> _pauseSession() async {
    _sessionTimer?.cancel();
    _hapticTimer?.cancel();
    _stopHapticPattern();
    await _audioPlayer?.pause();
    _pulseController?.stop();
    ref.read(hapticStateProvider.notifier).state = HapticSessionState.paused;
  }

  Future<void> _resumeSession() async {
    ref.read(hapticStateProvider.notifier).state = HapticSessionState.running;
    await _audioPlayer?.play();
    _startHapticPattern();
    _pulseController?.repeat(reverse: true);
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = ref.read(hapticElapsedProvider) + 1;
      ref.read(hapticElapsedProvider.notifier).state = elapsed;
      if (elapsed >= hapticTargetSeconds) _completeSession();
    });
  }

  Future<void> _completeSession() async {
    _sessionTimer?.cancel();
    _hapticTimer?.cancel();
    _stopHapticPattern();
    await _audioPlayer?.stop();
    _pulseController?.stop();
    ref.read(hapticStateProvider.notifier).state = HapticSessionState.completed;
    final total = ref.read(hapticTotalDaysProvider) + 1;
    ref.read(hapticTotalDaysProvider.notifier).state = total;
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 300));
    HapticFeedback.heavyImpact();
  }

  Future<void> _resetSession() async {
    _sessionTimer?.cancel();
    _hapticTimer?.cancel();
    _stopHapticPattern();
    await _audioPlayer?.stop();
    _pulseController?.stop();
    ref.read(hapticElapsedProvider.notifier).state = 0;
    ref.read(hapticStateProvider.notifier).state = HapticSessionState.idle;
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(hapticStateProvider);
    final elapsed  = ref.watch(hapticElapsedProvider);
    final total    = ref.watch(hapticTotalDaysProvider);
    final progress = elapsed / hapticTargetSeconds;
    final isRunning = state == HapticSessionState.running;

    return Scaffold(
      backgroundColor: AppColors.greenDark,
      appBar: AppBar(
        backgroundColor: AppColors.greenDark,
        foregroundColor: Colors.white,
        title: const Text('햅틱 바이모달 세션',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          Consumer(builder: (_, ref, __) {
            final isSoft = ref.watch(hapticSoftModeProvider);
            return GestureDetector(
              onTap: () async {
                ref.read(hapticSoftModeProvider.notifier).state = !isSoft;
                // 재생 중이면 새 모드 소리로 즉시 교체
                final state = ref.read(hapticStateProvider);
                if (state == HapticSessionState.running) {
                  final newSoft = !isSoft;
                  final soundId = newSoft ? 'brown_noise' : 'masking_8k';
                  try {
                    await _audioPlayer?.stop();
                    _audioPlayer?.dispose();
                    _audioPlayer = AudioPlayer();
                    final file = await SoundGenerator.generateSound(soundId, volume: 1.0);
                    await _audioPlayer!.setFilePath(file.path);
                    await _audioPlayer!.setLoopMode(LoopMode.one);
                    await _audioPlayer!.setVolume(0.85);
                    await _audioPlayer!.play();
                  } catch(e) { debugPrint('햅틱 모드 전환 오류: ' + e.toString()); }
                }
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSoft ? AppColors.greenLight.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSoft ? AppColors.greenLight : Colors.white.withOpacity(0.3)),
                ),
                child: Text(isSoft ? '🌊 부드러움' : '⚡ 기본',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            );
          }),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(20)),
            child: const Text('이완 보조',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(children: [

        // 진행 카드
        Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('바이모달 프로그램', style: TextStyle(color: AppColors.greenLight, fontSize: 12)),
              const SizedBox(height: 4),
              Text('$total / 42일 완료',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(20)),
              child: Text(
                total >= 42 ? '완료! 🎉' : '${42 - total}일 남음',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),

        // 중앙 시각화 + 타이머
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // 펄스 애니메이션
                if (_pulseController != null)
                  AnimatedBuilder(
                    animation: _pulseController!,
                    builder: (_, __) {
                      final v = _pulseController!.value;
                      return SizedBox(
                        width: 200, height: 200,
                        child: Stack(alignment: Alignment.center, children: [
                          if (isRunning) ...[
                            Container(
                              width: 180 + v * 20,
                              height: 180 + v * 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.green.withOpacity(0.15 - v * 0.1),
                                  width: 2),
                              ),
                            ),
                            Container(
                              width: 150 + v * 15,
                              height: 150 + v * 15,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.green.withOpacity(0.25 - v * 0.15),
                                  width: 2),
                              ),
                            ),
                          ],
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isRunning ? AppColors.green : Colors.white.withOpacity(0.1),
                            ),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(
                                isRunning ? Icons.vibration : Icons.phone_android,
                                color: Colors.white, size: 28),
                              const SizedBox(height: 4),
                              Text(
                                isRunning ? '진동 중' : '대기',
                                style: const TextStyle(color: Colors.white, fontSize: 11)),
                            ]),
                          ),
                        ]),
                      );
                    },
                  ),

                const SizedBox(height: 24),

                // 타이머
                Text(_formatTime(elapsed),
                  style: const TextStyle(
                    color: Colors.white, fontSize: 52,
                    fontWeight: FontWeight.w300, letterSpacing: 2)),
                const SizedBox(height: 6),
                Text('목표 ${_formatTime(hapticTargetSeconds)}',
                  style: const TextStyle(color: AppColors.greenLight, fontSize: 13)),
                const SizedBox(height: 20),

                // 진행 바
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white12,
                      color: AppColors.greenLight,
                      minHeight: 4),
                  ),
                ),
                const SizedBox(height: 6),
                Text('${(progress * 100).round()}% 완료',
                  style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),

        // 안내 + 컨트롤
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                state == HapticSessionState.idle
                  ? '📱 폰을 손에 쥐고 이어폰 착용 후 시작하세요\n소리와 부드러운 진동으로 긴장 완화를 돕습니다'
                  : state == HapticSessionState.running
                    ? '🎧 소리 + 진동 이완 진행 중\n폰을 손에 쥔 채로 편안히 계세요'
                    : state == HapticSessionState.completed
                      ? '🎉 오늘 이완 세션 완료! 수고하셨어요'
                      : '⏸ 세션 일시정지 중',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.greenLight, fontSize: 13, height: 1.5),
              ),
            ),
            const SizedBox(height: 16),

            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (state != HapticSessionState.idle && state != HapticSessionState.completed)
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: GestureDetector(
                    onTap: _resetSession,
                    child: Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle),
                      child: const Icon(Icons.stop, color: Colors.white, size: 24),
                    ),
                  ),
                ),

              GestureDetector(
                onTap: _vibrateOnce,
                child: Container(
                  width: 52, height: 52,
                  margin: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle),
                  child: const Icon(Icons.vibration, color: Colors.white, size: 24),
                ),
              ),

              GestureDetector(
                onTap: () {
                  if (state == HapticSessionState.idle) _startSession();
                  else if (state == HapticSessionState.running) _pauseSession();
                  else if (state == HapticSessionState.paused) _resumeSession();
                  else _resetSession();
                },
                child: Container(
                  width: 68, height: 68,
                  decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                  child: Icon(
                    state == HapticSessionState.running ? Icons.pause
                      : state == HapticSessionState.completed ? Icons.refresh
                        : Icons.play_arrow,
                    color: Colors.white, size: 34),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
