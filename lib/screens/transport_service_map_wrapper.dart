import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bilink/screens/transport_service_map_updated.dart';

// This file is a simple wrapper to launch the updated transport service map screen
// with tracking functionality

class TransportServiceMapWrapper extends StatelessWidget {
  final LatLng? destinationLocation;
  final String? destinationName;
  
  const TransportServiceMapWrapper({
    super.key, 
    this.destinationLocation,
    this.destinationName,
  });

  @override
  Widget build(BuildContext context) {
    return TransportServiceMapScreen(
      destinationLocation: destinationLocation,
      destinationName: destinationName,
    );
  }
}
