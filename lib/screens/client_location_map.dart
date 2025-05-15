import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class ClientLocationMap extends StatefulWidget {  final GeoPoint location;
  final String locationName;
  final String locationAddress;
  final bool isLiveLocation;
  final bool showLocationUnavailableMessage;

  const ClientLocationMap({
    super.key,
    required this.location,
    required this.locationName,
    this.locationAddress = '',
    this.isLiveLocation = false,
    this.showLocationUnavailableMessage = false,
  });

  @override
  State<ClientLocationMap> createState() => _ClientLocationMapState();
}

class _ClientLocationMapState extends State<ClientLocationMap> {
  late GoogleMapController _mapController;
  late CameraPosition _initialCameraPosition;
  late Set<Marker> _markers;
  bool _mapReady = false;
  final String _googleMapsApiKey = 'AIzaSyCSsMQzPwR92-RwufaNA9kPpi0nB4XjAtw';

  @override
  void initState() {
    super.initState();
    _setupMap();
  }

  void _setupMap() {
    final LatLng position = LatLng(widget.location.latitude, widget.location.longitude);
    
    _initialCameraPosition = CameraPosition(
      target: position,
      zoom: 15.0,
    );
    
    _markers = {
      Marker(
        markerId: const MarkerId('clientLocation'),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          widget.isLiveLocation ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
        ),
        infoWindow: InfoWindow(
          title: widget.locationName,
          snippet: widget.locationAddress.isNotEmpty ? widget.locationAddress : 'الموقع الحالي',
        ),
      ),
    };
  }
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    
    // تطبيق نمط مخصص للخريطة إذا أردت
    _mapController.setMapStyle('''
      [
        {
          "featureType": "poi",
          "elementType": "labels.icon",
          "stylers": [
            {
              "visibility": "off"
            }
          ]
        },
        {
          "featureType": "transit",
          "elementType": "labels.icon",
          "stylers": [
            {
              "visibility": "off"
            }
          ]
        }
      ]
    ''');
    
    setState(() {
      _mapReady = true;
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _openInGoogleMaps() async {
    final url = 'https://www.google.com/maps/search/?api=1&query=${widget.location.latitude},${widget.location.longitude}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن فتح تطبيق الخرائط'), backgroundColor: Colors.red),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.locationName),
        backgroundColor: const Color(0xFF0B3D91),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.navigation),
            onPressed: _openInGoogleMaps,
            tooltip: 'فتح في خرائط جوجل للملاحة',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            mapToolbarEnabled: true,
            onMapCreated: _onMapCreated,
          ),
          if (!_mapReady)
            const Center(
              child: CircularProgressIndicator(),
            ),
          // إذا كان موقع العميل غير متوفر، عرض رسالة تنبيه للمستخدم
          if (widget.showLocationUnavailableMessage)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'هذا موقع افتراضي. موقع العميل الفعلي غير متوفر.',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          widget.isLiveLocation ? Icons.location_on : Icons.place,
                          color: widget.isLiveLocation ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.locationName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (widget.isLiveLocation)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time,
                                  color: Colors.green,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'مباشر',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (widget.locationAddress.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.grey,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.locationAddress,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(                            onPressed: _openInGoogleMaps,
                            icon: const Icon(Icons.directions),
                            label: const Text('تتبع'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0B3D91),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
