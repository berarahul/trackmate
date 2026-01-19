import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/helpers.dart';
import '../../auth/provider/auth_provider.dart';
import '../../friends/provider/friends_provider.dart';
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

  static const String _callAppID = '845780799';
  static const String _callAppSign =
      '71b509b146cf6b5d4d5d73af34245a5b12399e71da9dab038f10b320340d7b9c';

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  Future<void> _initializeChat() async {
    final authProvider = context.read<AuthProvider>();
    final friendsProvider = context.read<FriendsProvider>();
    final chatProvider = context.read<ChatProvider>();

    if (authProvider.user == null) return;

    // Load friends if not already loaded
    if (friendsProvider.friends.isEmpty) {
      await friendsProvider.loadFriends(authProvider.user!.uid);
    }

    // Get friend IDs including current user
    final friendIds = [
      authProvider.user!.uid,
      ...friendsProvider.friends.map((f) => f.friendId),
    ];

    // Initialize chat with friends
    chatProvider.initializeWithFriends(friendIds);
    chatProvider.startListeningToMessages(friendIds: friendIds);

    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final authProvider = context.read<AuthProvider>();
    if (authProvider.user == null) {
      _showSnackBar('Please login to send messages');
      return;
    }

    try {
      await context.read<ChatProvider>().sendMessage(
        senderId: authProvider.user!.uid,
        senderName: authProvider.username,
        text: text,
      );

      _controller.clear();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      _showSnackBar('Failed to send message');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<bool> _requestPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    if (cameraStatus.isGranted && micStatus.isGranted) {
      return true;
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permissions Required'),
          content: const Text(
            'Camera and microphone permissions are required for video calls. '
            'Please grant these permissions in your device settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
    return false;
  }

  void _startVideoCall(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final friendsProvider = context.read<FriendsProvider>();

    if (authProvider.user == null) {
      _showSnackBar('Please login to join video calls');
      return;
    }

    if (friendsProvider.friends.isEmpty) {
      _showSnackBar('Add friends to start a video call');
      return;
    }

    final hasPermissions = await _requestPermissions();
    if (!hasPermissions) return;

    final userID = authProvider.user!.uid;
    final userName = authProvider.username;

    // Use friend-based call room ID
    final callID = chatProvider.getCallRoomId();

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            return ZegoUIKitPrebuiltCall(
              appID: int.tryParse(_callAppID) ?? 0,
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
  }

  @override
  Widget build(BuildContext context) {
    final friendsProvider = context.watch<FriendsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          friendsProvider.friends.isEmpty
              ? 'Friends Chat'
              : 'Friends Chat (${friendsProvider.friends.length})',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.video_call),
            tooltip: 'Start Video Call with Friends',
            onPressed: friendsProvider.friends.isEmpty
                ? null
                : () => _startVideoCall(context),
          ),
        ],
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : friendsProvider.friends.isEmpty
          ? _buildNoFriendsState()
          : Column(
              children: [
                // Friends indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  child: Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Chatting with: ${friendsProvider.friends.map((f) => f.friendUsername).join(', ')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
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
                            'No messages yet. Say hi to your friends!',
                            style: TextStyle(color: AppTheme.textHint),
                          ),
                        );
                      }

                      final userId = context.read<AuthProvider>().user?.uid;

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
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

  Widget _buildNoFriendsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: AppTheme.textHint),
            const SizedBox(height: 16),
            Text(
              'No Friends Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add friends to start chatting and video calling with them.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textHint),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to home/friends section
                // This would typically use a navigation controller
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Find Friends'),
            ),
          ],
        ),
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
