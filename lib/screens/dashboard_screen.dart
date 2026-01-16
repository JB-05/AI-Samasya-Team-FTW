import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../theme/design_tokens.dart';
import 'learner_context_screen.dart';

/// Home screen for logged-in adults.
/// Learners are contexts, not identities.
/// Observation precedes analysis.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _learners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLearners();
  }

  Future<String?> _getToken() async {
    return supabase.auth.currentSession?.accessToken;
  }

  Future<void> _fetchLearners() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final token = await _getToken();
      print('[DEBUG] Token: ${token != null ? "${token.substring(0, 20)}..." : "NULL"}');
      if (token == null) {
        print('[DEBUG] No token - user not logged in');
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      // Debug: Check what observer_id the backend sees
      final debugResponse = await http.get(
        Uri.parse('$backendUrl/api/auth/debug'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      print('[DEBUG] Auth debug: ${debugResponse.body}');
      
      print('[DEBUG] Fetching from: $backendUrl/api/learners');
      final response = await http.get(
        Uri.parse('$backendUrl/api/learners'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('[DEBUG] Response status: ${response.statusCode}');
      print('[DEBUG] Response body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _learners = data is List ? data : [];
          _isLoading = false;
        });
        print('[DEBUG] Loaded ${_learners.length} learners');
      } else {
        print('[DEBUG] Non-200 response: ${response.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('[DEBUG] ERROR fetching learners: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
  }

  void _navigateToLearner(String learnerId, String alias) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LearnerContextScreen(
          learnerId: learnerId,
          learnerAlias: alias,
          hasCompletedSessions: false,
        ),
      ),
    );
  }

  /// Shows a dialog to add a new learner
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
        _fetchLearners();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added "$alias"')),
          );
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
            SnackBar(content: Text('Error: ${response.statusCode}')),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI Samasya',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _signOut,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(
                      'Sign out',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Main Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchLearners,
                color: AppColors.primary,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  children: [
                    const SizedBox(height: AppSpacing.sm),

                    // Welcome Section
                    Text(
                      'Welcome',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Select a learner to begin.',
                      style: theme.textTheme.bodyMedium,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Learners Section Header
                    Text(
                      'Learners',
                      style: theme.textTheme.titleLarge,
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Learners List
                    _buildContent(theme),

                    const SizedBox(height: AppSpacing.sm),

                    // Add learner button (opens dialog)
                    TextButton.icon(
                      onPressed: _showAddLearnerDialog,
                      icon: Icon(
                        Icons.add,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      label: Text(
                        'Add learner',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        alignment: Alignment.centerLeft,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // Ethics Statement
                    Text(
                      'This tool supports understanding learning patterns.\nObservational insights only — not a diagnostic assessment.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary.withOpacity(0.8),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Text('Loading...', style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    if (_learners.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          'No learners yet. Add one to get started.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      children: _learners.map((learner) {
        final learnerId = (learner['learner_id'] ?? '').toString();
        final alias = (learner['alias'] ?? 'Unknown').toString();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.card),
              onTap: () => _navigateToLearner(learnerId, alias),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(alias, style: theme.textTheme.bodyLarge),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Separate dialog widget for adding a learner
/// This avoids widget tree manipulation in the main screen
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
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Title
            Text(
              'Add learner',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            // Subtitle
            Text(
              'Create an alias to identify this learner.',
              style: theme.textTheme.bodySmall,
            ),

            const SizedBox(height: 20),

            // Text field
            TextField(
              controller: widget.controller,
              autofocus: true,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                labelText: 'Learner alias',
                hintText: 'e.g. "Child A" or "Student 1"',
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: _isValid ? (_) => _submit() : null,
            ),

            const SizedBox(height: 24),

            // Buttons - full width, stacked
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isValid ? _submit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _isValid ? AppColors.primary : AppColors.border,
                  foregroundColor: _isValid ? Colors.white : AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Add learner'),
              ),
            ),

            const SizedBox(height: 10),

            // Cancel as text button, centered
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.red.shade600,
                  ),
                ),
              ),
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
