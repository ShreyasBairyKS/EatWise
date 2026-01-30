import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/platform_channel.dart';
import 'chatbot_controller.dart';

/// Main chat screen for ingredient analysis
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _ingredientSubscription;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startListening();
    _addWelcomeMessage();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reconnect stream when app resumes
    if (state == AppLifecycleState.resumed) {
      _startListening();
    }
  }

  void _addWelcomeMessage() {
    final controller = context.read<ChatbotController>();
    if (controller.messages.isEmpty) {
      controller.addMessage(ChatMessage(
        text: '👋 Welcome to EatWise!\n\n'
            'I help you understand food ingredients while you shop.\n\n'
            '📱 How to use:\n'
            '1. Open a shopping app (Swiggy, Blinkit, etc.)\n'
            '2. Go to any product page\n'
            '3. Tap the floating 🔍 icon\n'
            '4. Get instant health insights!\n\n'
            '💡 You can also:\n'
            '• Ask me questions about ingredients\n'
            '• Paste an ingredient list directly',
        isUser: false,
        type: MessageType.info,
      ));
    }
  }

  void _startListening() {
    if (_isListening) return;
    _isListening = true;

    _ingredientSubscription?.cancel();
    _ingredientSubscription = NativeBridge.ingredientStream().listen(
      (event) {
        if (!mounted) return;
        
        if (event['type'] == 'ingredientText') {
          final data = event['data'] as String?;
          if (data != null && data.isNotEmpty) {
            context.read<ChatbotController>().processIngredients(data);
            _scrollToBottom();
          }
        } else if (event['type'] == 'status') {
          final status = event['data'] as String?;
          if (status != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(status),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      },
      onError: (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
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
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/images/logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Text('🍎 ');
                },
              ),
            ),
            const SizedBox(width: 8),
            const Text('EatWise'),
          ],
        ),
        centerTitle: false,
        elevation: 1,
        actions: [
          // Manual scan button
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () async {
              await NativeBridge.startScan();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Scanning screen for ingredients...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Scan Now',
          ),
          // Clear chat
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear Chat?'),
                  content: const Text('This will remove all messages.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        context.read<ChatbotController>().clearMessages();
                        _addWelcomeMessage();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Clear Chat',
          ),
        ],
      ),
      body: Consumer<ChatbotController>(
        builder: (context, controller, _) {
          return Column(
            children: [
              // Scanning indicator
              if (controller.isScanning)
                Container(
                  color: Colors.green.shade50,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Scanning screen...'),
                    ],
                  ),
                ),

              // Chat messages
              Expanded(
                child: controller.messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: controller.messages.length +
                            (controller.isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == controller.messages.length) {
                            return _buildLoadingBubble();
                          }
                          return _buildMessageBubble(controller.messages[index]);
                        },
                      ),
              ),

              // Input area
              _buildInputArea(controller),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 20),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Open a shopping app and tap the\nfloating icon to scan ingredients',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Analyzing ingredients...'),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;

    // Get bubble color based on message type
    Color bubbleColor;
    if (isUser) {
      bubbleColor = Theme.of(context).colorScheme.primary;
    } else {
      switch (message.type) {
        case MessageType.error:
          bubbleColor = Colors.red.shade100;
          break;
        case MessageType.analysis:
          bubbleColor = Colors.green.shade50;
          break;
        default:
          bubbleColor = Colors.grey.shade200;
      }
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                color: isUser ? Colors.white70 : Colors.black45,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildInputArea(ChatbotController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Scan button
            IconButton(
              icon: Icon(
                Icons.document_scanner,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: () async {
                await NativeBridge.startScan();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Scanning screen for ingredients...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
              tooltip: 'Scan ingredients',
            ),

            // Text input
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Paste ingredients or ask a question...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                minLines: 1,
                onSubmitted: (_) => _sendMessage(controller),
              ),
            ),

            const SizedBox(width: 8),

            // Send button
            IconButton(
              icon: Icon(
                Icons.send,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: () => _sendMessage(controller),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage(ChatbotController controller) {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    _messageController.clear();
    
    // Check if text looks like an ingredient list (contains commas or common ingredient patterns)
    final lowerText = text.toLowerCase();
    final looksLikeIngredients = text.contains(',') ||
        lowerText.contains('ingredients') ||
        lowerText.contains('contains') ||
        (text.split(RegExp(r'[,;]')).length > 2);
    
    if (looksLikeIngredients) {
      // Process as ingredient list
      controller.processIngredients(text);
    } else {
      // Process as chat message
      controller.sendMessage(text);
    }
    _scrollToBottom();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ingredientSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
