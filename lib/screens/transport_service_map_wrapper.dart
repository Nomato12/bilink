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
    // If service data has valid location, use it
    LatLng? serviceLocation;
    String locationName = widget.destinationName ?? 'الوجهة';
    
    if (widget.serviceData != null && widget.serviceData!['location'] != null) {
      final locationData = widget.serviceData!['location'] as Map<String, dynamic>?;
      serviceLocation = safeGetLatLng(locationData);
      
      if (locationData != null && locationData['address'] != null) {
        locationName = locationData['address'].toString();
      }
    }
    
    return TransportServiceMapScreen(
      destinationLocation: serviceLocation ?? widget.destinationLocation,
      destinationName: locationName,
    );
  }
    @override
  void initState() {
    super.initState();
    // Debug logging
    if (widget.serviceData != null) {
      print("TransportServiceMapWrapper: Service data received with ID: ${widget.serviceData!['id']}");
      
      // Check if location exists and is valid
      if (widget.serviceData!.containsKey('location') && 
          widget.serviceData!['location'] != null &&
          widget.serviceData!['location'] is Map) {
        
        final locationData = widget.serviceData!['location'] as Map<String, dynamic>;
        print("TransportServiceMapWrapper: Location data available: $locationData");
      } else {
        print("TransportServiceMapWrapper: No valid location in service data");
      }
    }
  }
}
