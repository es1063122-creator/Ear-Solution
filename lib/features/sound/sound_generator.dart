import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class SoundGenerator {
  static const int sampleRate = 44100;
  static const int durationSeconds = 30;
  static const int totalSamples = sampleRate * durationSeconds;
  static final Random _rng = Random();

  static Future<File> generateSound(String soundId, {double volume = 1.0}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/sound_$soundId.wav');

    final safeVolume = volume.clamp(0.0, 0.8).toDouble();
    final pcm = Int16List(totalSamples);
    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      double s = _gen(soundId, t, i).clamp(-1.0, 1.0);

      // fade in/out to avoid clicks at loop boundary.
      final fade = sampleRate ~/ 2;
      if (i < fade) s *= i / fade;
      if (i > totalSamples - fade) s *= (totalSamples - i) / fade;

      pcm[i] = (s * safeVolume * 18000).round().clamp(-32768, 32767);
    }

    await file.writeAsBytes(_wav(pcm), flush: true);
    debugPrint('생성: $soundId (${file.lengthSync()} bytes)');
    return file;
  }

  // Pink noise state.
  static final List<double> _pk = List.filled(7, 0.0);
  static double _lb = 0.0;

  static double _pink() {
    final w = _rng.nextDouble() * 2 - 1;
    _pk[0] = 0.99886 * _pk[0] + w * 0.0555179;
    _pk[1] = 0.99332 * _pk[1] + w * 0.0750759;
    _pk[2] = 0.96900 * _pk[2] + w * 0.1538520;
    _pk[3] = 0.86650 * _pk[3] + w * 0.3104856;
    _pk[4] = 0.55000 * _pk[4] + w * 0.5329522;
    _pk[5] = -0.7616 * _pk[5] - w * 0.0168980;
    final p = (_pk[0] + _pk[1] + _pk[2] + _pk[3] + _pk[4] + _pk[5] + _pk[6] + w * 0.5362) * 0.11;
    _pk[6] = w * 0.115926;
    return p.clamp(-1.0, 1.0);
  }

  static double _brown() {
    final w = _rng.nextDouble() * 2 - 1;
    _lb = (_lb + 0.02 * w) / 1.02;
    return (_lb * 3.5).clamp(-1.0, 1.0);
  }

  static double _gen(String id, double t, int i) {
    switch (id) {
      case 'masking_8k':
        // Safer lower-output 8 kHz masking layer.
        return _pink() * 0.35 + sin(2 * pi * 8000 * t) * 0.16 + sin(2 * pi * 7500 * t) * 0.08 + sin(2 * pi * 8500 * t) * 0.08;
      case 'pink_noise':
        return _pink() * 0.75;
      case 'brown_noise':
        return _brown() * 0.75;
      case 'rain':
        final base = _pink() * 0.5;
        final drop = _rng.nextDouble() < 0.003 ? sin(2 * pi * 1200 * t) * _rng.nextDouble() * 0.25 : 0.0;
        return base + drop;
      case 'waves':
        final wave = sin(2 * pi * 0.1 * t) * 0.5 + 0.5;
        final wave2 = sin(2 * pi * 0.07 * t) * 0.3 + 0.7;
        return _brown() * wave * wave2 * 0.75;
      case 'forest':
        final base = _pink() * 0.45;
        final leaf = _rng.nextDouble() < 0.001 ? _pink() * 0.22 * sin(2 * pi * 800 * t) : 0.0;
        final bird = sin(2 * pi * 12 * t) > 0.98 ? sin(2 * pi * (3000 + sin(2 * pi * 5 * t) * 200) * t) * 0.10 : 0.0;
        return base + leaf + bird;
      case 'cricket':
        final chirpRate = 4.0;
        final chirpPhase = (t * chirpRate) % 1.0;
        if (chirpPhase >= 0.3) return _pink() * 0.04;
        final intensity = sin(pi * chirpPhase / 0.3);
        return (sin(2 * pi * 4200 * t) * 0.25 + sin(2 * pi * 4500 * t) * 0.18) * intensity + _pink() * 0.08;
      case 'cafe':
        final rumble = sin(2 * pi * 80 * t) * 0.10 + sin(2 * pi * 120 * t) * 0.07;
        final voice = _pink() * 0.26 * (sin(2 * pi * 0.3 * t) * 0.3 + 0.7);
        final cup = _rng.nextDouble() < 0.0005 ? sin(2 * pi * 800 * t) * 0.12 : 0.0;
        return rumble + voice + cup;
      case 'fan':
        return sin(2 * pi * 50 * t) * 0.18 + sin(2 * pi * 100 * t) * 0.09 + sin(2 * pi * 150 * t) * 0.05 + _pink() * 0.18;
      case 'binaural_alpha':
        // Mono approximation. Keep modest volume for comfort.
        return sin(2 * pi * 440 * t) * 0.18 + sin(2 * pi * 10 * t) * 0.04;
      default:
        return _pink() * 0.45;
    }
  }

  static List<int> _wav(Int16List pcm) {
    final dataSize = pcm.length * 2;
    final header = ByteData(44);
    const riff = [0x52, 0x49, 0x46, 0x46];
    const wave = [0x57, 0x41, 0x56, 0x45];
    const fmt = [0x66, 0x6D, 0x74, 0x20];
    const data = [0x64, 0x61, 0x74, 0x61];
    for (var i = 0; i < 4; i++) header.setUint8(i, riff[i]);
    header.setUint32(4, 36 + dataSize, Endian.little);
    for (var i = 0; i < 4; i++) header.setUint8(8 + i, wave[i]);
    for (var i = 0; i < 4; i++) header.setUint8(12 + i, fmt[i]);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    for (var i = 0; i < 4; i++) header.setUint8(36 + i, data[i]);
    header.setUint32(40, dataSize, Endian.little);

    final result = <int>[...header.buffer.asUint8List()];
    for (final sample in pcm) {
      result.add(sample & 0xFF);
      result.add((sample >> 8) & 0xFF);
    }
    return result;
  }
}

