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