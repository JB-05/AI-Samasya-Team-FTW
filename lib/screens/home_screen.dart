import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../theme/design_tokens.dart';
import '../theme/animation_tokens.dart';
import '../widgets/skeleton.dart';
import 'learner_context_screen.dart';

/// Home screen - learner list and management.
/// Progressive disclosure: shows only what is needed.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Cache learners data at class level for persistence across rebuilds
  static List<dynamic> _cachedLearners = [];
  static bool _hasFetchedOnce = false;
  
  List<dynamic> _learners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Use cached data if available (instant display)
    if (_cachedLearners.isNotEmpty) {
      _learners = _cachedLearners;
      _isLoading = false;
      // Refresh in background silently
      _fetchLearners(silent: true);
    } else {
      _fetchLearners(silent: false);
    }
  }

  Future<String?> _getToken() async {
    return supabase.auth.currentSession?.accessToken;
  }

  /// Fetch learners from API
  /// [silent] = true: Don't show loading state (background refresh)
  /// [silent] = false: Show skeleton loading (initial load)
  Future<void> _fetchLearners({bool silent = false}) async {
    if (!mounted) return;

    // Only show loading skeleton if:
    // 1. Not silent AND
    // 2. We have no cached data
    if (!silent && _cachedLearners.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final token = await _getToken();
      if (token == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      final response = await http.get(
        Uri.parse('$backendUrl/api/learners'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newLearners = data is List ? data : [];
        
        // Update cache
        _cachedLearners = newLearners;
        _hasFetchedOnce = true;
        
        setState(() {
          _learners = newLearners;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _navigateToLearner(String learnerId, String alias, {String? learnerCode}) {
    navigateSmoothly(
      context,
      LearnerContextScreen(
        learnerId: learnerId,
        learnerAlias: alias,
        learnerCode: learnerCode,
      ),
    );
  }

  Future<void> _showAddLearnerDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _AddLearnerDialog(controller: controller),
    );

    if (result != null && result.isNotEmpty) {
      await _createLearner(result);
    }
  }

  Future<void> _createLearner(String alias) async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final response = await http.post(
        Uri.parse('$backendUrl/api/learners'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'alias': alias}),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final learnerCode = data['learner_code'] as String?;
        
        // Refresh list (non-silent to update UI)
        await _fetchLearners(silent: false);
        
        // Show learner code dialog (critical - shown only once)
        if (mounted && learnerCode != null) {
          await _showLearnerCodeDialog(alias, learnerCode);
        }
      } else if (response.statusCode == 409) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A learner with this alias already exists')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not add learner')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection error')),
        );
      }
    }
  }

  /// Show the learner code dialog - CRITICAL: Code is shown only once
  Future<void> _showLearnerCodeDialog(String alias, String code) async {
    await showDialog(
      context: context,
      barrierDismissible: false, // Must acknowledge
      builder: (ctx) => _LearnerCodeDialog(alias: alias, code: code),
    );
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
      body: RefreshIndicator(
        onRefresh: () => _fetchLearners(silent: true), // Silent - RefreshIndicator shows its own indicator
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          children: [
            // ─────────────────────────────────────────────────────────────
            // Section header
            // ─────────────────────────────────────────────────────────────
            Text(
              'Learners',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Select a learner to begin an activity or view observed patterns.',
              style: theme.textTheme.bodyMedium,
            ),

            const SizedBox(height: AppSpacing.md),

            // ─────────────────────────────────────────────────────────────
            // Learner list with AnimatedSwitcher
            // ─────────────────────────────────────────────────────────────
            AnimatedSwitcher(
              duration: kCrossFadeDuration,
              transitionBuilder: pageFadeTransitionBuilder,
              child: _buildLearnersList(theme),
            ),

            const SizedBox(height: AppSpacing.md),

            // ─────────────────────────────────────────────────────────────
            // Add learner action
            // ─────────────────────────────────────────────────────────────
            OutlinedButton.icon(
              onPressed: _showAddLearnerDialog,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add learner'),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ─────────────────────────────────────────────────────────────
            // Disclaimer (always visible)
            // ─────────────────────────────────────────────────────────────
            Text(
              kDisclaimer,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: AppColors.muted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearnersList(ThemeData theme) {
    // Skeleton loading state
    if (_isLoading) {
      return const LearnerListSkeleton(
        key: ValueKey('skeleton'),
        itemCount: 3,
      );
    }

    // Empty state
    if (_learners.isEmpty) {
      return Card(
        key: const ValueKey('empty'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Icon(
                Icons.person_outline,
                size: 40,
                color: AppColors.muted,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No learners yet',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Add a learner to begin observing patterns.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Learner list
    return Column(
      key: const ValueKey('list'),
      children: _learners.asMap().entries.map((entry) {
        final index = entry.key;
        final learner = entry.value;
        final learnerId = (learner['learner_id'] ?? '').toString();
        final alias = (learner['alias'] ?? 'Unknown').toString();
        final learnerCode = (learner['learner_code'] ?? '').toString();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              title: Text(alias, style: theme.textTheme.bodyLarge),
              subtitle: Text(
                'Tap to view observations',
                style: theme.textTheme.bodySmall,
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.muted,
              ),
              onTap: () => _navigateToLearner(learnerId, alias, learnerCode: learnerCode.isEmpty ? null : learnerCode),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Dialog for adding a new learner
/// Restrained, form-like, no celebratory elements
class _AddLearnerDialog extends StatefulWidget {
  final TextEditingController controller;

  const _AddLearnerDialog({required this.controller});

  @override
  State<_AddLearnerDialog> createState() => _AddLearnerDialogState();
}

class _AddLearnerDialogState extends State<_AddLearnerDialog> {
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final valid = widget.controller.text.trim().length >= 2;
    if (valid != _isValid) {
      setState(() => _isValid = valid);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      backgroundColor: AppColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add learner',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Enter an alias to identify this learner. No identifying information is stored.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: widget.controller,
                autofocus: true,
                style: theme.textTheme.bodyLarge,
                decoration: appInputDecoration(
                  label: 'Alias',
                  hint: 'e.g. "Learner A"',
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: _isValid ? (_) => _submit() : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    // Animated opacity for disabled state
                    child: AnimatedOpacity(
                      opacity: _isValid ? 1.0 : 0.5,
                      duration: kFadeDuration,
                      child: FilledButton(
                        onPressed: _isValid ? _submit : null,
                        child: const Text('Add'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    Navigator.pop(context, widget.controller.text.trim());
  }
}

/// Dialog showing the learner access code
/// CRITICAL: This code is shown ONCE and must be saved by the parent
class _LearnerCodeDialog extends StatelessWidget {
  final String alias;
  final String code;

  const _LearnerCodeDialog({
    required this.alias,
    required this.code,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      backgroundColor: AppColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header
              Text(
                'Learner added',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Save this access code for "$alias"',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.md),

              // Code display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Text(
                      code,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                        letterSpacing: 4,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy code'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Warning
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.destructive.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.input),
                ),
                child: Text(
                  'This code will not be shown again. Use it to start activities on the child\'s device.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Confirm button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('I have saved the code'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
