import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../theme/design_tokens.dart';
import '../theme/animation_tokens.dart';
import '../widgets/skeleton.dart';

/// Trends screen
/// Shows patterns over time
/// Language-only, text-based trends
class TrendsScreen extends StatefulWidget {
  final String? learnerId;  // Optional: if null, show all learners

  const TrendsScreen({super.key, this.learnerId});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  bool _contentVisible = false;
  bool _isLoading = true;
  String? _error;
  List<Map<String, String>> _trends = [];

  @override
  void initState() {
    super.initState();
    if (widget.learnerId != null) {
      _fetchTrends(widget.learnerId!);
    } else {
      // For now, show empty state if no learner specified
      setState(() {
        _isLoading = false;
        _error = 'Select a learner to view trends';
      });
    }
  }

  Future<void> _fetchTrends(String learnerId) async {
    try {
      final token = supabase.auth.currentSession?.accessToken;
      if (token == null) {
        setState(() {
          _error = 'Session expired';
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('$backendUrl/api/trends/learner/$learnerId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final trendsList = data['trends'] as List? ?? [];
        
        setState(() {
          _trends = trendsList.map((t) => {
            'pattern_name': t['pattern_name'] as String? ?? 'Pattern',
            'trend_type': t['trend_type'] as String? ?? '',
          }).toList();
          _isLoading = false;
        });
        
        // Trigger fade-in after load
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _contentVisible = true);
        });
      } else {
        setState(() {
          _error = 'Could not load trends';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'NeuroPlay',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: AppColors.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: AnimatedOpacity(
        opacity: _contentVisible ? 1.0 : 0.0,
        duration: kFadeDuration,
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          children: [
            const SizedBox(height: AppSpacing.sm),

            // ═══════════════════════════════════════════════════════════
            // Section Header
            // ═══════════════════════════════════════════════════════════
            Text(
              'Patterns over time',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Based on multiple learning activities',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 20),

            Container(height: 1, color: AppColors.border),

            const SizedBox(height: 28),

            // ═══════════════════════════════════════════════════════════
            // Trends Content
            // ═══════════════════════════════════════════════════════════
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else if (_trends.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Patterns over time will appear here after several learning activities.',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              )
            else
              _buildTrendsContent(),

            // ═══════════════════════════════════════════════════════════
            // Footer Disclaimer
            // ═══════════════════════════════════════════════════════════
            const SizedBox(height: 40),

            Container(height: 1, color: AppColors.border),

            const SizedBox(height: 16),

            Text(
              'Observational insights only. Not a diagnostic tool.',
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
    );
  }

  Widget _buildTrendsContent() {
    // Render trend items
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _trends.map((trend) {
        return _buildTrendItem(trend);
      }).toList(),
    );
  }

  Widget _buildTrendItem(Map<String, String> trend) {
    final patternName = trend['pattern_name'] ?? 'Pattern';
    final trendType = trend['trend_type'] ?? '';

    // Get trend summary using canonical language templates
    String trendSummary = '';
    if (trendType == 'stable') {
      trendSummary = 'This pattern has appeared consistently across recent activities, suggesting a stable learning rhythm.';
    } else if (trendType == 'fluctuating') {
      trendSummary = 'This pattern has varied across activities, which is common as learners adapt to different tasks.';
    } else if (trendType == 'improving') {
      trendSummary = 'Across recent activities, this pattern is appearing less strongly, suggesting growing ease with the task demands.';
    } else {
      // Fallback if trend_type is missing or unknown
      trendSummary = 'This pattern has appeared across recent activities.';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18), // 16-20px spacing
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pattern name
          Text(
            patternName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          // Trend summary
          Text(
            trendSummary,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
