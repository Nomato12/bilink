// Custom TransportServiceMapWrapper to ensure compatibility between old and new map implementations
// This wrapper ensures that vehicle locations from service data are properly displayed

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bilink/screens/transport_service_map_updated.dart';
import 'package:bilink/screens/transport_map_fix.dart';

class TransportServiceMapWrapper extends StatefulWidget {
  final LatLng? destinationLocation;
  final String? destinationName;
  final Map<String, dynamic>? serviceData;
  
  const TransportServiceMapWrapper({
    super.key, 
    this.destinationLocation,
    this.destinationName,
    this.serviceData,
  });

  @override
  State<TransportServiceMapWrapper> createState() => _TransportServiceMapWrapperState();
}

class _TransportServiceMapWrapperState extends State<TransportServiceMapWrapper> {
  
  @override
  Widget build(BuildContext context) {
    return TransportServiceMapScreen(
      destinationLocation: widget.destinationLocation,
      destinationName: widget.destinationName,
    );
  }
  
  @override
  void initState() {
    super.initState();
    // If we have service data, we can use it later when needed
    if (widget.serviceData != null) {
      print("TransportServiceMapWrapper: Service data provided: ${widget.serviceData!['id']}");
      
      // We could store this data or pass it to another component that needs it
      // For now, we're logging its presence for debugging
      final locationData = widget.serviceData!['location'] as Map<String, dynamic>?;
      final serviceLocation = safeGetLatLng(locationData);
      
      if (serviceLocation != null) {
        print("TransportServiceMapWrapper: Valid location found at: ${serviceLocation.latitude}, ${serviceLocation.longitude}");
      } else {
        print("TransportServiceMapWrapper: No valid location in service data");
      }
    }
  }
}
