// Script to verify the transport location fix
// This will print the location data of a transport service to verify the fix

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilink/screens/transport_map_fix.dart';

class VerifyTransportLocationFix extends StatelessWidget {
  final String serviceId;
  
  const VerifyTransportLocationFix({super.key, required this.serviceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Verify Location Fix')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('services').doc(serviceId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Service not found'));
          }
          
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final locationInfo = data.containsKey('location') ? data['location'] as Map<String, dynamic>? : null;
          
          // Use our fix function to process location
          final serviceLocation = safeGetLatLng(locationInfo);
          
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Service ID: $serviceId', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                SizedBox(height: 16),
                Text('Raw Location Data:', style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding: EdgeInsets.all(8),
                  color: Colors.grey[200],
                  child: Text('$locationInfo'),
                ),
                SizedBox(height: 16),
                Text('Processed Location:', style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding: EdgeInsets.all(8),
                  color: Colors.grey[200],
                  child: Text(serviceLocation != null 
                    ? 'Lat: ${serviceLocation.latitude}, Lng: ${serviceLocation.longitude}' 
                    : 'No valid location (using default)'),
                ),
                SizedBox(height: 32),
                if (locationInfo != null) ...[
                  Text('Map Preview:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: serviceLocation ?? LatLng(36.7538, 3.0588),
                          zoom: 14,
                        ),
                        markers: {
                          Marker(
                            markerId: MarkerId('serviceLocation'),
                            position: serviceLocation ?? LatLng(36.7538, 3.0588),
                            infoWindow: InfoWindow(
                              title: 'Service Location',
                              snippet: locationInfo['address'] ?? '',
                            ),
                          ),
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
