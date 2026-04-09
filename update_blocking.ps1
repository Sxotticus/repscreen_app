# RepScreen v4 - Screen Time Blocking Update
# Run from C:\pushscroll_app
Write-Host "Installing Screen Time Blocking feature..." -ForegroundColor Cyan
Write-Host ""
Write-Host "Creating android\app\src\main\kotlin\com\pushscroll\pushscroll_app\ScreenTimeService.kt..." -ForegroundColor Yellow
$content = @'
package com.pushscroll.pushscroll_app

import android.app.*
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.*
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import java.util.*

class ScreenTimeService : Service() {

    companion object {
        const val CHANNEL_ID = "repscreen_timer"
        const val NOTIFICATION_ID = 1001
    }

    private var remainingSeconds = 0
    private var blockedPackages = listOf<String>()
    private var timer: Timer? = null
    private var overlayView: View? = null
    private var windowManager: WindowManager? = null
    private var isOverlayShowing = false
    private val handler = Handler(Looper.getMainLooper())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START" -> {
                remainingSeconds = intent.getIntExtra("seconds", 0)
                blockedPackages =
                    intent.getStringArrayListExtra("blocked") ?: listOf()
                startForeground(NOTIFICATION_ID, buildNotification())
                startTimer()
            }
            "STOP" -> {
                stopTimer()
                hideOverlay()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_STICKY
    }

    /* ── notification channel ── */

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Screen Time Timer",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows remaining screen time"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val mins = remainingSeconds / 60
        val secs = remainingSeconds % 60
        val text =
            if (remainingSeconds > 0) String.format("Screen time: %d:%02d remaining", mins, secs)
            else "Screen time is up! Exercise to earn more."

        val pi = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("RepScreen")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setOngoing(true)
            .setContentIntent(pi)
            .setSilent(true)
            .build()
    }

    /* ── timer ── */

    private fun startTimer() {
        timer?.cancel()
        timer = Timer()
        timer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                if (remainingSeconds > 0) {
                    remainingSeconds--
                    updateNotification()
                }
                if (remainingSeconds <= 0 && blockedPackages.isNotEmpty()) {
                    checkForegroundApp()
                }
            }
        }, 1000, 1000)
    }

    private fun stopTimer() {
        timer?.cancel()
        timer = null
    }

    private fun updateNotification() {
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, buildNotification())
    }

    /* ── foreground-app check ── */

    private fun checkForegroundApp() {
        try {
            val usm =
                getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()
            val stats = usm.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY, now - 10_000, now
            )
            if (stats != null && stats.isNotEmpty()) {
                val current = stats.maxByOrNull { it.lastTimeUsed }?.packageName
                if (current != null && blockedPackages.contains(current)) {
                    handler.post { showOverlay() }
                } else {
                    handler.post { hideOverlay() }
                }
            }
        } catch (_: Exception) {
            // permission may not be granted
        }
    }

    /* ── overlay ── */

    private fun dp(value: Int): Int =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, value.toFloat(),
            resources.displayMetrics
        ).toInt()

    private fun showOverlay() {
        if (isOverlayShowing || !Settings.canDrawOverlays(this)) return

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#F2080818"))
            setPadding(dp(40), dp(60), dp(40), dp(60))
        }

        val emoji = TextView(this).apply {
            text = "\u23F0"
            textSize = 56f
            gravity = Gravity.CENTER
        }

        val title = TextView(this).apply {
            text = "Screen Time\u2019s Up!"
            textSize = 28f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(0, dp(24), 0, dp(10))
            typeface = Typeface.DEFAULT_BOLD
        }

        val sub = TextView(this).apply {
            text = "Do some reps to earn more screen time!"
            textSize = 15f
            setTextColor(Color.parseColor("#99FFFFFF"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(36))
        }

        val btn = TextView(this).apply {
            text = "\uD83D\uDCAA  Exercise Now"
            textSize = 18f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(dp(32), dp(16), dp(32), dp(16))
            setBackgroundColor(Color.parseColor("#6C63FF"))
            setOnClickListener {
                startActivity(
                    Intent(this@ScreenTimeService, MainActivity::class.java).apply {
                        flags =
                            Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                )
                hideOverlay()
            }
        }

        root.addView(emoji)
        root.addView(title)
        root.addView(sub)
        root.addView(btn)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )

        try {
            windowManager?.addView(root, params)
            overlayView = root
            isOverlayShowing = true
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun hideOverlay() {
        if (!isOverlayShowing || overlayView == null) return
        try { windowManager?.removeView(overlayView) } catch (_: Exception) {}
        overlayView = null
        isOverlayShowing = false
    }

    override fun onDestroy() {
        stopTimer()
        hideOverlay()
        super.onDestroy()
    }
}
'@
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$PWD\android\app\src\main\kotlin\com\pushscroll\pushscroll_app\ScreenTimeService.kt", $content, $utf8)

Write-Host "Updating android\app\src\main\kotlin\com\pushscroll\pushscroll_app\MainActivity.kt..." -ForegroundColor Yellow
$content = @'
package com.pushscroll.pushscroll_app

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.repscreen/blocking"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> result.success(getInstalledApps())

                    "hasUsagePermission" -> result.success(hasUsagePermission())
                    "requestUsagePermission" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(true)
                    }

                    "hasOverlayPermission" ->
                        result.success(Settings.canDrawOverlays(this))
                    "requestOverlayPermission" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                        )
                        result.success(true)
                    }

                    "startBlocking" -> {
                        val secs = call.argument<Int>("seconds") ?: 0
                        val apps =
                            call.argument<List<String>>("apps") ?: listOf()
                        val intent =
                            Intent(this, ScreenTimeService::class.java).apply {
                                action = "START"
                                putExtra("seconds", secs)
                                putStringArrayListExtra(
                                    "blocked", ArrayList(apps)
                                )
                            }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                            startForegroundService(intent)
                        else startService(intent)
                        result.success(true)
                    }

                    "stopBlocking" -> {
                        startService(
                            Intent(this, ScreenTimeService::class.java)
                                .apply { action = "STOP" }
                        )
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /* ── helpers ── */

    private fun getInstalledApps(): List<Map<String, String>> {
        val pm = packageManager
        val intent =
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return pm.queryIntentActivities(intent, 0)
            .map {
                mapOf(
                    "package" to it.activityInfo.packageName,
                    "name" to it.loadLabel(pm).toString()
                )
            }
            .filter { it["package"] != packageName }
            .sortedBy { it["name"]?.lowercase() }
    }

    private fun hasUsagePermission(): Boolean {
        val appOps =
            getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        return appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(), packageName
        ) == AppOpsManager.MODE_ALLOWED
    }
}
'@
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$PWD\android\app\src\main\kotlin\com\pushscroll\pushscroll_app\MainActivity.kt", $content, $utf8)

