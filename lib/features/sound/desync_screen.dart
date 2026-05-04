import 'dart:async';
import '../../core/utils/session_manager.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import 'desync_engine.dart';
import 'desync_audio_player.dart';
import 'frequency_matcher.dart' as fm;

enum DesyncSessionState { idle, running, paused, completed }

final desyncStateProvider     = StateProvider<DesyncSessionState>((ref) => DesyncSessionState.idle);
final desyncElapsedProvider   = StateProvider<int>((ref) => 0);
final desyncFreqProvider      = StateProvider<double>((ref) => 8000.0);
final desyncTotalDaysProvider = StateProvider<int>((ref) => 0);
final desyncSoftModeProvider  = StateProvider<bool>((ref) => false); // false=기본, true=부드러움

const int sessionTargetSeconds = 3600;
const int sessionTotalDays = 42;

class DesyncScreen extends ConsumerStatefulWidget {
  const DesyncScreen({super.key});
  @override
  ConsumerState<DesyncScreen> createState() => _DesyncScreenState();
}

class _DesyncScreenState extends ConsumerState<DesyncScreen>
    with SingleTickerProviderStateMixin {

  Timer? _timer;
  int _beforeIntensity = 5;
  late AnimationController _waveController;
  DesyncEngine? _engine;
  DesyncAudioPlayer? _audioPlayer;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면 재진입 시 재생 중이었으면 오디오 재시작
    final state = ref.read(desyncStateProvider);
    if (state == DesyncSessionState.running && (_audioPlayer == null || !(_audioPlayer!.isPlaying))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _restartAudio();
      });
    }
  }

  Future<void> _restartAudio() async {
    _initAudio();
    await _audioPlayer!.start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer?.dispose();
    _waveController.dispose();
    super.dispose();
  }

  // 매번 시작할 때 새로 생성 (뒤로갔다 다시 올 때도 정상 작동)
  void _initAudio() {
    _audioPlayer?.dispose();
    final freq = ref.read(desyncFreqProvider);
    final isSoft = ref.read(desyncSoftModeProvider);
    _engine = DesyncEngine(tinnitusFrequency: freq, softMode: isSoft);
    _audioPlayer = DesyncAudioPlayer(engine: _engine!);
  }

  Future<void> _startSession() async {
    // 음량 안전 경고
    final confirmed = await _showSafetyWarning();
    if (!confirmed) return;

    _initAudio();
    ref.read(desyncStateProvider.notifier).state = DesyncSessionState.running;
    await _audioPlayer!.start();
    _startElapsedTimer();
  }

  Future<void> _pauseSession() async {
    _timer?.cancel();
    await _audioPlayer?.pause();
    ref.read(desyncStateProvider.notifier).state = DesyncSessionState.paused;
  }

  Future<void> _resumeSession() async {
    await _audioPlayer?.resume();
    ref.read(desyncStateProvider.notifier).state = DesyncSessionState.running;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = ref.read(desyncElapsedProvider) + 1;
      ref.read(desyncElapsedProvider.notifier).state = elapsed;
      // 자동 누적 시간 저장 (10초마다)
      if (elapsed % 10 == 0) SessionManager.addSeconds(10);
      if (elapsed >= sessionTargetSeconds) _completeSession();
    });
  }

  Future<void> _completeSession() async {
    _timer?.cancel();
    await _audioPlayer?.stop();
    ref.read(desyncStateProvider.notifier).state = DesyncSessionState.completed;
    final total = ref.read(desyncTotalDaysProvider) + 1;
    ref.read(desyncTotalDaysProvider.notifier).state = total;
    // 사후 이명 강도 기록
    if (mounted) await _showAfterCheck();
  }

  Future<void> _showAfterCheck() async {
    int afterIntensity = _beforeIntensity;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.greenDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('세션 완료! 🎉', style: TextStyle(color: Colors.white, fontSize: 17)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('세션 후 이명 상태가 어떤가요?',
              style: TextStyle(color: AppColors.greenLight, fontSize: 13)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _AfterBtn(label: '줄어든 것 같아요', emoji: '😊',
                selected: afterIntensity < _beforeIntensity,
                onTap: () => setState(() => afterIntensity = (_beforeIntensity - 2).clamp(1, 10))),
              _AfterBtn(label: '비슷해요', emoji: '😐',
                selected: afterIntensity == _beforeIntensity,
                onTap: () => setState(() => afterIntensity = _beforeIntensity)),
              _AfterBtn(label: '더 심한 것 같아요', emoji: '😔',
                selected: afterIntensity > _beforeIntensity,
                onTap: () => setState(() => afterIntensity = (_beforeIntensity + 2).clamp(1, 10))),
            ]),
            const SizedBox(height: 16),
            if (afterIntensity < _beforeIntensity)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10)),
                child: const Text('세션 전보다 편안해졌어요 ✨\n꾸준히 들으면 누적 기록이 쌓입니다',
                  style: TextStyle(color: AppColors.greenLight, fontSize: 12, height: 1.5)))
            else if (afterIntensity > _beforeIntensity)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
                child: const Text('이명이 더 불편하면 볼륨을 낮추거나 전문의와 상담해 보세요',
                  style: TextStyle(color: Colors.orange, fontSize: 12, height: 1.5))),
            const SizedBox(height: 8),
            const Text('변화는 개인차가 있습니다. 기록을 통해 패턴을 확인해보세요',
              style: TextStyle(color: AppColors.textLight, fontSize: 11),
              textAlign: TextAlign.center),
          ]),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('확인')),
          ],
        ),
      ),
    );
  }

  Future<bool> _showSafetyWarning() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.greenDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('시작 전 확인', style: TextStyle(color: Colors.white, fontSize: 17)),
        content: const Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('✅ 이어폰 착용 권장\n✅ 볼륨을 낮게 유지하세요\n✅ 편안한 자세로 시작하세요\n\n⚠️ 통증·어지러움·이명 악화 시 즉시 중단하고 전문의 상담',
            style: TextStyle(color: AppColors.greenLight, fontSize: 13, height: 1.7)),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: AppColors.textLight))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('시작하기')),
        ],
      ),
    );
    return result ?? false;
  }

  void _startElapsedTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final elapsed = ref.read(desyncElapsedProvider) + 1;
      ref.read(desyncElapsedProvider.notifier).state = elapsed;
      if (elapsed % 10 == 0) SessionManager.addSeconds(10);
      if (elapsed >= sessionTargetSeconds) _completeSession();
    });
  }

  Future<void> _resetSession() async {
    _timer?.cancel();
    await _audioPlayer?.stop();
    ref.read(desyncElapsedProvider.notifier).state = 0;
    ref.read(desyncStateProvider.notifier).state = DesyncSessionState.idle;
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state     = ref.watch(desyncStateProvider);
    final elapsed   = ref.watch(desyncElapsedProvider);
    final freq      = ref.watch(desyncFreqProvider);
    final totalDays = ref.watch(desyncTotalDaysProvider);
    final progress  = (elapsed / sessionTargetSeconds).clamp(0.0, 1.0);

    // 엔진이 없으면 임시 생성 (시각화용)
    final engine = _engine ?? DesyncEngine(tinnitusFrequency: freq);

    return Scaffold(
      backgroundColor: AppColors.greenDark,
      appBar: AppBar(
        backgroundColor: AppColors.greenDark,
        foregroundColor: Colors.white,
        title: const Text('디싱크 사운드 세션',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          Consumer(builder: (_, ref, __) {
            final isSoft = ref.watch(desyncSoftModeProvider);
            return GestureDetector(
              onTap: () async {
                ref.read(desyncSoftModeProvider.notifier).state = !isSoft;
                // 재생 중이면 새 모드로 즉시 재시작
                final state = ref.read(desyncStateProvider);
                if (state == DesyncSessionState.running) {
                  await _audioPlayer?.stop();
                  _initAudio();
                  await _audioPlayer!.start();
                }
              },
              child: Container(
                margin: const EdgeInsets.only(right: 4),
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
          TextButton(
            onPressed: () => _showFreqSetting(context, freq),
            child: Text('${(freq / 1000).toStringAsFixed(1)}kHz',
              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(children: [
        _buildHeader(totalDays),
        Expanded(child: SingleChildScrollView(
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            _DesyncVisualizer(
              engine: engine,
              isRunning: state == DesyncSessionState.running,
              controller: _waveController,
            ),
            const SizedBox(height: 32),
            Text(_formatTime(elapsed), style: const TextStyle(
              color: Colors.white, fontSize: 56,
              fontWeight: FontWeight.w300, letterSpacing: 2)),
            const SizedBox(height: 8),
            Text('목표 ${_formatTime(sessionTargetSeconds)}',
              style: const TextStyle(color: AppColors.greenLight, fontSize: 14)),
            const SizedBox(height: 24),
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
            const SizedBox(height: 8),
            Text('${(progress * 100).round()}% 완료',
              style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
          ],
        ))),
        _buildControls(state),
      ]),
    );
  }

  Widget _buildHeader(int totalDays) => Container(
    margin: const EdgeInsets.all(20),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('6주 루틴', style: TextStyle(color: AppColors.greenLight, fontSize: 12)),
        const SizedBox(height: 4),
        Text('$totalDays / $sessionTotalDays일 완료',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(20)),
        child: Text(
          totalDays >= sessionTotalDays ? '완료! 🎉' : '${sessionTotalDays - totalDays}일 남음',
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    ]),
  );

  Widget _buildControls(DesyncSessionState state) => Container(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
    child: Column(children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          state == DesyncSessionState.idle
            ? '🎧 이어폰을 착용하고 편안한 자세로 시작하세요\n변조된 소리가 이상하게 들리는 게 정상입니다'
            : state == DesyncSessionState.running
              ? '🎧 변조 사운드 재생 중\n낮은 볼륨으로 편안하게 들어보세요'
              : state == DesyncSessionState.completed
                ? '🎉 오늘 세션 완료! 수고하셨어요\n변화는 개인차가 있어요. 기록을 함께 확인해보세요'
                : '⏸ 일시정지 중 · 언제든 이어서 들을 수 있어요',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.greenLight, fontSize: 13, height: 1.6),
        ),
      ),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (state != DesyncSessionState.idle && state != DesyncSessionState.completed)
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
          onTap: () {
            if (state == DesyncSessionState.idle) _startSession();
            else if (state == DesyncSessionState.running) _pauseSession();
            else if (state == DesyncSessionState.paused) _resumeSession();
            else _resetSession();
          },
          child: Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
            child: Icon(
              state == DesyncSessionState.running ? Icons.pause
                : state == DesyncSessionState.completed ? Icons.refresh
                  : Icons.play_arrow,
              color: Colors.white, size: 36),
          ),
        ),
      ]),
    ]),
  );

  void _showFreqSetting(BuildContext context, double currentFreq) async {
    final result = await Navigator.push<double>(
      context,
      MaterialPageRoute(builder: (_) => const fm.FrequencyMatcherScreen()),
    );
    if (result != null) {
      ref.read(desyncFreqProvider.notifier).state = result;
      _engine?.setTinnitusFrequency(result);
    }
  }
}

