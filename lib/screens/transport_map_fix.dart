// Helper functions for the transport service map and client interface
// To ensure proper null safety when accessing location data

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Safely extracts a LatLng from a location map
/// Returns null if any required field is missing
LatLng? safeGetLatLng(Map<String, dynamic>? location) {
  if (location == null) return null;
  
  // Check if location has the required fields
  if (!location.containsKey('latitude') || 
      !location.containsKey('longitude') ||
      location['latitude'] == null ||
      location['longitude'] == null) {
    return null;
  }
  
  try {
    final double lat = location['latitude'] is double 
        ? location['latitude'] 
        : double.parse(location['latitude'].toString());
    
    final double lng = location['longitude'] is double 
        ? location['longitude'] 
        : double.parse(location['longitude'].toString());
    
    return LatLng(lat, lng);
  } catch (e) {
    print('Error extracting LatLng from location data: $e');
    return null;
  }
}

/// Safely gets the address from a location map
/// Returns a default value if the address is null or empty
String safeGetAddress(Map<String, dynamic>? location, String defaultValue) {
  if (location == null) return defaultValue;
  
  // Check if location has address field
  if (!location.containsKey('address') || 
      location['address'] == null ||
      location['address'].toString().isEmpty) {
    return defaultValue;
  }
  
  return location['address'].toString();
}

/// Safely extracts location data with all needed safety checks
Map<String, dynamic> processLocationData(Map<String, dynamic>? service) {
  if (service == null) {
    return {'hasLocation': false};
  }
  
  // Check if service has location
  if (!service.containsKey('location') || 
      service['location'] == null ||
      service['location'] is! Map) {
    return {'hasLocation': false};
  }
  
  // Get the location map
  final locationData = service['location'] as Map<String, dynamic>;
  
  // Check for latitude and longitude
  if (!locationData.containsKey('latitude') || 
      !locationData.containsKey('longitude') ||
      locationData['latitude'] == null ||
      locationData['longitude'] == null) {
    return {
      'hasLocation': false,
      'hasAddress': locationData.containsKey('address') && 
                   locationData['address'] != null && 
                   locationData['address'].toString().isNotEmpty,
      'address': locationData.containsKey('address') ? 
                locationData['address'] : null,
    };
  }
  
  // Create a safe result
  return {
    'hasLocation': true,
    'latLng': LatLng(
      locationData['latitude'] is double ? 
        locationData['latitude'] : 
        double.parse(locationData['latitude'].toString()),
      locationData['longitude'] is double ? 
        locationData['longitude'] : 
        double.parse(locationData['longitude'].toString()),
    ),
    'hasAddress': locationData.containsKey('address') && 
                 locationData['address'] != null && 
                 locationData['address'].toString().isNotEmpty,
    'address': locationData.containsKey('address') ? 
              locationData['address'] : null,
  };
}
