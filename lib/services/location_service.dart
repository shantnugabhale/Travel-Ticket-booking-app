import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'location_name_service.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final StreamController<Position> _locationController = StreamController<Position>.broadcast();
  Stream<Position> get locationStream => _locationController.stream;

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;
  
  String _currentLocationName = 'Getting location...';
  String get currentLocationName => _currentLocationName;

  bool _isTracking = false;
  bool get isTracking => _isTracking;

  StreamSubscription<Position>? _positionStreamSubscription;

  /// Request location permissions
  Future<bool> requestLocationPermission() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable location services in your device settings.');
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied. Please allow location access in your device settings.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied. Please enable location access in your device settings and restart the app.');
      }

      return true;
    } catch (e) {
      print('Error requesting location permission: $e');
      return false;
    }
  }

  /// Get current location once
  Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      
      // Get location name
      _currentLocationName = await LocationNameService.getFormattedLocationName(
        _currentPosition!.latitude, 
        _currentPosition!.longitude
      );
      
      _locationController.add(_currentPosition!);
      return _currentPosition;
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  /// Start continuous location tracking
  Future<bool> startLocationTracking() async {
    try {
      if (_isTracking) return true;

      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) return false;

      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      );

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) async {
          _currentPosition = position;
          
          // Get location name for new position
          _currentLocationName = await LocationNameService.getFormattedLocationName(
            position.latitude, 
            position.longitude
          );
          
          _locationController.add(position);
        },
        onError: (error) {
          print('Error in location stream: $error');
          _locationController.addError(error);
        },
      );

      _isTracking = true;
      return true;
    } catch (e) {
      print('Error starting location tracking: $e');
      return false;
    }
  }

  /// Stop location tracking
  void stopLocationTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _isTracking = false;
  }

  /// Calculate distance between two positions
  double calculateDistance(Position pos1, Position pos2) {
    return Geolocator.distanceBetween(
      pos1.latitude,
      pos1.longitude,
      pos2.latitude,
      pos2.longitude,
    );
  }

  /// Get formatted speed
  String getFormattedSpeed(double? speed) {
    if (speed == null || speed < 0) return 'N/A';
    return '${(speed * 3.6).toStringAsFixed(1)} km/h';
  }

  /// Get formatted accuracy
  String getFormattedAccuracy(double? accuracy) {
    if (accuracy == null) return 'N/A';
    return '${accuracy.toStringAsFixed(1)} m';
  }

  /// Get formatted timestamp
  String getFormattedTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }

  /// Dispose resources
  void dispose() {
    stopLocationTracking();
    _locationController.close();
  }
}
