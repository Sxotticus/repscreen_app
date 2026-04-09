# RepScreen Camera Update Script
# Run from C:\pushscroll_app
Write-Host "Updating RepScreen with camera detection..." -ForegroundColor Cyan

# Create new directories
New-Item -ItemType Directory -Force -Path "lib\painters" | Out-Null
New-Item -ItemType Directory -Force -Path "lib\services" | Out-Null

Write-Host "Creating lib\services\rep_counter.dart..." -ForegroundColor Yellow
$content = @'
import 'dart:math';
import 'dart:ui';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Counts exercise reps using AI pose detection landmarks.
/// Uses adaptive thresholds and a state machine to detect up/down cycles.
class RepCounter {
  final String exerciseName;
  int repCount = 0;
  bool bodyDetected = false;
  String phase = 'up'; // 'up' or 'down'

  // Sliding window of metric values for adaptive thresholds
  final List<double> _history = [];
  static const int _windowSize = 90; // ~3 seconds at 30fps
  static const int _minFrames = 12; // Min frames before counting
  int _framesSinceLastRep = 0;
  static const int _minGap = 10; // Min frames between reps (anti-double-count)

  RepCounter({required this.exerciseName});

  /// Get the tracking metric for the current exercise type.
  /// Returns null if required landmarks aren't visible.
  double? _getMetric(Pose pose, Size imageSize) {
    final lm = pose.landmarks;
    switch (exerciseName) {
      case 'Push-ups':
        return _avgY(lm, PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, imageSize);
      case 'Squats':
        return _avgY(lm, PoseLandmarkType.leftHip, PoseLandmarkType.rightHip, imageSize);
      case 'Jumping Jacks':
        return _wristVsShoulder(lm, imageSize);
      case 'Sit-ups':
        return _avgY(lm, PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, imageSize);
      case 'Burpees':
        return _singleY(lm, PoseLandmarkType.nose, imageSize);
      default:
        // Custom exercises → use shoulder tracking (push-up logic)
        return _avgY(lm, PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, imageSize);
    }
  }

  /// Average normalized Y of two landmarks (0 = top, 1 = bottom).
  double? _avgY(Map<PoseLandmarkType, PoseLandmark> lm, PoseLandmarkType a, PoseLandmarkType b, Size size) {
    final la = lm[a];
    final lb = lm[b];
    if (la == null || lb == null) return null;
    if (la.likelihood < 0.5 || lb.likelihood < 0.5) return null;
    return ((la.y + lb.y) / 2) / size.height;
  }

  /// Single landmark normalized Y.
  double? _singleY(Map<PoseLandmarkType, PoseLandmark> lm, PoseLandmarkType type, Size size) {
    final l = lm[type];
    if (l == null || l.likelihood < 0.5) return null;
    return l.y / size.height;
  }

  /// Wrist Y relative to shoulder Y (negative = hands above head).
  double? _wristVsShoulder(Map<PoseLandmarkType, PoseLandmark> lm, Size size) {
    final lw = lm[PoseLandmarkType.leftWrist];
    final rw = lm[PoseLandmarkType.rightWrist];
    final ls = lm[PoseLandmarkType.leftShoulder];
    final rs = lm[PoseLandmarkType.rightShoulder];
    if (lw == null || rw == null || ls == null || rs == null) return null;
    double wristY = (lw.y + rw.y) / 2;
    double shoulderY = (ls.y + rs.y) / 2;
    return (wristY - shoulderY) / size.height;
  }

