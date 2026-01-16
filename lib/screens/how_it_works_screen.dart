import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../theme/animation_tokens.dart';

/// About / How it works screen
/// Document-like, structured reading experience
/// Builds trust through clarity, not decoration
class HowItWorksScreen extends StatefulWidget {
  const HowItWorksScreen({super.key});

  @override
  State<HowItWorksScreen> createState() => _HowItWorksScreenState();
}

class _HowItWorksScreenState extends State<HowItWorksScreen> {
  bool _contentVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _contentVisible = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // No AppBar - document-like feel
      body: SafeArea(
        child: AnimatedOpacity(
          opacity: _contentVisible ? 1.0 : 0.0,
          duration: kCrossFadeDuration,
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            children: [
              const SizedBox(height: AppSpacing.md),

              // ═══════════════════════════════════════════════════════════
              // PAGE TITLE (Anchor)
              // ═══════════════════════════════════════════════════════════
              Text(
                'About NeuroPlay',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 18),

              // Title divider
              Container(
                height: 1,
                color: AppColors.border,
              ),

              const SizedBox(height: 28),

              // ═══════════════════════════════════════════════════════════
              // SECTION: What this tool does
              // ═══════════════════════════════════════════════════════════
              _buildSectionHeader('What this tool does'),
              const SizedBox(height: 10),
              _buildParagraph(
                'NeuroPlay observes learning patterns through short activities. '
                'It provides support suggestions based on observed behaviours, '
                'not diagnoses or assessments.',
              ),

              const SizedBox(height: 32),

              // ═══════════════════════════════════════════════════════════
              // SECTION: How it works
              // ═══════════════════════════════════════════════════════════
              _buildSectionHeader('How it works'),
              const SizedBox(height: 10),
              _buildNumberedList([
                'Add a learner using an alias (no identifying information)',
                'Start an observation activity',
                'Review observed patterns after completion',
                'Use support suggestions to guide learning',
              ]),

              const SizedBox(height: 32),

              // ═══════════════════════════════════════════════════════════
              // SECTION: Privacy
              // ═══════════════════════════════════════════════════════════
              _buildSectionHeader('Privacy'),
              const SizedBox(height: 10),
              _buildParagraph(
                'No child identity is stored. Only adult-defined aliases are used.',
              ),
              const SizedBox(height: 8),
              _buildParagraph(
                'Raw activity data is processed immediately and not retained. '
                'Only pattern summaries are saved.',
              ),

              const SizedBox(height: 32),

              // ═══════════════════════════════════════════════════════════
              // SECTION: What we observe
              // ═══════════════════════════════════════════════════════════
              _buildSectionHeader('What we observe'),
              const SizedBox(height: 10),
              _buildBulletList([
                'Response timing and consistency',
                'Engagement patterns during activities',
                'Focus variability',
              ]),
              const SizedBox(height: 12),
              _buildParagraph(
                'These observations may inform support strategies but do not '
                'indicate any condition or diagnosis.',
              ),

              // ═══════════════════════════════════════════════════════════
              // FOOTER DISCLAIMER
              // ═══════════════════════════════════════════════════════════
              const SizedBox(height: 40),

              Container(
                height: 1,
                color: AppColors.border,
              ),

              const SizedBox(height: 20),

              Text(
                kDisclaimer,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.muted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  /// Section header - clearly secondary to page title
  Widget _buildSectionHeader(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        height: 1.3,
      ),
    );
  }

  /// Body paragraph - secondary color, good line height
  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.55,
      ),
    );
  }

  /// Numbered list - indented, spaced items
  Widget _buildNumberedList(List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final text = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '$index.',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                      height: 1.55,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Bullet list - indented, spaced items
  Widget _buildBulletList(List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((text) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 20,
                  child: Text(
                    '•',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                      height: 1.55,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
