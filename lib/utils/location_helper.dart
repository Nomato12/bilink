import 'package:cloud_firestore/cloud_firestore.dart';

class LocationHelper {  /// Get location data from a Firestore document
  /// Returns a GeoPoint if location is found, null otherwise
  /// Handles multiple possible location data structures
  static GeoPoint? getLocationFromData(Map<String, dynamic> data) {
    try {
      // Case 1: Direct GeoPoint field
      if (data['location'] is GeoPoint) {
        return data['location'] as GeoPoint;
      }

      // Case 2: Nested location map with latitude/longitude
      if (data['location'] is Map) {
        final locationMap = data['location'] as Map<String, dynamic>;
        
        // Check for GeoPoint in location map
        if (locationMap['geopoint'] is GeoPoint) {
          return locationMap['geopoint'] as GeoPoint;
        }
        
        // Check for lat/long in location map
        if (locationMap.containsKey('latitude') && locationMap.containsKey('longitude')) {
          final lat = locationMap['latitude'];
          final lng = locationMap['longitude'];
          
          if (lat != null && lng != null) {
            try {
              final double latDouble = lat is double ? lat : double.parse(lat.toString());
              final double lngDouble = lng is double ? lng : double.parse(lng.toString());
              return GeoPoint(latDouble, lngDouble);
            } catch (e) {
              print('Error converting lat/lng to double: $e');
            }
          }
        }
      }

      // Case 3: Direct lat/long fields at root
      if (data['latitude'] != null && data['longitude'] != null) {
        try {
          final lat = data['latitude'];
          final lng = data['longitude'];
          final double latDouble = lat is double ? lat : double.parse(lat.toString());
          final double lngDouble = lng is double ? lng : double.parse(lng.toString());
          return GeoPoint(latDouble, lngDouble);
        } catch (e) {
          print('Error converting root lat/lng to double: $e');
        }
      }

      // Case 4: Transport request data
      if (data.containsKey('originLocation') && data['originLocation'] is Map) {
        final originMap = data['originLocation'] as Map<String, dynamic>;
        if (originMap.containsKey('latitude') && originMap.containsKey('longitude')) {
          try {
            final lat = originMap['latitude'];
            final lng = originMap['longitude'];
            if (lat != null && lng != null) {
              final double latDouble = lat is double ? lat : double.parse(lat.toString());
              final double lngDouble = lng is double ? lng : double.parse(lng.toString());
              return GeoPoint(latDouble, lngDouble);
            }
          } catch (e) {
            print('Error converting origin lat/lng to double: $e');
          }
        }
      }

      // Case 5: Last known location
      if (data['lastLocation'] is GeoPoint) {
        return data['lastLocation'] as GeoPoint;
      }

      // Case 6: Home location as fallback
      if (data['homeLocation'] is GeoPoint) {
        return data['homeLocation'] as GeoPoint;
      }
    } catch (e) {
      print('Error in getLocationFromData: $e');
    }

    return null;
  }

  /// Get address string from location data
  /// Returns a string with the address if found, empty string otherwise
  static String getAddressFromData(Map<String, dynamic> data) {
    try {
      // Case 1: Check in location map
      if (data['location'] is Map) {
        final locationMap = data['location'] as Map<String, dynamic>;
        if (locationMap.containsKey('address') && locationMap['address'] != null) {
          return locationMap['address'].toString();
        }
      }

      // Case 2: Direct address field at root
      if (data.containsKey('address') && data['address'] != null) {
        return data['address'].toString();
      }

      // Case 3: Client address field
      if (data.containsKey('clientAddress') && data['clientAddress'] != null) {
        return data['clientAddress'].toString();
      }
      
      // Case 4: Check address in home location
      if (data.containsKey('homeAddress') && data['homeAddress'] != null) {
        return data['homeAddress'].toString();
      }
    } catch (e) {
      print('Error in getAddressFromData: $e');
    }
    
    return '';
  }

  /// Check if location data is recent (within the last 10 minutes)
  static bool isLocationRecent(Map<String, dynamic> data) {
    try {
      Timestamp? locationTimestamp;
      
      // Case 1: Check timestamp in location map
      if (data['location'] is Map) {
        final locationMap = data['location'] as Map<String, dynamic>;
        if (locationMap.containsKey('timestamp') && locationMap['timestamp'] is Timestamp) {
          locationTimestamp = locationMap['timestamp'] as Timestamp;
        }
      }
      
      // Case 2: Check lastLocationTimestamp at root
      if (locationTimestamp == null && data.containsKey('lastLocationTimestamp') && 
          data['lastLocationTimestamp'] is Timestamp) {
        locationTimestamp = data['lastLocationTimestamp'] as Timestamp;
      }
      
      // Case 3: Check locationTimestamp at root
      if (locationTimestamp == null && data.containsKey('locationTimestamp') && 
          data['locationTimestamp'] is Timestamp) {
        locationTimestamp = data['locationTimestamp'] as Timestamp;
      }
      
      if (locationTimestamp != null) {
        final DateTime now = DateTime.now();
        final DateTime locationTime = locationTimestamp.toDate();
        // Check if the location is recent (within the last 10 minutes)
        return now.difference(locationTime).inMinutes < 10;
      }
    } catch (e) {
      print('Error in isLocationRecent: $e');
    }
    
    return false;
  }
}
