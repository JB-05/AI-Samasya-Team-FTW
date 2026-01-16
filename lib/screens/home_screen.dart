import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../theme/design_tokens.dart';
import 'learner_context_screen.dart';
import 'insights_screen.dart';

/// Home screen - learner list and management.
/// Clean, focused on the task at hand.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
        setState(() {
          _learners = data is List ? data : [];
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

  void _navigateToLearner(String learnerId, String alias, {bool hasSessions = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LearnerContextScreen(
          learnerId: learnerId,
          learnerAlias: alias,
          hasCompletedSessions: hasSessions,
        ),
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
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            const Text('AI Samasya'),
          ],
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLearners,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          children: [
            const SizedBox(height: AppSpacing.xs),

            // Welcome Section
            Text(
              'Welcome',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Select a learner to begin an activity.',
              style: theme.textTheme.bodyMedium,
            ),

            const SizedBox(height: AppSpacing.md),

            // Learners Section Header with Add button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Learners',
                  style: theme.textTheme.titleLarge,
                ),
                TextButton.icon(
                  onPressed: _showAddLearnerDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xs),

            // Learners List
            _buildLearnersList(theme),

            const SizedBox(height: AppSpacing.xl),

            // Ethics Statement
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Text(
                'This tool supports understanding learning patterns. '
                'Observational insights only — not a diagnostic assessment.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearnersList(ThemeData theme) {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: Column(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Loading learners...', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    if (_learners.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Icon(
                Icons.person_add_outlined,
                size: 40,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No learners yet',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Add a learner to get started.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                onPressed: _showAddLearnerDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add learner'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _learners.asMap().entries.map((entry) {
        final index = entry.key;
        final learner = entry.value;
        final learnerId = (learner['learner_id'] ?? '').toString();
        final alias = (learner['alias'] ?? 'Unknown').toString();
        // First learner has demo sessions
        final hasDemoSessions = index == 0;

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
              subtitle: hasDemoSessions
                  ? Text(
                      '2 sessions • Demo insights available',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                      ),
                    )
                  : null,
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
              onTap: () => _navigateToLearner(learnerId, alias, hasSessions: hasDemoSessions),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Dialog for adding a new learner
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
              Text(
                'Add learner',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create an alias to identify this learner.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: widget.controller,
                autofocus: true,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  labelText: 'Learner alias',
                  hintText: 'e.g. "Child A" or "Student 1"',
                  filled: true,
                  fillColor: AppColors.background,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: _isValid ? (_) => _submit() : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isValid ? _submit : null,
                  child: const Text('Add learner'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.red.shade600),
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