class _DesyncVisualizer extends StatelessWidget {
  final DesyncEngine engine;
  final bool isRunning;
  final AnimationController controller;
  const _DesyncVisualizer({required this.engine, required this.isRunning, required this.controller});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (_, __) => CustomPaint(
      size: const Size(300, 130),
      painter: _DesyncPainter(
        progress: controller.value,
        isRunning: isRunning,
        bands: engine.bands,
      ),
    ),
  );
}

class _DesyncPainter extends CustomPainter {
  final double progress;
  final bool isRunning;
  final List bands;

  _DesyncPainter({required this.progress, required this.isRunning, required this.bands});

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 3.0;
    for (int b = 0; b < bands.length; b++) {
      final band = bands[b];
      final yCenter = size.height * (b + 1) / (bands.length + 1);
      final paint = Paint()
        ..color = AppColors.greenLight.withOpacity(isRunning ? 0.55 : 0.15)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      final path = Path();
      for (int x = 0; x <= size.width; x++) {
        final xNorm = x / size.width;
        final wave = sin(2 * pi * band.modRate * (t + xNorm * 0.4) + band.phaseOffset)
          * (size.height / (bands.length + 1) / 2) * 0.8;
        if (x == 0) path.moveTo(0, yCenter + wave);
        else path.lineTo(x.toDouble(), yCenter + wave);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_DesyncPainter old) => true;
}


class _AfterBtn extends StatelessWidget {
  final String label, emoji;
  final bool selected;
  final VoidCallback onTap;
  const _AfterBtn({required this.label, required this.emoji,
    required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.green : Colors.white12,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? AppColors.green : Colors.white24)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center,
          style: TextStyle(color: selected ? Colors.white : AppColors.greenLight,
            fontSize: 10, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
      ]),
    ),
  );
}