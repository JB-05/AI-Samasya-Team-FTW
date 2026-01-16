import 'package:flutter/material.dart';
import '../theme/animation_tokens.dart';
import '../theme/design_tokens.dart';

/// =============================================================================
/// SKELETON LOADING WIDGETS
/// Simple opacity pulse — no shimmer libraries
/// =============================================================================

/// Base skeleton container with pulse animation
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 4,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: kSkeletonPulseDuration,
      vsync: this,
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(
      begin: 0.3,
      end: 0.6,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.grey.shade300.withOpacity(_opacityAnimation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Skeleton for a single learner list item
class LearnerSkeleton extends StatelessWidget {
  const LearnerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBox(width: 120, height: 16, borderRadius: 4),
                  const SizedBox(height: 8),
                  SkeletonBox(width: 180, height: 12, borderRadius: 4),
                ],
              ),
            ),
            const SkeletonBox(width: 24, height: 24, borderRadius: 4),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for learner list (multiple items)
class LearnerListSkeleton extends StatelessWidget {
  final int itemCount;

  const LearnerListSkeleton({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => const LearnerSkeleton(),
      ),
    );
  }
}

/// Skeleton for report content
class ReportSkeleton extends StatelessWidget {
  const ReportSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title skeleton
        const SkeletonBox(width: 150, height: 24, borderRadius: 4),
        const SizedBox(height: 8),
        const SkeletonBox(width: 200, height: 14, borderRadius: 4),
        const SizedBox(height: AppSpacing.md),

        // Pattern card skeleton
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SkeletonBox(width: 140, height: 18, borderRadius: 4),
                    SkeletonBox(width: 60, height: 20, borderRadius: 4),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const SkeletonBox(width: double.infinity, height: 14, borderRadius: 4),
                const SizedBox(height: 6),
                const SkeletonBox(width: 280, height: 14, borderRadius: 4),
                const SizedBox(height: AppSpacing.sm),
                const Divider(),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const SkeletonBox(width: 18, height: 18, borderRadius: 4),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SkeletonBox(width: double.infinity, height: 12, borderRadius: 4),
                          SizedBox(height: 4),
                          SkeletonBox(width: 200, height: 12, borderRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Skeleton for profile content
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 80, height: 18, borderRadius: 4),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: const [
                    SkeletonBox(width: 20, height: 20, borderRadius: 4),
                    SizedBox(width: 8),
                    SkeletonBox(width: 180, height: 16, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
