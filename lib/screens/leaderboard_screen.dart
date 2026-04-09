import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profiles = List<UserProfile>.from(StorageService.profiles);
    profiles.sort((a, b) => b.weeklyReps.compareTo(a.weeklyReps));

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
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
                      'Leaderboard',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Weekly reps ranking',
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 30),

              // Podium (top 3)
              if (profiles.length >= 2) ...[
                _buildPodium(profiles),
                const SizedBox(height: 30),
              ],

              // Full list
              Expanded(
                child: ListView.builder(
                  itemCount: profiles.length,
                  itemBuilder: (ctx, i) {
                    final p = profiles[i];
                    final color = Color(p.colorValue);
                    final isActive = p.id == StorageService.activeProfileId;
                    final rank = i + 1;
                    final medal = rank == 1 ? '\uD83E\uDD47' : rank == 2 ? '\uD83E\uDD48' : rank == 3 ? '\uD83E\uDD49' : '#$rank';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: rank <= 3
                            ? LinearGradient(
                                colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.04)])
                            : null,
                        color: rank > 3 ? Colors.white.withValues(alpha: 0.06) : null,
                        borderRadius: BorderRadius.circular(14),
                        border: isActive
                            ? Border.all(color: color.withValues(alpha: 0.4))
                            : Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: rank <= 3
                                ? Text(medal, style: const TextStyle(fontSize: 22))
                                : Text(medal, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.5))),
                          ),
                          const SizedBox(width: 12),
                          Text(p.avatar, style: const TextStyle(fontSize: 28)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                                Text(
                                  '${p.totalReps} total reps',
                                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4)),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${p.weeklyReps}',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
                              ),
                              Text(
                                'this week',
                                style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPodium(List<UserProfile> profiles) {
    // Show top 3 (or fewer) on a podium
    final top = profiles.take(3).toList();

    Widget podiumItem(int rank, UserProfile p, double height) {
      final color = Color(p.colorValue);
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(p.avatar, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 4),
          Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 2),
          Text('${p.weeklyReps}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 6),
          Container(
            width: 70,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.5), color.withValues(alpha: 0.2)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Center(
              child: Text(
                rank == 1 ? '\uD83E\uDD47' : rank == 2 ? '\uD83E\uDD48' : '\uD83E\uDD49',
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
        ],
      );
    }

    // Arrange: 2nd | 1st | 3rd
    return SizedBox(
      height: 200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (top.length >= 2) Expanded(child: podiumItem(2, top[1], 60)),
          if (top.isNotEmpty) Expanded(child: podiumItem(1, top[0], 90)),
          if (top.length >= 3) Expanded(child: podiumItem(3, top[2], 45)),
        ],
      ),
    );
  }
}
