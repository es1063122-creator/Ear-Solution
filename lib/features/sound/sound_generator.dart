import 'dart:math';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// 각 사운드 레이어를 DSP로 직접 생성
class SoundGenerator {
  static const int sampleRate = 44100;
  static const int durationSeconds = 20; // 루프용 20초
  static const int totalSamples = sampleRate * durationSeconds;
  static final Random _random = Random();

  /// 사운드 ID별 WAV 파일 생성
  static Future<File> generateSound(String soundId, {double volume = 1.0}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/sound_$soundId.wav');

    final pcm = Int16List(totalSamples);
    final generator = _getGenerator(soundId);

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      double sample = generator(t, i);
      // 페이드인/아웃 (루프 클릭 방지)
      final fadeLen = sampleRate ~/ 4;
      if (i < fadeLen) sample *= i / fadeLen;
      if (i > totalSamples - fadeLen) sample *= (totalSamples - i) / fadeLen;
      pcm[i] = (sample * volume * 28000).round().clamp(-32768, 32767);
    }

    await file.writeAsBytes(_buildWav(pcm));
    return file;
  }

  /// 사운드 ID → 생성 함수
  static double Function(double t, int i) _getGenerator(String soundId) {
    switch (soundId) {
      case 'masking_8k':
        // 8kHz 중심 핑크노이즈 밴드패스 (와이프 이명 맞춤)
        return (t, i) => _bandpassNoise(i, 6000, 10000) * 0.7;

      case 'pink_noise':
        // 핑크노이즈 (1/f 특성)
        return (t, i) => _pinkNoise(i) * 0.8;

      case 'brown_noise':
        // 브라운노이즈 (저음 강조)
        return (t, i) => _brownNoise(i) * 0.7;

      case 'rain':
        // 빗소리 = 랜덤 버스트 + 핑크노이즈
        return (t, i) {
          final base = _pinkNoise(i) * 0.5;
          final drops = (_random.nextDouble() < 0.003) ? _random.nextDouble() * 0.4 : 0.0;
          return base + drops;
        };

      case 'waves':
        // 파도 = 저음 사인 변조 + 노이즈
        return (t, i) {
          final wave = sin(2 * pi * 0.15 * t) * 0.5 + 0.5;
          return _brownNoise(i) * wave * 0.8;
        };

      case 'forest':
        // 숲소리 = 중음 노이즈 + 귀뚜라미 요소
        return (t, i) {
          final base = _bandpassNoise(i, 800, 4000) * 0.4;
          final cricket = sin(2 * pi * 3800 * t) * 0.1 *
            (sin(2 * pi * 8 * t) > 0.7 ? 1.0 : 0.0);
          return base + cricket;
        };

      case 'cricket':
        // 귀뚜라미 = 고음 주기적 버스트
        return (t, i) {
          final burst = (sin(2 * pi * 5 * t) > 0.6) ? 1.0 : 0.0;
          return sin(2 * pi * 4200 * t) * burst * 0.4 +
                 sin(2 * pi * 3800 * t) * burst * 0.3;
        };

      case 'cafe':
        // 카페 = 중음 노이즈 (사람 소리 느낌)
        return (t, i) {
          final base = _bandpassNoise(i, 200, 3000) * 0.5;
          final rumble = sin(2 * pi * 80 * t) * 0.1;
          return base + rumble;
        };

      case 'fan':
        // 선풍기 = 저음 사인 + 고음 노이즈
        return (t, i) {
          final motor = sin(2 * pi * 50 * t) * 0.3 +
                        sin(2 * pi * 100 * t) * 0.15 +
                        sin(2 * pi * 150 * t) * 0.08;
          final air = _pinkNoise(i) * 0.2;
          return motor + air;
        };

      case 'binaural_alpha':
        // 알파파 바이노럴 = 10Hz 차이 (440Hz vs 450Hz)
        return (t, i) {
          final carrier = sin(2 * pi * 440 * t) * 0.4;
          final beat = sin(2 * pi * 10 * t) * 0.1; // 10Hz 알파파
          return carrier + beat;
        };

      default:
        return (t, i) => _pinkNoise(i) * 0.5;
    }
  }

  // --- 노이즈 생성기들 ---

  static double _lastPink = 0;
  static final List<double> _pinkState = List.filled(7, 0.0);
  static double _pinkNoise(int i) {
    // Paul Kellet 핑크노이즈 알고리즘
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
    return pink.clamp(-1.0, 1.0);
  }

  static double _lastBrown = 0;
  static double _brownNoise(int i) {
    final white = _random.nextDouble() * 2 - 1;
    _lastBrown = (_lastBrown + 0.02 * white) / 1.02;
    return (_lastBrown * 3.5).clamp(-1.0, 1.0);
  }

  static double _bandpassNoise(int i, double low, double high) {
    // 간단한 밴드패스: 랜덤 + 주파수 범위 내 사인 합성
    final white = _random.nextDouble() * 2 - 1;
    final t = i / sampleRate;
    final midFreq = (low + high) / 2;
    final bandwidth = high - low;
    final sine = sin(2 * pi * midFreq * t) *
      (1 + 0.3 * sin(2 * pi * (bandwidth / 4) * t));
    return (white * 0.3 + sine * 0.7).clamp(-1.0, 1.0);
  }

  // WAV 헤더 빌더
  static List<int> _buildWav(Int16List pcm) {
    final dataSize = pcm.length * 2;
    final header = ByteData(44);
    [0x52,0x49,0x46,0x46].asMap().forEach((i,v) => header.setUint8(i, v));
    header.setUint32(4, 36 + dataSize, Endian.little);
    [0x57,0x41,0x56,0x45].asMap().forEach((i,v) => header.setUint8(8+i, v));
    [0x66,0x6D,0x74,0x20].asMap().forEach((i,v) => header.setUint8(12+i, v));
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    [0x64,0x61,0x74,0x61].asMap().forEach((i,v) => header.setUint8(36+i, v));
    header.setUint32(40, dataSize, Endian.little);
    final result = <int>[];
    result.addAll(header.buffer.asUint8List());
    for (final s in pcm) {
      result.add(s & 0xFF);
      result.add((s >> 8) & 0xFF);
    }
    return result;
  }
}

