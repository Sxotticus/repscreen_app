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
