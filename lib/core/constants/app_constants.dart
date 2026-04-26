class AppConstants {
  static const String appName    = 'Auris';
  static const String appVersion = '1.0.0';
  static const String packageName = 'com.kdh.auris';

  static const int desyncProgramWeeks  = 6;
  static const int desyncDailyMinutes  = 60;
  static const int hapticSessionMinutes = 15;

  static const List<Map<String, dynamic>> soundLayers = [
    {'id': 'masking_8k',     'name': '8kHz 마스킹',    'icon': '🎵', 'file': 'masking_8k.mp3'},
    {'id': 'pink_noise',     'name': '핑크 노이즈',     'icon': '🌊', 'file': 'pink_noise.mp3'},
    {'id': 'rain',           'name': '빗소리',          'icon': '🌧', 'file': 'rain.mp3'},
    {'id': 'waves',          'name': '파도소리',        'icon': '🌊', 'file': 'waves.mp3'},
    {'id': 'forest',         'name': '숲소리',          'icon': '🌲', 'file': 'forest.mp3'},
    {'id': 'cricket',        'name': '귀뚜라미',        'icon': '🦗', 'file': 'cricket.mp3'},
    {'id': 'cafe',           'name': '카페 소음',       'icon': '☕', 'file': 'cafe.mp3'},
    {'id': 'brown_noise',    'name': '브라운 노이즈',   'icon': '🟤', 'file': 'brown_noise.mp3'},
    {'id': 'fan',            'name': '선풍기',          'icon': '💨', 'file': 'fan.mp3'},
    {'id': 'binaural_alpha', 'name': '알파파 바이노럴', 'icon': '🧠', 'file': 'binaural_alpha.mp3'},
  ];

  static const List<String> tinnitusTypes = ['고음형', '저음형', '복합형', '바람형', '오늘은 달라'];

  static const String colUsers          = 'users';
  static const String colRecords        = 'records';
  static const String colSoundPresets   = 'soundPresets';
  static const String colDesyncSessions = 'desyncSessions';

  static const String keyOnboardingDone  = 'onboarding_done';
  static const String keyUserId          = 'user_id';
  static const String keyLastSoundPreset = 'last_sound_preset';
  static const String keyDesyncDay       = 'desync_program_day';
  static const String keyDesyncStartDate = 'desync_start_date';
  static const String keyTinnitusFreq    = 'tinnitus_frequency';
}