/// 사운드 레이어 믹서 오디오 매니저
class SoundMixerPlayer {
  final Map<String, AudioPlayer> _players = {};
  final Map<String, double> _volumes = {};
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  Future<void> setVolume(String soundId, double volume) async {
    _volumes[soundId] = volume;
    if (_players.containsKey(soundId)) {
      await _players[soundId]!.setVolume(volume);
      if (volume <= 0) {
        await _players[soundId]!.pause();
      } else if (_isPlaying) {
        await _players[soundId]!.play();
      }
    }
  }

  Future<void> play() async {
    _isPlaying = true;
    for (final entry in _volumes.entries) {
      if (entry.value > 0) {
        await _ensurePlayerReady(entry.key, entry.value);
      }
    }
  }

  Future<void> _ensurePlayerReady(String soundId, double volume) async {
    if (!_players.containsKey(soundId)) {
      final player = AudioPlayer();
      _players[soundId] = player;
      try {
        final file = await SoundGenerator.generateSound(soundId, volume: volume);
        await player.setFilePath(file.path);
        await player.setLoopMode(LoopMode.one);
        await player.setVolume(volume);
        if (_isPlaying) await player.play();
      } catch (e) {
        debugPrint('SoundMixerPlayer error ($soundId): $e');
      }
    } else {
      await _players[soundId]!.setVolume(volume);
      if (_isPlaying) await _players[soundId]!.play();
    }
  }

  Future<void> pause() async {
    _isPlaying = false;
    for (final player in _players.values) {
      await player.pause();
    }
  }

  Future<void> stop() async {
    _isPlaying = false;
    for (final player in _players.values) {
      await player.stop();
    }
  }

  void dispose() {
    for (final player in _players.values) {
      player.dispose();
    }
    _players.clear();
  }
}
