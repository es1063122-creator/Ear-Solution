class SoundPreset {
  final String id;
  final String name;
  final Map<String, double> volumes;
  final DateTime createdAt;

  const SoundPreset({
    required this.id,
    required this.name,
    required this.volumes,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'volumes': volumes,
    'createdAt': createdAt.toIso8601String(),
  };

  factory SoundPreset.fromJson(Map<String, dynamic> json) => SoundPreset(
    id: json['id'], name: json['name'],
    volumes: Map<String, double>.from(json['volumes'] ?? {}),
    createdAt: DateTime.parse(json['createdAt']),
  );

  static SoundPreset get wifeDefault => SoundPreset(
    id: 'wife_default', name: '나의 조합',
    volumes: {'masking_8k': 0.7, 'pink_noise': 0.4, 'rain': 0.5},
    createdAt: DateTime.now(),
  );

  static SoundPreset get sleepMode => SoundPreset(
    id: 'sleep_mode', name: '수면 모드',
    volumes: {'brown_noise': 0.6, 'waves': 0.4, 'fan': 0.3},
    createdAt: DateTime.now(),
  );

  static SoundPreset get stressRelief => SoundPreset(
    id: 'stress_relief', name: '스트레스 완화',
    volumes: {'binaural_alpha': 0.5, 'forest': 0.6, 'rain': 0.3},
    createdAt: DateTime.now(),
  );
}
