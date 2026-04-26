import 'dart:math';
import 'dart:typed_data';

/// 뉴캐슬대학 2025 연구 기반
/// Cross-frequency de-correlating stimulus modulation
/// 각 주파수가 서로 다른 타이밍으로 변조되어 뇌 신경 동기화를 깨뜨림
class DesyncEngine {
  static const int sampleRate = 44100;
  static const int bufferSize = 4096;

  final Random _random = Random();

  // 이명 주파수 중심 (기본 8kHz - 와이프분 맞춤)
  double tinnitusFrequency;

  // 변조 파라미터
  static const double modulationDepth = 0.4;     // 볼륨 변조 깊이
  static const double freqModDepth = 0.05;       // 주파수 변조 깊이
  static const double minModRate = 0.5;          // 최소 변조 속도 (Hz)
  static const double maxModRate = 4.0;          // 최대 변조 속도 (Hz)

  // 각 주파수 밴드 (이명 주파수 근처 ±2옥타브)
  late List<_FrequencyBand> _bands;

  // 위상 추적
  final List<double> _phases = [];
  final List<double> _modPhases = [];
  int _sampleIndex = 0;

  DesyncEngine({this.tinnitusFrequency = 8000.0}) {
    _initBands();
  }

  void _initBands() {
    // 이명 주파수 근처 8개 밴드 생성
    // 각 밴드는 서로 다른 변조 속도와 위상 오프셋을 가짐
    _bands = [];
    _phases.clear();
    _modPhases.clear();

    final freqRatios = [0.5, 0.65, 0.8, 1.0, 1.25, 1.6, 2.0, 2.5];

    for (int i = 0; i < freqRatios.length; i++) {
      final freq = tinnitusFrequency * freqRatios[i];
      // 각 밴드마다 서로 다른 변조 속도 (핵심: 탈동기화)
      final modRate = minModRate + (maxModRate - minModRate) * (i / freqRatios.length);
      // 각 밴드마다 랜덤 초기 위상 오프셋 (탈동기화 강화)
      final phaseOffset = _random.nextDouble() * 2 * pi;

      _bands.add(_FrequencyBand(
        frequency: freq.clamp(200.0, 16000.0),
        modRate: modRate,
        phaseOffset: phaseOffset,
        amplitude: _calculateAmplitude(freq),
      ));
      _phases.add(0.0);
      _modPhases.add(phaseOffset);
    }
  }

  // 주파수별 진폭 (이명 주파수 중심으로 가우시안 분포)
  double _calculateAmplitude(double freq) {
    final sigma = tinnitusFrequency * 0.5;
    final diff = freq - tinnitusFrequency;
    return exp(-diff * diff / (2 * sigma * sigma)) * 0.3;
  }

  // 이명 주파수 변경 시 재초기화
  void setTinnitusFrequency(double freq) {
    tinnitusFrequency = freq;
    _initBands();
    _sampleIndex = 0;
  }

  /// 핵심 DSP: 탈동기화 버퍼 생성
  /// 각 주파수 밴드가 서로 다른 타이밍으로 변조됨
  Float32List generateBuffer() {
    final buffer = Float32List(bufferSize);

    for (int i = 0; i < bufferSize; i++) {
      double sample = 0.0;
      final t = (_sampleIndex + i) / sampleRate;

      for (int b = 0; b < _bands.length; b++) {
        final band = _bands[b];

        // 1. 볼륨 변조 - 각 밴드마다 다른 속도로 (핵심 탈동기화)
        final volMod = 1.0 - modulationDepth * (0.5 + 0.5 * sin(
          2 * pi * band.modRate * t + _modPhases[b]
        ));

        // 2. 주파수 변조 - 밴드마다 다른 위상으로 (스펙트럴 리플)
        final freqMod = band.frequency * (1.0 + freqModDepth * sin(
          2 * pi * band.modRate * 0.7 * t + _modPhases[b] + pi / 3
        ));

        // 3. 사인파 생성
        _phases[b] += 2 * pi * freqMod / sampleRate;
        if (_phases[b] > 2 * pi) _phases[b] -= 2 * pi;

        sample += sin(_phases[b]) * band.amplitude * volMod;
      }

      // 4. 브라운 노이즈 베이스 추가 (편안함)
      sample += (_random.nextDouble() * 2 - 1) * 0.05;

      // 소프트 클리핑
      buffer[i] = sample.clamp(-0.8, 0.8).toDouble();
    }

    _sampleIndex += bufferSize;
    return buffer;
  }

  // 주파수별 변조 상태 (UI 시각화용)
  List<double> getModulationLevels() {
    final t = _sampleIndex / sampleRate;
    return List.generate(_bands.length, (b) {
      return 0.5 + 0.5 * sin(2 * pi * _bands[b].modRate * t + _modPhases[b]);
    });
  }

  List<_FrequencyBand> get bands => List.unmodifiable(_bands);
}

class _FrequencyBand {
  final double frequency;
  final double modRate;
  final double phaseOffset;
  final double amplitude;

  const _FrequencyBand({
    required this.frequency,
    required this.modRate,
    required this.phaseOffset,
    required this.amplitude,
  });
}
