import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const _supabaseUrl = 'https://jltyrpvyrrvcozswjuyh.supabase.co';
  static const _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpsdHlycHZ5cnJ2Y296c3dqdXloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAwODUxMzksImV4cCI6MjA5NTY2MTEzOX0.bZBAMELS1cMe9B6mKMv1WnW8lfxkckWCepIqNVnGPEc';

  static final supabase = Supabase.instance.client;

  /// Initialize Supabase — call this once in main() before anything else.
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
    );
  }

  // ── Auth ──────────────────────────────────────────────────────

  static Future<AuthResponse> signUp(String email, String password) async {
    return supabase.auth.signUp(email: email, password: password);
  }

  static Future<AuthResponse> signIn(String email, String password) async {
    return supabase.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  static User? get currentUser => supabase.auth.currentUser;

  static Session? get currentSession => supabase.auth.currentSession;

  // ── Background Sync (fire-and-forget, silent fail) ────────────

  /// Sync a completed exercise session to the daily_history table.
  static Future<void> syncSession({
    required String exercise,
    required int reps,
    required int minutesEarned,
  }) async {
    final user = currentUser;
    if (user == null) return;

    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await supabase.from('daily_history').upsert(
        {
          'user_id': user.id,
          'date': today,
          'reps': reps,
          'sessions': 1,
          'minutes': minutesEarned,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,date',
        ignoreDuplicates: false,
      );
    } catch (_) {
      // Silent fail — app works 100% offline
    }
  }

  /// Sync streak data to the streaks table.
  static Future<void> syncStreak({
    required int current,
    required int best,
    required DateTime? lastDate,
  }) async {
    final user = currentUser;
    if (user == null) return;

    try {
      await supabase.from('streaks').upsert(
        {
          'user_id': user.id,
          'current_streak': current,
          'best_streak': best,
          'last_workout_date': lastDate?.toIso8601String().substring(0, 10),
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id',
        ignoreDuplicates: false,
      );
    } catch (_) {
      // Silent fail
    }
  }

  /// Sync per-exercise total reps to the exercise_stats table.
  static Future<void> syncExerciseStat({
    required String exercise,
    required int totalReps,
  }) async {
    final user = currentUser;
    if (user == null) return;

    try {
      await supabase.from('exercise_stats').upsert(
        {
          'user_id': user.id,
          'exercise_name': exercise,
          'total_reps': totalReps,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,exercise_name',
        ignoreDuplicates: false,
      );
    } catch (_) {
      // Silent fail
    }
  }
}
