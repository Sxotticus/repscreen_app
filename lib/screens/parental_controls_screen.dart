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
  bool _soundEnabled = true;
  bool _hapticEnabled = true;

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
                                label: '$_dailyLimit min',
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
                                '$_dailyLimit min',
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
                                label: '$_minReps reps',
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
                                '$_minReps reps',
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
