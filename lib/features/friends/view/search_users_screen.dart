import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/helpers.dart';
import '../../auth/provider/auth_provider.dart';
import '../provider/friends_provider.dart';

/// Screen for searching users and sending friend requests
class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final _searchController = TextEditingController();
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    // Load sent requests to check status
    final userId = context.read<AuthProvider>().user?.uid;
    if (userId != null) {
      context.read<FriendsProvider>().loadSentRequests(userId);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Handle search
  void _handleSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final userId = context.read<AuthProvider>().user?.uid;
    if (userId != null) {
      context.read<FriendsProvider>().searchUsers(query, userId);
      setState(() {
        _hasSearched = true;
      });
    }
  }

  /// Handle send friend request
  Future<void> _sendFriendRequest(String toUserId, String toUsername) async {
    final authProvider = context.read<AuthProvider>();
    final friendsProvider = context.read<FriendsProvider>();

    final success = await friendsProvider.sendFriendRequest(
      fromUserId: authProvider.user!.uid,
      fromUsername: authProvider.user!.username,
      toUserId: toUserId,
      toUsername: toUsername,
    );

    if (mounted) {
      if (success) {
        Helpers.showSnackBar(context, 'Friend request sent!');
      } else {
        Helpers.showSnackBar(
          context,
          friendsProvider.errorMessage ?? 'Failed to send request',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Users')),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search by username...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _handleSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _handleSearch,
                  child: const Text('Search'),
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: Consumer<FriendsProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!_hasSearched) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: AppTheme.textHint),
                        const SizedBox(height: 16),
                        Text(
                          'Search for users by username',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.searchResults.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_off,
                          size: 64,
                          color: AppTheme.textHint,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No users found',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.searchResults.length,
                  itemBuilder: (context, index) {
                    final user = provider.searchResults[index];
                    final hasRequestSent = provider.hasRequestSentTo(user.uid);

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryLight,
                          child: Text(
                            user.username[0].toUpperCase(),
                            style: TextStyle(
                              color: AppTheme.primaryDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(user.username),
                        subtitle: user.email.isNotEmpty
                            ? Text(user.email)
                            : null,
                        trailing: hasRequestSent
                            ? const Chip(
                                label: Text('Pending'),
                                backgroundColor: Colors.orange,
                                labelStyle: TextStyle(color: Colors.white),
                              )
                            : ElevatedButton.icon(
                                onPressed: () =>
                                    _sendFriendRequest(user.uid, user.username),
                                icon: const Icon(Icons.person_add, size: 18),
                                label: const Text('Add'),
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
