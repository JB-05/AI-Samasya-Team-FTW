import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../theme/design_tokens.dart';

/// Learners Management Screen
/// For managing learner aliases (add, remove).
/// Activity flows are handled via LearnerContextScreen from Home.
class LearnersScreen extends StatefulWidget {
  const LearnersScreen({super.key});

  @override
  State<LearnersScreen> createState() => _LearnersScreenState();
}

class _LearnersScreenState extends State<LearnersScreen> {
  List<dynamic> _learners = [];
  bool _isLoading = true;
  String? _errorMessage;
  final _aliasController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLearners();
  }

  @override
  void dispose() {
    _aliasController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    return supabase.auth.currentSession?.accessToken;
  }

  Future<void> _fetchLearners() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _getToken();
      if (token == null) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Session expired';
          _isLoading = false;
        });
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
        setState(() {
          _errorMessage = 'Could not load learners';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Connection error';
        _isLoading = false;
      });
    }
  }

  Future<void> _addLearner() async {
    final alias = _aliasController.text.trim();
    if (alias.isEmpty) return;

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
        _aliasController.clear();
        _fetchLearners();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added "$alias"')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add learner')),
        );
      }
    }
  }

  Future<void> _deleteLearner(String learnerId, String alias) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text('Remove learner'),
        content: Text('Remove "$alias"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = await _getToken();
      if (token == null) return;

      final response = await http.delete(
        Uri.parse('$backendUrl/api/learners/$learnerId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        _fetchLearners();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Learner removed')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove learner')),
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
        title: const Text('Manage learners'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add learner form
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add a learner', style: theme.textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _aliasController,
                          decoration: InputDecoration(
                            hintText: 'Alias (e.g. "Learner A")',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addLearner(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 44,
                        child: FilledButton(
                          onPressed: _addLearner,
                          child: const Text('Add'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text('Loading...'),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? _buildErrorState(theme)
                      : _learners.isEmpty
                          ? _buildEmptyState(theme)
                          : _buildLearnersList(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage ?? 'Unknown error',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _fetchLearners,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('No learners yet', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 4),
            Text(
              'Add a learner alias above to get started.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearnersList(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _fetchLearners,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.sm),
        itemCount: _learners.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final learner = _learners[index];
          final learnerId = (learner['learner_id'] ?? '').toString();
          final alias = (learner['alias'] ?? 'Unknown').toString();

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
                // Alias text only
                Expanded(
                  child: Text(alias, style: theme.textTheme.bodyLarge),
                ),
                // Remove button
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.textSecondary,
                  onPressed: () => _deleteLearner(learnerId, alias),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remove learner',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
