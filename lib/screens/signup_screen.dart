import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../theme/design_tokens.dart';

/// Sign up screen - institutional, restrained
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created. You can now sign in.')),
        );
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.lg,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─────────────────────────────────────────────────────────
                  // Logo / Wordmark (centered, distinguished)
                  // ─────────────────────────────────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'NeuroPlay',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 40,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // ─────────────────────────────────────────────────────────
                  // Header
                  // ─────────────────────────────────────────────────────────
                  Text(
                    'Create account',
                    style: theme.textTheme.headlineMedium,
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // ─────────────────────────────────────────────────────────
                  // Error message
                  // ─────────────────────────────────────────────────────────
                  if (_errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],

                  // ─────────────────────────────────────────────────────────
                  // Email field
                  // ─────────────────────────────────────────────────────────
                  TextField(
                    controller: _emailController,
                    decoration: appInputDecoration(label: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: !_isLoading,
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // ─────────────────────────────────────────────────────────
                  // Password field
                  // ─────────────────────────────────────────────────────────
                  TextField(
                    controller: _passwordController,
                    decoration: appInputDecoration(label: 'Password'),
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    enabled: !_isLoading,
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // ─────────────────────────────────────────────────────────
                  // Confirm password field
                  // ─────────────────────────────────────────────────────────
                  TextField(
                    controller: _confirmPasswordController,
                    decoration: appInputDecoration(label: 'Confirm password'),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    enabled: !_isLoading,
                    onSubmitted: (_) => _signUp(),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // ─────────────────────────────────────────────────────────
                  // Sign up button
                  // ─────────────────────────────────────────────────────────
                  FilledButton(
                    onPressed: _isLoading ? null : _signUp,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create account'),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // ─────────────────────────────────────────────────────────
                  // Disclaimer
                  // ─────────────────────────────────────────────────────────
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
          ),
        ),
      ),
    );
  }
}