Write-Host "Creating lib\services\screen_time_service.dart..." -ForegroundColor Yellow
$content = @'
import 'package:flutter/services.dart';

/// Talks to native Android code for app-blocking & screen-time enforcement.
class ScreenTimeBlockingService {
  static const _ch = MethodChannel('com.repscreen/blocking');

  /// Returns list of launchable apps [{package, name}, ...]
  static Future<List<Map<String, String>>> getInstalledApps() async {
    final result = await _ch.invokeMethod('getInstalledApps');
    return (result as List)
        .map((e) => Map<String, String>.from(e as Map))
        .toList();
  }

  // ── permissions ──

  static Future<bool> hasUsagePermission() async =>
      await _ch.invokeMethod('hasUsagePermission') as bool;

  static Future<void> requestUsagePermission() =>
      _ch.invokeMethod('requestUsagePermission');

  static Future<bool> hasOverlayPermission() async =>
      await _ch.invokeMethod('hasOverlayPermission') as bool;

  static Future<void> requestOverlayPermission() =>
      _ch.invokeMethod('requestOverlayPermission');

  // ── service control ──

  /// Start the background timer + blocking service.
  static Future<void> startBlocking({
    required int seconds,
    required List<String> blockedApps,
  }) =>
      _ch.invokeMethod('startBlocking', {
        'seconds': seconds,
        'apps': blockedApps,
      });

