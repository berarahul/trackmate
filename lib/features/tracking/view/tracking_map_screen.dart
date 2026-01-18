import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/helpers.dart';
import '../../auth/provider/auth_provider.dart';
import '../provider/tracking_provider.dart';

/// Screen for viewing tracked user's location on Google Maps
class TrackingMapScreen extends StatefulWidget {
  final String trackedUserId;
  final String trackedUsername;

  const TrackingMapScreen({
    super.key,
    required this.trackedUserId,
    required this.trackedUsername,
  });

  @override
  State<TrackingMapScreen> createState() => _TrackingMapScreenState();
}

class _TrackingMapScreenState extends State<TrackingMapScreen> {
  GoogleMapController? _mapController;
  MapType _currentMapType = MapType.normal;
  bool _isLoading = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndStartWatching();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    context.read<TrackingProvider>().stopWatchingLocation();
    super.dispose();
  }

  /// Check if user has permission to track
  Future<void> _checkPermissionAndStartWatching() async {
    final trackerId = context.read<AuthProvider>().user?.uid;
    if (trackerId == null) return;

    final trackingProvider = context.read<TrackingProvider>();
    final canTrack = await trackingProvider.canTrackUser(
      trackerId,
      widget.trackedUserId,
    );

    setState(() {
      _hasPermission = canTrack;
      _isLoading = false;
    });

    if (canTrack) {
      trackingProvider.startWatchingLocation(widget.trackedUserId);
    }
  }

  /// Open location in Google Maps app
  Future<void> _openInGoogleMaps(double lat, double lng) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Could not open Google Maps',
          isError: true,
        );
      }
    }
  }

  /// Move camera to location
  void _moveCameraToLocation(double lat, double lng) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tracking ${widget.trackedUsername}'),
        actions: [
          Consumer<TrackingProvider>(
            builder: (context, provider, child) {
              final location = provider.trackedUserLocation;
              if (location == null) return const SizedBox();

              return IconButton(
                icon: const Icon(Icons.my_location),
                tooltip: 'Center on location',
                onPressed: () => _moveCameraToLocation(
                  location.latitude,
                  location.longitude,
                ),
              );
            },
          ),
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
                value: MapType.terrain,
                child: Text('Terrain'),
              ),
              const PopupMenuItem<MapType>(
                value: MapType.hybrid,
                child: Text('Hybrid'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_hasPermission
          ? _buildNoPermissionView()
          : _buildMapView(),
    );
  }

  /// Build view when no permission
  Widget _buildNoPermissionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 80, color: AppTheme.textHint),
            const SizedBox(height: 24),
            Text(
              'Cannot Track',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.trackedUsername} has not accepted your tracking request yet, '
              'or has stopped sharing their location.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build map view
  Widget _buildMapView() {
    return Consumer<TrackingProvider>(
      builder: (context, provider, child) {
        final location = provider.trackedUserLocation;

        // Default to a location (will be updated when location is received)
        final initialPosition = location != null
            ? LatLng(location.latitude, location.longitude)
            : const LatLng(0, 0);

        return Stack(
          children: [
            // Google Map
            GoogleMap(
              mapType: _currentMapType,
              initialCameraPosition: CameraPosition(
                target: initialPosition,
                zoom: location != null ? 16 : 2,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                if (location != null) {
                  _moveCameraToLocation(location.latitude, location.longitude);
                }
              },
              markers: location != null
                  ? {
                      Marker(
                        markerId: MarkerId(widget.trackedUserId),
                        position: LatLng(location.latitude, location.longitude),
                        infoWindow: InfoWindow(
                          title: widget.trackedUsername,
                          snippet:
                              'Last updated: ${Helpers.formatRelativeTime(location.updatedAt)}',
                        ),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueAzure,
                        ),
                      ),
                    }
                  : {},
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),

            // Location Info Card
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildLocationInfoCard(location),
            ),

            // No location overlay
            if (location == null)
              Container(
                color: Colors.black26,
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.all(32),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Waiting for ${widget.trackedUsername}\'s location...',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'They need to have the app open and location sharing enabled.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textHint,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Build location info card at bottom
  Widget _buildLocationInfoCard(location) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryLight,
                  child: Text(
                    widget.trackedUsername[0].toUpperCase(),
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
                        widget.trackedUsername,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (location != null)
                        Row(
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
                            Text(
                              'Live',
                              style: TextStyle(
                                color: AppTheme.successColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),

            if (location != null) ...[
              const Divider(height: 24),

              // Coordinates
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      'Latitude',
                      location.latitude.toStringAsFixed(6),
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      'Longitude',
                      location.longitude.toStringAsFixed(6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Last updated
              _buildInfoItem(
                'Last Updated',
                Helpers.formatRelativeTime(location.updatedAt),
              ),
              const SizedBox(height: 16),

              // Open in Google Maps button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _openInGoogleMaps(location.latitude, location.longitude),
                  icon: const Icon(Icons.map),
                  label: const Text('Open in Google Maps'),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Location not available yet',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build info item
  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
