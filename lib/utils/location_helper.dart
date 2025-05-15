import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';

class LocationHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get location data from a Firestore document
  /// Returns a GeoPoint if location is found, null otherwise
  /// Handles multiple possible location data structures
  static GeoPoint? getLocationFromData(Map<String, dynamic> data) {    try {
      // Case 1: Direct GeoPoint field
      if (data['location'] is GeoPoint) {
        return data['location'] as GeoPoint;
      }

      // Case 1b: Check locationData map for client coordinates
      if (data.containsKey('locationData') && data['locationData'] is Map) {
        final locationDataMap = data['locationData'] as Map<String, dynamic>;
        if (locationDataMap.containsKey('clientCoords')) {
          try {
            final String clientCoords = locationDataMap['clientCoords'] as String;
            final List<String> parts = clientCoords.split(',');
            if (parts.length == 2) {
              return GeoPoint(
                double.parse(parts[0]), 
                double.parse(parts[1])
              );
            }
          } catch (e) {
            print('Error parsing clientCoords: $e');
          }
        }
      }

      // Case 2: Nested location map with latitude/longitude
      if (data['location'] is Map) {
        final locationMap = data['location'] as Map<String, dynamic>;
        
        // Check for GeoPoint in location map
        if (locationMap.containsKey('geopoint')) {
          if (locationMap['geopoint'] is GeoPoint) {
            return locationMap['geopoint'] as GeoPoint;
          } else if (locationMap['geopoint'] is Map) {
            // Handle GeoPoint stored as Map with latitude/longitude
            final geoMap = locationMap['geopoint'] as Map;
            if (geoMap.containsKey('latitude') && geoMap.containsKey('longitude')) {
              try {
                final lat = geoMap['latitude'];
                final lng = geoMap['longitude'];
                if (lat != null && lng != null) {
                  final double latDouble = lat is double ? lat : double.parse(lat.toString());
                  final double lngDouble = lng is double ? lng : double.parse(lng.toString());
                  return GeoPoint(latDouble, lngDouble);
                }
              } catch (e) {
                print('Error converting geopoint map lat/lng to double: $e');
              }
            }
          }
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
      if (data.containsKey('latitude') && data.containsKey('longitude')) {
        try {
          final lat = data['latitude'];
          final lng = data['longitude'];
          if (lat != null && lng != null) {
            final double latDouble = lat is double ? lat : double.parse(lat.toString());
            final double lngDouble = lng is double ? lng : double.parse(lng.toString());
            return GeoPoint(latDouble, lngDouble);
          }
        } catch (e) {
          print('Error converting root lat/lng to double: $e');
        }
      }

      // Case 4: Transport request data
      // First check for client location in transport request
      if (data.containsKey('clientLocation') && data['clientLocation'] != null) {
        if (data['clientLocation'] is GeoPoint) {
          return data['clientLocation'] as GeoPoint;
        } else if (data['clientLocation'] is Map) {
          final clientLocMap = data['clientLocation'] as Map<String, dynamic>;
          if (clientLocMap.containsKey('latitude') && clientLocMap.containsKey('longitude')) {
            try {
              final lat = clientLocMap['latitude'];
              final lng = clientLocMap['longitude'];
              if (lat != null && lng != null) {
                final double latDouble = lat is double ? lat : double.parse(lat.toString());
                final double lngDouble = lng is double ? lng : double.parse(lng.toString());
                return GeoPoint(latDouble, lngDouble);
              }
            } catch (e) {
              print('Error converting client location lat/lng to double: $e');
            }
          }
        }
      }
      
      // Then check originLocation for transport
      if (data.containsKey('originLocation')) {
        if (data['originLocation'] is GeoPoint) {
          return data['originLocation'] as GeoPoint;
        } else if (data['originLocation'] is Map) {
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

  /// حفظ بيانات موقع العميل والوجهة في قاعدة البيانات
  static Future<bool> saveClientLocationData({
    required String clientId,
    required LatLng originLocation,
    required String originName,
    required LatLng destinationLocation,
    required String destinationName,
    double? routeDistance,
    double? routeDuration,
    String? distanceText,
    String? durationText,
    String? serviceType,
  }) async {
    try {
      // تحويل LatLng إلى GeoPoint لتخزينها في Firestore
      final GeoPoint originGeoPoint = GeoPoint(originLocation.latitude, originLocation.longitude);
      final GeoPoint destinationGeoPoint = GeoPoint(destinationLocation.latitude, destinationLocation.longitude);
      
      // إنشاء بيانات الموقع للتخزين
      final Map<String, dynamic> locationData = {
        'originLocation': originGeoPoint,
        'originName': originName,
        'destinationLocation': destinationGeoPoint,
        'destinationName': destinationName,
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };
      
      // إضافة البيانات الإضافية إذا كانت متوفرة
      if (routeDistance != null) locationData['routeDistance'] = routeDistance;
      if (routeDuration != null) locationData['routeDuration'] = routeDuration;
      if (distanceText != null) locationData['distanceText'] = distanceText;
      if (durationText != null) locationData['durationText'] = durationText;
      if (serviceType != null) locationData['serviceType'] = serviceType;
      
      // تحديث بيانات موقع العميل في قاعدة البيانات
      await _firestore.collection('client_locations').doc(clientId).set(locationData, SetOptions(merge: true));
      
      // تحديث وثيقة العميل أيضاً مع آخر موقع معروف
      await _firestore.collection('clients').doc(clientId).update({
        'lastKnownLocation': {
          'location': originGeoPoint,
          'address': originName,
          'timestamp': FieldValue.serverTimestamp(),
        }
      });
      
      return true;
    } catch (e) {
      print('Error saving client location data: $e');
      return false;
    }
  }
  /// استرجاع بيانات موقع العميل من قاعدة البيانات
  static Future<Map<String, dynamic>?> getClientLocationData(String clientId) async {
    try {
      // محاولة الحصول على بيانات الموقع من مجموعة client_locations
      final docSnapshot = await _firestore.collection('client_locations').doc(clientId).get();
      
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null) {
          // First check if data has the required location fields regardless of the isActive flag
          if ((data.containsKey('originLocation') && data['originLocation'] is GeoPoint) ||
              (data.containsKey('destinationLocation') && data['destinationLocation'] is GeoPoint)) {
            print('Found transport location data for client $clientId: $data');
            return data;
          }
          
          // For backward compatibility, check isActive flag
          if (data['isActive'] == true) {
            final Timestamp? updatedAt = data['updatedAt'] as Timestamp?;
            if (updatedAt != null) {
              final DateTime updateTime = updatedAt.toDate();
              final DateTime now = DateTime.now();
              // Extend the time limit to 24 hours instead of 1 hour to be more lenient
              if (now.difference(updateTime).inHours < 24) {
                return data;
              }
            }
          }
        }
      }
      
      // إذا لم يتم العثور على بيانات أو كانت قديمة، حاول الحصول على بيانات من وثيقة العميل
      final clientDoc = await _firestore.collection('clients').doc(clientId).get();
      if (clientDoc.exists) {
        final clientData = clientDoc.data();
        if (clientData != null && clientData.containsKey('lastKnownLocation')) {
          return {
            'originLocation': clientData['lastKnownLocation']['location'],
            'originName': clientData['lastKnownLocation']['address'] ?? '',
            'updatedAt': clientData['lastKnownLocation']['timestamp'],
            'isActive': true,
          };
        }
      }
      
      return null;
    } catch (e) {
      print('Error getting client location data: $e');
      return null;
    }
  }

  /// تحويل GeoPoint إلى LatLng
  static LatLng? geoPointToLatLng(GeoPoint? geoPoint) {
    if (geoPoint == null) return null;
    return LatLng(geoPoint.latitude, geoPoint.longitude);
  }

  /// تحويل بيانات الموقع من Firestore إلى شكل يمكن استخدامه في واجهة المستخدم
  static Map<String, dynamic> processLocationDataForUI(Map<String, dynamic>? locationData) {
    Map<String, dynamic> result = {
      'hasOrigin': false,
      'hasDestination': false,
    };
    
    if (locationData == null) return result;
    
    try {
      if (locationData.containsKey('originLocation') && locationData['originLocation'] is GeoPoint) {
        final GeoPoint originGeoPoint = locationData['originLocation'] as GeoPoint;
        result['originLocation'] = LatLng(originGeoPoint.latitude, originGeoPoint.longitude);
        result['originName'] = locationData['originName'] ?? '';
        result['hasOrigin'] = true;
      }
      
      if (locationData.containsKey('destinationLocation') && locationData['destinationLocation'] is GeoPoint) {
        final GeoPoint destGeoPoint = locationData['destinationLocation'] as GeoPoint;
        result['destinationLocation'] = LatLng(destGeoPoint.latitude, destGeoPoint.longitude);
        result['destinationName'] = locationData['destinationName'] ?? '';
        result['hasDestination'] = true;
      }
      
      // نسخ البيانات الإضافية
      if (locationData.containsKey('routeDistance')) result['routeDistance'] = locationData['routeDistance'];
      if (locationData.containsKey('routeDuration')) result['routeDuration'] = locationData['routeDuration'];
      if (locationData.containsKey('distanceText')) result['distanceText'] = locationData['distanceText'];
      if (locationData.containsKey('durationText')) result['durationText'] = locationData['durationText'];
      
      return result;
    } catch (e) {
      print('Error processing location data for UI: $e');
      return result;
    }
  }
}
