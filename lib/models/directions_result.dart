import 'package:google_maps_flutter/google_maps_flutter.dart';

class DirectionsResult {
  final List<LatLng> polylinePoints;
  final String distance;
  final String duration;

  DirectionsResult({
    required this.polylinePoints,
    required this.distance,
    required this.duration,
  });
}
