import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import '../services/storage_service.dart';
import '../services/screen_time_service.dart';
import '../services/sound_haptic_service.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  late int _totalSeconds;
  late int _remainingSeconds;
  Timer? _timer;
  bool _isRunning = false;
  bool _timeUp = false;
  bool _warningPlayed = false;
  List<String> _blockedApps = [];
  bool _blockingActive = false;

  @override
  void initState() {
    super.initState();
    _totalSeconds = StorageService.screenTimeMinutes * 60;
    _remainingSeconds = _totalSeconds;
    _blockedApps = StorageService.blockedApps;
  }

  void _startTimer() {
    setState(() => _isRunning = true);

    // Start native blocking service in the background
    if (_blockedApps.isNotEmpty) {
      ScreenTimeBlockingService.startBlocking(
        seconds: _remainingSeconds,
        blockedApps: _blockedApps,
      );
      setState(() => _blockingActive = true);
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
      });

      // Sound effects based on remaining time
      if (_remainingSeconds <= 0) {
        _timer?.cancel();
        _onTimeUp();
      } else if (_remainingSeconds == 60 && !_warningPlayed) {
        _warningPlayed = true;
        SoundHapticService.playTimerWarning();
      } else if (_remainingSeconds <= 10 && _remainingSeconds > 0) {
        SoundHapticService.playCountdownTick();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);

    // Stop native blocking while paused
    if (_blockingActive) {
      ScreenTimeBlockingService.stopBlocking();
      setState(() => _blockingActive = false);
    }

    _saveRemainingTime();
  }

  void _onTimeUp() async {
    await StorageService.setScreenTimeMinutes(0);
    setState(() {
      _isRunning = false;
      _timeUp = true;
    });
    // Play alarm sound when timer expires
    SoundHapticService.playTimerExpired();
    // Native service keeps running — it will overlay blocked apps
  }

  void _saveRemainingTime() async {
    final remainingMinutes = (_remainingSeconds / 60).ceil();
    await StorageService.setScreenTimeMinutes(remainingMinutes);
  }

  String _formatTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double get _progress =>
      _totalSeconds > 0 ? _remainingSeconds / _totalSeconds : 0;

  Color get _timerColor {
    if (_timeUp) return Colors.red;
    if (_remainingSeconds < 60) return Colors.orange;
    return const Color(0xFF6C63FF);
  }

  @override
  Widget build(BuildContext context) {
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
                    icon: const Icon(Icons.arrow_back_ios,
                        color: Colors.white70),
                    onPressed: () {
                      if (_isRunning) _pauseTimer();
                      if (!_timeUp) _saveRemainingTime();
                      Navigator.pop(context);
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'Screen Time',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 40),

              // Blocking status badge
              if (_blockedApps.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _blockingActive
                        ? const Color(0xFF6C63FF).withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _blockingActive
                          ? const Color(0xFF6C63FF).withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _blockingActive ? Icons.shield : Icons.shield_outlined,
                        size: 16,
                        color: _blockingActive
                            ? const Color(0xFF6C63FF)
                            : Colors.white38,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _blockingActive
                            ? '${_blockedApps.length} app${_blockedApps.length == 1 ? '' : 's'} blocking active'
                            : '${_blockedApps.length} app${_blockedApps.length == 1 ? '' : 's'} will be blocked',
                        style: TextStyle(
                          fontSize: 13,
                          color: _blockingActive
                              ? const Color(0xFF6C63FF)
                              : Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 30),

              // Timer display
              SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 260,
                      height: 260,
                      child: CircularProgressIndicator(
                        value: 1,
                        strokeWidth: 14,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      height: 260,
                      child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 14,
                        strokeCap: StrokeCap.round,
                        color: _timerColor,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _timeUp
                              ? '\u23F0'
                              : (_isRunning ? '\uD83D\uDCF1' : '\u23F8\uFE0F'),
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _timeUp
                              ? '00:00'
                              : _formatTime(_remainingSeconds),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: _timeUp ? Colors.red : Colors.white,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _timeUp
                              ? "Time's up!"
                              : (_isRunning ? 'Enjoy your time' : 'Paused'),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Status messages
              if (_timeUp) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "\u23F0 Time's Up!",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _blockedApps.isNotEmpty
                            ? 'Blocked apps are now restricted.\nDo more reps to earn screen time.'
                            : 'Do more reps to earn more screen time.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ] else if (!_isRunning &&
                  _remainingSeconds < _totalSeconds) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.orange, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Timer is paused. Your remaining time is saved.',
                          style:
                              TextStyle(color: Colors.orange, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Action buttons
              if (_timeUp) ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/exercises');
                    },
                    icon: const Icon(Icons.fitness_center),
                    label: const Text(
                      'Earn More Time',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: TextButton(
                    onPressed: () {
                      // Stop blocking service when going home
                      if (_blockingActive) {
                        ScreenTimeBlockingService.stopBlocking();
                      }
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Back to Home',
                      style:
                          TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? _pauseTimer : _startTimer,
                    icon: Icon(
                        _isRunning ? Icons.pause : Icons.play_arrow),
                    label: Text(
                      _isRunning ? 'Pause' : 'Start Timer',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRunning
                          ? Colors.orange
                          : const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (!_timeUp) _saveRemainingTime();
    super.dispose();
  }
}
