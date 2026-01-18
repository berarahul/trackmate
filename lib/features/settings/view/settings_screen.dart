import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/helpers.dart';
import '../../auth/provider/auth_provider.dart';
import '../../tracking/provider/tracking_provider.dart';
import '../provider/settings_provider.dart';

/// Settings screen for app configuration
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SettingsProvider>().initialize();
  }

  /// Handle interval change
  Future<void> _onIntervalChanged(int newInterval) async {
    final settingsProvider = context.read<SettingsProvider>();
    final trackingProvider = context.read<TrackingProvider>();
    final userId = context.read<AuthProvider>().user?.uid;

    await settingsProvider.setLocationInterval(newInterval);

    // Update tracking provider if sharing location
    if (userId != null) {
      await trackingProvider.updateLocationInterval(userId, newInterval);
    }

    if (mounted) {
      Helpers.showSnackBar(
        context,
        'Location update interval changed to ${settingsProvider.getIntervalDisplayText(newInterval)}',
      );
    }
  }

  /// Handle logout
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Stop location sharing if active
      context.read<TrackingProvider>().stopSharingLocation();
      // Logout
      await context.read<AuthProvider>().logout();

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return ListView(
            children: [
              // Location Settings Section
              _buildSectionHeader('Location Settings'),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.timer,
                        color: AppTheme.primaryColor,
                      ),
                      title: const Text('Location Update Interval'),
                      subtitle: Text(
                        'How often your location is shared when tracking is active',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ...settingsProvider.availableIntervals.map((interval) {
                      final isSelected =
                          interval == settingsProvider.locationInterval;
                      return RadioListTile<int>(
                        value: interval,
                        groupValue: settingsProvider.locationInterval,
                        onChanged: (value) {
                          if (value != null) {
                            _onIntervalChanged(value);
                          }
                        },
                        title: Text(
                          settingsProvider.getIntervalDisplayText(interval),
                        ),
                        subtitle: interval == 10
                            ? const Text(
                                'Recommended',
                                style: TextStyle(
                                  color: AppTheme.successColor,
                                  fontSize: 12,
                                ),
                              )
                            : interval == 5
                            ? const Text(
                                'Uses more battery',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        activeColor: AppTheme.primaryColor,
                        selected: isSelected,
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Tracking Status Section
              _buildSectionHeader('Tracking Status'),
              Consumer<TrackingProvider>(
                builder: (context, trackingProvider, child) {
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            trackingProvider.isSharing
                                ? Icons.location_on
                                : Icons.location_off,
                            color: trackingProvider.isSharing
                                ? AppTheme.successColor
                                : AppTheme.textHint,
                          ),
                          title: const Text('Location Sharing'),
                          subtitle: Text(
                            trackingProvider.isSharing
                                ? 'Actively sharing your location'
                                : 'Not sharing location',
                          ),
                          trailing: trackingProvider.isSharing
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.successColor.withOpacity(
                                      0.2,
                                    ),
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
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                        ),
                        if (trackingProvider.activeAsTracked.isNotEmpty) ...[
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(
                              Icons.people,
                              color: AppTheme.infoColor,
                            ),
                            title: Text(
                              '${trackingProvider.activeAsTracked.length} people can see your location',
                            ),
                            subtitle: Text(
                              trackingProvider.activeAsTracked
                                  .map((r) => r.trackerUsername)
                                  .join(', '),
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Account Section
              _buildSectionHeader('Account'),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, child) {
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryLight,
                            child: Text(
                              authProvider.username.isNotEmpty
                                  ? authProvider.username[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: AppTheme.primaryDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(authProvider.username),
                          subtitle: Text(
                            authProvider.user?.email ?? 'No email',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text(
                        'Logout',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: _handleLogout,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // App Info
              Center(
                child: Text(
                  'TrackMate v1.0.0',
                  style: TextStyle(color: AppTheme.textHint, fontSize: 12),
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  /// Build section header
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
