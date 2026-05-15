import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_colors.dart';
import '../services/gemini_service.dart';

class AIChatPanel extends StatefulWidget {
  final String artifactTitle;
  final String history;
  final List<String> quickFacts;

  /// Bottom-sheet style (handle, rounded top, [Navigator.pop] close).
  /// When true: flat full-height layout for tab/shell use — pass [onDismiss] to go home.
  final bool embedAsFullPage;

  /// Close action when [embedAsFullPage] is true (e.g. shell [goHome]).
  final VoidCallback? onDismiss;

  const AIChatPanel({
    super.key,
    required this.artifactTitle,
    required this.history,
    required this.quickFacts,
    this.embedAsFullPage = false,
    this.onDismiss,
  });

  @override
  State<AIChatPanel> createState() => _AIChatPanelState();
}

class _AIChatPanelState extends State<AIChatPanel> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GeminiService _geminiService = GeminiService();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _geminiService.startArtifactChat(
      artifactTitle: widget.artifactTitle,
      history: widget.history,
      quickFacts: widget.quickFacts,
    );
    
    // Welcome message
    _messages.add(ChatMessage(
      text: "Hello! I'm your Ceylon Trails guide. Ask me anything about ${widget.artifactTitle}!",
      isUser: false,
    ));
  }

  void _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
      _controller.clear();
    });

    _scrollToBottom();

    try {
      if (!GeminiService.isApiKeySet) {
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          _messages.add(ChatMessage(
            text: GeminiService.missingCompileTimeKeyUserMessage,
            isUser: false,
          ));
          _isLoading = false;
        });
        _scrollToBottom();
        return;
      }

      var fullResponse = '';
      final responseStream = _geminiService.sendMessageStream(text);

      setState(() {
        _messages.add(ChatMessage(text: '', isUser: false));
      });

      await for (final chunk in responseStream) {
        setState(() {
          fullResponse += chunk;
          _messages.last = ChatMessage(text: fullResponse, isUser: false);
        });
        _scrollToBottom();
      }
    } catch (e, st) {
      debugPrint('Ceylon Trails Gemini error: $e');
      debugPrint('$st');
      setState(() {
        if (_messages.isNotEmpty &&
            !_messages.last.isUser &&
            _messages.last.text.isEmpty) {
          _messages.removeLast();
        }
        _messages.add(ChatMessage(
          text: GeminiService.userFacingErrorMessage(e),
          isUser: false,
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
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

  static const Color _forest = Color(0xFF0C3B2E);

  @override
  Widget build(BuildContext context) {
    if (widget.embedAsFullPage) {
      return DecoratedBox(
        decoration: const BoxDecoration(color: _forest),
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 0, 4),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI guide',
                        style: GoogleFonts.playfairDisplay(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                      tooltip: 'Close',
                      onPressed: () {
                        if (widget.onDismiss != null) {
                          widget.onDismiss!();
                        } else {
                          Navigator.of(context).maybePop();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Colors.white12),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return _ChatBubble(message: _messages[index]);
                  },
                ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Type your question…',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (_) => _handleSend(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _handleSend,
                      icon: const Icon(Icons.send_rounded, color: Colors.amber),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header (Expanded avoids overflow on long artifact titles)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ask about ${widget.artifactTitle}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          const Divider(color: Colors.white12),

          // Chat List
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _ChatBubble(message: msg);
                },
              ),
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.amber,
                ),
              ),
            ),

          // Input Area
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Type your question...",
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _handleSend,
                  icon: const Icon(Icons.send_rounded, color: Colors.amber),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.amber.withOpacity(0.9) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.black : Colors.white,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
