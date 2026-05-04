import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 세션 완료 기준
/// 0~29분: 미완료
/// 30~59분: 부분 완료
/// 60분+: 완료
enum DayStatus { none, partial, done }

class SessionManager {
  static const String _keyPrefix = 'session_';
  static const String _keyTotalDays = 'total_days_done';

  static String _todayKey() {
    final now = DateTime.now();
    return '$_keyPrefix${now.year}-${now.month}-${now.day}';
  }

  // 오늘 누적 세션 시간(초) 저장
  static Future<void> addSeconds(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _todayKey();
    final current = prefs.getInt(key) ?? 0;
    final newTotal = current + seconds;
    await prefs.setInt(key, newTotal);

    // 완료 상태 업데이트
    final prevStatus = _getStatus(current);
    final newStatus = _getStatus(newTotal);
    if (prevStatus != DayStatus.done && newStatus == DayStatus.done) {
      // 오늘 처음 완료됨
      final total = prefs.getInt(_keyTotalDays) ?? 0;
      await prefs.setInt(_keyTotalDays, total + 1);
    }
  }

  // 오늘 누적 시간(초)
  static Future<int> getTodaySeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_todayKey()) ?? 0;
  }

  // 오늘 상태
  static Future<DayStatus> getTodayStatus() async {
    final secs = await getTodaySeconds();
    return _getStatus(secs);
  }

  // 총 완료일 수
  static Future<int> getTotalDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTotalDays) ?? 0;
  }

  // 42일치 달력 데이터 반환
  static Future<List<Map<String, dynamic>>> getCalendarData() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];

    // 프로그램 시작일 저장/로드
    final startDateStr = prefs.getString('program_start_date');
    DateTime startDate;
    if (startDateStr == null) {
      startDate = now;
      await prefs.setString('program_start_date', now.toIso8601String());
    } else {
      startDate = DateTime.parse(startDateStr);
    }

    for (int i = 0; i < 42; i++) {
      final date = startDate.add(Duration(days: i));
      final key = '$_keyPrefix${date.year}-${date.month}-${date.day}';
      final secs = prefs.getInt(key) ?? 0;
      final isToday = date.year == now.year &&
                      date.month == now.month &&
                      date.day == now.day;
      final isPast = date.isBefore(DateTime(now.year, now.month, now.day));

      String status;
      if (isToday) {
        status = 'today';
      } else if (isPast) {
        if (secs >= 3600) status = 'done';
        else if (secs >= 1800) status = 'partial';
        else status = 'missed';
      } else {
        status = 'future';
      }

      result.add({
        'day': i + 1,
        'date': date,
        'seconds': secs,
        'status': status,
        'isToday': isToday,
      });
    }
    return result;
  }

  static DayStatus _getStatus(int seconds) {
    if (seconds >= 3600) return DayStatus.done;
    if (seconds >= 1800) return DayStatus.partial;
    return DayStatus.none;
  }

  static String formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }
}
