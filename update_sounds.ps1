# RepScreen v5 - Sounds & Haptics Update
# Run from: C:\pushscroll_app

Write-Host "=== RepScreen Sounds & Haptics Update ===" -ForegroundColor Cyan
Write-Host ""

# --- lib/services/sound_haptic_service.dart ---
Write-Host "[1/8] lib/services/sound_haptic_service.dart" -ForegroundColor Yellow
$f1 = @"
import 'package:flutter/services.dart';

/// Central service for all sound effects and haptic feedback.
/// Uses Android's sine-wave generator via platform channel,
/// and Flutter's built-in HapticFeedback for vibrations.
class SoundHapticService {
  static const _channel = MethodChannel('com.repscreen/sound');
  static bool _soundEnabled = true;
  static bool _hapticEnabled = true;

  static bool get soundEnabled => _soundEnabled;
  static bool get hapticEnabled => _hapticEnabled;

  static void setSoundEnabled(bool v) => _soundEnabled = v;
  static void setHapticEnabled(bool v) => _hapticEnabled = v;

  // ─── Sound Events ──────────────────────────────────────────

  /// Short click for each rep counted
  static Future<void> playRepTick() async {
    if (!_soundEnabled) return;
    _invoke('repTick');
    _hapticLight();
  }

  /// Celebration when a full set is complete
  static Future<void> playSetComplete() async {
    if (!_soundEnabled) return;
    _invoke('setComplete');
    _hapticHeavy();
  }

  /// Warning beep when timer has < 60 seconds left
  static Future<void> playTimerWarning() async {
    if (!_soundEnabled) return;
    _invoke('timerWarning');
    _hapticMedium();
  }

  /// Alarm when timer reaches zero
  static Future<void> playTimerExpired() async {
    if (!_soundEnabled) return;
    _invoke('timerExpired');
    _hapticHeavy();
  }

  /// Achievement/milestone unlocked
  static Future<void> playMilestone() async {
    if (!_soundEnabled) return;
    _invoke('milestone');
    _hapticHeavy();
  }

  /// Short tick for countdown seconds
  static Future<void> playCountdownTick() async {
    if (!_soundEnabled) return;
    _invoke('countdownTick');
  }

  /// Button tap feedback (haptic only, no sound)
  static Future<void> tapFeedback() async {
    _hapticLight();
  }

  // ─── Haptic Events ─────────────────────────────────────────

  static void _hapticLight() {
    if (!_hapticEnabled) return;
    HapticFeedback.lightImpact();
  }

  static void _hapticMedium() {
    if (!_hapticEnabled) return;
    HapticFeedback.mediumImpact();
  }

  static void _hapticHeavy() {
    if (!_hapticEnabled) return;
    HapticFeedback.heavyImpact();
  }

  /// Selection click — subtle feedback for toggles
  static void selectionClick() {
    if (!_hapticEnabled) return;
    HapticFeedback.selectionClick();
  }

  // ─── Private ───────────────────────────────────────────────

  static Future<void> _invoke(String sound) async {
    try {
      await _channel.invokeMethod('playSound', {'type': sound});
    } catch (_) {
      // Silently fail — sounds are nice-to-have, not critical
    }
  }
}
"@
Set-Content -Path "lib\services\sound_haptic_service.dart" -Value $f1 -Encoding UTF8

# --- lib/services/storage_service.dart ---
Write-Host "[2/8] lib/services/storage_service.dart" -ForegroundColor Yellow
$f2 = @"
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
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

    if (lastDate == today) return; // Already worked out today

    final yesterday = DateTime.now().subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);

    if (lastDate == yesterday) {
      // Continue streak
      final newStreak = currentStreak + 1;
      await setCurrentStreak(newStreak);
      if (newStreak > bestStreak) await setBestStreak(newStreak);
    } else {
      // Streak broken, start fresh
      await setCurrentStreak(1);
      if (1 > bestStreak) await setBestStreak(1);
    }
    await setLastWorkoutDate(today);
  }

  // ── Exercise Stats ──
  static int getExerciseCount(String exercise) =>
      _prefs.getInt('exercise_`$exercise') ?? 0;
  static Future<void> addExerciseCount(String exercise, int count) async {
    final current = getExerciseCount(exercise);
    await _prefs.setInt('exercise_`$exercise', current + count);
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

  // Clear all data (logout)
  static Future<void> clear() async {
    await _prefs.clear();
  }
}
"@
Set-Content -Path "lib\services\storage_service.dart" -Value $f2 -Encoding UTF8

