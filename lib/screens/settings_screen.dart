import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/sound_haptic_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  // Settings state
  bool _soundEnabled = true;
  bool _hapticEnabled = true;
  bool _parentalEnabled = false;
  int _dailyLimit = 60;
  int _minReps = 10;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _soundEnabled = StorageService.soundEnabled;
      _hapticEnabled = StorageService.hapticEnabled;
      _parentalEnabled = StorageService.parentalControlsEnabled;
      _dailyLimit = StorageService.dailyScreenTimeLimit;
      _minReps = StorageService.minRepsRequired;
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleSound(bool val) async {
    await StorageService.setSoundEnabled(val);
    SoundHapticService.setSoundEnabled(val);
    setState(() => _soundEnabled = val);
  }

  Future<void> _toggleHaptic(bool val) async {
    await StorageService.setHapticEnabled(val);
    SoundHapticService.setHapticEnabled(val);
    setState(() => _hapticEnabled = val);
    if (val) SoundHapticService.selectionClick();
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16162A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Log Out?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will clear all local data including your reps, streaks, and profiles. This cannot be undone.',
          style: TextStyle(color: Color(0xFFB0AECC)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6C63FF))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out',
                style: TextStyle(color: Color(0xFFFF4081))),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await StorageService.clear();
      Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (_) => false);
    }
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16162A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF9D4EDD)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.fitness_center,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('RepScreen',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version 1.0.0',
                style: TextStyle(
                    color: Color(0xFF6C63FF), fontWeight: FontWeight.w600)),
            SizedBox(height: 12),
            Text(
              'Earn your screen time through exercise.\nPowered by AI pose detection.',
              style: TextStyle(color: Color(0xFFB0AECC), height: 1.5),
            ),
            SizedBox(height: 16),
            Text('Built with 💪 and Flutter.',
                style: TextStyle(color: Color(0xFF888899))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close',
                style: TextStyle(color: Color(0xFF6C63FF))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            // ── App Bar ──
            SliverAppBar(
              backgroundColor: const Color(0xFF0A0A1A),
              surfaceTintColor: Colors.transparent,
              expandedHeight: 100,
              floating: false,
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding:
                    const EdgeInsets.only(left: 56, bottom: 16),
                title: const Text(
                  'Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // ── Feedback Section ──
                    _sectionHeader('Feedback', Icons.vibration),
                    _settingsCard([
                      _toggleTile(
                        icon: Icons.volume_up_rounded,
                        iconColor: const Color(0xFF6C63FF),
                        title: 'Sound Effects',
                        subtitle: 'Rep ticks, set complete, timer alerts',
                        value: _soundEnabled,
                        onChanged: _toggleSound,
                      ),
                      _divider(),
                      _toggleTile(
                        icon: Icons.vibration_rounded,
                        iconColor: const Color(0xFF00E676),
                        title: 'Haptic Feedback',
                        subtitle: 'Vibrations on reps and milestones',
                        value: _hapticEnabled,
                        onChanged: _toggleHaptic,
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // ── Workout Defaults Section ──
                    _sectionHeader('Workout Defaults', Icons.tune_rounded),
                    _settingsCard([
                      _stepperTile(
                        icon: Icons.repeat_rounded,
                        iconColor: const Color(0xFFFF6B35),
                        title: 'Min Reps to Earn Time',
                        subtitle: 'Reps needed per exercise set',
                        value: _minReps,
                        min: 5,
                        max: 50,
                        step: 5,
                        onChanged: (v) async {
                          await StorageService.setMinRepsRequired(v);
                          setState(() => _minReps = v);
                        },
                      ),
                      _divider(),
                      _stepperTile(
                        icon: Icons.timer_rounded,
                        iconColor: const Color(0xFF00BCD4),
                        title: 'Daily Screen Time Limit',
                        subtitle: 'Max minutes per day (parental)',
                        value: _dailyLimit,
                        min: 15,
                        max: 240,
                        step: 15,
                        suffix: 'min',
                        onChanged: (v) async {
                          await StorageService.setDailyScreenTimeLimit(v);
                          setState(() => _dailyLimit = v);
                        },
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // ── Data Section ──
                    _sectionHeader('Data & Account', Icons.manage_accounts_rounded),
                    _settingsCard([
                      _navTile(
                        icon: Icons.people_alt_rounded,
                        iconColor: const Color(0xFF9D4EDD),
                        title: 'Manage Profiles',
                        subtitle: 'Add, edit, or remove family profiles',
                        onTap: () => Navigator.pushNamed(context, '/profiles'),
                      ),
                      _divider(),
                      _navTile(
                        icon: Icons.shield_rounded,
                        iconColor: const Color(0xFFFFD700),
                        title: 'Parental Controls',
                        subtitle: 'PIN lock, app blocking, daily limits',
                        onTap: () => Navigator.pushNamed(context, '/parental'),
                      ),
                      _divider(),
                      _navTile(
                        icon: Icons.logout_rounded,
                        iconColor: const Color(0xFFFF4081),
                        title: 'Log Out & Clear Data',
                        subtitle: 'Removes all local data permanently',
                        onTap: _confirmLogout,
                        trailing: const Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFFF4081), size: 18),
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // ── About Section ──
                    _sectionHeader('About', Icons.info_outline_rounded),
                    _settingsCard([
                      _navTile(
                        icon: Icons.fitness_center_rounded,
                        iconColor: const Color(0xFF6C63FF),
                        title: 'About RepScreen',
                        subtitle: 'Version 1.0.0',
                        onTap: _showAbout,
                      ),
                    ]),

                    const SizedBox(height: 48),

                    // ── Bottom branding ──
                    Center(
                      child: Column(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFF6C63FF), Color(0xFF9D4EDD)],
                            ).createShader(bounds),
                            child: const Text(
                              '💪 RepScreen',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Earn your screen time.',
                            style: TextStyle(
                              color: Color(0xFF555570),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helper Builders ────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6C63FF), size: 16),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF6C63FF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E1E3A), width: 1),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() {
    return const Divider(
      height: 1,
      indent: 60,
      endIndent: 16,
      color: Color(0xFF1E1E3A),
    );
  }

  Widget _toggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _iconBadge(icon, iconColor),
      title: Text(title,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Color(0xFF888899), fontSize: 12)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF6C63FF),
        activeTrackColor: const Color(0xFF6C63FF).withValues(alpha: 0.3),
        inactiveTrackColor: const Color(0xFF1E1E3A),
        inactiveThumbColor: const Color(0xFF555570),
      ),
    );
  }

  Widget _stepperTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required int value,
    required int min,
    required int max,
    required int step,
    required ValueChanged<int> onChanged,
    String suffix = '',
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _iconBadge(icon, iconColor),
      title: Text(title,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Color(0xFF888899), fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(
            icon: Icons.remove,
            onTap: value > min
                ? () => onChanged(value - step)
                : null,
          ),
          SizedBox(
            width: 52,
            child: Text(
              '$value${suffix.isNotEmpty ? ' $suffix' : ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _stepBtn(
            icon: Icons.add,
            onTap: value < max ? () => onChanged(value + step) : null,
          ),
        ],
      ),
    );
  }

  Widget _stepBtn({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: onTap != null
              ? const Color(0xFF1E1E3A)
              : const Color(0xFF0F0F20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: onTap != null ? Colors.white : const Color(0xFF333350),
          size: 16,
        ),
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _iconBadge(icon, iconColor),
      title: Text(title,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Color(0xFF888899), fontSize: 12)),
      trailing: trailing ??
          const Icon(Icons.chevron_right_rounded,
              color: Color(0xFF555570)),
      onTap: onTap,
    );
  }

  Widget _iconBadge(IconData icon, Color color) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
