import 'dart:math';
import 'dart:typed_data';

/// Auris Neural Desync Engine (Soft Version)
/// Based on: Yukhnovich EA et al., Hearing Research, 2025
/// 논문 원리 기반 근사 구현 - 부드러운 사운드 버전
/// 핵심: cross-frequency de-correlating modulation
/// 변경: 날카로운 harmonic → 핑크노이즈 베이스 + 부드러운 변조
class DesyncEngine {
  static const int sampleRate = 44100;
  static const int bufferSize = 4096;

  final Random _random = Random();
  double tinnitusFrequency;

  // 논문 파라미터
  static const double mu = 4.5;       // spectral modulation mean
  static const double r = 3.0;        // spectral modulation variability
  static const double nu = 0.125;     // spectral modulation rate (Hz)
  static const double omega = 1.0;    // temporal modulation rate (Hz)

  // 핑크노이즈 상태
  final List<double> _pinkState = List.filled(7, 0.0);
  double _lastBrown = 0.0;

  // 각 밴드 변조 위상
  late List<_FrequencyBand> _bands;
  final List<double> _sinPhases = [];
  int _sampleIndex = 0;

  bool softMode;

  DesyncEngine({this.tinnitusFrequency = 8000.0, this.softMode = false}) {
    _initBands();
  }

  void _initBands() {
    _bands = [];
    _sinPhases.clear();

    // 이명 주파수 중심 1옥타브 밴드 내 8개 밴드
    final freqRatios = [0.707, 0.78, 0.86, 0.95, 1.05, 1.16, 1.28, 1.414];
    for (int i = 0; i < freqRatios.length; i++) {
      final freq = (tinnitusFrequency * freqRatios[i]).clamp(200.0, 16000.0);
      _bands.add(_FrequencyBand(
        frequency: freq,
        modRate: 0.5 + (3.5 * i / freqRatios.length), // 0.5~4Hz
        phaseOffset: _random.nextDouble() * 2 * pi,
        qPhase: _random.nextDouble() * 2 * pi,
        pPhase: _random.nextDouble() * 2 * pi,
      ));
      _sinPhases.add(0.0);
    }
    _sampleIndex = 0;
  }

  void setTinnitusFrequency(double freq) {
    tinnitusFrequency = freq.clamp(1000.0, 12000.0);
    _initBands();
  }

  void setSoftMode(bool soft) {
    softMode = soft;
  }

  Float32List generateBuffer() {
    final buffer = Float32List(bufferSize);
    final c = tinnitusFrequency;
    final bandLow  = c / sqrt2;
    final bandHigh = c * sqrt2;

    for (int i = 0; i < bufferSize; i++) {
      final t = (_sampleIndex + i) / sampleRate;

      // 1. 핑크노이즈 생성 (부드러운 베이스)
      final white = _random.nextDouble() * 2 - 1;
      _pinkState[0] = 0.99886 * _pinkState[0] + white * 0.0555179;
      _pinkState[1] = 0.99332 * _pinkState[1] + white * 0.0750759;
      _pinkState[2] = 0.96900 * _pinkState[2] + white * 0.1538520;
      _pinkState[3] = 0.86650 * _pinkState[3] + white * 0.3104856;
      _pinkState[4] = 0.55000 * _pinkState[4] + white * 0.5329522;
      _pinkState[5] = -0.7616 * _pinkState[5] - white * 0.0168980;
      final pink = (_pinkState[0] + _pinkState[1] + _pinkState[2] +
                    _pinkState[3] + _pinkState[4] + _pinkState[5] +
                    _pinkState[6] + white * 0.5362) * 0.11;
      _pinkState[6] = white * 0.115926;

      // 2. 논문 기반 변조 사운드 생성
      double harmonicSum = 0.0;
      for (int b = 0; b < _bands.length; b++) {
        final band = _bands[b];
        final freq = band.frequency;

        // Fn = log2(freq / c)
        final Fn = log(freq / c) / log(2);

        // S(t) = mu + r * sin(p + 2π*nu*t)
        final St = mu + r * sin(band.pPhase + 2 * pi * nu * t);

        // An(t) = 1 + sin(2π[omega*t + Fn*S(t)] + q)
        final An = 1 + sin(2 * pi * (omega * t + Fn * St) + band.qPhase);

        // 밴드 내 harmonic만 변조 적용
        final inBand = freq >= bandLow && freq <= bandHigh;
        final amp = inBand ? max(0.0, An) : 1.0;

        // 가우시안 가중치로 고차 harmonic 감쇠 (날카로움 제거)
        final weight = exp(-0.4 * b / _bands.length);

        _sinPhases[b] += 2 * pi * freq / sampleRate;
        if (_sinPhases[b] > 2 * pi) _sinPhases[b] -= 2 * pi;

        harmonicSum += sin(_sinPhases[b]) * amp * weight;
      }

      // 3. 혼합 - 소리 모드에 따라 다르게
      final norm = 0.12 / sqrt(_bands.length.toDouble());
      final harmonicPart = harmonicSum * norm;

      double sample;
      if (softMode) {
        // 🌊 부드러움: 브라운노이즈 베이스 + 낮은 변조 (편안한 저음)
        _lastBrown = (_lastBrown + 0.02 * white) / 1.02;
        final brownPart = _lastBrown.clamp(-1.0, 1.0) * 0.4;
        final noisePart = pink * 0.2;
        final softCarrier = sin(2 * pi * c * t) *
          (0.3 + 0.3 * sin(2 * pi * nu * t)) * 0.05;
        sample = harmonicPart * 0.3 + brownPart + noisePart + softCarrier;
        sample = tanh(sample * 1.0) * 0.5;
      } else {
        // ⚡ 기본: 변조음 강함 (논문 원리에 더 가까움)
        final noisePart = pink * 0.15;
        sample = harmonicPart * 1.2 + noisePart;
        sample = tanh(sample * 2.0) * 0.7;
      }

      buffer[i] = sample.clamp(-0.6, 0.6);
    }

    _sampleIndex += bufferSize;
    return buffer;
  }

  // tanh 근사
  static double tanh(double x) {
    if (x > 3) return 1.0;
    if (x < -3) return -1.0;
    final e2x = exp(2 * x);
    return (e2x - 1) / (e2x + 1);
  }

  static const double sqrt2 = 1.41421356237;

  List<_FrequencyBand> get bands => List.unmodifiable(_bands);
}

class _FrequencyBand {
  final double frequency;
  final double modRate;
  final double phaseOffset;
  final double qPhase;
  final double pPhase;

  const _FrequencyBand({
    required this.frequency,
    required this.modRate,
    required this.phaseOffset,
    required this.qPhase,
    required this.pPhase,
  });
}
