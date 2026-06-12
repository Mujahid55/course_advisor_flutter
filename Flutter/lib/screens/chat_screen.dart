import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import 'dart:async' show TimeoutException;
import '../widgets/chat_bubble.dart';
import '../widgets/upload_banner.dart';
import '../widgets/suggestion_chips.dart';

class ChatScreen extends StatefulWidget {
  final void Function() onLogout;

  const ChatScreen({super.key, required this.onLogout});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _sessionId = const Uuid().v4();
  final _auth = AuthService();
  final _adminSvc = AdminService();

  bool _syllabusUploaded = false;
  bool _isUploading = false;
  bool _isSending = false;
  String? _uploadedFileName;
  List<Map<String, dynamic>> _pendingWarnings = [];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _messages.add(ChatMessage(
      content:
          "👋 **Welcome to CourseAdvisor!**\n\nI'm your AI-powered academic assistant. I can help you:\n\n"
          "📚 Recommend textbooks for your course\n"
          "🎯 Identify key topics from your syllabus\n"
          "📝 Summarize learning objectives\n"
          "💡 Guide your study strategy\n\n"
          "To get started, upload your course syllabus PDF using the button above!",
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
    ));

    _loadWarnings();
  }

  Future<void> _loadWarnings() async {
    try {
      final warnings = await _adminSvc.getMyWarnings();
      if (warnings.isNotEmpty && mounted) {
        setState(() {
          _pendingWarnings = warnings.cast<Map<String, dynamic>>();
        });
        _showWarningBanners();
      }
    } catch (_) {
      // ignore
    }
  }

  void _showWarningBanners() {
    for (final w in _pendingWarnings) {
      final msg = w['message'] as String? ?? '';
      final adminName = w['from_admin_name'] as String? ?? 'Admin';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Warning from $adminName: $msg',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFF59E0B),
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('Are you sure?', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _auth.logout();
      widget.onLogout();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final platformFile = result.files.single;

    setState(() {
      _isUploading = true;
      _uploadedFileName = platformFile.name;
    });

    _addUserMessage('📎 Uploading: ${platformFile.name}');

    try {
      final reply = await ApiService.uploadSyllabus(
        sessionId: _sessionId,
        platformFile: platformFile,
      );
      setState(() {
        _syllabusUploaded = true;
        _isUploading = false;
      });
      _addAssistantMessage(reply);
    } on ApiException catch (e) {
      setState(() => _isUploading = false);
      _addAssistantMessage('❌ **Upload failed.**\n\n${e.message}');
    } on TimeoutException {
      setState(() => _isUploading = false);
      _addAssistantMessage(
        '❌ **Upload timed out.**\n\nThe server took too long to respond. Please try again.',
      );
    } catch (e) {
      setState(() => _isUploading = false);
      _addAssistantMessage(
        '❌ **Upload failed.**\n\nPlease check your connection and make sure the backend is running.',
      );
    }
  }

  Future<void> _sendMessage([String? predefined]) async {
    final text = predefined ?? _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    _inputController.clear();
    _addUserMessage(text);
    setState(() => _isSending = true);

    final loadingMsg = ChatMessage(
      content: '',
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      isLoading: true,
    );
    setState(() => _messages.add(loadingMsg));
    _scrollToBottom();

    try {
      final reply = await ApiService.sendMessage(
        sessionId: _sessionId,
        message: text,
      );
      setState(() {
        _messages.remove(loadingMsg);
        _isSending = false;
      });
      _addAssistantMessage(reply);
    } on ApiException catch (e) {
      setState(() {
        _messages.remove(loadingMsg);
        _isSending = false;
      });
      _addAssistantMessage('❌ ${e.message}');
    } on TimeoutException {
      setState(() {
        _messages.remove(loadingMsg);
        _isSending = false;
      });
      _addAssistantMessage(
        '❌ The request timed out. Please check your connection and try again.',
      );
    } catch (e) {
      setState(() {
        _messages.remove(loadingMsg);
        _isSending = false;
      });
      _addAssistantMessage(
        '❌ Something went wrong. Please check your connection and try again.',
      );
    }
  }

  void _addUserMessage(String text) {
    setState(() => _messages.add(ChatMessage(
      content: text,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    )));
    _scrollToBottom();
  }

  void _addAssistantMessage(String text) {
    setState(() => _messages.add(ChatMessage(
      content: text,
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
    )));
    _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                _buildHeader(),
                UploadBanner(
                  isUploaded: _syllabusUploaded,
                  isUploading: _isUploading,
                  fileName: _uploadedFileName,
                  onTap: _pickAndUploadFile,
                ),
                Expanded(child: _buildMessageList()),
                SuggestionChips(
                  syllabusUploaded: _syllabusUploaded,
                  onSuggestionTap: _sendMessage,
                ),
                const SizedBox(height: 8),
                _buildInputBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text('🎓', style: TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CourseAdvisor',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    _syllabusUploaded ? '● Active' : 'AI Academic Assistant',
                    style: GoogleFonts.inter(
                      color: _syllabusUploaded
                          ? const Color(0xFF86EFAC)
                          : Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: _showInfoSheet,
                icon: const Icon(Icons.info_outline_rounded,
                    color: Colors.white, size: 24),
              ),
              IconButton(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded,
                    color: Colors.white, size: 22),
                tooltip: 'Sign Out',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) => ChatBubble(message: _messages[index]),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: const Color(0xFF1E293B),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ask about your syllabus...',
                        hintStyle: GoogleFonts.inter(
                          color: const Color(0xFF94A3B8),
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    onPressed: _pickAndUploadFile,
                    icon: const Icon(Icons.attach_file_rounded,
                        color: Color(0xFF94A3B8), size: 22),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'About CourseAdvisor',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'CourseAdvisor uses AI (RAG + GPT-4o-mini) to analyze your course syllabus and provide personalized academic guidance.\n\n'
              '🔒 Your session is private and unique\n'
              '📚 Recommends Saudi Digital Library resources\n'
              '🤖 Powered by OpenAI GPT-4o-mini',
              style: GoogleFonts.inter(
                color: const Color(0xFF475569),
                fontSize: 14,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Session ID: $_sessionId',
              style: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8), fontSize: 11),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
