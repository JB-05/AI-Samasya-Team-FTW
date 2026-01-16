import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../theme/design_tokens.dart';
import 'report_screen.dart';

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

  // Game state
  bool _gameStarted = false;
  bool _gameEnded = false;
  int _targetCount = 0;
  int _hitCount = 0;
  int _missCount = 0;

  // Current target (using relative position 0-1)
  bool _showTarget = false;
  double _targetX = 0.5; // Relative X (0-1)
  double _targetY = 0.5; // Relative Y (0-1)
  int _targetAppearedMs = 0;

  // Events to send
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
          _gameStarted = true;
        });
        _startGame();
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

  void _startGame() {
    // Show targets every 2-4 seconds, for 15 targets total
    _showNextTarget();
  }

  void _showNextTarget() {
    if (_targetCount >= 15 || !mounted) {
      _endGame();
      return;
    }

    // Random delay between targets (1.5-3 seconds)
    final delay = 1500 + _random.nextInt(1500);

    _targetTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted || _gameEnded) return;

      setState(() {
        _showTarget = true;
        _targetAppearedMs = DateTime.now().millisecondsSinceEpoch;
        // Random relative position (0.1 to 0.8 to keep away from edges)
        _targetX = 0.1 + _random.nextDouble() * 0.7;
        _targetY = 0.1 + _random.nextDouble() * 0.6;
        _targetCount++;
      });

      // Hide target after 2 seconds if not tapped (miss)
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
      _hitCount++;
    });

    // Record hit event
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
      _missCount++;
    });

    // Record miss event
    _events.add({
      'timestamp_ms': _targetAppearedMs + 2000, // Missed after timeout
      'target_appeared_ms': _targetAppearedMs,
      'was_hit': false,
    });
  }

  Future<void> _endGame() async {
    if (_gameEnded) return;
    
    setState(() {
      _gameEnded = true;
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

      // Send events
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

      // Complete session
      final response = await http.post(
        Uri.parse('$backendUrl/api/sessions/$_sessionId/complete'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200 && mounted) {
        // Navigate to report
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReportScreen(
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
        title: Text('Focus Tap - ${widget.learnerAlias}'),
        actions: [
          if (_gameStarted && !_gameEnded)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '$_targetCount / 15',
                  style: theme.textTheme.bodyLarge,
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Go back'),
            ),
          ],
        ),
      );
    }

    if (!_gameStarted) {
      return _buildStartScreen(theme);
    }

    if (_gameEnded) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Game complete!', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Processing results...', style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    return _buildGameScreen(theme);
  }

  Widget _buildStartScreen(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Focus Tap',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the circles as quickly as you can when they appear.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Text('Learner: ${widget.learnerAlias}',
                    style: theme.textTheme.bodyLarge),
                const SizedBox(height: 4),
                Text('15 targets will appear',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _startSession,
            child: const Text('Start'),
          ),
          const SizedBox(height: 48),
          Text(
            'This activity observes response patterns.\nIt is not a test or assessment.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGameScreen(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate actual position from relative coordinates
        final targetLeft = _targetX * (constraints.maxWidth - 80);
        final targetTop = _targetY * (constraints.maxHeight - 80);

        return Stack(
          children: [
            // Score display
            Positioned(
              top: 16,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hits: $_hitCount', style: theme.textTheme.bodySmall),
                  Text('Missed: $_missCount', style: theme.textTheme.bodySmall),
                ],
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

            // Target
            if (_showTarget)
              Positioned(
                left: targetLeft,
                top: targetTop,
                child: GestureDetector(
                  onTap: _onTargetTap,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryDark, width: 3),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.touch_app,
                        color: Colors.white,
                        size: 32,
                      ),
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
