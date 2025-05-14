import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;

class FullScreenMap extends StatefulWidget {
  final GeoPoint originLocation;
  final GeoPoint destinationLocation;
  final String originName;
  final String destinationName;
  final String distanceText;
  final String durationText;

  const FullScreenMap({
    super.key,
    required this.originLocation,
    required this.destinationLocation,
    required this.originName,
    required this.destinationName,
    required this.distanceText,
    required this.durationText,
  });

  @override
  State<FullScreenMap> createState() => _FullScreenMapState();
}

class _FullScreenMapState extends State<FullScreenMap> {
  late CameraPosition initialCameraPosition;
  late Set<Marker> markers;
  late GoogleMapController _mapController;
  final Set<Polyline> _polylines = {};
  final bool _isLoading = false;
  bool _showPopularLocations = false;
  
  // Popular locations near the route
  final List<Map<String, dynamic>> _popularLocations = [
    {
      'name': 'مطار هواري بومدين',
      'location': GeoPoint(36.693, 3.2145),
      'type': 'مطار',
      'icon': Icons.flight
    },
    {
      'name': 'محطة القطار الجزائر',
      'location': GeoPoint(36.7525, 3.0602),
      'type': 'محطة قطار',
      'icon': Icons.train
    },
    {
      'name': 'جامعة الجزائر',
      'location': GeoPoint(36.7029, 3.1718),
      'type': 'جامعة',
      'icon': Icons.school
    },
    {
      'name': 'المستشفى المركزي',
      'location': GeoPoint(36.7754, 3.0573),
      'type': 'مستشفى',
      'icon': Icons.local_hospital
    },
    {
      'name': 'مركز التسوق باب الزوار',
      'location': GeoPoint(36.7207, 3.1873),
      'type': 'مركز تسوق',
      'icon': Icons.shopping_cart
    }
  ];

  @override
  void initState() {
    super.initState();
    _setupMap();
    _addNearbyLocationsToMap();
  }

