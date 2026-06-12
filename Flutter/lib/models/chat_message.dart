enum MessageRole { user, assistant }

class ChatMessage {
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final bool isLoading;

  const ChatMessage({
    required this.content,
    required this.role,
    required this.timestamp,
    this.isLoading = false,
  });

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;
}
