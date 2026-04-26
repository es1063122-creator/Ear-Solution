import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'desync_engine.dart';

/// PCM → WAV 파일 → just_audio 재생
/// StreamAudioSource 대신 파일 기반으로 안정적 재생
class DesyncAudioPlayer {
  final DesyncEngine engine;
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _disposed = false;

  DesyncAudioPlayer({required this.engine});

  bool get isPlaying => _isPlaying;

  Future<void> start() async {
    if (_isPlaying || _disposed) return;
    try {
      // 30초짜리 WAV 파일 생성 후 루프 재생
      final file = await _generateWavFile(durationSeconds: 30);
      await _player.setFilePath(file.path);
      await _player.setLoopMode(LoopMode.one); // 루프
      await _player.setVolume(0.85);
      await _player.play();
      _isPlaying = true;
    } catch (e) {
      debugPrint('DesyncAudioPlayer start error: $e');
    }
  }

  Future<void> pause() async {
    await _player.pause();
    _isPlaying = false;
  }

  Future<void> resume() async {
    await _player.play();
    _isPlaying = true;
  }

  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
  }

  void dispose() {
    _disposed = true;
    _player.dispose();
  }

  /// DSP 엔진으로 WAV 파일 생성
  Future<File> _generateWavFile({int durationSeconds = 30}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/desync_${DateTime.now().millisecondsSinceEpoch}.wav');

    const int sampleRate = 44100;
    final int totalSamples = sampleRate * durationSeconds;
    final pcmData = Int16List(totalSamples);

    // DSP 엔진으로 PCM 데이터 생성
    int offset = 0;
    while (offset < totalSamples) {
      final chunk = engine.generateBuffer();
      for (int i = 0; i < chunk.length && offset < totalSamples; i++) {
        pcmData[offset++] = (chunk[i] * 32767).round().clamp(-32768, 32767);
      }
    }

    // WAV 파일 작성
    final bytes = _buildWav(pcmData, sampleRate);
    await file.writeAsBytes(bytes);
    debugPrint('WAV 생성 완료: ${file.path} (${bytes.length} bytes)');
    return file;
  }

  List<int> _buildWav(Int16List pcm, int sampleRate) {
    final dataSize = pcm.length * 2;
    final header = ByteData(44);

    // RIFF
    [0x52,0x49,0x46,0x46].asMap().forEach((i,v) => header.setUint8(i, v));
    header.setUint32(4, 36 + dataSize, Endian.little);
    // WAVE
    [0x57,0x41,0x56,0x45].asMap().forEach((i,v) => header.setUint8(8+i, v));
    // fmt
    [0x66,0x6D,0x74,0x20].asMap().forEach((i,v) => header.setUint8(12+i, v));
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);   // PCM
    header.setUint16(22, 1, Endian.little);   // mono
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little); // byteRate
    header.setUint16(32, 2, Endian.little);   // blockAlign
    header.setUint16(34, 16, Endian.little);  // bitsPerSample
    // data
    [0x64,0x61,0x74,0x61].asMap().forEach((i,v) => header.setUint8(36+i, v));
    header.setUint32(40, dataSize, Endian.little);

    final result = <int>[];
    result.addAll(header.buffer.asUint8List());
    for (final sample in pcm) {
      result.add(sample & 0xFF);
      result.add((sample >> 8) & 0xFF);
    }
    return result;
  }
}
