import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../theme/design_tokens.dart';
import '../theme/animation_tokens.dart';
import 'report_screen.dart';

/// Focus tap observation activity
/// Neutral visual language - no celebratory elements
class FocusTapGameScreen extends StatefulWidget {
  final String learnerId;
  final String learnerAlias;

  const FocusTapGameScreen({
    super.key,
    required this.learnerId,
    required this.learnerAlias,
  });

  @override
  State<FocusTapGameScreen> createState() => _FocusTapGameScreenState();
}

class _FocusTapGameScreenState extends State<FocusTapGameScreen> {
  // Session state
  String? _sessionId;
  bool _isLoading = false;
  String? _error;

  // Activity state
  bool _activityStarted = false;
  bool _activityEnded = false;
  int _targetCount = 0;
  int _responseCount = 0;

  // Current target
  bool _showTarget = false;
  double _targetX = 0.5;
  double _targetY = 0.5;
  int _targetAppearedMs = 0;

  // Events
  final List<Map<String, dynamic>> _events = [];

  // Timers
  Timer? _targetTimer;
  Timer? _hideTimer;

  final Random _random = Random();

  @override
  void dispose() {
    _targetTimer?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  Future<String?> _getToken() async {
    return supabase.auth.currentSession?.accessToken;
  }

  Future<void> _startSession() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _getToken();
      if (token == null) {
        setState(() {
          _error = 'Session expired';
          _isLoading = false;
        });
        return;
      }

      final response = await http.post(
        Uri.parse('$backendUrl/api/sessions/start'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'learner_id': widget.learnerId,
          'game_type': 'focus_tap',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _sessionId = data['session_id'];
          _isLoading = false;
          _activityStarted = true;
        });
        _startActivity();
      } else {
        setState(() {
          _error = 'Could not start session';
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

  void _startActivity() {
    _showNextTarget();
  }

  void _showNextTarget() {
    if (_targetCount >= 15 || !mounted) {
      _endActivity();
      return;
    }

    final delay = 1500 + _random.nextInt(1500);

    _targetTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted || _activityEnded) return;

      setState(() {
        _showTarget = true;
        _targetAppearedMs = DateTime.now().millisecondsSinceEpoch;
        _targetX = 0.1 + _random.nextDouble() * 0.7;
        _targetY = 0.1 + _random.nextDouble() * 0.6;
        _targetCount++;
      });

      _hideTimer = Timer(const Duration(milliseconds: 2000), () {
        if (_showTarget && mounted) {
          _recordMiss();
          _showNextTarget();
        }
      });
    });
  }

  void _onTargetTap() {
    if (!_showTarget) return;

    _hideTimer?.cancel();

    final tapMs = DateTime.now().millisecondsSinceEpoch;

    setState(() {
      _showTarget = false;
      _responseCount++;
    });

    _events.add({
      'timestamp_ms': tapMs,
      'target_appeared_ms': _targetAppearedMs,
      'was_hit': true,
    });

    _showNextTarget();
  }

  void _recordMiss() {
    setState(() {
      _showTarget = false;
    });

    _events.add({
      'timestamp_ms': _targetAppearedMs + 2000,
      'target_appeared_ms': _targetAppearedMs,
      'was_hit': false,
    });
  }

  Future<void> _endActivity() async {
    if (_activityEnded) return;

    setState(() {
      _activityEnded = true;
      _showTarget = false;
      _isLoading = true;
    });

    try {
      final token = await _getToken();
      if (token == null || _sessionId == null) {
        setState(() {
          _error = 'Session error';
          _isLoading = false;
        });
        return;
      }

      if (_events.isNotEmpty) {
        await http.post(
          Uri.parse('$backendUrl/api/sessions/$_sessionId/events'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({'events': _events}),
        );
      }

      final response = await http.post(
        Uri.parse('$backendUrl/api/sessions/$_sessionId/complete'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200 && mounted) {
        Navigator.pushReplacement(
          context,
          SmoothPageRoute(
            page: ReportScreen(
              sessionId: _sessionId!,
              learnerAlias: widget.learnerAlias,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Could not complete session';
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
        title: Text(widget.learnerAlias),
        actions: [
          if (_activityStarted && !_activityEnded)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Center(
                child: Text(
                  '$_targetCount / 15',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.secondary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, style: theme.textTheme.bodyLarge),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_activityStarted) {
      return _buildStartScreen(theme);
    }

    if (_activityEnded) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Activity complete', style: theme.textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text('Processing observations...', style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    return _buildActivityScreen(theme);
  }

  Widget _buildStartScreen(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Focus observation',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tap the circles as they appear.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                children: [
                  Text(
                    'Learner: ${widget.learnerAlias}',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '15 targets will appear',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _startSession,
            child: const Text('Begin'),
          ),
          const SizedBox(height: AppSpacing.xl),
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
    );
  }

  Widget _buildActivityScreen(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final targetLeft = _targetX * (constraints.maxWidth - 72);
        final targetTop = _targetY * (constraints.maxHeight - 72);

        return Stack(
          children: [
            // Progress indicator
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
              child: Text(
                'Responses: $_responseCount',
                style: theme.textTheme.bodySmall,
              ),
            ),

            // Instruction
            if (!_showTarget)
              Center(
                child: Text(
                  'Wait for the circle...',
                  style: theme.textTheme.bodyMedium,
                ),
              ),

            // Target (neutral, no celebration)
            if (_showTarget)
              Positioned(
                left: targetLeft,
                top: targetTop,
                child: GestureDetector(
                  onTap: _onTargetTap,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
