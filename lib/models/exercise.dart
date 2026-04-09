import 'package:flutter/material.dart';

class Exercise {
  final String name;
  final IconData icon;
  final String emoji;
  final int repsPerSet;
  final int minutesEarned;
  final bool isCustom;

  const Exercise({
    required this.name,
    required this.icon,
    required this.emoji,
    this.repsPerSet = 10,
    this.minutesEarned = 10,
    this.isCustom = false,
  });

  static const List<Exercise> defaults = [
    Exercise(
      name: 'Push-ups',
      icon: Icons.fitness_center,
      emoji: '💪',
      repsPerSet: 10,
      minutesEarned: 10,
    ),
    Exercise(
      name: 'Squats',
      icon: Icons.accessibility_new,
      emoji: '🦵',
      repsPerSet: 15,
      minutesEarned: 10,
    ),
    Exercise(
      name: 'Planks',
      icon: Icons.timer,
      emoji: '🧘',
      repsPerSet: 1, // 1 = 60 seconds
      minutesEarned: 10,
    ),
    Exercise(
      name: 'Jumping Jacks',
      icon: Icons.directions_run,
      emoji: '⭐',
      repsPerSet: 25,
      minutesEarned: 10,
    ),
    Exercise(
      name: 'Sit-ups',
      icon: Icons.self_improvement,
      emoji: '🔥',
      repsPerSet: 15,
      minutesEarned: 10,
    ),
    Exercise(
      name: 'Burpees',
      icon: Icons.bolt,
      emoji: '🏋️',
      repsPerSet: 8,
      minutesEarned: 15,
    ),
  ];
}
