import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final LocationService _locationService = LocationService();
  Completer<GoogleMapController> _mapController = Completer();
  StreamSubscription<Position>? _locationSubscription;
  
  Position? _currentPosition;
  String _lastUpdated = 'Never';
  bool _isTracking = false;
  bool _isLoading = true;
  String? _errorMessage;

  final Set<Marker> _markers = {};
  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(37.7749, -122.4194), // San Francisco
    zoom: 16.0,
  );

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Get initial location
      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        setState(() {
          _currentPosition = position;
          _isLoading = false;
          _lastUpdated = _locationService.getFormattedTimestamp(DateTime.now());
        });
        _updateMapMarker(position);
        _moveCameraToPosition(position);
      } else {
        setState(() {
          _errorMessage = 'Unable to get current location. Please check permissions and try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing location: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _startTracking() async {
    if (_isTracking) return;

    try {
      final success = await _locationService.startLocationTracking();
      if (success) {
        setState(() {
          _isTracking = true;
          _errorMessage = null;
        });

        _locationSubscription = _locationService.locationStream.listen(
          (Position position) {
            setState(() {
              _currentPosition = position;
              _lastUpdated = _locationService.getFormattedTimestamp(DateTime.now());
            });
            _updateMapMarker(position);
            _moveCameraToPosition(position);
          },
          onError: (error) {
            setState(() {
              _errorMessage = 'Location tracking error: $error';
            });
          },
        );
      } else {
        setState(() {
          _errorMessage = 'Failed to start location tracking. Please check permissions.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error starting tracking: $e';
      });
    }
  }

  void _stopTracking() {
    _locationService.stopLocationTracking();
    _locationSubscription?.cancel();
    setState(() {
      _isTracking = false;
    });
  }

  void _updateMapMarker(Position position) {
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Current position',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    });
  }

  void _moveCameraToPosition(Position position) {
    _mapController.future.then((controller) {
      controller.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
      );
    });
  }

  void _recenterMap() {
    if (_currentPosition != null) {
      _mapController.future.then((controller) {
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              zoom: 16.0,
            ),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _locationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Location'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _isTracking ? _stopTracking : _startTracking,
            icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
            tooltip: _isTracking ? 'Stop Tracking' : 'Start Tracking',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget()
              : _buildMapWidget(),
      floatingActionButton: _currentPosition != null
          ? FloatingActionButton(
              onPressed: _recenterMap,
              tooltip: 'Recenter Map',
              child: const Icon(Icons.my_location),
            )
          : null,
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_off,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Location Error',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeLocation,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapWidget() {
    return Column(
      children: [
        // Map Section
        Expanded(
          flex: 2,
          child: _currentPosition != null
              ? GoogleMap(
                  onMapCreated: (GoogleMapController controller) {
                    _mapController.complete(controller);
                    _moveCameraToPosition(_currentPosition!);
                  },
                  initialCameraPosition: _currentPosition != null
                      ? CameraPosition(
                          target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                          zoom: 16.0,
                        )
                      : _defaultPosition,
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  mapType: MapType.normal,
                )
              : const Center(
                  child: Text('No location data available'),
                ),
        ),
        
        // Location Details Section
        Expanded(
          flex: 1,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Location Details',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isTracking ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _isTracking ? 'LIVE' : 'STATIC',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                if (_currentPosition != null) ...[
                  _buildDetailRow('Latitude', _currentPosition!.latitude.toStringAsFixed(6)),
                  _buildDetailRow('Longitude', _currentPosition!.longitude.toStringAsFixed(6)),
                  _buildDetailRow('Accuracy', _locationService.getFormattedAccuracy(_currentPosition!.accuracy)),
                  _buildDetailRow('Speed', _locationService.getFormattedSpeed(_currentPosition!.speed)),
                  _buildDetailRow('Last Updated', _lastUpdated),
                ] else ...[
                  const Center(
                    child: Text('No location data available'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
