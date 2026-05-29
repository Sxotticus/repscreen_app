import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../widgets/gradient_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _screenTime = 0;
  int _totalPushups = 0;
  int _totalSessions = 0;
  int _currentStreak = 0;
  int _blockedAppsCount = 0;

  // Staggered entrance animations
  late AnimationController _staggerController;
  late List<Animation<double>> _fadeAnims;
  late List<Animation<Offset>> _slideAnims;

  // Animated screen time counter
  late AnimationController _counterController;
  late Animation<double> _counterAnim;
  int _displayedTime = 0;

  // Pulsing workout button
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initAnimations();
  }

  void _initAnimations() {
    // Staggered entrance — 6 items
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnims = List.generate(6, (i) {
      final start = i * 0.12;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });

    _slideAnims = List.generate(6, (i) {
      final start = i * 0.12;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });

    // Counter animation
    _counterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _counterAnim = CurvedAnimation(
      parent: _counterController,
      curve: Curves.easeOutCubic,
    );
    _counterAnim.addListener(() {
      setState(() {
        _displayedTime = (_screenTime * _counterAnim.value).round();
      });
    });

    // Pulsing button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _staggerController.forward();
    _counterController.forward();
  }

  void _loadData() {
    setState(() {
      _screenTime = StorageService.screenTimeMinutes;
      _totalPushups = StorageService.totalPushups;
      _totalSessions = StorageService.totalSessions;
      _currentStreak = StorageService.currentStreak;
      _blockedAppsCount = StorageService.blockedApps.length;
    });
  }

  Widget _animItem(int index, Widget child) {
    if (index >= _fadeAnims.length) return child;
    return FadeTransition(
      opacity: _fadeAnims[index],
      child: SlideTransition(
        position: _slideAnims[index],
        child: child,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // ── Header (item 0) ──
              _animItem(0, Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'RepScreen',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.bar_chart_rounded, color: Colors.white54),
                        onPressed: () async {
                          await Navigator.pushNamed(context, '/stats');
                          _loadData();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white54),
                        onPressed: () async {
                          await Navigator.pushNamed(context, '/settings');
                          _loadData();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.people_alt_rounded, color: Colors.white54),
                        onPressed: () async {
                          await Navigator.pushNamed(context, '/profiles');
                          _loadData();
                        },
                      ),
                    ],
                  ),
                ],
              )),
              const SizedBox(height: 24),

              // ── Screen Time Card (item 1) — with animated counter ──
              _animItem(1, Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF9D4EDD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Available Screen Time',
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$_displayedTime',
                          style: const TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(' min',
                              style: TextStyle(
                                  fontSize: 22,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                    if (StorageService.parentalControlsEnabled) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Daily limit: ${StorageService.dailyScreenTimeLimit} min',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.white54),
                      ),
                    ],
                  ],
                ),
              )),
              const SizedBox(height: 20),

              // ── Streak Banner (item 2) ──
              _animItem(2, GestureDetector(
                onTap: () async {
                  await Navigator.pushNamed(context, '/streaks');
                  _loadData();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _currentStreak >= 7
                          ? [const Color(0xFFFF6B35), const Color(0xFFFF9F1C)]
                          : [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.04)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: _currentStreak < 7
                        ? Border.all(color: Colors.white.withValues(alpha: 0.08))
                        : null,
                  ),
                  child: Row(
                    children: [
                      const Text('\uD83D\uDD25', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_currentStreak Day Streak${_currentStreak >= 7 ? ' \uD83C\uDF89' : ''}',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currentStreak == 0
                                  ? 'Start a streak today!'
                                  : _currentStreak >= 7
                                      ? 'Amazing! Keep the fire going!'
                                      : 'Best: ${StorageService.bestStreak} days \u00b7 Tap for details',
                              style: TextStyle(
                                fontSize: 13,
                                color: _currentStreak >= 7 ? Colors.white70 : Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: _currentStreak >= 7 ? Colors.white70 : Colors.white38),
                    ],
                  ),
                ),
              )),
              const SizedBox(height: 20),

              // ── Stats Row (item 3) ──
              _animItem(3, Row(
                children: [
                  Expanded(child: _buildStatCard('Total\nReps', '$_totalPushups', Icons.fitness_center)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard('Sessions', '$_totalSessions', Icons.check_circle_outline)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard('Challenges', '${StorageService.challengesCompleted}', Icons.emoji_events)),
                ],
              )),
              const SizedBox(height: 20),

              // ── App Blocking Card (item 4) ──
              _animItem(4, GestureDetector(
                onTap: () async {
                  await Navigator.pushNamed(context, '/blocked_apps');
                  _loadData();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield,
                          color: _blockedAppsCount > 0 ? const Color(0xFF6C63FF) : Colors.white38,
                          size: 26),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('App Blocking',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                            const SizedBox(height: 2),
                            Text(
                              _blockedAppsCount > 0
                                  ? '$_blockedAppsCount app${_blockedAppsCount == 1 ? '' : 's'} blocked when time is up'
                                  : 'Tap to choose which apps to block',
                              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3)),
                    ],
                  ),
                ),
              )),
              const SizedBox(height: 24),

              // ── Family Card (between blocking and buttons) ──
              GestureDetector(
                onTap: () async {
                  await Navigator.pushNamed(context, '/profiles');
                  _loadData();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.group, color: Color(0xFF9D4EDD), size: 26),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Family & Friends',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                            SizedBox(height: 2),
                            Text(
                              'Compete with family members',
                              style: TextStyle(fontSize: 12, color: Colors.white38),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Action Buttons (item 5) — with pulse animation ──
              _animItem(5, Column(
                children: [
                  // Pulsing "Start Workout" button
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnim.value,
                        child: child,
                      );
                    },
                    child: GradientButton(
                      text: 'Start Workout \uD83D\uDCAA',
                      icon: Icons.fitness_center,
                      onPressed: () async {
                        await Navigator.pushNamed(context, '/exercises');
                        _loadData();
                        // Re-animate counter when returning
                        _counterController.forward(from: 0);
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: _screenTime > 0
                          ? () async {
                              await Navigator.pushNamed(context, '/timer');
                              _loadData();
                              _counterController.forward(from: 0);
                            }
                          : null,
                      icon: Icon(
                        Icons.play_arrow_rounded,
                        color: _screenTime > 0 ? const Color(0xFF6C63FF) : Colors.white24,
                      ),
                      label: Text(
                        _screenTime > 0 ? 'Use Screen Time \u25B6' : 'No Time Available',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: _screenTime > 0 ? const Color(0xFF6C63FF) : Colors.white24,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _screenTime > 0
                              ? const Color(0xFF6C63FF).withValues(alpha: 0.5)
                              : Colors.white12,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              )),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF6C63FF), size: 24),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5))),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning \u2600\uFE0F';
    if (hour < 17) return 'Good afternoon \uD83D\uDC4B';
    return 'Good evening \uD83C\uDF19';
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _counterController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}
