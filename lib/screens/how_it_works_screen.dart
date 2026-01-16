import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// How It Works screen - explains the app to adults.
/// Educational, reassuring, privacy-focused.
class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('How it works'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          // Hero Section
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Observe. Understand. Support.',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'AI Samasya helps adults observe learning patterns '
                  'through simple, engaging activities.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Step 1
          _StepCard(
            number: '1',
            title: 'Create a learner profile',
            description:
                'Add an alias for each child you want to observe. '
                'No personal information is required — just a name you\'ll recognize.',
            icon: Icons.person_add_outlined,
          ),

          const SizedBox(height: AppSpacing.sm),

          // Step 2
          _StepCard(
            number: '2',
            title: 'Start a learning activity',
            description:
                'Guide the child through a short, game-like activity. '
                'Activities are designed to be fun and non-stressful, '
                'taking only 2-3 minutes.',
            icon: Icons.play_circle_outline,
          ),

          const SizedBox(height: AppSpacing.sm),

          // Step 3
          _StepCard(
            number: '3',
            title: 'Review observations',
            description:
                'After the activity, see patterns in how the child engaged. '
                'Observations focus on attention, response timing, and consistency.',
            icon: Icons.insights_outlined,
          ),

          const SizedBox(height: AppSpacing.sm),

          // Step 4
          _StepCard(
            number: '4',
            title: 'Track over time',
            description:
                'Multiple sessions reveal trends. See how patterns evolve '
                'across different days and contexts.',
            icon: Icons.trending_up_outlined,
          ),

          const SizedBox(height: AppSpacing.lg),

          // Privacy Section
          Text(
            'Privacy & Safety',
            style: theme.textTheme.titleLarge,
          ),

          const SizedBox(height: AppSpacing.sm),

          _InfoCard(
            icon: Icons.shield_outlined,
            title: 'No child identity stored',
            description:
                'We only store the alias you provide. No names, photos, '
                'or identifying information about children.',
          ),

          const SizedBox(height: AppSpacing.xs),

          _InfoCard(
            icon: Icons.delete_outline,
            title: 'Raw data is temporary',
            description:
                'Individual tap data is processed and discarded. '
                'Only summarized patterns are saved.',
          ),

          const SizedBox(height: AppSpacing.xs),

          _InfoCard(
            icon: Icons.lock_outline,
            title: 'Your data stays yours',
            description:
                'Each observer can only see their own learners. '
                'Data is never shared or sold.',
          ),

          const SizedBox(height: AppSpacing.lg),

          // Important Note
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: AppColors.accent.withOpacity(0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Important',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'AI Samasya provides observational insights only. '
                        'It is not a diagnostic or assessment tool. '
                        'Always consult qualified professionals for concerns '
                        'about a child\'s development.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // What We Observe Section
          Text(
            'What we observe',
            style: theme.textTheme.titleLarge,
          ),

          const SizedBox(height: AppSpacing.sm),

          _MetricCard(
            title: 'Response timing',
            description: 'How quickly does the child respond to prompts?',
          ),
          const SizedBox(height: AppSpacing.xs),
          _MetricCard(
            title: 'Consistency',
            description: 'How steady are response times across the activity?',
          ),
          const SizedBox(height: AppSpacing.xs),
          _MetricCard(
            title: 'Engagement',
            description: 'Does the child maintain focus throughout?',
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final IconData icon;

  const _StepCard({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  number,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String description;

  const _MetricCard({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
