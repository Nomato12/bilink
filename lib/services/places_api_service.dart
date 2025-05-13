import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class PlacesApiService {
  final String _apiKey;
  final String _language;
  
  PlacesApiService({
    required String apiKey,
    String language = 'ar',
  })  : _apiKey = apiKey,
        _language = language;

  /// Search for place predictions based on input text
  Future<List<Map<String, dynamic>>> getPlacePredictions(String input) async {
    if (input.isEmpty) {
      return [];
    }

    final String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&language=$_language&key=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          return List<Map<String, dynamic>>.from(data['predictions']);
        } else {
          print('Error fetching place predictions: ${data['status']}');
          return [];
        }
      } else {
        print('Error fetching place predictions: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception when fetching place predictions: $e');
      return [];
    }
  }

  /// Get place details from place ID
  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    if (placeId.isEmpty) {
      return null;
    }

    final String url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry,formatted_address,name&language=$_language&key=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          return data['result'] as Map<String, dynamic>;
        } else {
          print('Error fetching place details: ${data['status']}');
          return null;
        }
      } else {
        print('Error fetching place details: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exception when fetching place details: $e');
      return null;
    }
  }

  /// Get LatLng from place ID
  Future<LatLng?> getPlaceLatLng(String placeId) async {
    final placeDetails = await getPlaceDetails(placeId);
    
    if (placeDetails != null && 
        placeDetails.containsKey('geometry') && 
        placeDetails['geometry'].containsKey('location')) {
      
      final location = placeDetails['geometry']['location'];
      return LatLng(location['lat'], location['lng']);
    }
    
    return null;
  }
  
  /// Get directions between two coordinates
  Future<Map<String, dynamic>> getDirections(LatLng origin, LatLng destination) async {
    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${origin.latitude},${origin.longitude}&'
        'destination=${destination.latitude},${destination.longitude}&'
        'language=$_language&key=$_apiKey';
        
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          // تحليل البيانات وتحويلها إلى صيغة أبسط
          final routes = data['routes'] as List;
          if (routes.isNotEmpty) {
            final route = routes[0];
            final legs = route['legs'] as List;
            final leg = legs[0];
            
            // الحصول على معلومات المسافة والوقت
            final Map<String, dynamic> distance = leg['distance'];
            final Map<String, dynamic> duration = leg['duration'];
            
            // الحصول على خط المسار المشفر
            final String polyline = route['overview_polyline']['points'];
            
            // تجهيز المسارات البديلة إذا كانت متوفرة
            final List<Map<String, dynamic>> alternatives = [];
            if (routes.length > 1) {
              for (int i = 1; i < routes.length; i++) {
                final altRoute = routes[i];
                final altLegs = altRoute['legs'] as List;
                final altLeg = altLegs[0];
                
                alternatives.add({
                  'distance': altLeg['distance'],
                  'duration': altLeg['duration'],
                  'polyline': altRoute['overview_polyline']['points'],
                });
              }
            }
            
            // إرجاع البيانات المعالجة
            return {
              'distance': distance,
              'duration': duration,
              'start_address': leg['start_address'],
              'end_address': leg['end_address'],
              'polyline': polyline,
              'alternatives': alternatives,
            };
          }
        } else {
          print('Error fetching directions: ${data['status']}');
        }
      } else {
        print('Error fetching directions: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when fetching directions: $e');
    }
    
    return {};
  }
  
  /// تحويل المسار المشفر إلى نقاط
  List<LatLng> decodePolyline(String encoded) {
    return PolylinePoints().decodePolyline(encoded)
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
  }
}
