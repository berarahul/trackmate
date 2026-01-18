import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/provider/auth_provider.dart';
import '../../tracking/provider/tracking_provider.dart';
import '../../tracking/view/tracking_map_screen.dart';
import '../provider/friends_provider.dart';
import 'search_users_screen.dart';

/// Screen displaying the list of friends
class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  void _loadFriends() {
    final userId = context.read<AuthProvider>().user?.uid;
    if (userId != null) {
      context.read<FriendsProvider>().loadFriends(userId);
    }
  }

  /// Show options for a friend
  void _showFriendOptions(String friendId, String friendUsername) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textHint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                friendUsername,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.location_on,
                  color: AppTheme.primaryColor,
                ),
                title: const Text('Send Tracking Request'),
                subtitle: const Text('Request to track their location'),
                onTap: () {
                  Navigator.pop(context);
                  _sendTrackingRequest(friendId, friendUsername);
                },
              ),
              ListTile(
                leading: const Icon(Icons.map, color: AppTheme.successColor),
                title: const Text('View Location'),
                subtitle: const Text(
                  'If they have accepted your tracking request',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _viewFriendLocation(friendId, friendUsername);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /// Send tracking request to friend
  Future<void> _sendTrackingRequest(
    String friendId,
    String friendUsername,
  ) async {
    final authProvider = context.read<AuthProvider>();
    final trackingProvider = context.read<TrackingProvider>();

    final success = await trackingProvider.sendTrackingRequest(
      trackerId: authProvider.user!.uid,
      trackerUsername: authProvider.user!.username,
      trackedId: friendId,
      trackedUsername: friendUsername,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Tracking request sent to $friendUsername'
                : trackingProvider.errorMessage ?? 'Failed to send request',
          ),
          backgroundColor: success
              ? AppTheme.successColor
              : AppTheme.errorColor,
        ),
      );
    }
  }

  /// View friend's location on map
  void _viewFriendLocation(String friendId, String friendUsername) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackingMapScreen(
          trackedUserId: friendId,
          trackedUsername: friendUsername,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Friend',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchUsersScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<FriendsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.friends.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people, size: 64, color: AppTheme.textHint),
                  const SizedBox(height: 16),
                  Text(
                    'No friends yet',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Search and add friends to start tracking',
                    style: TextStyle(color: AppTheme.textHint),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SearchUsersScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('Search Users'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _loadFriends(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.friends.length,
              itemBuilder: (context, index) {
                final friend = provider.friends[index];

                return Card(
                  child: ListTile(
                    onTap: () => _showFriendOptions(
                      friend.friendId,
                      friend.friendUsername,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.successColor.withOpacity(0.2),
                      child: Text(
                        friend.friendUsername[0].toUpperCase(),
                        style: TextStyle(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      friend.friendUsername,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      'Friends since ${friend.addedAt.day}/${friend.addedAt.month}/${friend.addedAt.year}',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppTheme.textHint,
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