  /// Process one frame of pose data. Call this for each camera frame.
  void processFrame(Pose pose, Size imageSize) {
    // Check body visibility
    final required = [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    ];
    bodyDetected = required.every((t) {
      final l = pose.landmarks[t];
      return l != null && l.likelihood > 0.5;
    });

    if (!bodyDetected) return;

    final metric = _getMetric(pose, imageSize);
    if (metric == null) return;

    _history.add(metric);
    if (_history.length > _windowSize) _history.removeAt(0);
    _framesSinceLastRep++;

    if (_history.length < _minFrames) return;

    // Adaptive thresholds from sliding window
    double minVal = _history.reduce(min);
    double maxVal = _history.reduce(max);
    double range = maxVal - minVal;
    if (range < 0.03) return; // Not enough movement

    // Jumping jacks have inverted logic (hands go UP = metric decreases)
    bool inverted = exerciseName == 'Jumping Jacks';

    double downThresh = minVal + (inverted ? 0.35 : 0.65) * range;
    double upThresh = minVal + (inverted ? 0.65 : 0.35) * range;

    if (!inverted) {
      // Standard: metric increases when going "down"
      if (phase == 'up' && metric > downThresh && _framesSinceLastRep > _minGap) {
        phase = 'down';
      } else if (phase == 'down' && metric < upThresh) {
        phase = 'up';
        repCount++;
        _framesSinceLastRep = 0;
      }
    } else {
      // Inverted: metric decreases when in "active" position
      if (phase == 'up' && metric < downThresh && _framesSinceLastRep > _minGap) {
        phase = 'down';
      } else if (phase == 'down' && metric > upThresh) {
        phase = 'up';
        repCount++;
        _framesSinceLastRep = 0;
      }
    }
  }

  void reset() {
    repCount = 0;
    phase = 'up';
    bodyDetected = false;
    _history.clear();
    _framesSinceLastRep = 0;
  }
}
'@
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$PWD\lib\services\rep_counter.dart", $content, $utf8)

