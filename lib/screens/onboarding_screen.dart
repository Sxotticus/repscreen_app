import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  late final AnimationController _fadeCtrl;
  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceAnim;

  final _pages = const <_OnboardingPage>[
    _OnboardingPage(
      emoji: '\uD83D\uDCAA',
      title: 'Welcome to RepScreen',
      subtitle: 'Turn real exercise into\nearned screen time',
      description: 'The app that rewards you for\nstaying active and healthy',
      gradientColors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
    ),
    _OnboardingPage(
      emoji: '\uD83C\uDFCB\uFE0F',
      title: 'Do Real Reps',
      subtitle: 'Push-ups, squats, planks\nand more',
      description: 'Choose from 6 built-in exercises\nor create your own custom workouts',
      gradientColors: [Color(0xFFFF6B35), Color(0xFFFF8F00)],
    ),
    _OnboardingPage(
      emoji: '\uD83D\uDCF7',
      title: 'AI Counts For You',
      subtitle: 'Camera-powered rep\ndetection',
      description: 'Point your camera and our AI\nautomatically counts every rep',
      gradientColors: [Color(0xFF00E676), Color(0xFF00BFA5)],
    ),
    _OnboardingPage(
      emoji: '\u23F1\uFE0F',
      title: 'Earn Screen Time',
      subtitle: '10 reps = 10 minutes\nof screen time',
      description: 'A countdown timer tracks your\nearned time — stay motivated!',
      gradientColors: [Color(0xFFE040FB), Color(0xFF9C27B0)],
    ),
    _OnboardingPage(
      emoji: '\uD83D\uDD25',
      title: 'Compete & Streak',
      subtitle: 'Family leaderboards &\ndaily streaks',
      description: 'Challenge family members, track\nstats, and build an exercise habit',
      gradientColors: [Color(0xFFFFD700), Color(0xFFFF6B35)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _bounceAnim = Tween<double>(begin: 0, end: -12).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _fadeCtrl.dispose();
    _bounceCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() async {
    await StorageService.setHasSeenOnboarding(true);
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      body: Stack(
        children: [
          // Page View
          PageView.builder(
            controller: _pageCtrl,
            itemCount: _pages.length,
            onPageChanged: (i) {
              setState(() => _currentPage = i);
              _fadeCtrl.reset();
              _fadeCtrl.forward();
            },
            itemBuilder: (ctx, i) {
              final page = _pages[i];
              return FadeTransition(
                opacity: _fadeCtrl,
                child: _buildPage(page),
              );
            },
          ),

          // Top right skip button
          if (!isLastPage)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 20,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          // Bottom controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 50,
            child: Column(
              children: [
                // Dot indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (i) {
                    final active = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active
                            ? _pages[_currentPage].gradientColors[0]
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),

                // Next / Get Started button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: AnimatedBuilder(
                    animation: _bounceAnim,
                    builder: (ctx, child) => Transform.translate(
                      offset: Offset(0, isLastPage ? _bounceAnim.value : 0),
                      child: child,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _pages[_currentPage].gradientColors,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _pages[_currentPage].gradientColors[0].withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isLastPage ? "Let's Go!" : 'Next',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (!isLastPage) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded,
                                    color: Colors.white, size: 22),
                              ],
                              if (isLastPage) ...[
                                const SizedBox(width: 8),
                                const Text('\uD83D\uDE80',
                                    style: TextStyle(fontSize: 20)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            page.gradientColors[0].withValues(alpha: 0.15),
            const Color(0xFF0A0A1A),
            const Color(0xFF0A0A1A),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            // Big emoji
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: page.gradientColors[0].withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(page.emoji, style: const TextStyle(fontSize: 56)),
              ),
            ),
            const SizedBox(height: 40),
            // Title
            Text(
              page.title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Subtitle
            Text(
              page.subtitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: page.gradientColors[0],
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                page.description,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.5),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final String emoji;
  final String title;
  final String subtitle;
  final String description;
  final List<Color> gradientColors;

  const _OnboardingPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.gradientColors,
  });
}
