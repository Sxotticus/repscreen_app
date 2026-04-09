import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_profile.dart';

class StorageService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Onboarding
  static bool get hasSeenOnboarding => _prefs.getBool('has_seen_onboarding') ?? false;
  static Future<void> setHasSeenOnboarding(bool v) async {
    await _prefs.setBool('has_seen_onboarding', v);
  }

  // Screen time balance in minutes
  static int get screenTimeMinutes => _prefs.getInt('screen_time') ?? 0;
  static Future<void> setScreenTimeMinutes(int minutes) async {
    await _prefs.setInt('screen_time', minutes);
  }

  // Total reps completed (lifetime)
  static int get totalPushups => _prefs.getInt('total_pushups') ?? 0;
  static Future<void> setTotalPushups(int count) async {
    await _prefs.setInt('total_pushups', count);
  }

  // Total sessions completed
  static int get totalSessions => _prefs.getInt('total_sessions') ?? 0;
  static Future<void> setTotalSessions(int count) async {
    await _prefs.setInt('total_sessions', count);
  }

  // User logged in state
  static bool get isLoggedIn => _prefs.getBool('logged_in') ?? false;
  static Future<void> setLoggedIn(bool value) async {
    await _prefs.setBool('logged_in', value);
  }

  // User email
  static String get userEmail => _prefs.getString('user_email') ?? '';
  static Future<void> setUserEmail(String email) async {
    await _prefs.setString('user_email', email);
  }

  // ── Streaks ──
  static int get currentStreak => _prefs.getInt('current_streak') ?? 0;
  static Future<void> setCurrentStreak(int days) async {
    await _prefs.setInt('current_streak', days);
  }

  static int get bestStreak => _prefs.getInt('best_streak') ?? 0;
  static Future<void> setBestStreak(int days) async {
    await _prefs.setInt('best_streak', days);
  }

  static String get lastWorkoutDate => _prefs.getString('last_workout_date') ?? '';
  static Future<void> setLastWorkoutDate(String date) async {
    await _prefs.setString('last_workout_date', date);
  }

  static Future<void> updateStreak() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = lastWorkoutDate;

    if (lastDate == today) return;

    final yesterday = DateTime.now().subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);

    if (lastDate == yesterday) {
      final newStreak = currentStreak + 1;
      await setCurrentStreak(newStreak);
      if (newStreak > bestStreak) await setBestStreak(newStreak);
    } else {
      await setCurrentStreak(1);
      if (1 > bestStreak) await setBestStreak(1);
    }
    await setLastWorkoutDate(today);
  }

  // ── Exercise Stats ──
  static int getExerciseCount(String exercise) =>
      _prefs.getInt('exercise_$exercise') ?? 0;
  static Future<void> addExerciseCount(String exercise, int count) async {
    final current = getExerciseCount(exercise);
    await _prefs.setInt('exercise_$exercise', current + count);
  }

  // ── Custom Exercises ──
  static List<String> get customExercises {
    final data = _prefs.getString('custom_exercises');
    if (data == null) return [];
    return List<String>.from(json.decode(data));
  }
  static Future<void> setCustomExercises(List<String> exercises) async {
    await _prefs.setString('custom_exercises', json.encode(exercises));
  }

  // ── Challenges ──
  static int get dailyChallengeProgress => _prefs.getInt('daily_challenge_progress') ?? 0;
  static Future<void> setDailyChallengeProgress(int count) async {
    await _prefs.setInt('daily_challenge_progress', count);
  }

  static String get dailyChallengeDate => _prefs.getString('daily_challenge_date') ?? '';
  static Future<void> setDailyChallengeDate(String date) async {
    await _prefs.setString('daily_challenge_date', date);
  }

  static int get challengesCompleted => _prefs.getInt('challenges_completed') ?? 0;
  static Future<void> setChallengesCompleted(int count) async {
    await _prefs.setInt('challenges_completed', count);
  }

  // ── Parental Controls ──
  static bool get parentalControlsEnabled => _prefs.getBool('parental_enabled') ?? false;
  static Future<void> setParentalControlsEnabled(bool value) async {
    await _prefs.setBool('parental_enabled', value);
  }

  static String get parentalPin => _prefs.getString('parental_pin') ?? '';
  static Future<void> setParentalPin(String pin) async {
    await _prefs.setString('parental_pin', pin);
  }

  static int get dailyScreenTimeLimit => _prefs.getInt('daily_limit') ?? 60;
  static Future<void> setDailyScreenTimeLimit(int minutes) async {
    await _prefs.setInt('daily_limit', minutes);
  }

  static int get minRepsRequired => _prefs.getInt('min_reps_required') ?? 10;
  static Future<void> setMinRepsRequired(int reps) async {
    await _prefs.setInt('min_reps_required', reps);
  }

  static int get dailyScreenTimeUsed => _prefs.getInt('daily_used') ?? 0;
  static Future<void> setDailyScreenTimeUsed(int minutes) async {
    await _prefs.setInt('daily_used', minutes);
  }

  // ── Sound & Haptic Settings ──
  static bool get soundEnabled => _prefs.getBool('sound_enabled') ?? true;
  static Future<void> setSoundEnabled(bool value) async {
    await _prefs.setBool('sound_enabled', value);
  }

  static bool get hapticEnabled => _prefs.getBool('haptic_enabled') ?? true;
  static Future<void> setHapticEnabled(bool value) async {
    await _prefs.setBool('haptic_enabled', value);
  }

  // ── Blocked Apps ──
  static List<String> get blockedApps {
    final data = _prefs.getString('blocked_apps');
    if (data == null) return [];
    return List<String>.from(json.decode(data));
  }

  static Future<void> setBlockedApps(List<String> apps) async {
    await _prefs.setString('blocked_apps', json.encode(apps));
  }

  // ── Daily History (for Stats Dashboard) ──

  /// Get the full daily history map: { "2026-04-06": { "reps": 50, "sessions": 3, "minutes": 30 }, ... }
  static Map<String, Map<String, int>> get dailyHistory {
    final data = _prefs.getString('daily_history');
    if (data == null) return {};
    final decoded = json.decode(data) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, Map<String, int>.from(v as Map)));
  }

  static Future<void> _saveDailyHistory(Map<String, Map<String, int>> history) async {
    await _prefs.setString('daily_history', json.encode(history));
  }

  /// Log a completed session to daily history
  static Future<void> logSession({
    required String exercise,
    required int reps,
    required int minutesEarned,
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final history = dailyHistory;
    final dayData = history[today] ?? {'reps': 0, 'sessions': 0, 'minutes': 0};
    dayData['reps'] = (dayData['reps'] ?? 0) + reps;
    dayData['sessions'] = (dayData['sessions'] ?? 0) + 1;
    dayData['minutes'] = (dayData['minutes'] ?? 0) + minutesEarned;
    history[today] = dayData;
    await _saveDailyHistory(history);

    // Also track per-exercise daily history
    final exKey = 'daily_ex_${today}_$exercise';
    final exCount = _prefs.getInt(exKey) ?? 0;
    await _prefs.setInt(exKey, exCount + reps);
  }

  /// Get reps for last N days (returns list from oldest to newest)
  static List<MapEntry<String, int>> getRecentDays(int days) {
    final history = dailyHistory;
    final result = <MapEntry<String, int>>[];
    final now = DateTime.now();
    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i)).toIso8601String().substring(0, 10);
      final reps = history[date]?['reps'] ?? 0;
      result.add(MapEntry(date, reps));
    }
    return result;
  }

  /// Get total minutes earned (lifetime)
  static int get totalMinutesEarned {
    final history = dailyHistory;
    int total = 0;
    for (final day in history.values) {
      total += day['minutes'] ?? 0;
    }
    return total;
  }

  /// Get best single-day reps
  static int get bestDayReps {
    final history = dailyHistory;
    int best = 0;
    for (final day in history.values) {
      final r = day['reps'] ?? 0;
      if (r > best) best = r;
    }
    return best;
  }

  /// Get total active days
  static int get totalActiveDays => dailyHistory.length;

  // ── Family / Profiles ──

  static List<UserProfile> get profiles {
    final data = _prefs.getString('profiles');
    if (data == null) return [];
    return UserProfile.decodeList(data);
  }

  static Future<void> _saveProfiles(List<UserProfile> list) async {
    await _prefs.setString('profiles', UserProfile.encodeList(list));
  }

  static String get activeProfileId => _prefs.getString('active_profile_id') ?? '';
  static Future<void> setActiveProfileId(String id) async {
    await _prefs.setString('active_profile_id', id);
  }

  static UserProfile? get activeProfile {
    final id = activeProfileId;
    if (id.isEmpty) return null;
    final list = profiles;
    for (final p in list) {
      if (p.id == id) return p;
    }
    return null;
  }

  static Future<void> addProfile(UserProfile profile) async {
    final list = profiles;
    list.add(profile);
    await _saveProfiles(list);
    // Auto-set as active if first profile
    if (list.length == 1) {
      await setActiveProfileId(profile.id);
    }
  }

  static Future<void> removeProfile(String id) async {
    final list = profiles;
    list.removeWhere((p) => p.id == id);
    await _saveProfiles(list);
    if (activeProfileId == id) {
      await setActiveProfileId(list.isNotEmpty ? list.first.id : '');
    }
  }

  /// Update the active profile's stats after a session
  static Future<void> updateProfileStats({required int reps}) async {
    final id = activeProfileId;
    if (id.isEmpty) return;
    final list = profiles;
    for (final p in list) {
      if (p.id == id) {
        p.totalReps += reps;
        p.weeklyReps += reps;
        p.totalSessions += 1;
        final streak = currentStreak;
        if (streak > p.bestStreak) p.bestStreak = streak;
        break;
      }
    }
    await _saveProfiles(list);
  }

  /// Reset weekly reps for all profiles (call on Monday or via check)
  static Future<void> resetWeeklyIfNeeded() async {
    final lastReset = _prefs.getString('weekly_reset_date') ?? '';
    final now = DateTime.now();
    // Reset on Monday
    if (now.weekday == 1) {
      final today = now.toIso8601String().substring(0, 10);
      if (lastReset != today) {
        final list = profiles;
        for (final p in list) {
          p.weeklyReps = 0;
        }
        await _saveProfiles(list);
        await _prefs.setString('weekly_reset_date', today);
      }
    }
  }

  // Clear all data (logout)
  static Future<void> clear() async {
    await _prefs.clear();
  }
}
