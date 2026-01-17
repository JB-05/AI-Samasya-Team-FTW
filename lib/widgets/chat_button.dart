import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'chat_modal.dart';

/// Floating Chat Button Widget
/// Small floating action button in bottom right corner
class ChatButton extends StatelessWidget {
  const ChatButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Calculate position above bottom navigation bar
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final navigationBarHeight = 65.0; // Height of NavigationBar
    
    return Positioned(
      bottom: bottomPadding + navigationBarHeight - 8, // Overlap slightly with nav bar (closer)
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ChatModal(),
                fullscreenDialog: true,
              ),
            );
          },
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
