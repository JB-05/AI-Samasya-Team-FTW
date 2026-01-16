import 'package:flutter/material.dart';

/// =============================================================================
/// NEUROPLAY ANIMATION TOKENS
/// Subtle, functional animations for clarity — not delight
/// =============================================================================
///
/// Principles:
/// - Animations reduce uncertainty, not add excitement
/// - No bounces, springs, scaling, or playful motion
/// - No animation longer than 200ms
/// - Prefer opacity and cross-fade over movement
/// =============================================================================

/// Standard fade duration for UI state changes
/// Slower = calmer, increases perceived trust
const Duration kFadeDuration = Duration(milliseconds: 180);

/// Cross-fade duration for content switches
const Duration kCrossFadeDuration = Duration(milliseconds: 220);

/// Skeleton pulse animation duration (one full cycle)
const Duration kSkeletonPulseDuration = Duration(milliseconds: 1200);

/// Standard curve for all animations (linear for subtlety)
const Curve kAnimationCurve = Curves.easeOut;

/// =============================================================================
/// ANIMATION UTILITIES
/// =============================================================================

/// Page fade transition builder for AnimatedSwitcher
Widget pageFadeTransitionBuilder(Widget child, Animation<double> animation) {
  return FadeTransition(
    opacity: animation,
    child: child,
  );
}

/// Standard AnimatedSwitcher for page content
class FadeInContent extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const FadeInContent({
    super.key,
    required this.child,
    this.duration = kCrossFadeDuration,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: pageFadeTransitionBuilder,
      child: child,
    );
  }
}

/// Wrapper for conditional UI elements (fade in/out)
class ConditionalFade extends StatelessWidget {
  final bool visible;
  final Widget child;
  final Duration duration;

  const ConditionalFade({
    super.key,
    required this.visible,
    required this.child,
    this.duration = kFadeDuration,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: duration,
      curve: kAnimationCurve,
      child: visible ? child : const SizedBox.shrink(),
    );
  }
}

/// =============================================================================
/// SMOOTH PAGE ROUTE TRANSITIONS
/// =============================================================================

/// Custom page route with smooth fade transition
/// Use instead of MaterialPageRoute for smoother navigation
class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SmoothPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: kCrossFadeDuration,
          reverseTransitionDuration: kFadeDuration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
                reverseCurve: Curves.easeIn,
              ),
              child: child,
            );
          },
        );
}

/// Helper function for smooth navigation
Future<T?> navigateSmoothly<T>(BuildContext context, Widget page) {
  return Navigator.push<T>(
    context,
    SmoothPageRoute<T>(page: page),
  );
}
