import 'package:cloud_firestore/cloud_firestore.dart';

class DailyRecord {
  final String id;
  final DateTime date;
  final int intensity;
  final List<String> tinnitusTypes;
  final String? memo;
  final int mood;
  final double stressLevel;
  final double fatigueLevel;
  final double sleepHours;
  final int sleepQuality;
  final int? minutesToFallAsleep;
  final bool hadCaffeine;
  final bool hadExercise;
  final bool hadOutdoor;
  final bool hadNoisyEnvironment;
  final List<String> usedSoundIds;
  final bool desyncCompleted;
  final bool hapticCompleted;

  const DailyRecord({
    required this.id,
    required this.date,
    required this.intensity,
    this.tinnitusTypes = const [],
    this.memo,
    this.mood = 2,
    this.stressLevel = 3,
    this.fatigueLevel = 3,
    this.sleepHours = 7,
    this.sleepQuality = 3,
    this.minutesToFallAsleep,
    this.hadCaffeine = false,
    this.hadExercise = false,
    this.hadOutdoor = false,
    this.hadNoisyEnvironment = false,
    this.usedSoundIds = const [],
    this.desyncCompleted = false,
    this.hapticCompleted = false,
  });

  Map<String, dynamic> toFirestore() => {
    'date': Timestamp.fromDate(date),
    'intensity': intensity,
    'tinnitusTypes': tinnitusTypes,
    'memo': memo,
    'mood': mood,
    'stressLevel': stressLevel,
    'fatigueLevel': fatigueLevel,
    'sleepHours': sleepHours,
    'sleepQuality': sleepQuality,
    'minutesToFallAsleep': minutesToFallAsleep,
    'hadCaffeine': hadCaffeine,
    'hadExercise': hadExercise,
    'hadOutdoor': hadOutdoor,
    'hadNoisyEnvironment': hadNoisyEnvironment,
    'usedSoundIds': usedSoundIds,
    'desyncCompleted': desyncCompleted,
    'hapticCompleted': hapticCompleted,
    'createdAt': FieldValue.serverTimestamp(),
  };

  factory DailyRecord.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return DailyRecord(
      id: doc.id,
      date: (d['date'] as Timestamp).toDate(),
      intensity: d['intensity'] ?? 5,
      tinnitusTypes: List<String>.from(d['tinnitusTypes'] ?? []),
      memo: d['memo'],
      mood: d['mood'] ?? 2,
      stressLevel: (d['stressLevel'] ?? 3).toDouble(),
      fatigueLevel: (d['fatigueLevel'] ?? 3).toDouble(),
      sleepHours: (d['sleepHours'] ?? 7).toDouble(),
      sleepQuality: d['sleepQuality'] ?? 3,
      minutesToFallAsleep: d['minutesToFallAsleep'],
      hadCaffeine: d['hadCaffeine'] ?? false,
      hadExercise: d['hadExercise'] ?? false,
      hadOutdoor: d['hadOutdoor'] ?? false,
      hadNoisyEnvironment: d['hadNoisyEnvironment'] ?? false,
      usedSoundIds: List<String>.from(d['usedSoundIds'] ?? []),
      desyncCompleted: d['desyncCompleted'] ?? false,
      hapticCompleted: d['hapticCompleted'] ?? false,
    );
  }
}