  /// Stop the blocking service.
  static Future<void> stopBlocking() => _ch.invokeMethod('stopBlocking');
}
'@
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$PWD\lib\services\screen_time_service.dart", $content, $utf8)

Write-Host "Creating lib\screens\blocked_apps_screen.dart..." -ForegroundColor Yellow
$content = @'
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

  // ─────────────────────────── UI ───────────────────────────

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

  // ─── permission cards ───

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

  // ─── app list ───

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
'@
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$PWD\lib\screens\blocked_apps_screen.dart", $content, $utf8)

Write-Host "Updating lib\services\storage_service.dart..." -ForegroundColor Yellow
$content = @'
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Screen time balance in minutes
  static int get screenTimeMinutes => _prefs.getInt('screen_time') ?? 0;
  static Future<void> setScreenTimeMinutes(int minutes) async {
    await _prefs.setInt('screen_time', minutes);
  }

  // Total reps completed (lifetime)
  static int get totalPushups => _prefs.getInt('total_pushups') ?? 0;
  static Future<void> setTotalPushups(int count) async {
    await _prefs.setInt('total_pushups', count);
  }

  // Total sessions completed
  static int get totalSessions => _prefs.getInt('total_sessions') ?? 0;
  static Future<void> setTotalSessions(int count) async {
    await _prefs.setInt('total_sessions', count);
  }

  // User logged in state
  static bool get isLoggedIn => _prefs.getBool('logged_in') ?? false;
  static Future<void> setLoggedIn(bool value) async {
    await _prefs.setBool('logged_in', value);
  }

  // User email
  static String get userEmail => _prefs.getString('user_email') ?? '';
  static Future<void> setUserEmail(String email) async {
    await _prefs.setString('user_email', email);
  }

  // ── Streaks ──
  static int get currentStreak => _prefs.getInt('current_streak') ?? 0;
  static Future<void> setCurrentStreak(int days) async {
    await _prefs.setInt('current_streak', days);
  }

  static int get bestStreak => _prefs.getInt('best_streak') ?? 0;
  static Future<void> setBestStreak(int days) async {
    await _prefs.setInt('best_streak', days);
  }

  static String get lastWorkoutDate => _prefs.getString('last_workout_date') ?? '';
  static Future<void> setLastWorkoutDate(String date) async {
    await _prefs.setString('last_workout_date', date);
  }

  static Future<void> updateStreak() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = lastWorkoutDate;

    if (lastDate == today) return; // Already worked out today

    final yesterday = DateTime.now().subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);

    if (lastDate == yesterday) {
      // Continue streak
      final newStreak = currentStreak + 1;
      await setCurrentStreak(newStreak);
      if (newStreak > bestStreak) await setBestStreak(newStreak);
    } else {
      // Streak broken, start fresh
      await setCurrentStreak(1);
      if (1 > bestStreak) await setBestStreak(1);
    }
    await setLastWorkoutDate(today);
  }

  // ── Exercise Stats ──
  static int getExerciseCount(String exercise) =>
      _prefs.getInt('exercise_$exercise') ?? 0;
  static Future<void> addExerciseCount(String exercise, int count) async {
    final current = getExerciseCount(exercise);
    await _prefs.setInt('exercise_$exercise', current + count);
  }

  // ── Custom Exercises ──
  static List<String> get customExercises {
    final data = _prefs.getString('custom_exercises');
    if (data == null) return [];
    return List<String>.from(json.decode(data));
  }
  static Future<void> setCustomExercises(List<String> exercises) async {
    await _prefs.setString('custom_exercises', json.encode(exercises));
  }

  // ── Challenges ──
  static int get dailyChallengeProgress => _prefs.getInt('daily_challenge_progress') ?? 0;
  static Future<void> setDailyChallengeProgress(int count) async {
    await _prefs.setInt('daily_challenge_progress', count);
  }

  static String get dailyChallengeDate => _prefs.getString('daily_challenge_date') ?? '';
  static Future<void> setDailyChallengeDate(String date) async {
    await _prefs.setString('daily_challenge_date', date);
  }

  static int get challengesCompleted => _prefs.getInt('challenges_completed') ?? 0;
  static Future<void> setChallengesCompleted(int count) async {
    await _prefs.setInt('challenges_completed', count);
  }

  // ── Parental Controls ──
  static bool get parentalControlsEnabled => _prefs.getBool('parental_enabled') ?? false;
  static Future<void> setParentalControlsEnabled(bool value) async {
    await _prefs.setBool('parental_enabled', value);
  }

  static String get parentalPin => _prefs.getString('parental_pin') ?? '';
  static Future<void> setParentalPin(String pin) async {
    await _prefs.setString('parental_pin', pin);
  }

  static int get dailyScreenTimeLimit => _prefs.getInt('daily_limit') ?? 60;
  static Future<void> setDailyScreenTimeLimit(int minutes) async {
    await _prefs.setInt('daily_limit', minutes);
  }

  static int get minRepsRequired => _prefs.getInt('min_reps_required') ?? 10;
  static Future<void> setMinRepsRequired(int reps) async {
    await _prefs.setInt('min_reps_required', reps);
  }

  static int get dailyScreenTimeUsed => _prefs.getInt('daily_used') ?? 0;
  static Future<void> setDailyScreenTimeUsed(int minutes) async {
    await _prefs.setInt('daily_used', minutes);
  }

  // ── Blocked Apps ──
  static List<String> get blockedApps {
    final data = _prefs.getString('blocked_apps');
    if (data == null) return [];
    return List<String>.from(json.decode(data));
  }

  static Future<void> setBlockedApps(List<String> apps) async {
    await _prefs.setString('blocked_apps', json.encode(apps));
  }

  // Clear all data (logout)
  static Future<void> clear() async {
    await _prefs.clear();
  }
}
'@
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$PWD\lib\services\storage_service.dart", $content, $utf8)

