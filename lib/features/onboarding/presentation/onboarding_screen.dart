import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/services/services.dart';
import '../../auth/providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = const [
    OnboardingPage(
      icon: Icons.receipt_long,
      title: 'Effortless Reporting',
      subtitle: 'Turn receipt photos into clean expense reports.',
    ),
    OnboardingPage(
      icon: Icons.document_scanner,
      title: 'Smart Receipt Scanning',
      subtitle: 'We detect merchant, date, amount & currency for you.',
    ),
    OnboardingPage(
      icon: Icons.share,
      title: 'Share Reports Easily',
      subtitle: 'Submit to your manager or accountant in one tap.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    final storage = ref.read(storageServiceProvider);
    await storage.setOnboardingCompleted(true);

    // Login anonymously
    await ref.read(authProvider.notifier).loginAnonymous();

    if (mounted) {
      context.go(AppRoutes.main);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Background
          _buildBackground(),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: Platform.isIOS
                              ? Colors.white70
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),

                // Pages
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      return _OnboardingPageContent(
                        page: _pages[index],
                        isIOS: Platform.isIOS,
                      );
                    },
                  ),
                ),

                // Page indicators
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => _PageIndicator(
                        isActive: index == _currentPage,
                        isIOS: Platform.isIOS,
                      ),
                    ),
                  ),
                ),

                // Buttons
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: _currentPage == _pages.length - 1
                      ? Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _completeOnboarding,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Platform.isIOS
                                      ? Colors.white
                                      : theme.colorScheme.primary,
                                  foregroundColor: Platform.isIOS
                                      ? theme.colorScheme.primary
                                      : Colors.white,
                                ),
                                child: const Text('Get Started'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                // TODO: Implement sign in flow
                                _completeOnboarding();
                              },
                              child: Text(
                                'Sign In',
                                style: TextStyle(
                                  color: Platform.isIOS
                                      ? Colors.white70
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _nextPage,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Platform.isIOS
                                  ? Colors.white
                                  : theme.colorScheme.primary,
                              foregroundColor: Platform.isIOS
                                  ? theme.colorScheme.primary
                                  : Colors.white,
                            ),
                            child: const Text('Next'),
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

  Widget _buildBackground() {
    if (Platform.isIOS) {
      // Use Liquid Glass platform view on iOS
      return const LiquidGlassBackground();
    } else {
      // Use gradient on Android
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withOpacity(0.6),
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
      );
    }
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;

  const OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _OnboardingPageContent extends StatelessWidget {
  final OnboardingPage page;
  final bool isIOS;

  const _OnboardingPageContent({
    required this.page,
    required this.isIOS,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = isIOS ? Colors.white : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon container
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: isIOS
                  ? Colors.white.withOpacity(0.2)
                  : theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 64,
              color: isIOS ? Colors.white : theme.colorScheme.primary,
            ),
          ),

          const SizedBox(height: 48),

          // Title
          Text(
            page.title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Subtitle
          Text(
            page.subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: textColor.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final bool isActive;
  final bool isIOS;

  const _PageIndicator({
    required this.isActive,
    required this.isIOS,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isIOS ? Colors.white : Theme.of(context).colorScheme.primary;
    final inactiveColor = isIOS
        ? Colors.white.withOpacity(0.3)
        : Theme.of(context).colorScheme.primary.withOpacity(0.3);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? activeColor : inactiveColor,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Liquid Glass background for iOS
/// Uses a gradient with glass-like appearance
class LiquidGlassBackground extends StatelessWidget {
  const LiquidGlassBackground({super.key});

  @override
  Widget build(BuildContext context) {
    // Beautiful gradient background for onboarding
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667EEA),
            Color(0xFF764BA2),
            Color(0xFFF093FB),
          ],
        ),
      ),
    );
  }
}

class _LiquidGlassPlatformView extends StatelessWidget {
  const _LiquidGlassPlatformView();

  @override
  Widget build(BuildContext context) {
    // Try to render native platform view
    // If it fails, we catch the error and show nothing (gradient shows through)
    try {
      return const UiKitView(
        viewType: 'liquid_glass_view',
        creationParamsCodec: StandardMessageCodec(),
      );
    } catch (e) {
      // Platform view not available, show frosted glass effect with ClipRect
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
        ),
      );
    }
  }
}