Write-Host "Creating lib\painters\pose_painter.dart..." -ForegroundColor Yellow
$content = @'
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Draws the pose skeleton (bones + joints) over the camera preview.
class PosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final Size canvasSize;
  final bool isFrontCamera;

  PosePainter({
    required this.pose,
    required this.imageSize,
    required this.canvasSize,
    this.isFrontCamera = true,
  });

  // All bone connections to draw
  static const _connections = [
    // Face
    [PoseLandmarkType.leftEar, PoseLandmarkType.leftEye],
    [PoseLandmarkType.leftEye, PoseLandmarkType.nose],
    [PoseLandmarkType.nose, PoseLandmarkType.rightEye],
    [PoseLandmarkType.rightEye, PoseLandmarkType.rightEar],
    // Upper body
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
    [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
    [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
    // Torso
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
    // Lower body
    [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
    [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
    [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
    [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Bone line paint
    final bonePaint = Paint()
      ..color = const Color(0xFF6C63FF)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Joint dot paint
    final jointPaint = Paint()
      ..color = const Color(0xFF9D4EDD)
      ..style = PaintingStyle.fill;

    // Draw bones
    for (final conn in _connections) {
      final a = pose.landmarks[conn[0]];
      final b = pose.landmarks[conn[1]];
      if (a != null && b != null && a.likelihood > 0.5 && b.likelihood > 0.5) {
        canvas.drawLine(_toCanvas(a), _toCanvas(b), bonePaint);
      }
    }

    // Draw joints
    for (final lm in pose.landmarks.values) {
      if (lm.likelihood > 0.5) {
        canvas.drawCircle(_toCanvas(lm), 6, jointPaint);
      }
    }
  }

  /// Transform a pose landmark from image coordinates to canvas coordinates.
  Offset _toCanvas(PoseLandmark lm) {
    double x = lm.x * canvasSize.width / imageSize.width;
    double y = lm.y * canvasSize.height / imageSize.height;
    if (isFrontCamera) x = canvasSize.width - x; // Mirror for selfie cam
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant PosePainter old) => true;
}
'@
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$PWD\lib\painters\pose_painter.dart", $content, $utf8)

Write-Host "Creating lib\screens\camera_exercise_screen.dart..." -ForegroundColor Yellow
$content = @'
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/exercise.dart';
import '../services/storage_service.dart';
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
            : 'Camera error: $e';
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
        _repCounter.processFrame(poses.first, _imgSize);
        setState(() { _latestPose = poses.first; });

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
                      '${_exercise.emoji} ${_exercise.name}',
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
                      '$reps',
                      style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.white, height: 1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'of $target $label',
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
                      '${_exercise.minutesEarned} min reward  •  ${target - reps} $label to go',
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
              Text('+${_exercise.minutesEarned} minutes earned!',
                  style: const TextStyle(fontSize: 20, color: Colors.white70)),
              const SizedBox(height: 8),
              Text('Total: ${StorageService.screenTimeMinutes} min available',
                  style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5))),
              const SizedBox(height: 6),
              Text('🔥 Streak: ${StorageService.currentStreak} days',
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
'@
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$PWD\lib\screens\camera_exercise_screen.dart", $content, $utf8)

Write-Host "Updating pubspec.yaml..." -ForegroundColor Yellow
$content = @'
name: repscreen_app
description: "A new Flutter project."
# The following line prevents the package from being accidentally published to
# pub.dev using `flutter pub publish`. This is preferred for private packages.
publish_to: 'none' # Remove this line if you wish to publish to pub.dev

# The following defines the version and build number for your application.
# A version number is three numbers separated by dots, like 1.2.43
# followed by an optional build number separated by a +.
# Both the version and the builder number may be overridden in flutter
# build by specifying --build-name and --build-number, respectively.
# In Android, build-name is used as versionName while build-number used as versionCode.
# Read more about Android versioning at https://developer.android.com/studio/publish/versioning
# In iOS, build-name is used as CFBundleShortVersionString while build-number is used as CFBundleVersion.
# Read more about iOS versioning at
# https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html
# In Windows, build-name is used as the major, minor, and patch parts
# of the product and file versions while build-number is used as the build suffix.
version: 1.0.0+1

environment:
  sdk: ^3.11.4

# Dependencies specify other packages that your package needs in order to work.
# To automatically upgrade your package dependencies to the latest versions
# consider running `flutter pub upgrade --major-versions`. Alternatively,
# dependencies can be manually updated by changing the version numbers below to
# the latest version available on pub.dev. To see which dependencies have newer
# versions available, run `flutter pub outdated`.
dependencies:
  flutter:
    sdk: flutter

  # The following adds the Cupertino Icons font to your application.
  # Use with the CupertinoIcons class for iOS style icons.
  cupertino_icons: ^1.0.8
  shared_preferences: ^2.2.2
  camera: ^0.11.0
  google_mlkit_pose_detection: ^0.12.0

dev_dependencies:
  flutter_test:
    sdk: flutter

  # The "flutter_lints" package below contains a set of recommended lints to
  # encourage good coding practices. The lint set provided by the package is
  # activated in the `analysis_options.yaml` file located at the root of your
  # package. See that file for information about deactivating specific lint
  # rules and activating additional ones.
  flutter_lints: ^6.0.0

# For information on the generic Dart part of this file, see the
# following page: https://dart.dev/tools/pub/pubspec

# The following section is specific to Flutter packages.
flutter:

  # The following line ensures that the Material Icons font is
  # included with your application, so that you can use the icons in
  # the material Icons class.
  uses-material-design: true

  # To add assets to your application, add an assets section, like this:
  # assets:
  #   - images/a_dot_burr.jpeg
  #   - images/a_dot_ham.jpeg

  # An image asset can refer to one or more resolution-specific "variants", see
  # https://flutter.dev/to/resolution-aware-images

  # For details regarding adding assets from package dependencies, see
  # https://flutter.dev/to/asset-from-package

  # To add custom fonts to your application, add a fonts section here,
  # in this "flutter" section. Each entry in this list should have a
  # "family" key with the font family name, and a "fonts" key with a
  # list giving the asset and other descriptors for the font. For
  # example:
  # fonts:
  #   - family: Schyler
  #     fonts:
  #       - asset: fonts/Schyler-Regular.ttf
  #       - asset: fonts/Schyler-Italic.ttf
  #         style: italic
  #   - family: Trajan Pro
  #     fonts:
  #       - asset: fonts/TrajanPro.ttf
  #       - asset: fonts/TrajanPro_Bold.ttf
  #         weight: 700
  #
  # For details regarding fonts from package dependencies,
  # see https://flutter.dev/to/font-from-package
'@
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$PWD\pubspec.yaml", $content, $utf8)

Write-Host "Updating android\app\src\main\AndroidManifest.xml..." -ForegroundColor Yellow
$content = @'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-feature android:name="android.hardware.camera" android:required="false"/>
    <uses-feature android:name="android.hardware.camera.front" android:required="false"/>
    <application
        android:label="RepScreen"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <!-- Specifies an Android theme to apply to this Activity as soon as
                 the Android process has started. This theme is visible to the user
                 while the Flutter UI initializes. After that, this theme continues
                 to determine the Window background behind the Flutter UI. -->
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <!-- Don't delete the meta-data below.
             This is used by the Flutter tool to generate GeneratedPluginRegistrant.java -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
    <!-- Required to query activities that can process text, see:
         https://developer.android.com/training/package-visibility and
         https://developer.android.com/reference/android/content/Intent#ACTION_PROCESS_TEXT.

         In particular, this is used by the Flutter engine in io.flutter.plugin.text.ProcessTextPlugin. -->
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
'@
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$PWD\android\app\src\main\AndroidManifest.xml", $content, $utf8)

Write-Host "Updating android\app\build.gradle.kts..." -ForegroundColor Yellow
$content = @'
plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.pushscroll.pushscroll_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.pushscroll.pushscroll_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
'@
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$PWD\android\app\build.gradle.kts", $content, $utf8)

Write-Host "Updating lib\screens\exercise_select_screen.dart..." -ForegroundColor Yellow
$content = @'
import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../services/storage_service.dart';

class ExerciseSelectScreen extends StatefulWidget {
  const ExerciseSelectScreen({super.key});

  @override
  State<ExerciseSelectScreen> createState() => _ExerciseSelectScreenState();
}

class _ExerciseSelectScreenState extends State<ExerciseSelectScreen> {
  List<Exercise> _allExercises = [];

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  void _loadExercises() {
    final customs = StorageService.customExercises;
    setState(() {
      _allExercises = [
        ...Exercise.defaults,
        ...customs.map((name) => Exercise(
              name: name,
              icon: Icons.sports_gymnastics,
              emoji: '⚡',
              repsPerSet: 10,
              minutesEarned: 10,
              isCustom: true,
            )),
      ];
    });
  }

  void _addCustomExercise() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Add Custom Exercise', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. Lunges, Pull-ups...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final customs = StorageService.customExercises;
                customs.add(name);
                await StorageService.setCustomExercises(customs);
                _loadExercises();
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add', style: TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _deleteCustomExercise(String name) async {
    final customs = StorageService.customExercises;
    customs.remove(name);
    await StorageService.setCustomExercises(customs);
    _loadExercises();
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
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Choose Exercise',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Pick an exercise to earn screen time',
                style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 24),

              // Exercise Grid
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.1,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: _allExercises.length + 1, // +1 for add button
                  itemBuilder: (context, index) {
                    if (index == _allExercises.length) {
                      return _buildAddCard();
                    }
                    return _buildExerciseCard(_allExercises[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showModeChoice(Exercise exercise) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '${exercise.emoji} ${exercise.name}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              'How do you want to exercise?',
              style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            // Camera mode
            _modeButton(
              icon: Icons.camera_alt,
              title: '📸  Camera Mode',
              subtitle: 'AI detects your reps automatically',
              color: const Color(0xFF6C63FF),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/camera_exercise', arguments: exercise);
              },
            ),
            const SizedBox(height: 12),
            // Manual mode
            _modeButton(
              icon: Icons.touch_app,
              title: '👆  Manual Tap Mode',
              subtitle: 'Tap the button to count reps',
              color: Colors.white24,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/earn', arguments: exercise);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color == Colors.white24 ? Colors.white54 : color, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseCard(Exercise exercise) {
    final totalDone = StorageService.getExerciseCount(exercise.name);
    return GestureDetector(
      onTap: () => _showModeChoice(exercise),
      onLongPress: exercise.isCustom
          ? () => _deleteCustomExercise(exercise.name)
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(exercise.emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 10),
            Text(
              exercise.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              exercise.name == 'Planks'
                  ? '${exercise.repsPerSet} min hold → ${exercise.minutesEarned} min'
                  : '${exercise.repsPerSet} reps → ${exercise.minutesEarned} min',
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
            ),
            if (totalDone > 0) ...[
              const SizedBox(height: 4),
              Text(
                '$totalDone total',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6C63FF)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddCard() {
    return GestureDetector(
      onTap: _addCustomExercise,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 40, color: const Color(0xFF6C63FF).withValues(alpha: 0.6)),
            const SizedBox(height: 10),
            Text(
              'Add Custom\nExercise',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}
'@
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$PWD\lib\screens\exercise_select_screen.dart", $content, $utf8)

Write-Host "Updating lib\main.dart..." -ForegroundColor Yellow
$content = @'
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
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
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
      },
    );
  }
}
'@
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$PWD\lib\main.dart", $content, $utf8)

Write-Host ""
Write-Host "All files updated! Now run:" -ForegroundColor Green
Write-Host "  flutter.bat pub get" -ForegroundColor White
Write-Host ""