// Helper functions for the transport service map and client interface
// To ensure proper null safety when accessing location data

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Helper function to parse and validate coordinates
LatLng? _parseAndValidateLatLng(dynamic latRaw, dynamic lngRaw, String source) {
  if (latRaw == null || lngRaw == null) {
    print('DEBUG: Null latitude or longitude value from $source before parsing. Raw lat: $latRaw, Raw lng: $lngRaw');
    return null;
  }

  double? lat;
  double? lng;

  if (latRaw is num) {
    lat = latRaw.toDouble();
  } else if (latRaw is String) {
    lat = double.tryParse(latRaw);
  } else {
    print('DEBUG: Latitude from $source is not num or String: ${latRaw.runtimeType}');
  }

  if (lngRaw is num) {
    lng = lngRaw.toDouble();
  } else if (lngRaw is String) {
    lng = double.tryParse(lngRaw);
  } else {
    print('DEBUG: Longitude from $source is not num or String: ${lngRaw.runtimeType}');
  }

  if (lat != null && lng != null) {
    if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
      print('DEBUG: Using $source: Lat $lat, Lng $lng');
      return LatLng(lat, lng);
    } else {
      print('DEBUG: Invalid coordinates from $source after parsing: Lat $lat, Lng $lng. Out of range.');
      return null;
    }
  } else {
    print('DEBUG: Failed to parse latitude/longitude from $source. Parsed lat: $lat, Parsed lng: $lng. Raw values: Lat $latRaw, Lng $lngRaw.');
    return null;
  }
}

/// Safely extracts a LatLng from a location map
/// Returns null if any required field is missing or invalid
LatLng? safeGetLatLng(Map<String, dynamic>? location) {
  if (location == null) {
    print('DEBUG: safeGetLatLng called with null location');
    return null;
  }

  // Try getting location from 'position' map
  if (location.containsKey('position')) {
    final positionData = location['position'];
    if (positionData is Map<String, dynamic>) {
      // 1. Check for GeoPoint within 'position'
      if (positionData.containsKey('geopoint')) {
        final geopointData = positionData['geopoint'];
        if (geopointData is GeoPoint) {
          // Validate GeoPoint coordinates
          if (geopointData.latitude >= -90 && geopointData.latitude <= 90 &&
              geopointData.longitude >= -180 && geopointData.longitude <= 180) {
            print('DEBUG: Using GeoPoint from position: ${geopointData.latitude}, ${geopointData.longitude}');
            return LatLng(geopointData.latitude, geopointData.longitude);
          } else {
            print('DEBUG: Invalid GeoPoint coordinates from position: Lat ${geopointData.latitude}, Lng ${geopointData.longitude}');
            // Do not return here, continue to check other formats within 'position'
          }
        } else if (geopointData != null) {
          print('DEBUG: \'geopoint\' in position is not a GeoPoint type: ${geopointData.runtimeType}, value: $geopointData');
        }
      }

      // 2. Check for 'latitude'/'longitude' within 'position'
      // This check should be performed even if 'geopoint' was present but invalid
      if (positionData.containsKey('latitude') && positionData.containsKey('longitude')) {
        LatLng? parsedLatLng = _parseAndValidateLatLng(
          positionData['latitude'],
          positionData['longitude'],
          'latitude/longitude from position'
        );
        if (parsedLatLng != null) return parsedLatLng;
      }
    } else if (positionData != null) {
      print('DEBUG: \'position\' field is not a Map: ${positionData.runtimeType}, value: $positionData');
    }
  }

  // Try getting location from root of the map
  // 3. Check for GeoPoint at root
  if (location.containsKey('geopoint')) {
    final geopointData = location['geopoint'];
    if (geopointData is GeoPoint) {
      // Validate GeoPoint coordinates
      if (geopointData.latitude >= -90 && geopointData.latitude <= 90 &&
          geopointData.longitude >= -180 && geopointData.longitude <= 180) {
        print('DEBUG: Using GeoPoint from root: ${geopointData.latitude}, ${geopointData.longitude}');
        return LatLng(geopointData.latitude, geopointData.longitude);
      } else {
        print('DEBUG: Invalid GeoPoint coordinates from root: Lat ${geopointData.latitude}, Lng ${geopointData.longitude}');
        // Do not return here, continue to check root lat/lng
      }
    } else if (geopointData != null) {
      print('DEBUG: \'geopoint\' at root is not a GeoPoint type: ${geopointData.runtimeType}, value: $geopointData');
    }
  }

  // 4. Check for 'latitude'/'longitude' at root
  // This check should be performed even if root 'geopoint' was present but invalid
  if (location.containsKey('latitude') && location.containsKey('longitude')) {
    LatLng? parsedLatLng = _parseAndValidateLatLng(
      location['latitude'],
      location['longitude'],
      'root latitude/longitude'
    );
    if (parsedLatLng != null) return parsedLatLng;
  }
  
  print('DEBUG: Could not find valid location data in any expected format after all checks for location: $location');
  return null;
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