class SoundMixerPlayer {
  final Map<String, AudioPlayer> _players = <String, AudioPlayer>{};
  final Map<String, double> _volumes = <String, double>{};
  final Map<String, int> _versions = <String, int>{};
  bool _isPlaying = false;
  bool _disposed = false;

  bool get isPlaying => _isPlaying;
  bool get hasActiveVolume => _volumes.values.any((v) => v > 0.001);

  Future<void> setVolume(String id, double volume) async {
    if (_disposed) return;

    final safeVolume = volume.clamp(0.0, 1.0).toDouble();
    _volumes[id] = safeVolume;
    _versions[id] = (_versions[id] ?? 0) + 1;
    final version = _versions[id]!;

    if (safeVolume <= 0.001) {
      await _stopAndRemove(id);
      if (!hasActiveVolume) _isPlaying = false;
      return;
    }

    final existing = _players[id];
    if (existing != null) {
      await existing.setVolume(safeVolume);
      if (_isPlaying) await existing.play();
      return;
    }

    if (_isPlaying) {
      await _createPlayerIfStillNeeded(id, safeVolume, version);
    }
  }

  Future<void> play() async {
    if (_disposed) return;
    _isPlaying = true;

    final entries = Map<String, double>.from(_volumes).entries.where((e) => e.value > 0.001).toList();
    for (final entry in entries) {
      final id = entry.key;
      final volume = entry.value;
      _versions[id] = (_versions[id] ?? 0) + 1;
      final version = _versions[id]!;

      final existing = _players[id];
      if (existing != null) {
        await existing.setVolume(volume);
        await existing.play();
      } else {
        await _createPlayerIfStillNeeded(id, volume, version);
      }
    }

    if (!hasActiveVolume) _isPlaying = false;
  }

  Future<void> pause() async {
    _isPlaying = false;
    final players = List<AudioPlayer>.from(_players.values);
    for (final player in players) {
      try {
        await player.pause();
      } catch (e) {
        debugPrint('SoundMixerPlayer pause error: $e');
      }
    }
  }

  Future<void> stop({bool disposePlayers = true}) async {
    _isPlaying = false;
    for (final id in _players.keys.toList()) {
      _versions[id] = (_versions[id] ?? 0) + 1;
    }

    final players = List<AudioPlayer>.from(_players.values);
    _players.clear();

    for (final player in players) {
      try {
        await player.stop();
      } catch (_) {}
      if (disposePlayers) {
        try {
          await player.dispose();
        } catch (_) {}
      }
    }
  }

  Future<void> resetAll() async {
    _volumes.clear();
    await stop(disposePlayers: true);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop(disposePlayers: true);
  }

  Future<void> _createPlayerIfStillNeeded(String id, double volume, int version) async {
    try {
      final file = await SoundGenerator.generateSound(id, volume: 1.0);

      if (_disposed || !_isPlaying || (_volumes[id] ?? 0.0) <= 0.001 || _versions[id] != version) {
        return;
      }

      final player = AudioPlayer();
      _players[id] = player;
      await player.setFilePath(file.path);
      await player.setLoopMode(LoopMode.one);
      await player.setVolume((_volumes[id] ?? volume).clamp(0.0, 1.0).toDouble());

      if (_disposed || !_isPlaying || (_volumes[id] ?? 0.0) <= 0.001 || _versions[id] != version) {
        await _stopAndRemove(id);
        return;
      }

      await player.play();
    } catch (e) {
      debugPrint('SoundMixerPlayer error ($id): $e');
    }
  }

  Future<void> _stopAndRemove(String id) async {
    _versions[id] = (_versions[id] ?? 0) + 1;
    final player = _players.remove(id);
    if (player == null) return;
    try {
      await player.stop();
    } catch (_) {}
    try {
      await player.dispose();
    } catch (_) {}
  }
}