# --- lib/main.dart ---
Write-Host "[3/8] lib/main.dart" -ForegroundColor Yellow
$f3 = @"
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/earn_time_screen.dart';
import 'screens/timer_screen.dart';
import 'screens/exercise_select_screen.dart';
import 'screens/streaks_screen.dart';
import 'screens/parental_controls_screen.dart';
import 'screens/camera_exercise_screen.dart';
import 'screens/blocked_apps_screen.dart';
import 'services/storage_service.dart';
import 'services/sound_haptic_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  // Sync sound/haptic settings from storage
  SoundHapticService.setSoundEnabled(StorageService.soundEnabled);
  SoundHapticService.setHapticEnabled(StorageService.hapticEnabled);
  runApp(const RepScreenApp());
}

class RepScreenApp extends StatelessWidget {
  const RepScreenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RepScreen',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0A0A1A),
        fontFamily: 'Roboto',
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),
        '/exercises': (context) => const ExerciseSelectScreen(),
        '/earn': (context) => const EarnTimeScreen(),
        '/timer': (context) => const TimerScreen(),
        '/streaks': (context) => const StreaksScreen(),
        '/parental': (context) => const ParentalControlsScreen(),
        '/camera_exercise': (context) => const CameraExerciseScreen(),
        '/blocked_apps': (context) => const BlockedAppsScreen(),
      },
    );
  }
}
"@
Set-Content -Path "lib\main.dart" -Value $f3 -Encoding UTF8

