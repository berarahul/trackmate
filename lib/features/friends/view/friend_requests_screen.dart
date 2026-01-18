import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/helpers.dart';
import '../../auth/provider/auth_provider.dart';
import '../provider/friends_provider.dart';

/// Screen for managing incoming friend requests
class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  void _loadRequests() {
    final userId = context.read<AuthProvider>().user?.uid;
    if (userId != null) {
      context.read<FriendsProvider>().loadPendingRequests(userId);
    }
  }

  /// Handle accept request
  Future<void> _acceptRequest(request) async {
    final userId = context.read<AuthProvider>().user?.uid;
    if (userId == null) return;

    final success = await context.read<FriendsProvider>().acceptFriendRequest(
      request,
      userId,
    );

    if (mounted) {
      if (success) {
        Helpers.showSnackBar(context, 'Friend request accepted!');
      } else {
        Helpers.showSnackBar(
          context,
          'Failed to accept request',
          isError: true,
        );
      }
    }
  }

  /// Handle reject request
  Future<void> _rejectRequest(String requestId) async {
    final userId = context.read<AuthProvider>().user?.uid;
    if (userId == null) return;

    final success = await context.read<FriendsProvider>().rejectFriendRequest(
      requestId,
      userId,
    );

    if (mounted) {
      if (success) {
        Helpers.showSnackBar(context, 'Friend request rejected');
      } else {
        Helpers.showSnackBar(
          context,
          'Failed to reject request',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Friend Requests')),
      body: Consumer<FriendsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.pendingRequests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: AppTheme.textHint,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pending requests',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When someone sends you a friend request,\nit will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textHint),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _loadRequests(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.pendingRequests.length,
              itemBuilder: (context, index) {
                final request = provider.pendingRequests[index];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppTheme.primaryLight,
                              child: Text(
                                request.fromUsername[0].toUpperCase(),
                                style: TextStyle(
                                  color: AppTheme.primaryDark,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    request.fromUsername,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Sent ${Helpers.formatRelativeTime(request.createdAt)}',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    _rejectRequest(request.requestId),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                ),
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _acceptRequest(request),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.successColor,
                                ),
                                child: const Text('Accept'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
