import 'dart:math';
import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../services/storage_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _chartAnim;

  @override
  void initState() {
    super.initState();
    _chartAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _chartAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recentDays = StorageService.getRecentDays(7);
    final exercises = Exercise.defaults;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Stats Dashboard',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 24),

              // ── Summary Cards ──
              Row(
                children: [
                  Expanded(child: _summaryCard(
                    '\uD83D\uDCAA', 'Total Reps',
                    '${StorageService.totalPushups}',
                    const Color(0xFF6C63FF),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _summaryCard(
                    '\u23F1\uFE0F', 'Time Earned',
                    '${StorageService.totalMinutesEarned}m',
                    const Color(0xFF9D4EDD),
                  )),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _summaryCard(
                    '\uD83D\uDD25', 'Best Streak',
                    '${StorageService.bestStreak}d',
                    const Color(0xFFFF6B35),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _summaryCard(
                    '\uD83C\uDFC6', 'Best Day',
                    '${StorageService.bestDayReps} reps',
                    const Color(0xFFFF9F1C),
                  )),
                ],
              ),
              const SizedBox(height: 28),

              // ── Weekly Bar Chart ──
              const Text(
                'Last 7 Days',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                'Daily reps completed',
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _chartAnim,
                builder: (context, child) {
                  return SizedBox(
                    height: 180,
                    child: _buildBarChart(recentDays, _chartAnim.value),
                  );
                },
              ),
              const SizedBox(height: 28),

              // ── Exercise Breakdown ──
              const Text(
                'Exercise Breakdown',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                'Total reps per exercise',
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 16),
              ...exercises.map((e) => _buildExerciseRow(e)),

              // Custom exercises
              ...StorageService.customExercises.map((name) => _buildExerciseRow(
                Exercise(
                  name: name,
                  icon: Icons.sports_gymnastics,
                  emoji: '\u26A1',
                  repsPerSet: 10,
                  minutesEarned: 10,
                  isCustom: true,
                ),
              )),
              const SizedBox(height: 28),

              // ── Records Section ──
              const Text(
                'Personal Records',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(height: 16),
              _recordCard(
                icon: Icons.fitness_center,
                title: 'Total Sessions',
                value: '${StorageService.totalSessions}',
                subtitle: 'workouts completed',
              ),
              const SizedBox(height: 10),
              _recordCard(
                icon: Icons.calendar_today,
                title: 'Active Days',
                value: '${StorageService.totalActiveDays}',
                subtitle: 'days you worked out',
              ),
              const SizedBox(height: 10),
              _recordCard(
                icon: Icons.emoji_events,
                title: 'Challenges Won',
                value: '${StorageService.challengesCompleted}',
                subtitle: 'daily challenges completed',
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(String emoji, String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.15), accent.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<MapEntry<String, int>> days, double animProgress) {
    final maxVal = days.fold<int>(0, (m, e) => max(m, e.value));
    final maxHeight = max(maxVal, 1);
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(days.length, (i) {
        final entry = days[i];
        final date = DateTime.parse(entry.key);
        final label = dayNames[date.weekday - 1];
        final isToday = i == days.length - 1;
        final barRatio = (entry.value / maxHeight).clamp(0.0, 1.0);
        final animatedRatio = barRatio * animProgress;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (entry.value > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${entry.value}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isToday ? const Color(0xFF6C63FF) : Colors.white54,
                      ),
                    ),
                  ),
                Container(
                  height: max(4, 120 * animatedRatio),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isToday
                          ? [const Color(0xFF6C63FF), const Color(0xFF9D4EDD)]
                          : [Colors.white.withValues(alpha: 0.2), Colors.white.withValues(alpha: 0.1)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                    color: isToday ? Colors.white : Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildExerciseRow(Exercise exercise) {
    final count = StorageService.getExerciseCount(exercise.name);
    final totalReps = StorageService.totalPushups;
    final ratio = totalReps > 0 ? count / totalReps : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(exercise.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      exercise.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    Text(
                      '$count reps',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6C63FF), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFF6C63FF).withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF6C63FF), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF)),
          ),
        ],
      ),
    );
  }
}
