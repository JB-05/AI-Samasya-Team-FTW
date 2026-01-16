import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/design_tokens.dart';
import 'login_screen.dart';

/// Profile screen with user info and sign out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await supabase.auth.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = supabase.auth.currentUser;
    final email = user?.email ?? 'Unknown';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          children: [
            const SizedBox(height: AppSpacing.md),

            // Profile Avatar
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Icon(
                  Icons.person,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Email
            Center(
              child: Text(
                email,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xs),

            // Role badge
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Observer',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Settings Section
            Text(
              'Settings',
              style: theme.textTheme.titleLarge,
            ),

            const SizedBox(height: AppSpacing.sm),

            // About Card
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline, color: AppColors.textSecondary),
                title: Text('About AI Samasya', style: theme.textTheme.bodyLarge),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon')),
                  );
                },
              ),
            ),

            const SizedBox(height: AppSpacing.xs),

            // Privacy Card
            Card(
              child: ListTile(
                leading: const Icon(Icons.shield_outlined, color: AppColors.textSecondary),
                title: Text('Privacy & Data', style: theme.textTheme.bodyLarge),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon')),
                  );
                },
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Sign Out Button
            OutlinedButton.icon(
              onPressed: () => _signOut(context),
              icon: Icon(Icons.logout, color: Colors.red.shade600),
              label: Text(
                'Sign out',
                style: TextStyle(color: Colors.red.shade600),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Disclaimer
            Text(
              'AI Samasya provides observational insights only. '
              'It is not a diagnostic tool. Consult professionals for concerns.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.sm),

            // Version
            Center(
              child: Text(
                'Version 1.0.0',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary.withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
