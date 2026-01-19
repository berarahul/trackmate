import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/helpers.dart';
import '../../auth/provider/auth_provider.dart';
import '../../friends/provider/friends_provider.dart';
import '../provider/tracking_provider.dart';
import '../model/location_model.dart';

class GlobalMapScreen extends StatefulWidget {
  const GlobalMapScreen({super.key});

  @override
  State<GlobalMapScreen> createState() => _GlobalMapScreenState();
}

class _GlobalMapScreenState extends State<GlobalMapScreen>
    with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  MapType _currentMapType = MapType.normal;
  bool _isInit = false;
  bool _hasZoomedToUsers = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
    });
  }

  Future<void> _initializeMap() async {
    final authProvider = context.read<AuthProvider>();
    final trackingProvider = context.read<TrackingProvider>();
    final friendsProvider = context.read<FriendsProvider>();

    if (authProvider.user == null) return;

    final userId = authProvider.user!.uid;

    // Set user as active on map
    await trackingProvider.setMapActive(userId, true);

    // Load friends if not already loaded
    if (friendsProvider.friends.isEmpty) {
      await friendsProvider.loadFriends(userId);
    }

    // Get friend IDs
    final friendIds = friendsProvider.friends.map((f) => f.friendId).toList();

    // Start location sharing while on map
    if (!trackingProvider.isSharing) {
      await trackingProvider.startSharingLocation(userId, setActiveOnMap: true);
    }

    // Start streaming active friend locations
    trackingProvider.startActiveFriendLocationStream(friendIds);

    setState(() {
      _isInit = true;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deactivateMap();
    _mapController?.dispose();
    super.dispose();
  }

  void _deactivateMap() {
    final authProvider = context.read<AuthProvider>();
    final trackingProvider = context.read<TrackingProvider>();

    if (authProvider.user != null) {
      trackingProvider.setMapActive(authProvider.user!.uid, false);
      trackingProvider.stopActiveFriendLocationStream();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final authProvider = context.read<AuthProvider>();
    final trackingProvider = context.read<TrackingProvider>();

    if (authProvider.user == null) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App going to background - set inactive
      trackingProvider.setMapActive(authProvider.user!.uid, false);
    } else if (state == AppLifecycleState.resumed) {
      // App coming back - set active if map is visible
      trackingProvider.setMapActive(authProvider.user!.uid, true);
    }
  }

  /// Get username for a location
  String _getUsername(String friendId, FriendsProvider friendsProvider) {
    try {
      final friend = friendsProvider.friends.firstWhere(
        (f) => f.friendId == friendId,
      );
      return friend.friendUsername;
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Create markers for active user locations
  Set<Marker> _createMarkersWithNames(
    List<LocationModel> locations,
    FriendsProvider friendsProvider,
  ) {
    final markers = <Marker>{};

    for (final loc in locations) {
      final username = _getUsername(loc.userId, friendsProvider);
      final isMoving = _isLocationRecent(loc.updatedAt);

      markers.add(
        Marker(
          markerId: MarkerId(loc.userId),
          position: LatLng(loc.latitude, loc.longitude),
          infoWindow: InfoWindow(
            title: '$username ${isMoving ? "🟢" : ""}',
            snippet: 'Updated: ${Helpers.formatRelativeTime(loc.updatedAt)}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isMoving ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }
    return markers;
  }

  /// Check if location was updated recently (within last minute)
  bool _isLocationRecent(DateTime updatedAt) {
    return DateTime.now().difference(updatedAt).inSeconds < 60;
  }

  /// Auto-zoom to fit all active user locations
  void _zoomToFitLocations(List<LocationModel> locations) {
    if (locations.isEmpty || _mapController == null) return;

    if (locations.length == 1) {
      // Single user - zoom to their location
      final loc = locations.first;
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(loc.latitude, loc.longitude),
          15, // Zoom level for single user
        ),
      );
      return;
    }

    // Multiple users - fit bounds
    double minLat = locations.first.latitude;
    double maxLat = locations.first.latitude;
    double minLng = locations.first.longitude;
    double maxLng = locations.first.longitude;

    for (final loc in locations) {
      if (loc.latitude < minLat) minLat = loc.latitude;
      if (loc.latitude > maxLat) maxLat = loc.latitude;
      if (loc.longitude < minLng) minLng = loc.longitude;
      if (loc.longitude > maxLng) maxLng = loc.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80, // padding
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final friendsProvider = context.watch<FriendsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Friends Map'),
        actions: [
          PopupMenuButton<MapType>(
            icon: const Icon(Icons.layers),
            tooltip: 'Map Type',
            onSelected: (MapType result) {
              setState(() {
                _currentMapType = result;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<MapType>>[
              const PopupMenuItem<MapType>(
                value: MapType.normal,
                child: Text('Normal'),
              ),
              const PopupMenuItem<MapType>(
                value: MapType.satellite,
                child: Text('Satellite'),
              ),
              const PopupMenuItem<MapType>(
                value: MapType.hybrid,
                child: Text('Hybrid'),
              ),
            ],
          ),
          // Refresh button to re-zoom
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Zoom to active users',
            onPressed: () {
              final locations = context
                  .read<TrackingProvider>()
                  .activeFriendLocations;
              _zoomToFitLocations(locations);
            },
          ),
        ],
      ),
      body: !_isInit
          ? const Center(child: CircularProgressIndicator())
          : Consumer<TrackingProvider>(
              builder: (context, provider, child) {
                final locations = provider.activeFriendLocations;

                // Auto-zoom on first load when we have locations
                if (locations.isNotEmpty &&
                    !_hasZoomedToUsers &&
                    _mapController != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _zoomToFitLocations(locations);
                    _hasZoomedToUsers = true;
                  });
                }

                if (locations.isEmpty && friendsProvider.friends.isEmpty) {
                  return _buildNoFriendsState();
                }

                if (locations.isEmpty) {
                  return _buildNoActiveUsersState();
                }

                return Stack(
                  children: [
                    GoogleMap(
                      mapType: _currentMapType,
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(0, 0),
                        zoom: 2,
                      ),
                      markers: _createMarkersWithNames(
                        locations,
                        friendsProvider,
                      ),
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      onMapCreated: (controller) {
                        _mapController = controller;
                        // Auto-zoom after map is created
                        if (locations.isNotEmpty) {
                          Future.delayed(const Duration(milliseconds: 500), () {
                            _zoomToFitLocations(locations);
                            _hasZoomedToUsers = true;
                          });
                        }
                      },
                    ),
                    // Active users indicator
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.people,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${locations.length} active friend${locations.length != 1 ? 's' : ''} sharing location',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.5),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
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
              'Add friends to see their locations on the map.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textHint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoActiveUsersState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: AppTheme.textHint),
            const SizedBox(height: 16),
            Text(
              'No Active Friends',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'None of your friends are currently sharing their location.\nThey need to open the Map tab to share.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textHint),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Your location is being shared',
                    style: TextStyle(color: AppTheme.primaryColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