Write-Host "Updating lib\screens\home_screen.dart..." -ForegroundColor Yellow
$content = @'
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../widgets/gradient_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _screenTime = 0;
  int _totalPushups = 0;
  int _totalSessions = 0;
  int _currentStreak = 0;
  int _blockedAppsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
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

              // Header
              Row(
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
                        icon: const Icon(Icons.settings, color: Colors.white54),
                        onPressed: () async {
                          await Navigator.pushNamed(context, '/parental');
                          _loadData();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white54),
                        onPressed: () async {
                          await StorageService.clear();
                          if (mounted) {
                            Navigator.pushReplacementNamed(context, '/login');
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Screen Time Card
              Container(
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
                          '$_screenTime',
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
              ),
              const SizedBox(height: 20),

              // Streak Banner
              GestureDetector(
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
                          ? [
                              const Color(0xFFFF6B35),
                              const Color(0xFFFF9F1C)
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.08),
                              Colors.white.withValues(alpha: 0.04)
                            ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: _currentStreak < 7
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.08))
                        : null,
                  ),
                  child: Row(
                    children: [
                      const Text('\uD83D\uDD25',
                          style: TextStyle(fontSize: 28)),
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
                                color: _currentStreak >= 7
                                    ? Colors.white70
                                    : Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: _currentStreak >= 7
                              ? Colors.white70
                              : Colors.white38),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Stats Row
              Row(
                children: [
                  Expanded(
                      child: _buildStatCard(
                          'Total\nReps', '$_totalPushups', Icons.fitness_center)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildStatCard('Sessions', '$_totalSessions',
                          Icons.check_circle_outline)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildStatCard(
                          'Challenges',
                          '${StorageService.challengesCompleted}',
                          Icons.emoji_events)),
                ],
              ),
              const SizedBox(height: 20),

              // ── App Blocking Card ──
              GestureDetector(
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
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield,
                          color: _blockedAppsCount > 0
                              ? const Color(0xFF6C63FF)
                              : Colors.white38,
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
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Colors.white.withValues(alpha: 0.4)),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: Colors.white.withValues(alpha: 0.3)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              GradientButton(
                text: 'Start Workout \uD83D\uDCAA',
                icon: Icons.fitness_center,
                onPressed: () async {
                  await Navigator.pushNamed(context, '/exercises');
                  _loadData();
                },
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
                        }
                      : null,
                  icon: Icon(
                    Icons.play_arrow_rounded,
                    color: _screenTime > 0
                        ? const Color(0xFF6C63FF)
                        : Colors.white24,
                  ),
                  label: Text(
                    _screenTime > 0
                        ? 'Use Screen Time \u25B6'
                        : 'No Time Available',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _screenTime > 0
                          ? const Color(0xFF6C63FF)
                          : Colors.white24,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _screenTime > 0
                          ? const Color(0xFF6C63FF).withValues(alpha: 0.5)
                          : Colors.white12,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
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
}
'@
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$PWD\lib\screens\home_screen.dart", $content, $utf8)

Write-Host "Updating lib\screens\timer_screen.dart..." -ForegroundColor Yellow
$content = @'
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import '../services/storage_service.dart';
import '../services/screen_time_service.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  late int _totalSeconds;
  late int _remainingSeconds;
  Timer? _timer;
  bool _isRunning = false;
  bool _timeUp = false;
  List<String> _blockedApps = [];
  bool _blockingActive = false;

  @override
  void initState() {
    super.initState();
    _totalSeconds = StorageService.screenTimeMinutes * 60;
    _remainingSeconds = _totalSeconds;
    _blockedApps = StorageService.blockedApps;
  }

  void _startTimer() {
    setState(() => _isRunning = true);

    // Start native blocking service in the background
    if (_blockedApps.isNotEmpty) {
      ScreenTimeBlockingService.startBlocking(
        seconds: _remainingSeconds,
        blockedApps: _blockedApps,
      );
      setState(() => _blockingActive = true);
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0) {
        _timer?.cancel();
        _onTimeUp();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);

    // Stop native blocking while paused
    if (_blockingActive) {
      ScreenTimeBlockingService.stopBlocking();
      setState(() => _blockingActive = false);
    }

    _saveRemainingTime();
  }

  void _onTimeUp() async {
    await StorageService.setScreenTimeMinutes(0);
    setState(() {
      _isRunning = false;
      _timeUp = true;
    });
    // Native service keeps running — it will overlay blocked apps
  }

  void _saveRemainingTime() async {
    final remainingMinutes = (_remainingSeconds / 60).ceil();
    await StorageService.setScreenTimeMinutes(remainingMinutes);
  }

  String _formatTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double get _progress =>
      _totalSeconds > 0 ? _remainingSeconds / _totalSeconds : 0;

  Color get _timerColor {
    if (_timeUp) return Colors.red;
    if (_remainingSeconds < 60) return Colors.orange;
    return const Color(0xFF6C63FF);
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
                    icon: const Icon(Icons.arrow_back_ios,
                        color: Colors.white70),
                    onPressed: () {
                      if (_isRunning) _pauseTimer();
                      if (!_timeUp) _saveRemainingTime();
                      Navigator.pop(context);
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'Screen Time',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 40),

              // Blocking status badge
              if (_blockedApps.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _blockingActive
                        ? const Color(0xFF6C63FF).withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _blockingActive
                          ? const Color(0xFF6C63FF).withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _blockingActive ? Icons.shield : Icons.shield_outlined,
                        size: 16,
                        color: _blockingActive
                            ? const Color(0xFF6C63FF)
                            : Colors.white38,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _blockingActive
                            ? '${_blockedApps.length} app${_blockedApps.length == 1 ? '' : 's'} blocking active'
                            : '${_blockedApps.length} app${_blockedApps.length == 1 ? '' : 's'} will be blocked',
                        style: TextStyle(
                          fontSize: 13,
                          color: _blockingActive
                              ? const Color(0xFF6C63FF)
                              : Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 30),

              // Timer display
              SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 260,
                      height: 260,
                      child: CircularProgressIndicator(
                        value: 1,
                        strokeWidth: 14,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      height: 260,
                      child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 14,
                        strokeCap: StrokeCap.round,
                        color: _timerColor,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _timeUp
                              ? '\u23F0'
                              : (_isRunning ? '\uD83D\uDCF1' : '\u23F8\uFE0F'),
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _timeUp
                              ? '00:00'
                              : _formatTime(_remainingSeconds),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: _timeUp ? Colors.red : Colors.white,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _timeUp
                              ? "Time's up!"
                              : (_isRunning ? 'Enjoy your time' : 'Paused'),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Status messages
              if (_timeUp) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "\u23F0 Time's Up!",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _blockedApps.isNotEmpty
                            ? 'Blocked apps are now restricted.\nDo more reps to earn screen time.'
                            : 'Do more reps to earn more screen time.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ] else if (!_isRunning &&
                  _remainingSeconds < _totalSeconds) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.orange, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Timer is paused. Your remaining time is saved.',
                          style:
                              TextStyle(color: Colors.orange, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Action buttons
              if (_timeUp) ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/exercises');
                    },
                    icon: const Icon(Icons.fitness_center),
                    label: const Text(
                      'Earn More Time',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: TextButton(
                    onPressed: () {
                      // Stop blocking service when going home
                      if (_blockingActive) {
                        ScreenTimeBlockingService.stopBlocking();
                      }
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Back to Home',
                      style:
                          TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? _pauseTimer : _startTimer,
                    icon: Icon(
                        _isRunning ? Icons.pause : Icons.play_arrow),
                    label: Text(
                      _isRunning ? 'Pause' : 'Start Timer',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRunning
                          ? Colors.orange
                          : const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (!_timeUp) _saveRemainingTime();
    super.dispose();
  }
}
'@
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$PWD\lib\screens\timer_screen.dart", $content, $utf8)

Write-Host "Updating lib\main.dart..." -ForegroundColor Yellow
$content = @'
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/earn_time_screen.dart';
import 'screens/timer_screen.dart';
import 'screens/exercise_select_screen.dart';
import 'screens/streaks_screen.dart';
import 'screens/parental_controls_screen.dart';
import 'screens/camera_exercise_screen.dart';
import 'screens/blocked_apps_screen.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  runApp(const RepScreenApp());
}

class RepScreenApp extends StatelessWidget {
  const RepScreenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RepScreen',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0A0A1A),
        fontFamily: 'Roboto',
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),
        '/exercises': (context) => const ExerciseSelectScreen(),
        '/earn': (context) => const EarnTimeScreen(),
        '/timer': (context) => const TimerScreen(),
        '/streaks': (context) => const StreaksScreen(),
        '/parental': (context) => const ParentalControlsScreen(),
        '/camera_exercise': (context) => const CameraExerciseScreen(),
        '/blocked_apps': (context) => const BlockedAppsScreen(),
      },
    );
  }
}
'@
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$PWD\lib\main.dart", $content, $utf8)

Write-Host "Updating android\app\src\main\AndroidManifest.xml..." -ForegroundColor Yellow
$content = @'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Camera for exercise detection -->
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-feature android:name="android.hardware.camera" android:required="false"/>
    <uses-feature android:name="android.hardware.camera.front" android:required="false"/>

    <!-- Screen-time blocking -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE"/>
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
    <uses-permission android:name="android.permission.PACKAGE_USAGE_STATS"
        tools:ignore="ProtectedPermissions"
        xmlns:tools="http://schemas.android.com/tools"/>

    <application
        android:label="RepScreen"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <!-- Screen-time blocking service -->
        <service
            android:name=".ScreenTimeService"
            android:exported="false"
            android:foregroundServiceType="specialUse"/>

        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>

    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
        <!-- For listing installed apps -->
        <intent>
            <action android:name="android.intent.action.MAIN"/>
            <category android:name="android.intent.category.LAUNCHER"/>
        </intent>
    </queries>
</manifest>
'@
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$PWD\android\app\src\main\AndroidManifest.xml", $content, $utf8)

Write-Host ""
Write-Host "All 9 files updated!" -ForegroundColor Green
Write-Host "Screen Time Blocking is ready to build." -ForegroundColor Green
Write-Host ""