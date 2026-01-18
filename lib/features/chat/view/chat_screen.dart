import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/helpers.dart';
import '../../auth/provider/auth_provider.dart';
import '../model/chat_message_model.dart';
import '../provider/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const String _callAppID = '845780799'; // Placeholder
  static const String _callAppSign = '71b509b146cf6b5d4d5d73af34245a5b12399e71da9dab038f10b320340d7b9c'; // Placeholder

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().startListeningToMessages();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    context.read<ChatProvider>().stopListening();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final authProvider = context.read<AuthProvider>();
    if (authProvider.user == null) return;

    context.read<ChatProvider>().sendMessage(
      senderId: authProvider.user!.uid,
      senderName: authProvider.username,
      text: text,
    );

    _controller.clear();
    // Scroll to top (since list is reversed)
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _startVideoCall(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user == null) return;

    final userID = authProvider.user!.uid;
    final userName = authProvider.username;

    // For a public chat room, we can use a fixed call ID, e.g., "global_call_room"
    // Or we could generate a new one. Let's use a fixed one for the "Chat Room" concept.
    const callID = "global_call_room_1";

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return ZegoUIKitPrebuiltCall(
            appID: int.tryParse(_callAppID) ?? 0, // Ensure this is replaced
            appSign: _callAppSign,
            userID: userID,
            userName: userName,
            callID: callID,
            config: ZegoUIKitPrebuiltCallConfig.groupVideoCall(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Chat Room'),
        actions: [
          IconButton(
            icon: const Icon(Icons.video_call),
            tooltip: 'Join Video Call',
            onPressed: () => _startVideoCall(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat List
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Say hi!',
                      style: TextStyle(color: AppTheme.textHint),
                    ),
                  );
                }

                final userId = context.read<AuthProvider>().user?.uid;

                return ListView.builder(
                  controller: _scrollController,
                  reverse:
                      true, // Show latest at bottom (standard chat) -> actually List is ordered DESC, so first item is latest.
                  // If we want standard chat behavior:
                  // List is [Latest, ..., Oldest]
                  // Reverse: true means index 0 is at bottom.
                  // So user sees Latest at bottom. Perfect.
                  itemCount: provider.messages.length,
                  itemBuilder: (context, index) {
                    final message = provider.messages[index];
                    final isMe = message.senderId == userId;

                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 5,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryColor,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
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

  Widget _buildMessageBubble(ChatMessageModel message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMe ? const Radius.circular(0) : null,
            bottomLeft: isMe ? null : const Radius.circular(0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                message.senderName,
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (!isMe) const SizedBox(height: 4),
            Text(
              message.text,
              style: TextStyle(color: isMe ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 2),
            Text(
              Helpers.formatRelativeTime(message.createdAt),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.black45,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
