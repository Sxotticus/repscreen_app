import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import 'screens/stats_screen.dart';
import 'screens/profiles_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'services/storage_service.dart';
import 'services/supabase_service.dart';
import 'services/sound_haptic_service.dart';
import 'utils/page_transitions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await StorageService.init();
  SoundHapticService.setSoundEnabled(StorageService.soundEnabled);
  SoundHapticService.setHapticEnabled(StorageService.hapticEnabled);
  await StorageService.resetWeeklyIfNeeded();
  runApp(const RepScreenApp());
}

class RepScreenApp extends StatelessWidget {
  const RepScreenApp({super.key});

  static String _getInitialRoute() {
    // If the user has an active Supabase session, go straight to home.
    if (SupabaseService.currentSession != null) return '/home';
    // Otherwise check if onboarding has been seen.
    return StorageService.hasSeenOnboarding ? '/login' : '/onboarding';
  }

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
      initialRoute: _getInitialRoute(),
      onGenerateRoute: (settings) {
        final routes = <String, Widget Function()>{
          '/onboarding': () => const OnboardingScreen(),
          '/login': () => const LoginScreen(),
          '/signup': () => const SignupScreen(),
          '/home': () => const HomeScreen(),
          '/exercises': () => const ExerciseSelectScreen(),
          '/earn': () => const EarnTimeScreen(),
          '/timer': () => const TimerScreen(),
          '/streaks': () => const StreaksScreen(),
          '/parental': () => const ParentalControlsScreen(),
          '/camera_exercise': () => const CameraExerciseScreen(),
          '/blocked_apps': () => const BlockedAppsScreen(),
          '/stats': () => const StatsScreen(),
          '/profiles': () => const ProfilesScreen(),
          '/leaderboard': () => const LeaderboardScreen(),
          '/settings': () => const SettingsScreen(),
        };

        final builder = routes[settings.name];
        if (builder == null) return null;

        // Use custom transitions for all routes
        return SlideUpRoute(page: builder());
      },
    );
  }
}
