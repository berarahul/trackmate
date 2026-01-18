import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/helpers.dart';
import '../provider/tracking_provider.dart';
import '../model/location_model.dart';

class GlobalMapScreen extends StatefulWidget {
  const GlobalMapScreen({super.key});

  @override
  State<GlobalMapScreen> createState() => _GlobalMapScreenState();
}

class _GlobalMapScreenState extends State<GlobalMapScreen> {
  GoogleMapController? _mapController;
  MapType _currentMapType = MapType.normal;
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TrackingProvider>().startGlobalLocationStream();
    });
  }

  @override
  void dispose() {
    // We don't stop the stream here because we might want to keep it alive
    // if we come back, or if the user switches tabs.
    // However, for battery, we should probably stop if we background.
    // For now, let's stop it to be safe.
    _mapController?.dispose();
    super.dispose();
  }

  /// Create markers for all locations
  String _getUsername(String userId, TrackingProvider provider) {
    try {
      final req = provider.activeAsTracker.firstWhere(
        (r) => r.trackedId == userId,
      );
      return req.trackedUsername;
    } catch (e) {
      return 'Unknown';
    }
  }

  Set<Marker> _createMarkersWithNames(
    List<LocationModel> locations,
    TrackingProvider provider,
  ) {
    final markers = <Marker>{};
    for (final loc in locations) {
      final username = _getUsername(loc.userId, provider);
      markers.add(
        Marker(
          markerId: MarkerId(loc.userId),
          position: LatLng(loc.latitude, loc.longitude),
          infoWindow: InfoWindow(
            title: username,
            snippet: Helpers.formatRelativeTime(loc.updatedAt),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Friends'),
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
        ],
      ),
      body: Consumer<TrackingProvider>(
        builder: (context, provider, child) {
          final locations = provider.globalLocations;

          if (locations.isEmpty && provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (locations.isEmpty) {
            // Check if we are even tracking anyone
            if (provider.activeAsTracker.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.supervised_user_circle_outlined,
                      size: 64,
                      color: AppTheme.textHint,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No active tracking sessions.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ask friends to accept your tracking requests.',
                      style: TextStyle(color: AppTheme.textHint, fontSize: 12),
                    ),
                  ],
                ),
              );
            }
            // We are tracking people, but no location data yet
            // Show map anyway (maybe centered on user?)
          }

          return GoogleMap(
            mapType: _currentMapType,
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0), // Should ideally be user's current location
              zoom: 2,
            ),
            markers: _createMarkersWithNames(locations, provider),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onMapCreated: (controller) {
              _mapController = controller;
              // If we have locations, zoom to fit them all
              if (locations.isNotEmpty && !_isInit) {
                _isInit = true;
                // Wait a bit for map to render
                Future.delayed(const Duration(milliseconds: 500), () {
                  _zoomToFit(locations);
                });
              }
            },
          );
        },
      ),
    );
  }

  void _zoomToFit(List<LocationModel> locations) {
    if (locations.isEmpty || _mapController == null) return;

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
        50, // padding
      ),
    );
  }
}
