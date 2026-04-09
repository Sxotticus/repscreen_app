import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class StreaksScreen extends StatelessWidget {
  const StreaksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentStreak = StorageService.currentStreak;
    final bestStreak = StorageService.bestStreak;
    final challengesCompleted = StorageService.challengesCompleted;
    final dailyProgress = StorageService.dailyChallengeProgress;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final isTodayChallenge = StorageService.dailyChallengeDate == today;
    final todaySessions = isTodayChallenge ? dailyProgress : 0;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text('Streaks & Challenges', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 30),

              // Streak Fire Display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFF9F1C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 60)),
                    const SizedBox(height: 10),
                    Text(
                      '$currentStreak',
                      style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white, height: 1),
                    ),
                    const Text('Day Streak', style: TextStyle(fontSize: 18, color: Colors.white70)),
                    const SizedBox(height: 16),
                    Text(
                      'Best: $bestStreak days',
                      style: const TextStyle(fontSize: 15, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Weekly Progress
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('This Week', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(7, (i) {
                        final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                        final now = DateTime.now();
                        final weekday = now.weekday; // 1 = Monday
                        final isActive = i < weekday && i < currentStreak;
                        final isToday = i == weekday - 1;
                        return Column(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isActive
                                    ? const Color(0xFF4CAF50)
                                    : isToday
                                        ? const Color(0xFF6C63FF).withValues(alpha: 0.3)
                                        : Colors.white.withValues(alpha: 0.06),
                                border: isToday
                                    ? Border.all(color: const Color(0xFF6C63FF), width: 2)
                                    : null,
                              ),
                              child: Center(
                                child: isActive
                                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                                    : Text(dayNames[i],
                                        style: TextStyle(
                                          color: isToday ? const Color(0xFF6C63FF) : Colors.white38,
                                          fontWeight: FontWeight.w600,
                                        )),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Daily Challenge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🏆', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Daily Challenge', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        if (todaySessions >= 3)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('DONE ✓', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Complete 3 workout sessions today',
                      style: TextStyle(fontSize: 14, color: Colors.white54),
                    ),
                    const SizedBox(height: 12),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (todaySessions / 3).clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        color: todaySessions >= 3 ? const Color(0xFF4CAF50) : const Color(0xFF6C63FF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$todaySessions / 3 sessions',
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Milestones
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Milestones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 16),
                    _buildMilestone('3-Day Streak', '🔥', currentStreak >= 3),
                    _buildMilestone('7-Day Streak', '⚡', currentStreak >= 7),
                    _buildMilestone('14-Day Streak', '💎', currentStreak >= 14),
                    _buildMilestone('30-Day Streak', '👑', currentStreak >= 30),
                    _buildMilestone('5 Challenges Done', '🏆', challengesCompleted >= 5),
                    _buildMilestone('100 Total Reps', '💯', StorageService.totalPushups >= 100),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMilestone(String title, String emoji, bool achieved) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                color: achieved ? Colors.white : Colors.white38,
                fontWeight: achieved ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          achieved
              ? const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 22)
              : Icon(Icons.circle_outlined, color: Colors.white.withValues(alpha: 0.2), size: 22),
        ],
      ),
    );
  }
}
