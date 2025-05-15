import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:bilink/services/directions_helper.dart';
import 'package:bilink/models/directions_result.dart';

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
  }  // Create route between provider and client locations
  Future<void> _createRoute() async {
    if (_providerLocation == null) {
      await _getProviderCurrentLocation();
      if (_providerLocation == null) return;
    }
    
    setState(() {
      _polylines.clear();
    });
    
    try {
      // Use DirectionsService to get a proper route instead of a straight line
      final directionsService = DirectionsHelper();
      final result = await directionsService.getRoute(
        origin: LatLng(_providerLocation!.latitude, _providerLocation!.longitude),
        destination: LatLng(_currentLocation.latitude, _currentLocation.longitude),
      );
      
      if (result == null) {
        // If directions service fails, fall back to a straight line
        List<LatLng> polylineCoordinates = [
          LatLng(_providerLocation!.latitude, _providerLocation!.longitude),
          LatLng(_currentLocation.latitude, _currentLocation.longitude),
        ];
        
        final PolylineId id = const PolylineId('route');
        final Polyline polyline = Polyline(
          polylineId: id,
          color: Colors.blue,
          points: polylineCoordinates,
          width: 5,
        );
        
        setState(() {
          _polylines[id] = polyline;
        });
        
        // Set zoom to fit the route
        _fitRouteInMap();
        return;
      }
      
      // Create polyline with the route from directions service
      final PolylineId id = const PolylineId('route');
      final Polyline polyline = Polyline(
        polylineId: id,
        color: Colors.blue,
        points: result.polylinePoints,
        width: 5,
      );
    
      setState(() {
        _polylines[id] = polyline;
      });
      
      // Set zoom to fit the route
      _fitRouteInMap();
      
    } catch (e) {
      print('Error creating route: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء إنشاء المسار: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
    // Adjust map to fit the route
  void _fitRouteInMap() {
    if (_polylines.isEmpty || !_mapInitialized) return;
    
    // Get all points from all polylines
    List<LatLng> points = [];
    _polylines.forEach((_, polyline) {
      points.addAll(polyline.points);
    });
    
    if (points.isEmpty) return;
    
    // Find the bounds of all points
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    
    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    
    // Create bounds and animate camera
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    
    // Add padding
    _mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }// Find the minimum of two values
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
  }  void _stopTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _isTracking = false;
    
    // لا نقوم بعرض رسالة Snackbar هنا لأنه قد يكون غير آمن إذا تم استدعاء هذه الدالة من dispose()
    // بدلاً من ذلك، نتحقق ما إذا كان الويدجت نشطاً قبل عرض الرسالة
  }@override
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
        ),        actions: [
          if (_showTrackingOptions)
            IconButton(
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
          if (widget.enableNavigation)            IconButton(
              icon: const Icon(Icons.directions),
              onPressed: _openLocationInMaps,
              tooltip: 'تتبع',
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
                  ),                  if (_showTrackingOptions) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
      ),      floatingActionButton: widget.enableNavigation ? FloatingActionButton.extended(
        onPressed: _openLocationInMaps,
        icon: const Icon(Icons.navigation),
        label: const Text('تتبع'),
        backgroundColor: Colors.green,
      ) : null,
    );
  }
    // Calculate distance between two points in km
  double _calculateDistance(GeoPoint point1, GeoPoint point2) {
    // Using the Haversine formula
    const radius = 6371.0; // Earth radius in kilometers
    final lat1 = point1.latitude * math.pi / 180;
    final lat2 = point2.latitude * math.pi / 180;
    final deltaLat = (point2.latitude - point1.latitude) * math.pi / 180;
    final deltaLng = (point2.longitude - point1.longitude) * math.pi / 180;

    final a = math.sin(deltaLat/2) * math.sin(deltaLat/2) +
              math.cos(lat1) * math.cos(lat2) *
              math.sin(deltaLng/2) * math.sin(deltaLng/2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
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
      // قم بإظهار الخريطة داخل التطبيق بدلاً من فتح تطبيق خارجي
      
      // إظهار مؤشر التحميل
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // إذا كان هناك مسار بالفعل، تأكد من تكبير/تصغير الخريطة لتناسب المسار
      if (_polylines.isNotEmpty) {
        _fitRouteInMap();
      } else {
        // إذا لم يكن هناك مسار، قم بإنشاء واحد
        if (_providerLocation == null) {
          await _getProviderCurrentLocation();
        }
        
        if (_providerLocation != null) {
          await _createRoute();
        } else {
          // إذا تعذر الحصول على موقع المزود، ركز على موقع العميل فقط
          if (_mapInitialized) {
            _mapController.animateCamera(
              CameraUpdate.newLatLngZoom(
                LatLng(_currentLocation.latitude, _currentLocation.longitude),
                15.0,
              ),
            );
          }
        }
      }
      
      // إغلاق مؤشر التحميل
      if (context.mounted) {
        Navigator.pop(context);
      }
      
      // إذا كانت ميزة التتبع متاحة ولم تكن مفعلة، قم بتفعيلها
      if (_showTrackingOptions && !_isTracking) {
        _startTracking();
      }
      
      // عرض رسالة نجاح
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تفعيل تتبع موقع العميل في الخريطة'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // إغلاق مؤشر التحميل
      if (context.mounted) {
        Navigator.pop(context);
      }
      
      // عرض رسالة خطأ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء محاولة تتبع الموقع: $e'),
          backgroundColor: Colors.red,
        ),
      );      print('Error opening in-app maps: $e');
    }
  }
}