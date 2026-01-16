import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../theme/design_tokens.dart';
import '../theme/animation_tokens.dart';
import 'signup_screen.dart';

/// Login screen - institutional, restrained, human-centered
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToSignUp() {
    navigateSmoothly(context, const SignUpScreen());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
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

                  const SizedBox(height: AppSpacing.xl),

                  // ─────────────────────────────────────────────────────────
                  // Form section header
                  // ─────────────────────────────────────────────────────────
                  Text(
                    'Sign in to continue',
                    style: theme.textTheme.bodyLarge,
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // ─────────────────────────────────────────────────────────
                  // Error message (neutral, not alarming)
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
                    textInputAction: TextInputAction.done,
                    enabled: !_isLoading,
                    onSubmitted: (_) => _signIn(),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // ─────────────────────────────────────────────────────────
                  // Sign in button (solid, restrained)
                  // ─────────────────────────────────────────────────────────
                  FilledButton(
                    onPressed: _isLoading ? null : _signIn,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Sign in'),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // ─────────────────────────────────────────────────────────
                  // Create account link
                  // ─────────────────────────────────────────────────────────
                  Center(
                    child: TextButton(
                      onPressed: _isLoading ? null : _goToSignUp,
                      child: const Text('New here? Create an account'),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // ─────────────────────────────────────────────────────────
                  // Disclaimer (always visible)
                  // ─────────────────────────────────────────────────────────
                  const Divider(),
                  const SizedBox(height: AppSpacing.sm),

                  Text(
                    'This tool supports understanding learning patterns through observation.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
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
