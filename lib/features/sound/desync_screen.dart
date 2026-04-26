import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import 'desync_engine.dart';
import 'desync_audio_player.dart';

enum DesyncSessionState { idle, running, paused, completed }

final desyncStateProvider    = StateProvider<DesyncSessionState>((ref) => DesyncSessionState.idle);
final desyncElapsedProvider  = StateProvider<int>((ref) => 0);
final desyncFreqProvider     = StateProvider<double>((ref) => 8000.0);
final desyncTotalDaysProvider = StateProvider<int>((ref) => 0);

const int sessionTargetSeconds = 3600; // 1시간
const int sessionTotalDays = 42;       // 6주

class DesyncScreen extends ConsumerStatefulWidget {
  const DesyncScreen({super.key});
  @override
  ConsumerState<DesyncScreen> createState() => _DesyncScreenState();
}

class _DesyncScreenState extends ConsumerState<DesyncScreen>
    with SingleTickerProviderStateMixin {

  Timer? _timer;
  late AnimationController _waveController;
  late DesyncEngine _engine;
  late DesyncAudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _engine = DesyncEngine(tinnitusFrequency: 8000.0);
    _audioPlayer = DesyncAudioPlayer(engine: _engine);
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    ref.read(desyncStateProvider.notifier).state = DesyncSessionState.running;
    await _audioPlayer.start(); // 실제 소리 시작
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = ref.read(desyncElapsedProvider) + 1;
      ref.read(desyncElapsedProvider.notifier).state = elapsed;
      if (elapsed >= sessionTargetSeconds) _completeSession();
    });
  }

  Future<void> _pauseSession() async {
    _timer?.cancel();
    await _audioPlayer.pause();
    ref.read(desyncStateProvider.notifier).state = DesyncSessionState.paused;
  }

  Future<void> _resumeSession() async {
    await _audioPlayer.resume();
    ref.read(desyncStateProvider.notifier).state = DesyncSessionState.running;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = ref.read(desyncElapsedProvider) + 1;
      ref.read(desyncElapsedProvider.notifier).state = elapsed;
      if (elapsed >= sessionTargetSeconds) _completeSession();
    });
  }

  Future<void> _completeSession() async {
    _timer?.cancel();
    await _audioPlayer.stop();
    ref.read(desyncStateProvider.notifier).state = DesyncSessionState.completed;
    final total = ref.read(desyncTotalDaysProvider) + 1;
    ref.read(desyncTotalDaysProvider.notifier).state = total;
  }

  Future<void> _resetSession() async {
    _timer?.cancel();
    await _audioPlayer.stop();
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
    final state   = ref.watch(desyncStateProvider);
    final elapsed = ref.watch(desyncElapsedProvider);
    final freq    = ref.watch(desyncFreqProvider);
    final totalDays = ref.watch(desyncTotalDaysProvider);
    final progress = elapsed / sessionTargetSeconds;

    return Scaffold(
      backgroundColor: AppColors.greenDark,
      appBar: AppBar(
        backgroundColor: AppColors.greenDark,
        foregroundColor: Colors.white,
        title: const Text('신경 디싱크 세션',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: () => _showFreqSetting(context, freq),
            child: Text('${(freq / 1000).toStringAsFixed(1)}kHz',
              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(children: [
        // 프로그램 진행
        _buildHeader(totalDays),

        // 중앙 시각화 + 타이머
        Expanded(child: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 뇌파 탈동기화 시각화
            _DesyncVisualizer(
              engine: _engine,
              isRunning: state == DesyncSessionState.running,
              controller: _waveController,
            ),
            const SizedBox(height: 32),

            // 타이머
            Text(_formatTime(elapsed), style: const TextStyle(
              color: Colors.white, fontSize: 56,
              fontWeight: FontWeight.w300, letterSpacing: 2,
            )),
            const SizedBox(height: 8),
            Text('목표 ${_formatTime(sessionTargetSeconds)}',
              style: const TextStyle(color: AppColors.greenLight, fontSize: 14)),
            const SizedBox(height: 24),

            // 진행 바
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white12,
                  color: AppColors.greenLight,
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('${(progress * 100).round()}% 완료',
              style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
          ],
        ))),

        // 안내 + 컨트롤
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
        const Text('6주 프로그램', style: TextStyle(color: AppColors.greenLight, fontSize: 12)),
        const SizedBox(height: 4),
        Text('$totalDays / $sessionTotalDays일 완료',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(20)),
        child: Text(
          totalDays >= sessionTotalDays ? '완료! 🎉' : '${sessionTotalDays - totalDays}일 남음',
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    ]),
  );

  Widget _buildControls(DesyncSessionState state) => Container(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
    child: Column(children: [
      // 안내 텍스트
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
              ? '🧠 뇌 신경 탈동기화 진행 중\n이어폰을 유지하고 편안히 계세요'
              : state == DesyncSessionState.completed
                ? '🎉 오늘 세션 완료! 수고하셨어요\n효과는 3주 이상 지속될 수 있어요'
                : '⏸ 세션 일시정지 중',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.greenLight, fontSize: 13, height: 1.6),
        ),
      ),
      const SizedBox(height: 20),

      // 버튼
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
                  shape: BoxShape.circle,
                ),
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
              color: Colors.white, size: 36,
            ),
          ),
        ),
      ]),
    ]),
  );

  void _showFreqSetting(BuildContext context, double currentFreq) {
    final freqs = [
      {'label': '4kHz', 'value': 4000.0, 'desc': '저음 이명'},
      {'label': '6kHz', 'value': 6000.0, 'desc': '중고음 이명'},
      {'label': '8kHz', 'value': 8000.0, 'desc': '고음 이명 (와이프 맞춤)'},
      {'label': '10kHz', 'value': 10000.0, 'desc': '매우 고음'},
      {'label': '12kHz', 'value': 12000.0, 'desc': '초고음'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.greenDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('이명 주파수 설정',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('본인 이명 소리와 가장 비슷한 주파수를 선택하세요',
              style: TextStyle(color: AppColors.greenLight, fontSize: 13)),
            const SizedBox(height: 16),
            ...freqs.map((f) {
              final selected = currentFreq == f['value'];
              return GestureDetector(
                onTap: () {
                  final newFreq = f['value'] as double;
                  ref.read(desyncFreqProvider.notifier).state = newFreq;
                  _engine.setTinnitusFrequency(newFreq);
                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.green : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(f['label'] as String,
                        style: TextStyle(color: Colors.white,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400, fontSize: 15)),
                      Text(f['desc'] as String,
                        style: const TextStyle(color: AppColors.greenLight, fontSize: 12)),
                    ])),
                    if (selected) const Icon(Icons.check, color: Colors.white),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}

// 뇌파 탈동기화 시각화
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
