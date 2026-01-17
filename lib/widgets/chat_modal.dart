import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../theme/animation_tokens.dart';
import '../main.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// AI Chat Modal Widget
/// Full-screen modal for AI assistant chat
class ChatModal extends StatefulWidget {
  const ChatModal({super.key});

  @override
  State<ChatModal> createState() => _ChatModalState();
}

class _ChatModalState extends State<ChatModal> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Add welcome message
    _messages.add(ChatMessage(
      text: "Hello! I'm your NeuroPlay assistant. How can I help you today?",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
      _messageController.clear();
    });

    _scrollToBottom();

    try {
      // Call backend chat endpoint
      final token = supabase.auth.currentSession?.accessToken;
      if (token == null) {
        setState(() {
          _messages.add(ChatMessage(
            text: "Please log in to use the chat assistant.",
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isLoading = false;
        });
        _scrollToBottom();
        return;
      }

      final response = await http.post(
        Uri.parse('$backendUrl/api/chat'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': text,
          'conversation_history': _messages
              .where((m) => !m.isUser || m.text != text)
              .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.text,
              })
              .toList(),
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messages.add(ChatMessage(
            text: data['response'] ?? 'I apologize, but I could not process your request.',
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isLoading = false;
        });
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          _messages.add(ChatMessage(
            text: errorData['detail'] ?? 'Sorry, something went wrong. Please try again.',
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Unable to connect to the assistant. Please check your connection and try again.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'AI Assistant',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  // Loading indicator
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.message),
                          ),
                          child: const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),

          // Input area
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: TextStyle(color: AppColors.muted),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                      ),
                      style: const TextStyle(color: AppColors.textPrimary),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      enabled: !_isLoading,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    onPressed: _isLoading ? null : _sendMessage,
                    icon: Icon(
                      Icons.send,
                      color: _isLoading ? AppColors.muted : AppColors.primary,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: message.isUser ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.message),
                  topRight: const Radius.circular(AppRadius.message),
                  bottomLeft: Radius.circular(
                    message.isUser ? AppRadius.message : 0,
                  ),
                  bottomRight: Radius.circular(
                    message.isUser ? 0 : AppRadius.message,
                  ),
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser
                      ? Colors.white
                      : AppColors.textPrimary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.person_outline,
                size: 20,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
