import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationNameService {
  static const String _baseUrl = 'https://api.bigdatacloud.net/data/reverse-geocode-client';
  
  /// Get location name from coordinates using reverse geocoding
  static Future<String> getLocationName(double latitude, double longitude) async {
    try {
      final url = Uri.parse('$_baseUrl?latitude=$latitude&longitude=$longitude&localityLanguage=en');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Extract location name from response
        String locationName = '';
        
        if (data['locality'] != null && data['locality'].isNotEmpty) {
          locationName = data['locality'];
        } else if (data['city'] != null && data['city'].isNotEmpty) {
          locationName = data['city'];
        } else if (data['principalSubdivision'] != null && data['principalSubdivision'].isNotEmpty) {
          locationName = data['principalSubdivision'];
        } else if (data['countryName'] != null && data['countryName'].isNotEmpty) {
          locationName = data['countryName'];
        }
        
        // Add country if available and different from location
        if (data['countryName'] != null && 
            data['countryName'].isNotEmpty && 
            data['countryName'] != locationName) {
          locationName += ', ${data['countryName']}';
        }
        
        return locationName.isNotEmpty ? locationName : 'Unknown Location';
      } else {
        print('Reverse geocoding error: ${response.statusCode}');
        return 'Unknown Location';
      }
    } catch (e) {
      print('Error getting location name: $e');
      return 'Unknown Location';
    }
  }
  
  /// Get formatted location name with fallback
  static Future<String> getFormattedLocationName(double? latitude, double? longitude) async {
    if (latitude == null || longitude == null) {
      return 'Location not available';
    }
    
    try {
      final locationName = await getLocationName(latitude, longitude);
      return locationName;
    } catch (e) {
      return 'Unknown Location';
    }
  }
}
