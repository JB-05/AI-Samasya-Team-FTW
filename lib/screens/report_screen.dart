import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../theme/design_tokens.dart';

class ReportScreen extends StatefulWidget {
  final String sessionId;
  final String learnerAlias;

  const ReportScreen({
    super.key,
    required this.sessionId,
    required this.learnerAlias,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  Map<String, dynamic>? _report;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

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
        Uri.parse('$backendUrl/api/reports/session/${widget.sessionId}'),
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Session Report'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // Pop back to dashboard
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _fetchReport,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    if (_report == null) {
      return Center(
        child: Text('No data', style: theme.textTheme.bodyMedium),
      );
    }

    final patterns = _report!['patterns'] as List<dynamic>? ?? [];
    final disclaimer = _report!['disclaimer'] as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Report for ${widget.learnerAlias}',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Focus Tap activity',
            style: theme.textTheme.bodySmall,
          ),

          const SizedBox(height: AppSpacing.md),

          // Patterns
          if (patterns.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Text(
                    'No patterns detected',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Not enough data was collected in this session.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            )
          else
            ...patterns.map((p) => _buildPatternCard(theme, p)),

          const SizedBox(height: AppSpacing.lg),

          // Disclaimer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.border.withOpacity(0.3),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Text(
              disclaimer,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Done button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Done'),
            ),
          ),

          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _buildPatternCard(ThemeData theme, Map<String, dynamic> pattern) {
    final patternName = pattern['pattern_name'] as String? ?? 'Unknown';
    final confidence = pattern['confidence'] as String? ?? 'low';
    final learningImpact = pattern['learning_impact'] as String? ?? '';
    final supportFocus = pattern['support_focus'] as String? ?? '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pattern name + confidence
          Row(
            children: [
              Expanded(
                child: Text(
                  patternName,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _confidenceColor(confidence).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  confidence,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _confidenceColor(confidence),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // Learning impact
          Text(
            'What this means',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            learningImpact,
            style: theme.textTheme.bodyMedium,
          ),

          const SizedBox(height: AppSpacing.sm),

          // Support focus
          Text(
            'How to support',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            supportFocus,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Color _confidenceColor(String confidence) {
    switch (confidence) {
      case 'high':
        return AppColors.primary;
      case 'moderate':
        return AppColors.textSecondary;
      default:
        return AppColors.border;
    }
  }
}
