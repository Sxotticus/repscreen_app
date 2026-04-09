import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';

class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  List<UserProfile> _profiles = [];
  String _activeId = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _profiles = StorageService.profiles;
      _activeId = StorageService.activeProfileId;
    });
  }

  void _switchProfile(String id) async {
    await StorageService.setActiveProfileId(id);
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to ${_profiles.firstWhere((p) => p.id == id).name}'),
          backgroundColor: const Color(0xFF6C63FF),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _addProfile() {
    final nameCtrl = TextEditingController();
    String selectedAvatar = UserProfile.avatars[0];
    int selectedColor = UserProfile.profileColors[0];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              const Text('Add Family Member', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 20),

              // Avatar picker
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Pick an avatar', style: TextStyle(fontSize: 13, color: Colors.white54)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: UserProfile.avatars.length,
                  itemBuilder: (ctx, i) {
                    final a = UserProfile.avatars[i];
                    final selected = a == selectedAvatar;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedAvatar = a),
                      child: Container(
                        width: 46, height: 46,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFF6C63FF).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: selected ? Border.all(color: const Color(0xFF6C63FF), width: 2) : null,
                        ),
                        child: Center(child: Text(a, style: const TextStyle(fontSize: 22))),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Color picker
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Pick a color', style: TextStyle(fontSize: 13, color: Colors.white54)),
              ),
              const SizedBox(height: 8),
              Row(
                children: UserProfile.profileColors.map((c) {
                  final selected = c == selectedColor;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedColor = c),
                    child: Container(
                      width: 36, height: 36,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: selected ? Border.all(color: Colors.white, width: 3) : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Name field
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Name (e.g. Mom, Dad, Alex...)',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Add button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final id = DateTime.now().millisecondsSinceEpoch.toString();
                    final profile = UserProfile(
                      id: id,
                      name: name,
                      avatar: selectedAvatar,
                      colorValue: selectedColor,
                    );
                    await StorageService.addProfile(profile);
                    _load();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Add Member', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteProfile(UserProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Remove Member?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove ${profile.name}? Their stats will be lost.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              await StorageService.removeProfile(profile.id);
              _load();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      'Family Members',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Tap a profile to switch, swipe to remove',
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Profiles list
              Expanded(
                child: _profiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('\uD83D\uDC68\u200D\uD83D\uDC69\u200D\uD83D\uDC67\u200D\uD83D\uDC66',
                                style: const TextStyle(fontSize: 48)),
                            const SizedBox(height: 16),
                            const Text('No family members yet', style: TextStyle(fontSize: 16, color: Colors.white54)),
                            const SizedBox(height: 4),
                            Text('Add members to compete!',
                                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4))),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _profiles.length,
                        itemBuilder: (ctx, i) {
                          final p = _profiles[i];
                          final isActive = p.id == _activeId;
                          final color = Color(p.colorValue);

                          return Dismissible(
                            key: Key(p.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.delete, color: Colors.red),
                            ),
                            confirmDismiss: (_) async {
                              _deleteProfile(p);
                              return false;
                            },
                            child: GestureDetector(
                              onTap: () => _switchProfile(p.id),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: isActive
                                      ? LinearGradient(
                                          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.08)])
                                      : null,
                                  color: isActive ? null : Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isActive ? color.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08),
                                    width: isActive ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50, height: 50,
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Center(child: Text(p.avatar, style: const TextStyle(fontSize: 26))),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                                              if (isActive) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: color.withValues(alpha: 0.3),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text('Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${p.totalReps} reps \u00b7 ${p.totalSessions} sessions',
                                            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        Text('${p.weeklyReps}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                                        Text('this week', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Leaderboard button
              if (_profiles.length >= 2) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/leaderboard'),
                    icon: const Icon(Icons.emoji_events, color: Color(0xFFFFD700)),
                    label: const Text('View Leaderboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFFD700), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Add member button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _addProfile,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Family Member', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
