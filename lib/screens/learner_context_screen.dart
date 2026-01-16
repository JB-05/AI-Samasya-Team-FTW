import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'focus_tap_game_screen.dart';
import 'insights_screen.dart';

/// Learner Context Screen
/// Appears when a learner row is tapped.
/// Purpose: Establish context, guide adult actions responsibly.
class LearnerContextScreen extends StatelessWidget {
  final String learnerId;
  final String learnerAlias;
  final bool hasCompletedSessions;

  const LearnerContextScreen({
    super.key,
    required this.learnerId,
    required this.learnerAlias,
    this.hasCompletedSessions = false, // Phase 1: always false
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.sm),

              // ─────────────────────────────────────────────────────────────
              // Learner Alias (Title)
              // ─────────────────────────────────────────────────────────────
              Text(
                learnerAlias,
                style: theme.textTheme.headlineMedium,
              ),

              const SizedBox(height: AppSpacing.xs),

              // ─────────────────────────────────────────────────────────────
              // Guiding Question
              // ─────────────────────────────────────────────────────────────
              Text(
                'What would you like to do?',
                style: theme.textTheme.bodyMedium,
              ),

              const SizedBox(height: AppSpacing.lg),

              // ─────────────────────────────────────────────────────────────
              // Primary Action: Start learning activity
              // ─────────────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FocusTapGameScreen(
                          learnerId: learnerId,
                          learnerAlias: learnerAlias,
                        ),
                      ),
                    );
                  },
                  child: const Text('Start learning activity'),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // ─────────────────────────────────────────────────────────────
              // Secondary Action: View observations
              // ─────────────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: hasCompletedSessions
                    ? OutlinedButton(
                        onPressed: () {
                          // Navigate to insights/observations
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => InsightsScreen(
                                learnerId: learnerId,
                                learnerAlias: learnerAlias,
                              ),
                            ),
                          );
                        },
                        child: const Text('View observations'),
                      )
                    : OutlinedButton(
                        onPressed: null, // Disabled
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary.withOpacity(0.5),
                        ),
                        child: const Text('View observations'),
                      ),
              ),

              // Helper text when no sessions
              if (!hasCompletedSessions) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Available after activities are completed',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary.withOpacity(0.7),
                  ),
                ),
              ],

              const Spacer(),

              // ─────────────────────────────────────────────────────────────
              // Ethics Statement (Anchored at bottom)
              // ─────────────────────────────────────────────────────────────
              const Divider(),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Observational insights only. Not a diagnostic assessment.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
