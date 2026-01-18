import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/helpers.dart';
import '../../auth/provider/auth_provider.dart';
import '../provider/tracking_provider.dart';

/// Screen for managing tracking requests
class TrackingRequestsScreen extends StatefulWidget {
  const TrackingRequestsScreen({super.key});

  @override
  State<TrackingRequestsScreen> createState() => _TrackingRequestsScreenState();
}

class _TrackingRequestsScreenState extends State<TrackingRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    final userId = context.read<AuthProvider>().user?.uid;
    if (userId != null) {
      final provider = context.read<TrackingProvider>();
      provider.loadPendingRequests(userId);
      provider.loadActiveTrackingSessions(userId);
    }
  }

  /// Accept tracking request
  Future<void> _acceptRequest(String requestId) async {
    final userId = context.read<AuthProvider>().user?.uid;
    if (userId == null) return;

    final success = await context
        .read<TrackingProvider>()
        .acceptTrackingRequest(requestId, userId);

    if (mounted) {
      Helpers.showSnackBar(
        context,
        success ? 'Tracking request accepted' : 'Failed to accept request',
        isError: !success,
      );
    }
  }

  /// Reject tracking request
  Future<void> _rejectRequest(String requestId) async {
    final userId = context.read<AuthProvider>().user?.uid;
    if (userId == null) return;

    final success = await context
        .read<TrackingProvider>()
        .rejectTrackingRequest(requestId, userId);

    if (mounted) {
      Helpers.showSnackBar(
        context,
        success ? 'Tracking request rejected' : 'Failed to reject request',
        isError: !success,
      );
    }
  }

  /// Stop tracking
  Future<void> _stopTracking(String requestId) async {
    final userId = context.read<AuthProvider>().user?.uid;
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Tracking'),
        content: const Text(
          'Are you sure you want to stop sharing your location? '
          'They will no longer be able to see your location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Stop'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await context.read<TrackingProvider>().stopTracking(
        requestId,
        userId,
      );

      if (mounted) {
        Helpers.showSnackBar(
          context,
          success ? 'Tracking stopped' : 'Failed to stop tracking',
          isError: !success,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracking Requests'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Tracking Me'),
            Tab(text: 'I Track'),
          ],
        ),
      ),
      body: Consumer<TrackingProvider>(
        builder: (context, provider, child) {
          return TabBarView(
            controller: _tabController,
            children: [
              // Pending Requests Tab
              _buildPendingRequestsTab(provider),
              // Active Tracking (Being Tracked) Tab
              _buildBeingTrackedTab(provider),
              // People I'm Tracking Tab
              _buildTrackingOthersTab(provider),
            ],
          );
        },
      ),
    );
  }

  /// Build pending requests tab
  Widget _buildPendingRequestsTab(TrackingProvider provider) {
    if (provider.pendingRequests.isEmpty) {
      return _buildEmptyState(
        Icons.pending_actions,
        'No pending requests',
        'When someone requests to track you,\nit will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.pendingRequests.length,
        itemBuilder: (context, index) {
          final request = provider.pendingRequests[index];
          return _buildRequestCard(
            request.trackerUsername,
            'wants to track your location',
            Helpers.formatRelativeTime(request.createdAt),
            actions: [
              OutlinedButton(
                onPressed: () => _rejectRequest(request.requestId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                child: const Text('Reject'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _acceptRequest(request.requestId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                ),
                child: const Text('Accept'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Build being tracked tab
  Widget _buildBeingTrackedTab(TrackingProvider provider) {
    if (provider.activeAsTracked.isEmpty) {
      return _buildEmptyState(
        Icons.visibility_off,
        'No one is tracking you',
        'When you accept a tracking request,\nit will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.activeAsTracked.length,
        itemBuilder: (context, index) {
          final request = provider.activeAsTracked[index];
          return _buildRequestCard(
            request.trackerUsername,
            'can see your location',
            'Since ${Helpers.formatDate(request.createdAt)}',
            isActive: true,
            actions: [
              ElevatedButton.icon(
                onPressed: () => _stopTracking(request.requestId),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                icon: const Icon(Icons.stop, size: 18),
                label: const Text('Stop Sharing'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Build tracking others tab
  Widget _buildTrackingOthersTab(TrackingProvider provider) {
    if (provider.activeAsTracker.isEmpty) {
      return _buildEmptyState(
        Icons.location_searching,
        'Not tracking anyone',
        'When friends accept your tracking requests,\nthey will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.activeAsTracker.length,
        itemBuilder: (context, index) {
          final request = provider.activeAsTracker[index];
          return _buildRequestCard(
            request.trackedUsername,
            'is sharing location with you',
            'Since ${Helpers.formatDate(request.createdAt)}',
            isActive: true,
            actions: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/tracking-map',
                    arguments: {
                      'trackedUserId': request.trackedId,
                      'trackedUsername': request.trackedUsername,
                    },
                  );
                },
                icon: const Icon(Icons.map, size: 18),
                label: const Text('View on Map'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Build empty state widget
  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppTheme.textHint),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }

  /// Build request card
  Widget _buildRequestCard(
    String username,
    String subtitle,
    String time, {
    bool isActive = false,
    required List<Widget> actions,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isActive
                      ? AppTheme.successColor.withOpacity(0.2)
                      : AppTheme.primaryLight,
                  child: Text(
                    username[0].toUpperCase(),
                    style: TextStyle(
                      color: isActive
                          ? AppTheme.successColor
                          : AppTheme.primaryDark,
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
                        username,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
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
                          'Active',
                          style: TextStyle(
                            color: AppTheme.successColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(color: AppTheme.textHint, fontSize: 11),
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
          ],
        ),
      ),
    );
  }
}
