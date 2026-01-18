import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/provider/auth_provider.dart';
import '../../friends/provider/friends_provider.dart';
import '../../friends/view/friend_requests_screen.dart';
import '../../friends/view/friends_list_screen.dart';
import '../../settings/view/settings_screen.dart';
import '../../tracking/provider/tracking_provider.dart';
import '../../tracking/view/tracking_requests_screen.dart';

/// Home dashboard screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final userId = context.read<AuthProvider>().user?.uid;
    if (userId != null) {
      final friendsProvider = context.read<FriendsProvider>();
      final trackingProvider = context.read<TrackingProvider>();

      friendsProvider.loadFriends(userId);
      friendsProvider.loadPendingRequests(userId);
      trackingProvider.loadPendingRequests(userId);
      trackingProvider.loadActiveTrackingSessions(userId);

      // Start sharing location if there are active tracking sessions
      _checkAndStartLocationSharing();
    }
  }

  /// Check if we should start sharing location
  Future<void> _checkAndStartLocationSharing() async {
    final userId = context.read<AuthProvider>().user?.uid;
    if (userId == null) return;

    final trackingProvider = context.read<TrackingProvider>();
    await trackingProvider.loadActiveTrackingSessions(userId);

    // If someone is tracking us, start sharing location
    if (trackingProvider.activeAsTracked.isNotEmpty) {
      trackingProvider.startSharingLocation(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TrackMate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              _buildWelcomeCard(),
              const SizedBox(height: 24),

              // Quick Actions Grid
              Text(
                'Quick Actions',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildQuickActionsGrid(),
              const SizedBox(height: 24),

              // Location Sharing Status
              _buildLocationSharingStatus(),
            ],
          ),
        ),
      ),
    );
  }

  /// Build welcome card
  Widget _buildWelcomeCard() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Text(
                      authProvider.username.isNotEmpty
                          ? authProvider.username[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome back,',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          authProvider.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Consumer<TrackingProvider>(
                builder: (context, trackingProvider, child) {
                  return Row(
                    children: [
                      Icon(
                        trackingProvider.isSharing
                            ? Icons.location_on
                            : Icons.location_off,
                        color: Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trackingProvider.isSharing
                            ? 'Location sharing is active'
                            : 'Location sharing is off',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build quick actions grid
  Widget _buildQuickActionsGrid() {
    return Consumer2<FriendsProvider, TrackingProvider>(
      builder: (context, friendsProvider, trackingProvider, child) {
        return GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // Friends
            _buildQuickActionCard(
              icon: Icons.people,
              title: 'Friends',
              count: friendsProvider.friends.length,
              color: AppTheme.successColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FriendsListScreen(),
                  ),
                );
              },
            ),

            // Friend Requests
            _buildQuickActionCard(
              icon: Icons.person_add,
              title: 'Friend Requests',
              count: friendsProvider.pendingRequestsCount,
              color: AppTheme.warningColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FriendRequestsScreen(),
                  ),
                );
              },
            ),

            // Tracking Requests
            _buildQuickActionCard(
              icon: Icons.location_searching,
              title: 'Tracking Requests',
              count: trackingProvider.pendingRequestsCount,
              color: AppTheme.primaryColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TrackingRequestsScreen(),
                  ),
                );
              },
            ),

            // Active Tracking
            _buildQuickActionCard(
              icon: Icons.share_location,
              title: 'Active Tracking',
              count: trackingProvider.activeAsTracker.length,
              color: AppTheme.infoColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TrackingRequestsScreen(),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  /// Build quick action card
  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            const SizedBox(height: 4),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Text(
                '0',
                style: TextStyle(color: AppTheme.textHint, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  /// Build location sharing status
  Widget _buildLocationSharingStatus() {
    return Consumer<TrackingProvider>(
      builder: (context, trackingProvider, child) {
        if (trackingProvider.activeAsTracked.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'People Tracking You',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: trackingProvider.activeAsTracked.map((request) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.successColor.withOpacity(0.2),
                      child: Text(
                        request.trackerUsername[0].toUpperCase(),
                        style: TextStyle(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(request.trackerUsername),
                    subtitle: const Text('Can see your location'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.successColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Live',
                          style: TextStyle(
                            color: AppTheme.successColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}
