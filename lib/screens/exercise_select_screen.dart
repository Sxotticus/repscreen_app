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
              emoji: 'âš¡',
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
              title: 'ðŸ“¸  Camera Mode',
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
              title: 'ðŸ‘†  Manual Tap Mode',
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
                  ? '${exercise.repsPerSet} min hold â†’ ${exercise.minutesEarned} min'
                  : '${exercise.repsPerSet} reps â†’ ${exercise.minutesEarned} min',
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