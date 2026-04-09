import 'dart:convert';

class UserProfile {
  final String id;
  final String name;
  final String avatar;
  final int colorValue;
  int totalReps;
  int weeklyReps;
  int totalSessions;
  int bestStreak;

  UserProfile({
    required this.id,
    required this.name,
    required this.avatar,
    required this.colorValue,
    this.totalReps = 0,
    this.weeklyReps = 0,
    this.totalSessions = 0,
    this.bestStreak = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'colorValue': colorValue,
        'totalReps': totalReps,
        'weeklyReps': weeklyReps,
        'totalSessions': totalSessions,
        'bestStreak': bestStreak,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        avatar: json['avatar'] as String,
        colorValue: json['colorValue'] as int,
        totalReps: json['totalReps'] as int? ?? 0,
        weeklyReps: json['weeklyReps'] as int? ?? 0,
        totalSessions: json['totalSessions'] as int? ?? 0,
        bestStreak: json['bestStreak'] as int? ?? 0,
      );

  static String encodeList(List<UserProfile> profiles) =>
      json.encode(profiles.map((p) => p.toJson()).toList());

  static List<UserProfile> decodeList(String data) {
    final list = json.decode(data) as List;
    return list.map((j) => UserProfile.fromJson(j as Map<String, dynamic>)).toList();
  }

  // Avatar options
  static const avatars = [
    '\uD83D\uDE03', '\uD83D\uDE0E', '\uD83E\uDDB8', '\uD83E\uDDB9',
    '\uD83E\uDDD1\u200D\uD83D\uDE80', '\uD83E\uDDD7', '\uD83C\uDFC3',
    '\uD83E\uDD38', '\uD83E\uDD3C', '\uD83D\uDCAA', '\uD83C\uDFC6',
    '\uD83D\uDD25', '\u2B50', '\uD83E\uDD8A', '\uD83E\uDD81',
    '\uD83D\uDC32',
  ];

  // Color options
  static const profileColors = [
    0xFF6C63FF, // purple
    0xFFFF6B35, // orange
    0xFF00E676, // green
    0xFFFF4081, // pink
    0xFF00BCD4, // cyan
    0xFFFFD700, // gold
    0xFFE040FB, // magenta
    0xFF40C4FF, // light blue
  ];
}
