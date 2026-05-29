import 'package:flutter/material.dart';
import 'dart:async';
import '../models/exercise.dart';
import '../services/storage_service.dart';
import '../services/sound_haptic_service.dart';
import '../widgets/gradient_button.dart';

class EarnTimeScreen extends StatefulWidget {
  const EarnTimeScreen({super.key});

  @override
  State<EarnTimeScreen> createState() => _EarnTimeScreenState();
}

class _EarnTimeScreenState extends State<EarnTimeScreen>
    with SingleTickerProviderStateMixin {
  int _repCount = 0;
  bool _sessionActive = false;
  bool _sessionComplete = false;
  late AnimationController _pulseController;
  Exercise _exercise = Exercise.defaults[0];
  Timer? _simulationTimer;

  // ── Plank hold timer state ──
  static const int _plankTargetSeconds = 60;
  int _plankSecondsHeld = 0;
  bool _plankHolding = false;
  Timer? _plankTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Exercise) {
      _exercise = args;
    }
  }

  void _startSession() {
    setState(() {
      _sessionActive = true;
      _repCount = 0;
      _sessionComplete = false;
    });
    _pulseController.repeat(reverse: true);
  }

  void _countRep() {
    if (!_sessionActive || _sessionComplete) return;
    setState(() {
      _repCount++;
    });
    SoundHapticService.playRepTick();
    if (_repCount >= _exercise.repsPerSet) {
      _completeSession();
    }
  }

  bool _dailyGoalJustReached = false;

  void _completeSession() async {
    _pulseController.stop();
    _pulseController.reset();

    final newReps = StorageService.totalPushups + _exercise.repsPerSet;
    final newSessions = StorageService.totalSessions + 1;

    await StorageService.setTotalPushups(newReps);
    await StorageService.setTotalSessions(newSessions);
    await StorageService.addExerciseCount(_exercise.name, _exercise.repsPerSet);

    // logSession now handles screen-time crediting + daily goal check
    final goalJustReached = await StorageService.logSession(
      exercise: _exercise.name,
      reps: _exercise.repsPerSet,
      minutesEarned: _exercise.minutesEarned,
    );

    await StorageService.updateStreak();
    await StorageService.updateProfileStats(reps: _exercise.repsPerSet);

    // Update daily challenge progress
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (StorageService.dailyChallengeDate != today) {
      await StorageService.setDailyChallengeDate(today);
      await StorageService.setDailyChallengeProgress(0);
    }
    final newProgress = StorageService.dailyChallengeProgress + 1;
    await StorageService.setDailyChallengeProgress(newProgress);
    if (newProgress >= 3 && StorageService.dailyChallengeProgress == 3) {
      await StorageService.setChallengesCompleted(StorageService.challengesCompleted + 1);
    }

    setState(() {
      _sessionComplete = true;
      _sessionActive = false;
      _dailyGoalJustReached = goalJustReached;
    });

    if (goalJustReached) {
      SoundHapticService.playMilestone();
    } else {
      SoundHapticService.playSetComplete();
    }
  }

  void _simulateReps() {
    if (_simulationTimer != null) return;
    _startSession();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _countRep();
      if (_repCount >= _exercise.repsPerSet) {
        timer.cancel();
        _simulationTimer = null;
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _simulationTimer?.cancel();
    _plankTimer?.cancel();
    super.dispose();
  }

  // ── Plank: press-and-hold to accumulate hold time ──
  void _onPlankHoldStart() {
    if (_sessionComplete || !_sessionActive) return;
    if (_plankHolding) return;
    setState(() => _plankHolding = true);
    _plankTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) { t.cancel(); return; }
      setState(() => _plankSecondsHeld++);
      if (_plankSecondsHeld % 10 == 0) SoundHapticService.playCountdownTick();
      if (_plankSecondsHeld >= _plankTargetSeconds) {
        t.cancel();
        setState(() => _plankHolding = false);
        await _completeSession();
      }
    });
  }

  void _onPlankHoldEnd() {
    if (!_plankHolding) return;
    _plankTimer?.cancel();
    _plankTimer = null;
    setState(() => _plankHolding = false);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _repCount / _exercise.repsPerSet;
    final isPlank = _exercise.name == 'Planks';

    // Plank-specific display
    final plankProgress = _plankSecondsHeld / _plankTargetSeconds;
    final plankMins = _plankSecondsHeld ~/ 60;
    final plankSecs = _plankSecondsHeld % 60;
    final plankDisplay = '$plankMins:${plankSecs.toString().padLeft(2, '0')}';
    final plankRemaining = _plankTargetSeconds - _plankSecondsHeld;

    final displayProgress = isPlank ? plankProgress : progress;
    final centerLabel = isPlank ? plankDisplay : '$_repCount / ${_exercise.repsPerSet}';
    final subLabel = isPlank ? 'hold' : 'reps';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
              const SizedBox(height: 20),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      _exercise.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 40),

              // Circular Progress
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = _sessionActive ? 1.0 + (_pulseController.value * 0.05) : 1.0;
                  return Transform.scale(scale: scale, child: child);
                },
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 220, height: 220,
                        child: CircularProgressIndicator(
                          value: 1, strokeWidth: 12,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      SizedBox(\n                        width: 220, height: 220,
                        child: CircularProgressIndicator(
                          value: displayProgress, strokeWidth: 12, strokeCap: StrokeCap.round,
                          color: _sessionComplete
                              ? const Color(0xFF4CAF50)
                              : (isPlank && _plankHolding)
                                  ? const Color(0xFF00E676)
                                  : const Color(0xFF6C63FF),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_sessionComplete ? '✅' : _exercise.emoji, style: const TextStyle(fontSize: 36)),
                          const SizedBox(height: 8),
                          Text(
                            centerLabel,
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(subLabel, style: const TextStyle(fontSize: 16, color: Colors.white54)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Status
              if (_sessionComplete) ...[
                Text(
                  _dailyGoalJustReached ? '🏆 Daily Goal Crushed!' : '🎉 Session Complete!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _dailyGoalJustReached ? const Color(0xFFFFD700) : const Color(0xFF4CAF50),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _dailyGoalJustReached
                      ? '🔓 Phone unlocked for the rest of the day!'
                      : '+${_exercise.minutesEarned} minutes earned!',
                  style: const TextStyle(fontSize: 18, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                if (!_dailyGoalJustReached)
                  Text(
                    'Total: ${StorageService.screenTimeMinutes} minutes available',
                    style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5)),
                  ),
                if (StorageService.unlockMode == 'daily' || StorageService.unlockMode == 'both') ...[
                  const SizedBox(height: 6),
                  Text(
                    'Today: ${StorageService.todayReps} / ${StorageService.dailyRepGoal} reps',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF6C63FF)),
                  ),
                ],
                const SizedBox(height: 8),
                Text('🔥 Streak: ${StorageService.currentStreak} days',
                    style: const TextStyle(fontSize: 15, color: Color(0xFFFF6B35))),
              ] else if (!_sessionActive) ...[
                Text('Ready for ${_exercise.name}?',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 8),
                Builder(builder: (ctx) {
                  final mode = StorageService.unlockMode;
                  final goal = StorageService.dailyRepGoal;
                  final todayDone = StorageService.todayReps;
                  if (mode == 'daily') {
                    return Text(
                      isPlank
                          ? 'Hold for 60s  •  Goal: $todayDone / $goal reps today'
                          : 'Complete ${_exercise.repsPerSet} reps  •  Goal: $todayDone / $goal reps today',
                      style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.5)));
                  } else if (mode == 'both') {
                    return Text(
                      isPlank
                          ? 'Hold for 60s → earn time  •  Goal: $todayDone / $goal reps'
                          : 'Complete ${_exercise.repsPerSet} reps → earn ${_exercise.minutesEarned} min  •  Goal: $todayDone / $goal',
                      style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.5)));
                  }
                  return Text(
                    isPlank
                        ? 'Hold for 60 seconds to earn ${_exercise.minutesEarned} minutes'
                        : 'Complete ${_exercise.repsPerSet} reps to earn ${_exercise.minutesEarned} minutes',
                    style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.5)));
                }),
              ] else if (isPlank) ...[
                Text(
                  _plankHolding ? 'Hold steady! 🧘' : 'Release detected — keep holding!',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 8),
                Text('${plankRemaining}s remaining',
                    style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.5))),
              ] else ...[
                const Text('Keep going! 🔥', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 8),
                Text('${_exercise.repsPerSet - _repCount} reps remaining',
                    style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.5))),
              ],

              const Spacer(),

              // Camera note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.camera_alt, color: Color(0xFF6C63FF), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Camera detection coming soon! For now, tap the button or use auto-demo.',
                        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Buttons
              if (_sessionComplete) ...[
                GradientButton(text: 'Do Another Set', icon: Icons.refresh, onPressed: _startSession),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Home', style: TextStyle(fontSize: 16, color: Colors.white54)),
                  ),
                ),
              ] else if (!_sessionActive) ...[
                GradientButton(text: 'Start Set', icon: Icons.play_arrow, onPressed: _startSession),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: OutlinedButton(
                    onPressed: _simulateReps,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('▶ Auto Demo', style: TextStyle(color: Colors.white54)),
                  ),
                ),
              ] else ...[
                // Active session: tap for reps OR hold for plank
                if (isPlank) ...[
                  GestureDetector(
                    onTapDown: (_) => _onPlankHoldStart(),
                    onTapUp: (_) => _onPlankHoldEnd(),
                    onTapCancel: () => _onPlankHoldEnd(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: double.infinity,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _plankHolding
                              ? [const Color(0xFF00C853), const Color(0xFF00E676)]
                              : [const Color(0xFF6C63FF), const Color(0xFF9D4EDD)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: (_plankHolding ? const Color(0xFF00E676) : const Color(0xFF6C63FF))
                                .withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _plankHolding ? 'HOLDING 🧘 KEEP IT UP!' : 'HOLD TO TIME PLANK 🧘',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  GestureDetector(
                    onTap: _countRep,
                    child: Container(
                      width: double.infinity,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF9D4EDD)]),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF6C63FF).withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'TAP FOR REP ${_exercise.emoji}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }
}