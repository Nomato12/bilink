import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math' show sin, cos, sqrt, atan2, pi;

class RequestLocationMap extends StatefulWidget {
  final GeoPoint location;
  final String title;
  final String address;
  final bool enableNavigation;
  final String? clientId; // Add clientId parameter for real-time tracking
  final bool showRouteToCurrent; // Show route between client and current location
  final bool showLocationUnavailableMessage; // Show message if location is not the actual client location

  const RequestLocationMap({
    super.key,
    required this.location,
    required this.title,
    this.address = '',
    this.enableNavigation = true,
    this.clientId,
    this.showRouteToCurrent = false,
    this.showLocationUnavailableMessage = false,
  });

  @override
  State<RequestLocationMap> createState() => _RequestLocationMapState();
}

class _RequestLocationMapState extends State<RequestLocationMap> {
  late GoogleMapController _mapController;
  bool _mapInitialized = false;
  final Set<Marker> _markers = {};  StreamSubscription<DocumentSnapshot>? _locationSubscription;
  bool _isTracking = false;
  GeoPoint _currentLocation;
  bool _showTrackingOptions = false;
  
  // For routing
  GeoPoint? _providerLocation;
  final Map<PolylineId, Polyline> _polylines = {};
    _RequestLocationMapState() : _currentLocation = GeoPoint(0, 0);
  
  @override
  void initState() {
    super.initState();
    // Set the current location to the initial location provided
    _currentLocation = widget.location;
    _updateMarker();
    
    // If clientId is provided, enable tracking option
    _showTrackingOptions = widget.clientId != null;
    
    // Get provider location if route should be shown
    if (widget.showRouteToCurrent) {
      _getProviderCurrentLocation();
    }
  }  @override
  void dispose() {
    // إلغاء الاشتراك بشكل آمن دون عرض أي رسائل
    if (_locationSubscription != null) {
      _locationSubscription!.cancel();
      _locationSubscription = null;
    }
    _isTracking = false;
    
    // التأكد من إغلاق وحدة تحكم الخريطة
    if (_mapInitialized) {
      _mapController.dispose();
    }
    
    super.dispose();
  }

