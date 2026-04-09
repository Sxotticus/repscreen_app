import 'package:flutter/material.dart';
import '../services/screen_time_service.dart';
import '../services/storage_service.dart';

class BlockedAppsScreen extends StatefulWidget {
  const BlockedAppsScreen({super.key});

  @override
  State<BlockedAppsScreen> createState() => _BlockedAppsScreenState();
}

class _BlockedAppsScreenState extends State<BlockedAppsScreen>
    with WidgetsBindingObserver {
  List<Map<String, String>> _apps = [];
  Set<String> _selected = {};
  bool _loading = true;
  bool _hasUsage = false;
  bool _hasOverlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selected = StorageService.blockedApps.toSet();
    _checkAndLoad();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check permissions when user returns from Settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkAndLoad();
  }

  Future<void> _checkAndLoad() async {
    try {
      _hasUsage = await ScreenTimeBlockingService.hasUsagePermission();
      _hasOverlay = await ScreenTimeBlockingService.hasOverlayPermission();
      if (_hasUsage && _hasOverlay) {
        final apps = await ScreenTimeBlockingService.getInstalledApps();
        setState(() {
          _apps = apps;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    await StorageService.setBlockedApps(_selected.toList());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_selected.length} app${_selected.length == 1 ? '' : 's'} will be blocked when time runs out',
          ),
          backgroundColor: const Color(0xFF6C63FF),
        ),
      );
      Navigator.pop(context);
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ UI â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            if (_loading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                ),
              )
            else if (!_hasUsage || !_hasOverlay)
              _permissionSetup()
            else
              _appList(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Blocked Apps',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          TextButton(
            onPressed: _save,
            child: Text(
              'Save',
              style: TextStyle(
                color: _selected.isNotEmpty
                    ? const Color(0xFF6C63FF)
                    : Colors.white38,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ permission cards â”€â”€â”€

  Widget _permissionSetup() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('\uD83D\uDD12', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 20),
            const Text(
              'Permissions Needed',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'RepScreen needs two permissions to block apps\nwhen your screen time runs out.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 32),
            _permissionCard(
              title: 'Usage Access',
              subtitle: 'Detect which app is open',
              granted: _hasUsage,
              onTap: () =>
                  ScreenTimeBlockingService.requestUsagePermission(),
            ),
            const SizedBox(height: 12),
            _permissionCard(
              title: 'Display Over Apps',
              subtitle: 'Show blocking screen over restricted apps',
              granted: _hasOverlay,
              onTap: () =>
                  ScreenTimeBlockingService.requestOverlayPermission(),
            ),
            const SizedBox(height: 24),
            Text(
              'After granting each permission, come back here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _permissionCard({
    required String title,
    required String subtitle,
    required bool granted,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: granted ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: granted
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: granted
                ? Colors.green.withValues(alpha: 0.3)
                : const Color(0xFF6C63FF).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              granted ? Icons.check_circle : Icons.lock_outline,
              color: granted ? Colors.green : const Color(0xFF6C63FF),
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5))),
                ],
              ),
            ),
            if (!granted)
              const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ app list â”€â”€â”€

  Widget _appList() {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Column(
              children: [
                Text(
                  'Select apps to block when screen time expires',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_selected.length} app${_selected.length == 1 ? '' : 's'} selected',
                    style: const TextStyle(
                      color: Color(0xFF6C63FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _apps.length,
              itemBuilder: (_, i) {
                final app = _apps[i];
                final pkg = app['package'] ?? '';
                final name = app['name'] ?? pkg;
                final on = _selected.contains(pkg);
                return ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                  title: Text(name,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 15)),
                  subtitle: Text(pkg,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.3)),
                      overflow: TextOverflow.ellipsis),
                  trailing: Checkbox(
                    value: on,
                    activeColor: const Color(0xFF6C63FF),
                    onChanged: (_) => _toggle(pkg),
                  ),
                  onTap: () => _toggle(pkg),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _toggle(String pkg) {
    setState(() {
      if (_selected.contains(pkg)) {
        _selected.remove(pkg);
      } else {
        _selected.add(pkg);
      }
    });
  }
}