  // Calculate distance between two GeoPoints in kilometers
  double _calculateDistance(GeoPoint point1, GeoPoint point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    final double lat1 = point1.latitude * math.pi / 180;
    final double lat2 = point2.latitude * math.pi / 180;
    final double lon1 = point1.longitude * math.pi / 180;
    final double lon2 = point2.longitude * math.pi / 180;
    
    final double dLat = lat2 - lat1;
    final double dLon = lon2 - lon1;
    
    final double a = math.sin(dLat/2) * math.sin(dLat/2) +
                     math.cos(lat1) * math.cos(lat2) * 
                     math.sin(dLon/2) * math.sin(dLon/2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
    return earthRadius * c;
  }
  
  // Add nearby popular locations to the map
  void _addNearbyLocationsToMap() {
    // Calculate the midpoint of the route
    final GeoPoint midpoint = GeoPoint(
      (widget.originLocation.latitude + widget.destinationLocation.latitude) / 2,
      (widget.originLocation.longitude + widget.destinationLocation.longitude) / 2
    );
    
    // Filter locations that are within 50km of the route midpoint
    final nearbyLocations = _popularLocations.where((location) {
      final double distance = _calculateDistance(midpoint, location['location']);
      return distance <= 50; // 50km radius
    }).toList();
    
    // Add markers for nearby locations
    for (var i = 0; i < nearbyLocations.length; i++) {
      final location = nearbyLocations[i];
      markers.add(
        Marker(
          markerId: MarkerId('popular_$i'),
          position: LatLng(location['location'].latitude, location['location'].longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          visible: _showPopularLocations,
          infoWindow: InfoWindow(
            title: location['name'],
            snippet: location['type'],
            onTap: () => _openLocationInMaps(location['location'], location['name']),
          ),
        ),
      );
    }
  }
  
  // Toggle visibility of popular locations
  void _togglePopularLocations() {
    setState(() {
      _showPopularLocations = !_showPopularLocations;
      
      // Update marker visibility
      final updatedMarkers = <Marker>{};
      
      // Keep origin and destination markers
      updatedMarkers.add(markers.firstWhere((marker) => marker.markerId == const MarkerId('origin')));
      updatedMarkers.add(markers.firstWhere((marker) => marker.markerId == const MarkerId('destination')));
      
      // Add popular location markers with updated visibility
      for (var i = 0; i < _popularLocations.length; i++) {
        final marker = markers.firstWhere(
          (marker) => marker.markerId == MarkerId('popular_$i'),
          orElse: () => const Marker(markerId: MarkerId('not_found'))
        );
        
        if (marker.markerId.value != 'not_found') {
          updatedMarkers.add(Marker(
            markerId: marker.markerId,
            position: marker.position,
            icon: marker.icon,
            visible: _showPopularLocations,
            infoWindow: marker.infoWindow,
          ));
        }
      }
      
      markers = updatedMarkers;
    });
  }
  
  void _setupMap() {
    // Calculate the center between origin and destination
    final double avgLat = (widget.originLocation.latitude + widget.destinationLocation.latitude) / 2;
    final double avgLng = (widget.originLocation.longitude + widget.destinationLocation.longitude) / 2;
    
    // Calculate zoom level based on distance
    final double latDiff = (widget.originLocation.latitude - widget.destinationLocation.latitude).abs();
    final double lngDiff = (widget.originLocation.longitude - widget.destinationLocation.longitude).abs();
    final double maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    final double zoom = maxDiff > 0.1 ? 10.0 : (maxDiff > 0.05 ? 12.0 : 14.0);
    
    initialCameraPosition = CameraPosition(
      target: LatLng(avgLat, avgLng),
      zoom: zoom,
    );

    // Setup markers
    markers = {
      // Origin marker
      Marker(
        markerId: const MarkerId('origin'),
        position: LatLng(widget.originLocation.latitude, widget.originLocation.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'نقطة الانطلاق',
          snippet: widget.originName,
        ),
      ),
      
      // Destination marker
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(widget.destinationLocation.latitude, widget.destinationLocation.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'الوجهة',
          snippet: widget.destinationName,
        ),
      ),
    };
  }

  void _openLocationInMaps(GeoPoint location, String label) async {
    try {
      final url = 'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}';
      final uri = Uri.parse(url);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Try alternative URL
        final geoUrl = 'geo:${location.latitude},${location.longitude}?q=${Uri.encodeComponent(label)}';
        final geoUri = Uri.parse(geoUrl);
        
        if (await canLaunchUrl(geoUri)) {
          await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('لا يمكن فتح تطبيق الخرائط')),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    }
  }

  void _openDirectionsInMaps() async {
    try {
      // Create a URL for directions from origin to destination
      final url = 'https://www.google.com/maps/dir/?api=1&origin=${widget.originLocation.latitude},${widget.originLocation.longitude}&destination=${widget.destinationLocation.latitude},${widget.destinationLocation.longitude}&travelmode=driving';
      final uri = Uri.parse(url);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يمكن فتح تطبيق الخرائط للحصول على الاتجاهات')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الطريق', 
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: initialCameraPosition,
            markers: markers,
            polylines: _polylines,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),
          
          // Info panel at the top
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.trip_origin, size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'من: ${widget.originName}',
                            style: const TextStyle(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'إلى: ${widget.destinationName}',
                            style: const TextStyle(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.route, size: 16, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(widget.distanceText, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 16, color: Colors.orange),
                            const SizedBox(width: 4),
                            Text(widget.durationText, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Action buttons at the bottom
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Origin navigation button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openLocationInMaps(
                      widget.originLocation,
                      'نقطة الانطلاق: ${widget.originName}',
                    ),
                    icon: const Icon(Icons.trip_origin, size: 18),
                    label: const Text('ملاحة للانطلاق'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Destination navigation button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openLocationInMaps(
                      widget.destinationLocation,
                      'الوجهة: ${widget.destinationName}',
                    ),
                    icon: const Icon(Icons.location_on, size: 18),
                    label: const Text('ملاحة للوجهة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Directions button
          Positioned(
            bottom: 80,
            left: 16,
            right: 16,
            child: ElevatedButton.icon(
              onPressed: _openDirectionsInMaps,
              icon: const Icon(Icons.directions, size: 18),
              label: const Text('عرض الاتجاهات كاملة في خرائط Google'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          
          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'toggleLocations',
            onPressed: _togglePopularLocations,
            backgroundColor: _showPopularLocations ? Colors.purple : Colors.white,
            mini: true,
            child: Icon(
              Icons.place,
              color: _showPopularLocations ? Colors.white : Colors.purple,
            ),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'centerMap',
            onPressed: () {
              _mapController.animateCamera(
                CameraUpdate.newCameraPosition(initialCameraPosition),
              );
            },
            backgroundColor: Colors.white,
            child: const Icon(Icons.center_focus_strong, color: Colors.blue),
          ),
        ],
      ),
      
      // Popular locations panel
      endDrawer: _buildPopularLocationsDrawer(),
    );
  }
  
  // Build the popular locations drawer
  Widget _buildPopularLocationsDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.purple,
            width: double.infinity,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 40), // For status bar
                Text(
                  'المواقع الهامة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'اضغط على أي موقع للانتقال إليه',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _popularLocations.length,
              itemBuilder: (context, index) {
                final location = _popularLocations[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.shade100,
                    child: Icon(location['icon'] as IconData, color: Colors.purple),
                  ),
                  title: Text(location['name']),
                  subtitle: Text(location['type']),
                  trailing: const Icon(Icons.navigation, color: Colors.purple),
                  onTap: () {
                    // Close drawer and navigate to location
                    Navigator.pop(context);
                    _openLocationInMaps(location['location'], location['name']);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