# --- lib/screens/earn_time_screen.dart ---
Write-Host "[4/8] lib/screens/earn_time_screen.dart" -ForegroundColor Yellow
$f4 = @"
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
  Exercise _exercise = Exercise.defaults[0]; // Default to push-ups
  Timer? _simulationTimer;

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

  void _completeSession() async {
    _pulseController.stop();
    _pulseController.reset();

    final newTime = StorageService.screenTimeMinutes + _exercise.minutesEarned;
    final newReps = StorageService.totalPushups + _exercise.repsPerSet;
    final newSessions = StorageService.totalSessions + 1;

    await StorageService.setScreenTimeMinutes(newTime);
    await StorageService.setTotalPushups(newReps);
    await StorageService.setTotalSessions(newSessions);
    await StorageService.addExerciseCount(_exercise.name, _exercise.repsPerSet);
    await StorageService.updateStreak();

    // Update daily challenge progress
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (StorageService.dailyChallengeDate != today) {
      await StorageService.setDailyChallengeDate(today);
      await StorageService.setDailyChallengeProgress(0);
    }
    final newProgress = StorageService.dailyChallengeProgress + 1;
    await StorageService.setDailyChallengeProgress(newProgress);
    if (newProgress >= 3) {
      // Daily challenge: complete 3 sessions
      final completed = StorageService.challengesCompleted;
      if (StorageService.dailyChallengeProgress == 3) {
        await StorageService.setChallengesCompleted(completed + 1);
      }
    }

    setState(() {
      _sessionComplete = true;
      _sessionActive = false;
    });

    // Play set complete sound
    SoundHapticService.playSetComplete();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _repCount / _exercise.repsPerSet;
    final isPlank = _exercise.name == 'Planks';
    final repLabel = isPlank ? 'min hold' : 'reps';

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
                      SizedBox(
                        width: 220, height: 220,
                        child: CircularProgressIndicator(
                          value: progress, strokeWidth: 12, strokeCap: StrokeCap.round,
                          color: _sessionComplete ? const Color(0xFF4CAF50) : const Color(0xFF6C63FF),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_sessionComplete ? '✅' : _exercise.emoji, style: const TextStyle(fontSize: 36)),
                          const SizedBox(height: 8),
                          Text(
                            '`$_repCount / `${_exercise.repsPerSet}',
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(repLabel, style: const TextStyle(fontSize: 16, color: Colors.white54)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Status
              if (_sessionComplete) ...[
                const Text('🎉 Session Complete!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),
                const SizedBox(height: 8),
                Text('+`${_exercise.minutesEarned} minutes earned!', style: const TextStyle(fontSize: 18, color: Colors.white70)),
                const SizedBox(height: 8),
                Text('Total: `${StorageService.screenTimeMinutes} minutes available',
                    style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5))),
                const SizedBox(height: 8),
                Text('🔥 Streak: `${StorageService.currentStreak} days',
                    style: const TextStyle(fontSize: 15, color: Color(0xFFFF6B35))),
              ] else if (!_sessionActive) ...[
                Text('Ready for `${_exercise.name}?',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 8),
                Text('Complete `${_exercise.repsPerSet} `$repLabel to earn `${_exercise.minutesEarned} minutes',
                    style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.5))),
              ] else ...[
                const Text('Keep going! 🔥', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 8),
                Text('`${_exercise.repsPerSet - _repCount} `$repLabel remaining',
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
                // Tap to count
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
                        'TAP FOR REP `${_exercise.emoji}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
            )
"@
Set-Content -Path "lib\screens\earn_time_screen.dart" -Value $f4 -Encoding UTF8

# --- lib/screens/camera_exercise_screen.dart ---
Write-Host "[5/8] lib/screens/camera_exercise_screen.dart" -ForegroundColor Yellow
$f5 = @"
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/exercise.dart';
import '../services/storage_service.dart';
import '../services/sound_haptic_service.dart';
import '../services/rep_counter.dart';
import '../painters/pose_painter.dart';
import '../widgets/gradient_button.dart';

class CameraExerciseScreen extends StatefulWidget {
  const CameraExerciseScreen({super.key});

  @override
  State<CameraExerciseScreen> createState() => _CameraExerciseScreenState();
}

class _CameraExerciseScreenState extends State<CameraExerciseScreen> {
  CameraController? _camCtrl;
  PoseDetector? _poseDetector;
  late RepCounter _repCounter;
  Exercise _exercise = Exercise.defaults[0];
  CameraDescription? _camera;

  bool _initializing = true;
  bool _cameraReady = false;
  bool _processing = false;
  bool _sessionDone = false;
  String _error = '';
  Pose? _latestPose;
  Size _imgSize = const Size(640, 480);
  bool _argsLoaded = false;

  @override
  void initState() {
    super.initState();
    _repCounter = RepCounter(exerciseName: _exercise.name);
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.base,
        mode: PoseDetectionMode.stream,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsLoaded) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Exercise) {
        _exercise = args;
        _repCounter = RepCounter(exerciseName: _exercise.name);
      }
      _argsLoaded = true;
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() { _error = 'No cameras found'; _initializing = false; });
        return;
      }

      // Prefer front camera (selfie)
      _camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _camCtrl = CameraController(
        _camera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _camCtrl!.initialize();
      if (!mounted) return;

      // Get actual image dimensions
      final previewSize = _camCtrl!.value.previewSize!;
      _imgSize = Size(previewSize.height, previewSize.width);

      // Start streaming frames to ML Kit
      await _camCtrl!.startImageStream(_onFrame);

      setState(() { _cameraReady = true; _initializing = false; });
    } catch (e) {
      setState(() {
        _error = e.toString().contains('Permission')
            ? 'Camera permission denied. Please allow camera access.'
            : 'Camera error: `$e';
        _initializing = false;
      });
    }
  }

  void _onFrame(CameraImage image) async {
    if (_processing || _sessionDone || _poseDetector == null) return;
    _processing = true;

    try {
      final input = _toInputImage(image);
      if (input == null) { _processing = false; return; }

      final poses = await _poseDetector!.processImage(input);

      if (!mounted) { _processing = false; return; }

      if (poses.isNotEmpty) {
        final prevReps = _repCounter.repCount;
        _repCounter.processFrame(poses.first, _imgSize);
        setState(() { _latestPose = poses.first; });

        // Play rep tick when a new rep is counted
        if (_repCounter.repCount > prevReps) {
          SoundHapticService.playRepTick();
        }

        if (_repCounter.repCount >= _exercise.repsPerSet) {
          await _completeSession();
        }
      } else {
        setState(() { _latestPose = null; });
        _repCounter.bodyDetected = false;
      }
    } catch (_) {}

    _processing = false;
  }

  InputImage? _toInputImage(CameraImage img) {
    if (_camera == null) return null;
    final rot = InputImageRotationValue.fromRawValue(_camera!.sensorOrientation);
    final fmt = InputImageFormatValue.fromRawValue(img.format.raw);
    if (rot == null || fmt == null) return null;

    final allBytes = WriteBuffer();
    for (final p in img.planes) {
      allBytes.putUint8List(p.bytes);
    }

    return InputImage.fromBytes(
      bytes: allBytes.done().buffer.asUint8List(),
      metadata: InputImageMetadata(
        size: Size(img.width.toDouble(), img.height.toDouble()),
        rotation: rot,
        format: fmt,
        bytesPerRow: img.planes[0].bytesPerRow,
      ),
    );
  }

  Future<void> _completeSession() async {
    try { await _camCtrl?.stopImageStream(); } catch (_) {}

    final newTime = StorageService.screenTimeMinutes + _exercise.minutesEarned;
    final newReps = StorageService.totalPushups + _exercise.repsPerSet;
    final newSessions = StorageService.totalSessions + 1;

    await StorageService.setScreenTimeMinutes(newTime);
    await StorageService.setTotalPushups(newReps);
    await StorageService.setTotalSessions(newSessions);
    await StorageService.addExerciseCount(_exercise.name, _exercise.repsPerSet);
    await StorageService.updateStreak();

    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (StorageService.dailyChallengeDate != today) {
      await StorageService.setDailyChallengeDate(today);
      await StorageService.setDailyChallengeProgress(0);
    }
    final prog = StorageService.dailyChallengeProgress + 1;
    await StorageService.setDailyChallengeProgress(prog);
    if (prog >= 3 && prog == 3) {
      await StorageService.setChallengesCompleted(StorageService.challengesCompleted + 1);
    }

    setState(() { _sessionDone = true; });

    // Play set complete celebration sound
    SoundHapticService.playSetComplete();
  }

  @override
  void dispose() {
    _camCtrl?.dispose();
    _poseDetector?.close();
    super.dispose();
  }

  // ─── BUILD ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final reps = _repCounter.repCount;
    final target = _exercise.repsPerSet;
    final isPlank = _exercise.name == 'Planks';
    final label = isPlank ? 'min' : 'reps';
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview ──
          if (_cameraReady && _camCtrl != null && _camCtrl!.value.isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _camCtrl!.value.previewSize!.height,
                  height: _camCtrl!.value.previewSize!.width,
                  child: CameraPreview(_camCtrl!),
                ),
              ),
            )
          else if (_initializing)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF6C63FF)),
                  SizedBox(height: 16),
                  Text('Starting camera...', style: TextStyle(color: Colors.white70, fontSize: 16)),
                ],
              ),
            )
          else if (_error.isNotEmpty)
            _buildError(),

          // ── Pose skeleton overlay ──
          if (_latestPose != null && _cameraReady)
            CustomPaint(
              size: screenSize,
              painter: PosePainter(
                pose: _latestPose!,
                imageSize: _imgSize,
                canvasSize: screenSize,
                isFrontCamera: _camera?.lensDirection == CameraLensDirection.front,
              ),
            ),

          // ── Top bar ──
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      '`${_exercise.emoji} `${_exercise.name}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                  _buildTrackingBadge(),
                ],
              ),
            ),
          ),

          // ── Center rep counter ──
          if (!_sessionDone && _cameraReady)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '`$reps',
                      style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.white, height: 1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'of `$target `$label',
                      style: TextStyle(fontSize: 18, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ),

          // ── Bottom bar ──
          if (!_sessionDone && _cameraReady)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: reps / target,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        color: const Color(0xFF6C63FF),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '`${_exercise.minutesEarned} min reward  •  `${target - reps} `$label to go',
                      style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6)),
                    ),
                    if (!_repCounter.bodyDetected && _cameraReady) ...[
                      const SizedBox(height: 8),
                      const Text(
                        '📍 Position yourself so the camera can see your full body',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Color(0xFFFF9800)),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // ── Session complete overlay ──
          if (_sessionDone) _buildComplete(),
        ],
      ),
    );
  }

  Widget _buildTrackingBadge() {
    final tracking = _repCounter.bodyDetected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (tracking ? Colors.green : Colors.red).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tracking ? Icons.person : Icons.person_off,
            color: tracking ? Colors.green : Colors.redAccent,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            tracking ? 'Tracking' : 'No body',
            style: TextStyle(fontSize: 12, color: tracking ? Colors.green : Colors.redAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.white38),
            const SizedBox(height: 16),
            Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 15)),
            const SizedBox(height: 24),
            GradientButton(text: 'Go Back', icon: Icons.arrow_back, onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildComplete() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text('Session Complete!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),
              const SizedBox(height: 8),
              Text('+`${_exercise.minutesEarned} minutes earned!',
                  style: const TextStyle(fontSize: 20, color: Colors.white70)),
              const SizedBox(height: 8),
              Text('Total: `${StorageService.screenTimeMinutes} min available',
                  style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5))),
              const SizedBox(height: 6),
              Text('🔥 Streak: `${StorageService.currentStreak} days',
                  style: const TextStyle(fontSize: 16, color: Color(0xFFFF6B35))),
              const SizedBox(height: 32),
              GradientButton(
                text: 'Back to Home',
                icon: Icons.home,
                onPressed: () => Navigator.popUntil(context, (r) => r.settings.name == '/home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
"@
Set-Content -Path "lib\screens\camera_exercise_screen.dart" -Value $f5 -Encoding UTF8

# --- lib/screens/timer_screen.dart ---
Write-Host "[6/8] lib/screens/timer_screen.dart" -ForegroundColor Yellow
$f6 = @"
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
      return '`${hours.toString().padLeft(2, '0')}:`${minutes.toString().padLeft(2, '0')}:`${seconds.toString().padLeft(2, '0')}';
    }
    return '`${minutes.toString().padLeft(2, '0')}:`${seconds.toString().padLeft(2, '0')}';
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
                            ? '`${_blockedApps.length} app`${_blockedApps.length == 1 ? '' : 's'} blocking active'
                            : '`${_blockedApps.length} app`${_blockedApps.length == 1 ? '' : 's'} will be blocked',
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
"@
Set-Content -Path "lib\screens\timer_screen.dart" -Value $f6 -Encoding UTF8

# --- lib/screens/parental_controls_screen.dart ---
Write-Host "[7/8] lib/screens/parental_controls_screen.dart" -ForegroundColor Yellow
$f7 = @"
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/sound_haptic_service.dart';

class ParentalControlsScreen extends StatefulWidget {
  const ParentalControlsScreen({super.key});

  @override
  State<ParentalControlsScreen> createState() => _ParentalControlsScreenState();
}

class _ParentalControlsScreenState extends State<ParentalControlsScreen> {
  bool _isUnlocked = false;
  bool _parentalEnabled = false;
  int _dailyLimit = 60;
  int _minReps = 10;

  @override
  void initState() {
    super.initState();
    _parentalEnabled = StorageService.parentalControlsEnabled;
    _dailyLimit = StorageService.dailyScreenTimeLimit;
    _minReps = StorageService.minRepsRequired;
    _soundEnabled = StorageService.soundEnabled;
    _hapticEnabled = StorageService.hapticEnabled;
    // If no PIN set yet, auto-unlock for initial setup
    if (StorageService.parentalPin.isEmpty) {
      _isUnlocked = true;
    }
  }

  void _showPinDialog({required bool isSetup}) {
    final controller = TextEditingController();
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Text(
            isSetup ? 'Set Parent PIN' : 'Enter Parent PIN',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 12),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '••••',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                  counterText: '',
                  errorText: error,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (isSetup) ...[
                const SizedBox(height: 8),
                Text(
                  'This PIN locks the parental settings',
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () async {
                final pin = controller.text.trim();
                if (pin.length != 4) {
                  setDialogState(() => error = 'PIN must be 4 digits');
                  return;
                }
                if (isSetup) {
                  await StorageService.setParentalPin(pin);
                  setState(() => _isUnlocked = true);
                  if (ctx.mounted) Navigator.pop(ctx);
                } else {
                  if (pin == StorageService.parentalPin) {
                    setState(() => _isUnlocked = true);
                    if (ctx.mounted) Navigator.pop(ctx);
                  } else {
                    setDialogState(() => error = 'Wrong PIN');
                  }
                }
              },
              child: Text(
                isSetup ? 'Set PIN' : 'Unlock',
                style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    child: Text('Settings', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 30),

              // Parental Controls Section
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
                        const Icon(Icons.shield, color: Color(0xFF6C63FF), size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Parental Controls', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        if (!_isUnlocked)
                          IconButton(
                            icon: const Icon(Icons.lock, color: Colors.white38),
                            onPressed: () => _showPinDialog(isSetup: false),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isUnlocked
                          ? 'Set rules for screen time usage'
                          : 'Tap the lock to enter your PIN',
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
                    ),

                    if (_isUnlocked) ...[
                      const SizedBox(height: 20),

                      // Enable toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Enable Parental Controls', style: TextStyle(fontSize: 15, color: Colors.white)),
                          Switch(
                            value: _parentalEnabled,
                            activeColor: const Color(0xFF6C63FF),
                            onChanged: (val) async {
                              if (val && StorageService.parentalPin.isEmpty) {
                                _showPinDialog(isSetup: true);
                                return;
                              }
                              await StorageService.setParentalControlsEnabled(val);
                              setState(() => _parentalEnabled = val);
                            },
                          ),
                        ],
                      ),

                      if (_parentalEnabled) ...[
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 12),

                        // Daily limit slider
                        Text('Daily Screen Time Limit', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7))),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Slider(
                                value: _dailyLimit.toDouble(),
                                min: 15,
                                max: 180,
                                divisions: 11,
                                activeColor: const Color(0xFF6C63FF),
                                inactiveColor: Colors.white12,
                                label: '`$_dailyLimit min',
                                onChanged: (val) {
                                  setState(() => _dailyLimit = val.round());
                                },
                                onChangeEnd: (val) async {
                                  await StorageService.setDailyScreenTimeLimit(val.round());
                                },
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              child: Text(
                                '`$_dailyLimit min',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Min reps slider
                        Text('Minimum Reps Per Session', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7))),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Slider(
                                value: _minReps.toDouble(),
                                min: 5,
                                max: 50,
                                divisions: 9,
                                activeColor: const Color(0xFF6C63FF),
                                inactiveColor: Colors.white12,
                                label: '`$_minReps reps',
                                onChanged: (val) {
                                  setState(() => _minReps = val.round());
                                },
                                onChangeEnd: (val) async {
                                  await StorageService.setMinRepsRequired(val.round());
                                },
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              child: Text(
                                '`$_minReps reps',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Change PIN
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showPinDialog(isSetup: true),
                            icon: const Icon(Icons.lock_reset, color: Color(0xFF6C63FF)),
                            label: const Text('Change PIN', style: TextStyle(color: Color(0xFF6C63FF))),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Sound & Haptics Section ──
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
                    const Row(
                      children: [
                        Icon(Icons.volume_up, color: Color(0xFF6C63FF), size: 28),
                        SizedBox(width: 12),
                        Text('Sound & Haptics',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Control audio and vibration feedback',
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
                    ),
                    const SizedBox(height: 16),

                    // Sound toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.music_note,
                                color: _soundEnabled ? const Color(0xFF6C63FF) : Colors.white38, size: 20),
                            const SizedBox(width: 10),
                            const Text('Sound Effects', style: TextStyle(fontSize: 15, color: Colors.white)),
                          ],
                        ),
                        Switch(
                          value: _soundEnabled,
                          activeColor: const Color(0xFF6C63FF),
                          onChanged: (val) async {
                            await StorageService.setSoundEnabled(val);
                            SoundHapticService.setSoundEnabled(val);
                            setState(() => _soundEnabled = val);
                            if (val) SoundHapticService.playRepTick();
                          },
                        ),
                      ],
                    ),
                    Text(
                      'Rep ticks, completion sounds, timer alerts',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
                    ),
                    const SizedBox(height: 8),

                    // Haptic toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.vibration,
                                color: _hapticEnabled ? const Color(0xFF6C63FF) : Colors.white38, size: 20),
                            const SizedBox(width: 10),
                            const Text('Vibration Feedback', style: TextStyle(fontSize: 15, color: Colors.white)),
                          ],
                        ),
                        Switch(
                          value: _hapticEnabled,
                          activeColor: const Color(0xFF6C63FF),
                          onChanged: (val) async {
                            await StorageService.setHapticEnabled(val);
                            SoundHapticService.setHapticEnabled(val);
                            setState(() => _hapticEnabled = val);
                            if (val) SoundHapticService.tapFeedback();
                          },
                        ),
                      ],
                    ),
                    Text(
                      'Phone vibrations on reps and milestones',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // App Info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  children: [
                    const Text('💪', style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 10),
                    const Text('RepScreen', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Version 1.0.0 MVP', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4))),
                    const SizedBox(height: 12),
                    Text(
                      'Earn screen time by exercising.\nBuilt with ❤️',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
                    ),
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
}
"@
Set-Content -Path "lib\screens\parental_controls_screen.dart" -Value $f7 -Encoding UTF8

# --- android/app/src/main/kotlin/com/pushscroll/pushscroll_app/MainActivity.kt ---
Write-Host "[8/8] android/app/src/main/kotlin/com/pushscroll/pushscroll_app/MainActivity.kt" -ForegroundColor Yellow
$f8 = @"
package com.pushscroll.pushscroll_app

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.PI
import kotlin.math.min
import kotlin.math.sin

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.repscreen/blocking"
    private val SOUND_CHANNEL = "com.repscreen/sound"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Blocking method channel (existing) ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> result.success(getInstalledApps())

                    "hasUsagePermission" -> result.success(hasUsagePermission())
                    "requestUsagePermission" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(true)
                    }

                    "hasOverlayPermission" ->
                        result.success(Settings.canDrawOverlays(this))
                    "requestOverlayPermission" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:`$packageName")
                            )
                        )
                        result.success(true)
                    }

                    "startBlocking" -> {
                        val secs = call.argument<Int>("seconds") ?: 0
                        val apps =
                            call.argument<List<String>>("apps") ?: listOf()
                        val intent =
                            Intent(this, ScreenTimeService::class.java).apply {
                                action = "START"
                                putExtra("seconds", secs)
                                putStringArrayListExtra(
                                    "blocked", ArrayList(apps)
                                )
                            }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                            startForegroundService(intent)
                        else startService(intent)
                        result.success(true)
                    }

                    "stopBlocking" -> {
                        startService(
                            Intent(this, ScreenTimeService::class.java)
                                .apply { action = "STOP" }
                        )
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }

        // ── Sound method channel (new) ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SOUND_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playSound" -> {
                        val type = call.argument<String>("type") ?: ""
                        playSound(type)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /* ── Sound Generation ── */

    private fun playSound(type: String) {
        Thread {
            try {
                when (type) {
                    "repTick" -> playTone(880.0, 60, 0.4f)
                    "setComplete" -> playChord(
                        listOf(
                            Triple(523.0, 0, 150),   // C5
                            Triple(659.0, 80, 150),   // E5
                            Triple(784.0, 160, 200)   // G5
                        ), 0.45f
                    )
                    "timerWarning" -> {
                        playTone(600.0, 120, 0.5f)
                        Thread.sleep(100)
                        playTone(600.0, 120, 0.5f)
                    }
                    "timerExpired" -> playChord(
                        listOf(
                            Triple(800.0, 0, 180),
                            Triple(700.0, 220, 180),
                            Triple(600.0, 440, 250)
                        ), 0.55f
                    )
                    "milestone" -> playChord(
                        listOf(
                            Triple(523.0, 0, 120),    // C5
                            Triple(659.0, 100, 120),  // E5
                            Triple(784.0, 200, 120),  // G5
                            Triple(1047.0, 300, 280)  // C6
                        ), 0.45f
                    )
                    "countdownTick" -> playTone(1000.0, 30, 0.25f)
                }
            } catch (_: Exception) {}
        }.start()
    }

    /** Play a single sine-wave tone */
    private fun playTone(freq: Double, durationMs: Int, volume: Float) {
        val sr = 44100
        val n = (sr * durationMs / 1000.0).toInt()
        val samples = ShortArray(n)

        for (i in 0 until n) {
            val t = i.toDouble() / sr
            var s = sin(2.0 * PI * freq * t)

            // Fade envelope to avoid clicks
            val fadeIn = min(i / (sr * 0.005), 1.0)
            val fadeOut = min((n - i) / (sr * 0.01), 1.0)
            s *= fadeIn * fadeOut * volume

            samples[i] = (s * Short.MAX_VALUE).toInt().toShort()
        }

        writeAndPlay(samples, sr)
    }

    /** Play a sequence of tones (arpeggio/chord) with timing offsets */
    private fun playChord(
        notes: List<Triple<Double, Int, Int>>,  // freq, offsetMs, durationMs
        volume: Float
    ) {
        val sr = 44100
        val totalMs = notes.maxOf { it.second + it.third }
        val totalSamples = (sr * totalMs / 1000.0).toInt()
        val mixed = FloatArray(totalSamples)

        for ((freq, offsetMs, durMs) in notes) {
            val offsetSamp = (sr * offsetMs / 1000.0).toInt()
            val durSamp = (sr * durMs / 1000.0).toInt()

            for (i in 0 until durSamp) {
                val idx = offsetSamp + i
                if (idx >= totalSamples) break
                val t = i.toDouble() / sr
                var s = sin(2.0 * PI * freq * t)

                val fadeIn = min(i / (sr * 0.005), 1.0)
                val fadeOut = min((durSamp - i) / (sr * 0.015), 1.0)
                s *= fadeIn * fadeOut

                mixed[idx] += (s * volume).toFloat()
            }
        }

        val samples = ShortArray(totalSamples)
        for (i in mixed.indices) {
            val clamped = mixed[i].coerceIn(-1f, 1f)
            samples[i] = (clamped * Short.MAX_VALUE).toInt().toShort()
        }

        writeAndPlay(samples, sr)
    }

    /** Write samples to an AudioTrack and play */
    private fun writeAndPlay(samples: ShortArray, sampleRate: Int) {
        val minBuf = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        val track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(maxOf(minBuf, samples.size * 2))
            .setTransferMode(AudioTrack.MODE_STATIC)
            .build()

        track.write(samples, 0, samples.size)
        track.play()

        // Wait for playback to finish, then release
        val durationMs = (samples.size * 1000L / sampleRate) + 80
        Thread.sleep(durationMs)
        track.stop()
        track.release()
    }

    /* ── helpers ── */

    private fun getInstalledApps(): List<Map<String, String>> {
        val pm = packageManager
        val intent =
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return pm.queryIntentActivities(intent, 0)
            .map {
                mapOf(
                    "package" to it.activityInfo.packageName,
                    "name" to it.loadLabel(pm).toString()
                )
            }
            .filter { it["package"] != packageName }
            .sortedBy { it["name"]?.lowercase() }
    }

    private fun hasUsagePermission(): Boolean {
        val appOps =
            getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        return appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(), packageName
        ) == AppOpsManager.MODE_ALLOWED
    }
}
"@
Set-Content -Path "android\app\src\main\kotlin\com\pushscroll\pushscroll_app\MainActivity.kt" -Value $f8 -Encoding UTF8

Write-Host ""
Write-Host "All 8 files updated!" -ForegroundColor Green
Write-Host ""
Write-Host "Now run:" -ForegroundColor Cyan
Write-Host "  C:\flutter\flutter\bin\flutter.bat run" -ForegroundColor White
