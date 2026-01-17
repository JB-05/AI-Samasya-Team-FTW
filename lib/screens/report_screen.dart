import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../theme/design_tokens.dart';
import '../theme/animation_tokens.dart';
import '../widgets/skeleton.dart';

/// Learning Summary screen
/// Interpretive safety through structure
/// Explains observed patterns in clear, non-diagnostic language
class ReportScreen extends StatefulWidget {
  final String? sessionId;
  final String? learnerId;
  final String? reportId; // AI-generated report ID
  final String learnerAlias;

  const ReportScreen({
    super.key,
    this.sessionId,
    this.learnerId,
    this.reportId,
    required this.learnerAlias,
  }) : assert(sessionId != null || learnerId != null || reportId != null, 'Either sessionId, learnerId, or reportId must be provided');

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  Map<String, dynamic>? _report;
  bool _isLoading = true;
  bool _contentVisible = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    try {
      final token = supabase.auth.currentSession?.accessToken;
      if (token == null) {
        setState(() {
          _error = 'Session expired';
          _isLoading = false;
        });
        return;
      }

      // Use appropriate endpoint based on what's provided
      // Priority: reportId (AI report) > sessionId > learnerId
      final String endpoint;
      if (widget.reportId != null) {
        // Fetch AI-generated report
        endpoint = '$backendUrl/api/reports/ai/${widget.reportId}';
      } else if (widget.sessionId != null) {
        endpoint = '$backendUrl/api/reports/session/${widget.sessionId}';
      } else if (widget.learnerId != null) {
        endpoint = '$backendUrl/api/reports/learner/${widget.learnerId}';
      } else {
        setState(() {
          _error = 'Invalid report parameters';
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _report = json.decode(response.body);
          _isLoading = false;
        });
        // Trigger fade-in after load
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _contentVisible = true);
        });
      } else {
        setState(() {
          _error = 'Could not load report';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Loading state
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: ReportSkeleton(),
      );
    }

    // Error state
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Return home'),
              ),
            ],
          ),
        ),
      );
    }

    // Check if this is an AI-generated report (has 'content' field)
    final isAiReport = widget.reportId != null && _report?['content'] != null;
    final patterns = _report?['patterns'] as List? ?? [];
    final aiContent = _report?['content'] as String?;
    final generatedAt = DateTime.now(); // Would come from backend in production

    // Fade in entire content at once
    return AnimatedOpacity(
      opacity: _contentVisible ? 1.0 : 0.0,
      duration: kFadeDuration,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        children: [
          // ═══════════════════════════════════════════════════════════════
          // SCREEN TITLE
          // ═══════════════════════════════════════════════════════════════
          Text(
            isAiReport ? 'Learning Report' : 'Learning Summary',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            isAiReport ? 'AI-generated narrative report' : 'Based on recent learning activities',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 16),

          // Title divider
          Container(height: 1, color: AppColors.border),

          // ═══════════════════════════════════════════════════════════════
          // AI-GENERATED REPORT CONTENT (if reportId provided)
          // ═══════════════════════════════════════════════════════════════
          if (isAiReport && aiContent != null) ...[
            const SizedBox(height: 28),

            // Display AI-generated narrative content
            _buildAiReportContent(aiContent),

          ] else ...[
            // ═══════════════════════════════════════════════════════════════
            // SECTION 1: Observed Patterns (Mandatory first) - For pattern-based reports
            // ═══════════════════════════════════════════════════════════════
            const SizedBox(height: 28),

            _buildSectionHeader('Observed patterns'),

            const SizedBox(height: 10),

            if (patterns.isEmpty)
              _buildParagraph(
                'No specific patterns were observed during this activity. '
                'Responses were within typical ranges.',
              )
            else
              ...patterns.map((p) => _buildPatternBlock(p)),

          // ═══════════════════════════════════════════════════════════════
          // SECTION 2: What This May Affect
          // ═══════════════════════════════════════════════════════════════
          if (patterns.isNotEmpty) ...[
            const SizedBox(height: 32),

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
          ],

          // ═══════════════════════════════════════════════════════════════
          // SECTION 3: Support Suggestions
          // ═══════════════════════════════════════════════════════════════
          if (patterns.isNotEmpty) ...[
            const SizedBox(height: 32),

            _buildSectionHeader('Support suggestions'),

            const SizedBox(height: 10),

            ...patterns.map((p) {
              final support = p['support_focus'] as String?;
              if (support == null || support.isEmpty) return const SizedBox.shrink();
              return _buildSupportSuggestion(support);
            }),
          ],
          ],

          // ═══════════════════════════════════════════════════════════════
          // SECTION 4: Report Metadata (De-emphasized, at bottom)
          // ═══════════════════════════════════════════════════════════════
          const SizedBox(height: 40),

          Container(height: 1, color: AppColors.border),

          const SizedBox(height: 16),

          // Metadata row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Generated ${_formatDate(generatedAt)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.muted,
                ),
              ),
              Text(
                'Language-checked',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Disclaimer
          Text(
            _report?['disclaimer'] ?? 'Observational insights only. Not a diagnostic tool.',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.muted,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Return action
          FilledButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Return home'),
          ),

          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  /// Section header - 16-17px Medium
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

  /// AI-generated report content display
  Widget _buildAiReportContent(String content) {
    // Split content into paragraphs (by double newlines or single newlines)
    final paragraphs = content.split(RegExp(r'\n\n+')).where((p) => p.trim().isNotEmpty).toList();
    
    if (paragraphs.isEmpty) {
      return _buildParagraph(content);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((para) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildParagraph(para.trim()),
        );
      }).toList(),
    );
  }

  /// Body paragraph - 15px Regular, secondary color
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

  /// Pattern block - plain text, no cards, no confidence values
  Widget _buildPatternBlock(dynamic pattern) {
    final name = pattern['pattern_name'] as String? ?? 'Observed pattern';
    final explanation = pattern['explanation'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pattern name as inline emphasis
          Text(
            name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              height: 1.55,
            ),
          ),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              explanation,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
                height: 1.55,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Support suggestion - short, neutral bullet point
  Widget _buildSupportSuggestion(String text) {
    // Split by sentence if multiple suggestions
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

  /// Format date for metadata
  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