  void _updateMarker() {
    _markers.clear();
    
    // Add client location marker
    _markers.add(
      Marker(
        markerId: const MarkerId('clientLocation'),
        position: LatLng(_currentLocation.latitude, _currentLocation.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: widget.title,
          snippet: widget.address.isNotEmpty ? widget.address : null,
        ),
      ),
    );
    
    // Add provider location marker if available
    if (_providerLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('providerLocation'),
          position: LatLng(_providerLocation!.latitude, _providerLocation!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(
            title: 'موقعك الحالي',
          ),
        ),
      );
    }
  }
    // Get the provider's current location
  Future<void> _getProviderCurrentLocation() async {
    try {
      // Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('تم رفض إذن الموقع');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('إذن الموقع مرفوض بشكل دائم، يرجى تمكينه من إعدادات التطبيق');
      }
        // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      if (mounted) {
        setState(() {
          _providerLocation = GeoPoint(position.latitude, position.longitude);
          _updateMarker();
        });
        
        // Create route if needed
        if (widget.showRouteToCurrent) {
          _createRoute();
        }
      }
        } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الحصول على الموقع: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error getting location: $e');
    }
  }
  // Create route between provider and client locations
  void _createRoute() {
    if (_providerLocation == null) {
      _getProviderCurrentLocation();
      return;
    }
    
    // Create a simple straight line between provider and client
    List<LatLng> polylineCoordinates = [
      LatLng(_providerLocation!.latitude, _providerLocation!.longitude),
      LatLng(_currentLocation.latitude, _currentLocation.longitude),
    ];
      // Create polyline
    final PolylineId id = const PolylineId('route');
    final Polyline polyline = Polyline(
      polylineId: id,
      color: Colors.blue,
      points: polylineCoordinates,
      width: 5,
    );
    
    if (mounted) {
      setState(() {
        _polylines[id] = polyline;
      });
      
      // Fit the map to include both points
      if (_mapInitialized) {
        LatLngBounds bounds = LatLngBounds(
          southwest: LatLng(
            min(_providerLocation!.latitude, _currentLocation.latitude),
            min(_providerLocation!.longitude, _currentLocation.longitude),
          ),
          northeast: LatLng(
            max(_providerLocation!.latitude, _currentLocation.latitude),
            max(_providerLocation!.longitude, _currentLocation.longitude),
          ),
        );
        
        // Add padding to the bounds
        _mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
      }
    }
  }    // Find the minimum of two values
  double min(double a, double b) => a < b ? a : b;
  
  // Find the maximum of two values
  double max(double a, double b) => a > b ? a : b;

  void _startTracking() {
    if (widget.clientId == null) return;
    
    _isTracking = true;
    // Listen to real-time updates of client location
    _locationSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.clientId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data() as Map<String, dynamic>;
        GeoPoint? newLocation;
        
        if (data.containsKey('location') && data['location'] is Map<String, dynamic>) {
          final locationData = data['location'] as Map<String, dynamic>;
          if (locationData.containsKey('latitude') && locationData.containsKey('longitude')) {
            newLocation = GeoPoint(
              locationData['latitude'] as double,
              locationData['longitude'] as double,
            );
          }
        } else if (data.containsKey('lastLocation') && data['lastLocation'] is GeoPoint) {
          newLocation = data['lastLocation'] as GeoPoint;
        }
        
        if (newLocation != null && mounted) {
          setState(() {
            _currentLocation = newLocation!;
            _updateMarker();
          });
          
          // Auto-center map on new location
          if (_mapInitialized && mounted) {
            _mapController.animateCamera(
              CameraUpdate.newLatLng(
                LatLng(_currentLocation.latitude, _currentLocation.longitude),
              ),
            );
          }
        }
      }
    });
    
    // Show notification that tracking is active
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تفعيل تتبع موقع العميل'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  void _stopTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _isTracking = false;
    
    // لا نقوم بعرض رسالة Snackbar هنا لأنه قد يكون غير آمن إذا تم استدعاء هذه الدالة من dispose()
    // بدلاً من ذلك، نتحقق ما إذا كان الويدجت نشطاً قبل عرض الرسالة
  }

  // Refresh client location once without starting continuous tracking
  void _refreshLocation() async {
    if (widget.clientId == null) return;
    
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Fetch the latest location from Firestore
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.clientId)
          .get();
      
      // Close loading indicator
      if (context.mounted) {
        Navigator.pop(context);
      }
      
      if (!docSnapshot.exists) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يمكن العثور على معلومات العميل'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      final userData = docSnapshot.data() as Map<String, dynamic>;
      GeoPoint? newLocation;
      
      if (userData.containsKey('location') && userData['location'] is Map<String, dynamic>) {
        final locationData = userData['location'] as Map<String, dynamic>;
        if (locationData.containsKey('latitude') && locationData.containsKey('longitude')) {
          newLocation = GeoPoint(
            locationData['latitude'] as double,
            locationData['longitude'] as double,
          );
        }
      } else if (userData.containsKey('lastLocation') && userData['lastLocation'] is GeoPoint) {
        newLocation = userData['lastLocation'] as GeoPoint;
      }        if (newLocation != null && mounted) {
          setState(() {
            _currentLocation = newLocation!;
            _updateMarker();
            
            // Center map on new location
            if (_mapInitialized) {
              _mapController.animateCamera(
                CameraUpdate.newLatLng(
                  LatLng(_currentLocation.latitude, _currentLocation.longitude),
                ),
              );
            }
          });
          
          // Show success message
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم تحديث موقع العميل'),
                backgroundColor: Colors.green,
              ),
            );
          }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لم يتم العثور على موقع محدث للعميل'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }    } catch (e) {
      // Close loading indicator
      if (context.mounted) {
        Navigator.pop(context);
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تحديث الموقع: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error refreshing location: $e');
    }
  }  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.title),
            if (_isTracking) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.gps_fixed, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'تتبع مباشر',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_showTrackingOptions && !_isTracking)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshLocation,
              tooltip: 'تحديث الموقع',
            ),
          if (_showTrackingOptions)            IconButton(
              icon: Icon(_isTracking ? Icons.gps_off : Icons.gps_fixed),
              onPressed: () {
                if (_isTracking) {
                  _stopTracking();
                  // عرض رسالة توقف التتبع هنا بدلاً من داخل _stopTracking
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم إيقاف تتبع موقع العميل'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } else {
                  _startTracking();
                }
                setState(() {});
              },
              tooltip: _isTracking ? 'إيقاف التتبع' : 'تتبع الموقع',
              color: _isTracking ? Colors.green : null,
            ),
          if (widget.enableNavigation)
            IconButton(
              icon: const Icon(Icons.directions),
              onPressed: _openLocationInMaps,
              tooltip: 'الملاحة',
            ),
          // Add route toggle button
          if (widget.showRouteToCurrent || _providerLocation != null)
            IconButton(
              icon: Icon(_polylines.isNotEmpty ? Icons.route : Icons.add_road),
              onPressed: () {
                if (_polylines.isNotEmpty) {                  setState(() {
                    _polylines.clear();
                  });
                } else {
                  _createRoute();
                }
              },
              tooltip: _polylines.isNotEmpty ? 'إخفاء المسار' : 'إظهار المسار',
              color: _polylines.isNotEmpty ? Colors.blue : null,
            ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerMap,
            tooltip: 'تحديد الموقع',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(_currentLocation.latitude, _currentLocation.longitude),
              zoom: 15.0,
            ),
            markers: _markers,
            polylines: Set<Polyline>.of(_polylines.values),
            myLocationButtonEnabled: false, // We'll provide our own button
            myLocationEnabled: true,
            zoomControlsEnabled: true,
            mapToolbarEnabled: true,
            compassEnabled: true,
            onMapCreated: (controller) {
              _mapController = controller;
              // Set custom map style
              _setMapStyle(controller);              setState(() {
                _mapInitialized = true;
              });
              
              // Create route if needed after map is initialized
              if (widget.showRouteToCurrent && _providerLocation != null && mounted) {
                _createRoute();
              }
            },
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
                        'هذا موقع تقريبي. موقع العميل الفعلي غير متوفر.',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Info panel at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.address.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.address,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.grey, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'الإحداثيات: ${_currentLocation.latitude.toStringAsFixed(6)}, ${_currentLocation.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  if (_showTrackingOptions) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (!_isTracking)
                          TextButton.icon(
                            icon: const Icon(Icons.refresh, size: 16, color: Colors.blue),
                            label: const Text(
                              'تحديث الموقع',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                              ),
                            ),
                            onPressed: _refreshLocation,
                          ),
            TextButton.icon(
                          icon: Icon(_isTracking ? Icons.gps_off : Icons.gps_fixed, 
                              size: 16, 
                              color: _isTracking ? Colors.red : Colors.green),
                          label: Text(
                            _isTracking ? 'إيقاف التتبع' : 'تفعيل التتبع المباشر',
                            style: TextStyle(
                              color: _isTracking ? Colors.red : Colors.green,
                              fontSize: 12,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              if (_isTracking) {
                                _stopTracking();
                                // عرض رسالة توقف التتبع هنا بدلاً من داخل _stopTracking
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم إيقاف تتبع موقع العميل'),
                                    backgroundColor: Colors.orange,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              } else {
                                _startTracking();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                  // Display route information if available
                  if (_providerLocation != null && _polylines.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Divider(color: Colors.grey.withOpacity(0.3), height: 16),
                    Row(
                      children: [
                        Icon(Icons.route, color: Colors.blue, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'المسافة تقريبًا: ${_calculateDistance(_currentLocation, _providerLocation!).toStringAsFixed(1)} كم',
                            style: TextStyle(
                              fontSize: 12, 
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: widget.enableNavigation ? FloatingActionButton.extended(
        onPressed: _openLocationInMaps,
        icon: const Icon(Icons.navigation),
        label: const Text('الملاحة'),
        backgroundColor: Colors.green,
      ) : null,
    );
  }
  
  // Calculate distance between two points in km
  double _calculateDistance(GeoPoint point1, GeoPoint point2) {
    // Using the Haversine formula
    const radius = 6371.0; // Earth radius in kilometers
    final lat1 = point1.latitude * pi / 180;
    final lat2 = point2.latitude * pi / 180;
    final deltaLat = (point2.latitude - point1.latitude) * pi / 180;
    final deltaLng = (point2.longitude - point1.longitude) * pi / 180;

    final a = sin(deltaLat/2) * sin(deltaLat/2) +
              cos(lat1) * cos(lat2) *
              sin(deltaLng/2) * sin(deltaLng/2);
    final c = 2 * atan2(sqrt(a), sqrt(1-a));
    return radius * c;
  }
    // Set custom map style with better Arabic language support
  void _setMapStyle(GoogleMapController controller) {
    try {
      controller.setMapStyle('''
      [
        {
          "featureType": "administrative",
          "elementType": "labels.text",
          "stylers": [
            {
              "visibility": "on"
            }
          ]
        },
        {
          "featureType": "poi",
          "stylers": [
            {
              "visibility": "simplified"
            }
          ]
        },
        {
          "featureType": "road",
          "elementType": "labels.icon",
          "stylers": [
            {
              "visibility": "on"
            }
          ]
        },
        {
          "featureType": "transit.station",
          "stylers": [
            {
              "visibility": "on"
            }
          ]
        }
      ]
      ''');
    } catch (e) {
      print('Error setting map style: $e');
    }
  }
  
  void _centerMap() {
    if (_mapInitialized) {
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentLocation.latitude, _currentLocation.longitude),
          15.0,
        ),
      );
    }
  }
  
  void _openLocationInMaps() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Try Google Maps URL format first
      final url = 'https://www.google.com/maps/search/?api=1&query=${_currentLocation.latitude},${_currentLocation.longitude}';
      final uri = Uri.parse(url);
      
      bool launched = false;
      
      if (await canLaunchUrl(uri)) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      
      // If Google Maps didn't work, try geo: scheme which works on many platforms
      if (!launched) {
        final String label = widget.address.isNotEmpty ? widget.address : widget.title;
        final geoUrl = 'geo:${_currentLocation.latitude},${_currentLocation.longitude}?q=${Uri.encodeComponent(label)}';
        final geoUri = Uri.parse(geoUrl);
        
        if (await canLaunchUrl(geoUri)) {
          launched = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        }
      }
      
      // If still not working, try Apple Maps format as a last resort
      if (!launched) {
        final String label = widget.address.isNotEmpty ? widget.address : widget.title;
        final appleMapsUrl = 'maps://?q=${Uri.encodeComponent(label)}&ll=${_currentLocation.latitude},${_currentLocation.longitude}';
        final appleMapsUri = Uri.parse(appleMapsUrl);
        
        if (await canLaunchUrl(appleMapsUri)) {
          launched = await launchUrl(appleMapsUri, mode: LaunchMode.externalApplication);
        }
      }
      
      // Close loading indicator
      if (context.mounted) {
        Navigator.pop(context);
      }
      
      // Show error if unable to launch any maps app
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن فتح تطبيق الخرائط'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close loading indicator
      if (context.mounted) {
        Navigator.pop(context);
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء محاولة فتح الخرائط: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error opening maps: $e');
    }
  }
}