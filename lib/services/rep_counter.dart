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
        // Custom exercises â†’ use shoulder tracking (push-up logic)
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