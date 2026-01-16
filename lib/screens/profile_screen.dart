import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../theme/design_tokens.dart';
import '../theme/animation_tokens.dart';

/// Profile screen - utility + trust surface
/// Restrained, calming, institutional
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  
  // Staggered fade-in states
  bool _accountVisible = false;
  bool _actionsVisible = false;
  bool _appInfoVisible = false;

  // Muted red for destructive actions (not alarming)
  static const Color _destructiveColor = Color(0xFFB85C5C);

  @override
  void initState() {
    super.initState();
    _user = supabase.auth.currentUser;
    _startFadeInSequence();
  }

  void _startFadeInSequence() {
    // Staggered fade-in with <100ms delays
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _accountVisible = true);
      
      Future.delayed(const Duration(milliseconds: 60), () {
        if (!mounted) return;
        setState(() => _actionsVisible = true);
      });
      
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) return;
        setState(() => _appInfoVisible = true);
      });
    });
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          // ─────────────────────────────────────────────────────────────
          // Account Card (fade-in first)
          // ─────────────────────────────────────────────────────────────
          AnimatedOpacity(
            opacity: _accountVisible ? 1.0 : 0.0,
            duration: kCrossFadeDuration,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    
                    // Email row
                    Row(
                      children: [
                        Icon(
                          Icons.mail_outline,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _user?.email ?? 'Not signed in',
                                style: theme.textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Signed in account',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    // Role indicator (optional future use)
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Role: Parent',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ─────────────────────────────────────────────────────────────
          // Sign Out (fade-in second, destructive secondary action)
          // ─────────────────────────────────────────────────────────────
          AnimatedOpacity(
            opacity: _actionsVisible ? 1.0 : 0.0,
            duration: kCrossFadeDuration,
            child: OutlinedButton(
              onPressed: _signOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: _destructiveColor,
                side: BorderSide(color: _destructiveColor.withOpacity(0.4)),
              ),
              child: const Text('Sign out'),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ─────────────────────────────────────────────────────────────
          // App Information (fade-in last)
          // ─────────────────────────────────────────────────────────────
          AnimatedOpacity(
            opacity: _appInfoVisible ? 1.0 : 0.0,
            duration: kCrossFadeDuration,
            child: Column(
              children: [
                // App name
                Text(
                  'NeuroPlay',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                
                // Version
                Text(
                  'Version 0.1.0',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                
                const SizedBox(height: AppSpacing.sm),
                
                // Tagline
                Text(
                  'Designed for observational learning insights.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.md),
                
                // Divider
                const Divider(),
                
                const SizedBox(height: AppSpacing.md),

                // Disclaimer
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
          
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
