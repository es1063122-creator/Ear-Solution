import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'desync_engine.dart';

class DesyncAudioPlayer {
  final DesyncEngine engine;
  AudioPlayer? _player;
  bool _isPlaying = false;
  bool _disposed = false;
  String? _filePath;

  DesyncAudioPlayer({required this.engine});
  bool get isPlaying => _isPlaying;

  Future<void> start() async {
    if (_disposed) return;
    await _cleanup();
    try {
      // WAV 생성
      final path = await _makeWav(60);
      _filePath = path;

      // 새 플레이어
      _player = AudioPlayer();
      await _player!.setFilePath(path);
      await _player!.setLoopMode(LoopMode.one);
      await _player!.setVolume(0.35); // 이명 사용자 안전 볼륨
      await _player!.play();
      _isPlaying = true;
      debugPrint('디싱크 재생 시작');
    } catch(e) {
      debugPrint('DesyncAudioPlayer.start 오류: $e');
    }
  }

  Future<void> pause() async {
    await _player?.pause();
    _isPlaying = false;
  }

  Future<void> resume() async {
    if (_disposed) return;
    if (_player == null) { await start(); return; }
    try {
      await _player!.play();
      _isPlaying = true;
    } catch(e) {
      debugPrint('resume 실패, 재시작: $e');
      await start();
    }
  }

  Future<void> stop() async {
    await _player?.stop();
    _isPlaying = false;
  }

  Future<void> _cleanup() async {
    try { await _player?.stop(); } catch(_) {}
    try { _player?.dispose(); } catch(_) {}
    _player = null;
    _isPlaying = false;
    if (_filePath != null) {
      try { File(_filePath!).deleteSync(); } catch(_) {}
      _filePath = null;
    }
  }

  void dispose() {
    _disposed = true;
    Future(() => _cleanup()); // unawaited
  }

  Future<String> _makeWav(int secs) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/desync_${DateTime.now().millisecondsSinceEpoch}.wav';
    const sr = 44100;
    final total = sr * secs;
    final pcm = Int16List(total);
    int offset = 0;
    while (offset < total) {
      final chunk = engine.generateBuffer();
      for (int i = 0; i < chunk.length && offset < total; i++) {
        pcm[offset++] = (chunk[i] * 32767).round().clamp(-32768, 32767);
      }
    }
    final bytes = _buildWav(pcm, sr);
    await File(path).writeAsBytes(bytes);
    debugPrint('WAV 생성: $path');
    return path;
  }

  List<int> _buildWav(Int16List pcm, int sr) {
    final ds = pcm.length * 2;
    final h = ByteData(44);
    [0x52,0x49,0x46,0x46].asMap().forEach((i,v)=>h.setUint8(i,v));
    h.setUint32(4,36+ds,Endian.little);
    [0x57,0x41,0x56,0x45].asMap().forEach((i,v)=>h.setUint8(8+i,v));
    [0x66,0x6D,0x74,0x20].asMap().forEach((i,v)=>h.setUint8(12+i,v));
    h.setUint32(16,16,Endian.little); h.setUint16(20,1,Endian.little);
    h.setUint16(22,1,Endian.little); h.setUint32(24,sr,Endian.little);
    h.setUint32(28,sr*2,Endian.little); h.setUint16(32,2,Endian.little);
    h.setUint16(34,16,Endian.little);
    [0x64,0x61,0x74,0x61].asMap().forEach((i,v)=>h.setUint8(36+i,v));
    h.setUint32(40,ds,Endian.little);
    final r = <int>[...h.buffer.asUint8List()];
    for(final s in pcm){r.add(s&0xFF);r.add((s>>8)&0xFF);}
    return r;
  }
}
