import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../theme/design_tokens.dart';
import '../theme/animation_tokens.dart';
import '../widgets/skeleton.dart';
import 'report_screen.dart';

/// Learner context screen
/// Displays learner name, code, and report directly
class LearnerContextScreen extends StatefulWidget {
  final String learnerId;
  final String learnerAlias;
  final String? learnerCode; // Optional - passed from home screen

  const LearnerContextScreen({
    super.key,
    required this.learnerId,
    required this.learnerAlias,
    this.learnerCode,
  });

  @override
  State<LearnerContextScreen> createState() => _LearnerContextScreenState();
}

class _LearnerContextScreenState extends State<LearnerContextScreen> {
  Map<String, dynamic>? _report;
  Map<String, dynamic>? _metrics;
  String? _learnerCode;
  bool _isLoading = true;
  bool _contentVisible = false;
  bool _isGeneratingReport = false;
  String? _generatedReportId;

  @override
  void initState() {
    super.initState();
    _learnerCode = widget.learnerCode;
    _fetchData();
  }

  Future<String?> _getToken() async {
    return supabase.auth.currentSession?.accessToken;
  }

  Future<void> _fetchData() async {
    // Fetch learner details (to get code if not provided) and report
    final token = await _getToken();
    if (token == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Get learner code if not provided
      if (_learnerCode == null) {
        final learnerResponse = await http.get(
          Uri.parse('$backendUrl/api/learners/${widget.learnerId}'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (learnerResponse.statusCode == 200) {
          final learnerData = json.decode(learnerResponse.body);
          _learnerCode = learnerData['learner_code'] as String?;
        }
      }

      // Fetch learner report
      final reportResponse = await http.get(
        Uri.parse('$backendUrl/api/reports/learner/${widget.learnerId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      // Fetch learner metrics
      final metricsResponse = await http.get(
        Uri.parse('$backendUrl/api/learners/${widget.learnerId}/metrics'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (mounted) {
        if (reportResponse.statusCode == 200) {
          setState(() {
            _report = json.decode(reportResponse.body);
          });
        }
        
        if (metricsResponse.statusCode == 200) {
          setState(() {
            _metrics = json.decode(metricsResponse.body);
          });
        }
        
        setState(() => _isLoading = false);

        // Trigger fade-in after load
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _contentVisible = true);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getErrorMessage(int statusCode, String? detail) {
    // Handle specific error messages from backend
    final detailLower = (detail ?? '').toLowerCase();
    
    // No patterns/data available
    if (detailLower.contains('no patterns') || 
        detailLower.contains('no data') ||
        detailLower.contains('insufficient data')) {
      return 'No learning data available yet. Please complete some activities first to generate a report.';
    }
    
    // Missing required data
    if (detailLower.contains('not found') && detailLower.contains('learner')) {
      return 'Learner information not found. Please try again.';
    }
    
    // Gemini API not configured
    if (detailLower.contains('gemini') && detailLower.contains('not configured')) {
      return 'Report generation is temporarily unavailable. Please try again later.';
    }
    
    // Missing session
    if (detailLower.contains('session') && detailLower.contains('required')) {
      return 'Please select a session to generate a report.';
    }
    
    // Permission/access errors
    if (statusCode == 403) {
      return 'You do not have permission to generate this report.';
    }
    
    // Server errors
    if (statusCode >= 500) {
      return 'Server error. Please try again in a moment.';
    }
    
    // Default: use backend message or generic error
    return detail ?? 'Failed to generate report. Please try again.';
  }

  Future<void> _generateReport() async {
    final token = await _getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please log in again.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isGeneratingReport = true);

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/reports/generate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'learner_id': widget.learnerId,
          'scope': 'learner',
          'audience': 'parent',
        }),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final reportId = data['report_id'] as String?;
          final status = data['status'] as String?;
          
          setState(() {
            _generatedReportId = reportId;
            _isGeneratingReport = false;
          });

          // Refresh report data after generation
          await Future.delayed(const Duration(seconds: 2)); // Wait for validation
          await _fetchData();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(status == 'cached_approved' 
                    ? 'Report ready (cached)'
                    : 'Report generated successfully'),
                backgroundColor: AppColors.primary.withOpacity(0.1),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          setState(() => _isGeneratingReport = false);
          
          String errorMessage = 'Failed to generate report.';
          try {
            final errorData = json.decode(response.body);
            final detail = errorData['detail'] as String?;
            errorMessage = _getErrorMessage(response.statusCode, detail);
          } catch (e) {
            // If parsing fails, use status code to determine message
            errorMessage = _getErrorMessage(response.statusCode, null);
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: AppColors.destructive.withOpacity(0.1),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Dismiss',
                  textColor: AppColors.destructive,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
              ),
            );
          }
        }
      }
    } on http.ClientException catch (e) {
      // Network/connection errors
      if (mounted) {
        setState(() => _isGeneratingReport = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Cannot connect to server. Please check your internet connection and make sure the backend is running.',
            ),
            backgroundColor: AppColors.destructive.withOpacity(0.1),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: AppColors.destructive,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    } catch (e) {
      // Other unexpected errors
      if (mounted) {
        setState(() => _isGeneratingReport = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: ${e.toString()}'),
            backgroundColor: AppColors.destructive.withOpacity(0.1),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

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
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: ReportSkeleton(),
            )
          : AnimatedOpacity(
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
                  // Learner Name
                  // ═══════════════════════════════════════════════════════════
                  Text(
                    widget.learnerAlias,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ═══════════════════════════════════════════════════════════
                  // Learner Code
                  // ═══════════════════════════════════════════════════════════
                  if (_learnerCode != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Code: ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            _learnerCode!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                              letterSpacing: 2,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  Container(height: 1, color: AppColors.border),

                  const SizedBox(height: 28),

                  // ═══════════════════════════════════════════════════════════
                  // Generate Report Button
                  // ═══════════════════════════════════════════════════════════
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Row(
                      children: [
                        // View Full Report button (if report exists or generated)
                        if (_report != null || _generatedReportId != null) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                String? reportIdToUse = _generatedReportId;
                                
                                // If no stored reportId, fetch latest
                                if (reportIdToUse == null) {
                                  final token = await _getToken();
                                  if (token != null) {
                                    try {
                                      final response = await http.get(
                                        Uri.parse('$backendUrl/api/reports/learner/${widget.learnerId}/latest'),
                                        headers: {
                                          'Authorization': 'Bearer $token',
                                          'Content-Type': 'application/json',
                                        },
                                      );
                                      
                                      if (response.statusCode == 200) {
                                        final data = json.decode(response.body);
                                        reportIdToUse = data['report_id'] as String?;
                                      }
                                    } catch (e) {
                                      // Ignore error, will fall back to pattern report
                                    }
                                  }
                                }
                                
                                // Navigate to report screen
                                if (mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ReportScreen(
                                        learnerId: widget.learnerId,
                                        learnerAlias: widget.learnerAlias,
                                        reportId: reportIdToUse,
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.visibility_outlined, size: 18),
                              label: const Text('View Full Report'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.input),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        // Generate Report button (always visible)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isGeneratingReport ? null : _generateReport,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.input),
                              ),
                            ),
                            child: _isGeneratingReport
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.description_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Generate Report',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ═══════════════════════════════════════════════════════════
                  // Metrics Section (only in profile, not in AI reports)
                  // ═══════════════════════════════════════════════════════════
                  if (_metrics != null) ...[
                    _buildSectionHeader('Activity Insights'),
                    const SizedBox(height: 10),
                    _buildMetricsSection(),
                    const SizedBox(height: 28),
                  ],

                  // ═══════════════════════════════════════════════════════════
                  // Section 1: Observed Patterns
                  // ═══════════════════════════════════════════════════════════
                  _buildSectionHeader('Observed patterns'),

                  const SizedBox(height: 10),

                  _buildPatternsContent(),

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

  Widget _buildPatternsContent() {
    final patterns = _report?['patterns'] as List? ?? [];

    if (patterns.isEmpty) {
      return _buildParagraph(
        'No specific patterns observed yet. Complete activities to see patterns.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Patterns list
        ...patterns.map((p) => _buildPatternBlock(p)),

        const SizedBox(height: 32),

        // What this may affect
        _buildSectionHeader('What this may affect'),
        const SizedBox(height: 10),
        ...patterns.map((p) {
          final impact = p['learning_impact'] as String?;
          if (impact == null || impact.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildParagraph(impact),
          );
        }),

        const SizedBox(height: 32),

        // Support suggestions
        _buildSectionHeader('Support suggestions'),
        const SizedBox(height: 10),
        ...patterns.map((p) {
          final support = p['support_focus'] as String?;
          if (support == null || support.isEmpty) return const SizedBox.shrink();
          return _buildSupportSuggestion(support);
        }),
      ],
    );
  }

  Widget _buildPatternBlock(dynamic pattern) {
    final name = pattern['pattern_name'] as String? ?? 'Observed pattern';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSuggestion(String text) {
    final suggestions = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: suggestions.map((suggestion) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 16,
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
                    suggestion.trim(),
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

  Widget _buildMetricsSection() {
    if (_metrics == null) return const SizedBox.shrink();
    
    final sessionCount = _metrics!['session_count'] as int? ?? 0;
    final patternCount = _metrics!['pattern_count'] as int? ?? 0;
    final avgPatterns = _metrics!['avg_patterns_per_session'] as double? ?? 0.0;
    final mostCommonPattern = _metrics!['most_common_pattern'] as String?;
    
    // New metrics from backend
    final patternVariety = (_metrics!['pattern_variety'] as num?)?.toDouble() ?? 0.0;
    final confidenceScore = (_metrics!['confidence_score'] as num?)?.toDouble() ?? 0.0;
    final recentActivityRate = (_metrics!['recent_activity_rate'] as num?)?.toDouble() ?? 0.0;
    final sessionsPerWeek = (_metrics!['sessions_per_week'] as num?)?.toDouble() ?? 0.0;
    final consistencyScore = (_metrics!['consistency_score'] as num?)?.toDouble() ?? 0.0;
    
    // Calculate percentages (normalize to 0-100)
    // Activity Level: sessions / 20 (assuming 20 is a good benchmark)
    final activityLevel = (sessionCount / 20 * 100).clamp(0.0, 100.0);
    
    // Pattern Detection Rate: patterns / 10 (assuming 10 is a good benchmark)
    final patternRate = (patternCount / 10 * 100).clamp(0.0, 100.0);
    
    // Engagement Score: avg patterns per session / 2 (assuming 2 is good)
    final engagementScore = (avgPatterns / 2 * 100).clamp(0.0, 100.0);
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Activity Level
          _buildMetricProgressBar(
            icon: Icons.play_circle_outline,
            label: 'Activity Level',
            value: sessionCount,
            percentage: activityLevel,
            color: AppColors.primary,
            suffix: 'sessions',
          ),
          const SizedBox(height: 20),
          
          // Pattern Detection Rate
          _buildMetricProgressBar(
            icon: Icons.insights_outlined,
            label: 'Pattern Detection',
            value: patternCount,
            percentage: patternRate,
            color: AppColors.secondary,
            suffix: 'patterns',
          ),
          const SizedBox(height: 20),
          
          // Engagement Score
          _buildMetricProgressBar(
            icon: Icons.trending_up_outlined,
            label: 'Engagement Score',
            value: avgPatterns,
            percentage: engagementScore,
            color: const Color(0xFF8E9AAF), // Accent color
            suffix: 'avg/session',
            isDecimal: true,
          ),
          const SizedBox(height: 20),
          
          // Pattern Variety
          _buildMetricProgressBar(
            icon: Icons.category_outlined,
            label: 'Pattern Variety',
            value: patternVariety,
            percentage: patternVariety.clamp(0.0, 100.0),
            color: const Color(0xFF6B8E23), // Olive green
            suffix: '% unique',
            isDecimal: true,
          ),
          const SizedBox(height: 20),
          
          // Confidence Score
          _buildMetricProgressBar(
            icon: Icons.check_circle_outline,
            label: 'Pattern Confidence',
            value: confidenceScore,
            percentage: confidenceScore.clamp(0.0, 100.0),
            color: const Color(0xFF4A90E2), // Blue
            suffix: '% weighted',
            isDecimal: true,
          ),
          const SizedBox(height: 20),
          
          // Recent Activity Rate
          _buildMetricProgressBar(
            icon: Icons.schedule_outlined,
            label: 'Recent Activity',
            value: recentActivityRate,
            percentage: recentActivityRate.clamp(0.0, 100.0),
            color: const Color(0xFFE67E22), // Orange
            suffix: '% (30 days)',
            isDecimal: true,
          ),
          const SizedBox(height: 20),
          
          // Sessions per Week
          _buildMetricProgressBar(
            icon: Icons.calendar_today_outlined,
            label: 'Session Frequency',
            value: sessionsPerWeek,
            percentage: (sessionsPerWeek / 3 * 100).clamp(0.0, 100.0), // Normalize to 3/week = 100%
            color: const Color(0xFF9B59B6), // Purple
            suffix: 'per week',
            isDecimal: true,
          ),
          const SizedBox(height: 20),
          
          // Consistency Score
          _buildMetricProgressBar(
            icon: Icons.repeat_outlined,
            label: 'Pattern Consistency',
            value: consistencyScore,
            percentage: consistencyScore.clamp(0.0, 100.0),
            color: const Color(0xFF16A085), // Teal
            suffix: '% stable',
            isDecimal: true,
          ),
          
          // Most common pattern (if available)
          if (mostCommonPattern != null) ...[
            const SizedBox(height: 20),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.star_outline,
                  size: 18,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Most Common Pattern',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mostCommonPattern,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricProgressBar({
    required IconData icon,
    required String label,
    required num value,
    required double percentage,
    required Color color,
    required String suffix,
    bool isDecimal = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row with icon
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              isDecimal ? '${value.toStringAsFixed(1)} $suffix' : '$value $suffix',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Progress bar
        Stack(
          children: [
            // Background bar
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.border.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Fill bar
            FractionallySizedBox(
              widthFactor: percentage / 100,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        
        // Percentage text
        Text(
          '${percentage.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
