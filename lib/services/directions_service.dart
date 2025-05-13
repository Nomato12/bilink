// filepath: d:\bilink\lib\services\directions_service.dart
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class DirectionsService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';
  static const String _apiKey = 'AIzaSyCSsMQzPwR92-RwufaNA9kPpi0nB4XjAtw'; // استخدم نفس مفتاح API المستخدم في التطبيق

  /// الحصول على معلومات المسار بين نقطتين
  Future<DirectionsResult?> getDirections({
    required LatLng origin,
    required LatLng destination,
    String language = 'ar', // استخدام اللغة العربية افتراضيًا
  }) async {
    try {
      final response = await http.get(Uri.parse(
          '$_baseUrl?origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&language=$language'
          '&key=$_apiKey'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          return DirectionsResult.fromMap(data);
        }
        
        print('Directions API error: ${data['status']}');
        return null;
      }
      
      print('HTTP error: ${response.statusCode}');
      return null;
    } catch (e) {
      print('Error getting directions: $e');
      return null;
    }
  }
}

class DirectionsResult {
  final List<LatLng> polylinePoints;
  final double distanceInKm;
  final double durationInMinutes;
  final String distanceText;
  final String durationText;

  DirectionsResult({
    required this.polylinePoints,
    required this.distanceInKm,
    required this.durationInMinutes,
    required this.distanceText,
    required this.durationText,
  });

  factory DirectionsResult.fromMap(Map<String, dynamic> map) {
    // استخراج المسافة والوقت من أول مسار
    final routes = map['routes'] as List;
    if (routes.isEmpty) {
      return DirectionsResult(
        polylinePoints: [],
        distanceInKm: 0,
        durationInMinutes: 0,
        distanceText: '0 كم',
        durationText: '0 دقيقة',
      );
    }

    final firstRoute = routes[0];
    final legs = firstRoute['legs'] as List;
    
    if (legs.isEmpty) {
      return DirectionsResult(
        polylinePoints: [],
        distanceInKm: 0,
        durationInMinutes: 0,
        distanceText: '0 كم',
        durationText: '0 دقيقة',
      );
    }

    final leg = legs[0];
    final distance = leg['distance'];
    final duration = leg['duration'];
    final distanceInMeters = distance['value'] as int;
    final durationInSeconds = duration['value'] as int;

    // تحويل المسافة إلى كيلومترات والوقت إلى دقائق
    final distanceInKm = distanceInMeters / 1000.0;
    final durationInMinutes = durationInSeconds / 60.0;

    // استخراج نقاط المسار المشفرة وفك تشفيرها
    final encodedPolyline = firstRoute['overview_polyline']['points'] as String;
    final polylinePoints = _decodePolyline(encodedPolyline);

    return DirectionsResult(
      polylinePoints: polylinePoints,
      distanceInKm: distanceInKm,
      durationInMinutes: durationInMinutes,
      distanceText: distance['text'],
      durationText: duration['text'],
    );
  }

  // فك تشفير نقاط المسار من Google Directions API
  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    
    return points;
  }
}
