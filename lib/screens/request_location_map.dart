import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:bilink/services/directions_helper.dart';

class RequestLocationMap extends StatefulWidget {
  final GeoPoint location;
  final String title;
  final String address;
  final bool enableNavigation;
  final String? clientId; // Add clientId parameter for real-time tracking
  final bool showRouteToCurrent; // Show route between client and current location
  final bool showLocationUnavailableMessage; // Show message if location is not the actual client location
  final GeoPoint? destinationLocation; // إضافة موقع الوجهة
  final String? destinationName; // إضافة اسم الوجهة
  final String? requestId; // إضافة معرّف الطلب

  const RequestLocationMap({
    super.key,
    required this.location,
    required this.title,
    this.address = '',
    this.enableNavigation = true,
    this.clientId,
    this.showRouteToCurrent = false,
    this.showLocationUnavailableMessage = false,
    this.destinationLocation, // إضافة موقع الوجهة كمعامل اختياري
    this.destinationName, // إضافة اسم الوجهة كمعامل اختياري
    this.requestId, // إضافة معرّف الطلب كمعامل اختياري
  });

  @override
  State<RequestLocationMap> createState() => _RequestLocationMapState();
}

class _RequestLocationMapState extends State<RequestLocationMap> {
  late GoogleMapController _mapController;
  bool _mapInitialized = false;
  final Set<Marker> _markers = {};  
  StreamSubscription<DocumentSnapshot>? _locationSubscription;
  bool _isTracking = false;
  late GeoPoint _currentLocation;
  bool _showTrackingOptions = false;
    // For routing
  GeoPoint? _providerLocation;
  final Map<PolylineId, Polyline> _polylines = {};
  
  // للوجهة النهائية
  GeoPoint? _destinationLocation;
  String? _destinationName;
  bool _showDestination = false;
  
  // للتتبع المباشر لموقع المزود
  StreamSubscription<Position>? _providerLocationSubscription;
  bool _isTrackingProvider = false;
  bool _followingProvider = false;

  _RequestLocationMapState() : _currentLocation = GeoPoint(0, 0);
    @override
  void initState() {
    super.initState();
    // Set the current location to the initial location provided
    _currentLocation = widget.location;
    _updateMarker();
    
    // If clientId is provided, enable tracking option
    _showTrackingOptions = widget.clientId != null;
    
    // Initialize destination information if provided
    if (widget.destinationLocation != null) {
      _destinationLocation = widget.destinationLocation;
      _destinationName = widget.destinationName;
    }
    
    // Get provider location if route should be shown
    if (widget.showRouteToCurrent) {
      _getProviderCurrentLocation();
      // بدء تتبع موقع المزود بشكل مستمر
      _startProviderTracking();
    }
  }@override
  void dispose() {
    // إلغاء الاشتراك بتتبع موقع العميل
    if (_locationSubscription != null) {
      _locationSubscription!.cancel();
      _locationSubscription = null;
    }
    _isTracking = false;
    
    // إلغاء الاشتراك بتتبع موقع المزود
    if (_providerLocationSubscription != null) {
      _providerLocationSubscription!.cancel();
      _providerLocationSubscription = null;
    }
    _isTrackingProvider = false;
    
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
    
    // Add destination marker if available and should be shown
    if (_destinationLocation != null && _showDestination) {
      _markers.add(
        Marker(
          markerId: const MarkerId('destinationLocation'),
          position: LatLng(_destinationLocation!.latitude, _destinationLocation!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: 'الوجهة النهائية',
            snippet: _destinationName ?? 'الوجهة',
          ),
        ),
      );
    }
  }  // Get the provider's current location
  Future<void> _getProviderCurrentLocation() async {
    try {
      // تحقق من أن الـ widget لا يزال مثبتًا في بداية العملية
      if (!mounted) return;
      
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
      
      // تحقق من أن الـ widget لا يزال مثبتًا بعد الحصول على الموقع
      if (!mounted) return;
      
      setState(() {
        _providerLocation = GeoPoint(position.latitude, position.longitude);
        _updateMarker();
      });
      
      // التحقق مما إذا كان السائق قد وصل إلى العميل
      if (_hasReachedClient() && _destinationLocation != null && !_showDestination) {
        setState(() {
          _showDestination = true;
          _updateMarker(); // تحديث العلامات لإظهار علامة الوجهة
        });
        
        // تحقق مرة أخرى من أن الـ widget لا يزال مثبتًا قبل عرض الرسالة
        if (!mounted) return;
        
        // عرض رسالة إشعار بالوصول للعميل
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم الوصول إلى العميل! استخدم زر التتبع لعرض الوجهة النهائية'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      // Create route if needed
      if (widget.showRouteToCurrent && mounted) {
        _createRoute();
      }
    } catch (e) {
      // تحقق من أن الـ widget لا يزال مثبتًا قبل عرض رسالة الخطأ
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في الحصول على الموقع: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      print('Error getting location: $e');
    }
  }// إنشاء مسار بين موقع المزود وموقع العميل مع تحسينات بصرية
  Future<void> _createRoute() async {
    // تأكد من وجود موقع المزود، وإلا قم بالحصول عليه
    if (_providerLocation == null) {
      await _getProviderCurrentLocation();
      if (_providerLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن تحديد موقعك الحالي، يرجى تفعيل خدمة الموقع'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    
    // أظهر مؤشر التحميل
    if (mounted && !_isTrackingProvider) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جاري إنشاء المسار...'),
          duration: Duration(seconds: 1),
        ),
      );
    }
    
    // مسح المسارات الموجودة
    setState(() {
      _polylines.clear();
    });
    
    try {
      // استخدم DirectionsService للحصول على مسار حقيقي بدلاً من خط مستقيم
      final directionsService = DirectionsHelper();
      final result = await directionsService.getRoute(
        origin: LatLng(_providerLocation!.latitude, _providerLocation!.longitude),
        destination: LatLng(_currentLocation.latitude, _currentLocation.longitude),
      );
      
      if (result == null) {
        // إذا فشلت خدمة الاتجاهات، استخدم خطًا مستقيمًا كبديل
        List<LatLng> polylineCoordinates = [
          LatLng(_providerLocation!.latitude, _providerLocation!.longitude),
          LatLng(_currentLocation.latitude, _currentLocation.longitude),
        ];
        
        final PolylineId id = const PolylineId('route');
        final Polyline polyline = Polyline(
          polylineId: id,
          color: Colors.blue.shade700,
          points: polylineCoordinates,
          width: 5,
          patterns: [
            PatternItem.dot, PatternItem.gap(10)
          ],
        );
        
        setState(() {
          _polylines[id] = polyline;
        });
        
        // ضبط تكبير/تصغير الخريطة لتناسب المسار
        _fitRouteInMap();
        return;
      }
      
      // إنشاء خط المسار باستخدام نتائج خدمة الاتجاهات
      final PolylineId id = const PolylineId('route');
      final Polyline polyline = Polyline(
        polylineId: id,
        color: Colors.blue.shade700,
        points: result.polylinePoints,
        width: 6,
        endCap: Cap.roundCap,
        startCap: Cap.roundCap,
        jointType: JointType.round,
      );
    
      // إضافة ظل للطريق لجعله أكثر وضوحًا
      final PolylineId shadowId = const PolylineId('route_shadow');
      final Polyline shadowPolyline = Polyline(
        polylineId: shadowId,
        color: Colors.black.withOpacity(0.3),
        points: result.polylinePoints,
        width: 8,
        endCap: Cap.roundCap,
        startCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 1, // جعله خلف المسار الأساسي
      );
    
      setState(() {
        _polylines[shadowId] = shadowPolyline;
        _polylines[id] = polyline;
      });
      
      // أظهر معلومات المسافة والوقت
      if (result.distance != null && result.duration != null && mounted && !_isTrackingProvider) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'المسافة: ${result.distance} - الوقت المتوقع: ${result.duration}',
              textAlign: TextAlign.center,
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      // ضبط تكبير/تصغير الخريطة لتناسب المسار
      _fitRouteInMap();
      
    } catch (e) {
      print('Error creating route: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء إنشاء المسار: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
  }
  
  // بدء تتبع موقع المزود (أنت) بشكل مباشر
  Future<void> _startProviderTracking() async {
    // أولاً، تأكد من الحصول على إذن الموقع
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفض إذن الموقع، لا يمكن تتبع موقعك'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم رفض إذن الموقع بشكل دائم، يرجى تغيير الإعدادات لاستخدام هذه الميزة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // إلغاء أي اشتراك موجود قبل إنشاء اشتراك جديد
    _stopProviderTracking();
    
    // تشغيل حالة التتبع
    _isTrackingProvider = true;
    _followingProvider = true;
    
    // الاشتراك في تحديثات الموقع
    _providerLocationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // تحديث كل 10 أمتار من الحركة
      ),
    ).listen((Position position) {
      // تحديث موقع المزود
      setState(() {
        _providerLocation = GeoPoint(position.latitude, position.longitude);
        _updateMarker();
      });
      
      // تحديث المسار إذا كان مفعلاً
      if (_polylines.isNotEmpty) {
        _createRoute();
      }
      
      // توجيه الكاميرا لمتابعة حركة المزود إذا كان مفعلاً
      if (_followingProvider && _mapInitialized) {
        _mapController.animateCamera(
          CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
        );
      }
    }, 
    onError: (error) {
      print('Error tracking provider location: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تتبع موقعك: $error'),
          backgroundColor: Colors.red,
        ),
      );
      _stopProviderTracking();
    });
    
    // أظهر رسالة تأكيد للمستخدم
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تفعيل تتبع موقعك بنجاح'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  // إيقاف تتبع موقع المزود
  void _stopProviderTracking() {
    if (_providerLocationSubscription != null) {
      _providerLocationSubscription!.cancel();
      _providerLocationSubscription = null;
    }
    _isTrackingProvider = false;
    _followingProvider = false;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
            ),
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
            ),          // زر لإظهار/إخفاء المسار
          if (widget.showRouteToCurrent || _providerLocation != null)
            IconButton(
              icon: Icon(_polylines.isNotEmpty ? Icons.route : Icons.add_road),
              onPressed: () {
                if (_polylines.isNotEmpty) {
                  setState(() {
                    _polylines.clear();
                  });
                } else {
                  _createRoute();
                }
              },
              tooltip: _polylines.isNotEmpty ? 'إخفاء المسار' : 'إظهار المسار',
              color: _polylines.isNotEmpty ? Colors.blue : null,
            ),
          
          // زر لبدء/إيقاف تتبع موقع المزود
          if (widget.showRouteToCurrent)
            IconButton(
              icon: Icon(_isTrackingProvider 
                ? Icons.location_on : Icons.location_off),
              onPressed: () {
                if (_isTrackingProvider) {
                  _stopProviderTracking();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم إيقاف تتبع موقعك'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  _startProviderTracking();
                }
                setState(() {});
              },
              tooltip: _isTrackingProvider ? 'إيقاف تتبع موقعك' : 'تتبع موقعك',
              color: _isTrackingProvider ? Colors.green : null,
            ),
            
          // زر لتفعيل/إيقاف متابعة المزود أثناء التنقل
          if (_isTrackingProvider)
            IconButton(
              icon: Icon(_followingProvider 
                ? Icons.navigation : Icons.explore),
              onPressed: () {
                setState(() {
                  _followingProvider = !_followingProvider;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_followingProvider 
                      ? 'تم تفعيل متابعة موقعك أثناء التنقل' 
                      : 'تم إيقاف متابعة موقعك أثناء التنقل'),
                    backgroundColor: _followingProvider ? Colors.green : Colors.orange,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              tooltip: _followingProvider ? 'إيقاف المتابعة' : 'متابعة موقعك',
              color: _followingProvider ? Colors.green : null,
            ),
            
          // زر لتحديد موقعك على الخريطة
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
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
                            Icon(Icons.location_on, color: Colors.blue[700], size: 18),
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
                      if (_showDestination && _destinationLocation != null) ...[
                        const SizedBox(height: 8),
                        Divider(color: Colors.grey.withOpacity(0.3), height: 16),
                        Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.blue, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'الوجهة النهائية: ${_destinationName ?? "الوجهة"}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _createRouteToDestination,
                          icon: Icon(Icons.navigation, size: 16),
                          label: Text('بدء الملاحة إلى الوجهة النهائية'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            minimumSize: Size(double.infinity, 36),
                          ),
                        ),
                      ],
                      if (_destinationLocation != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: ElevatedButton.icon(                            icon: const Icon(Icons.flag, size: 18),
                            label: const Text(
                              'اذهب إلى وجهة العميل',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[800], // Updated color
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 40),
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),onPressed: () async {
                              if (_mapInitialized && _destinationLocation != null) {
                                // First, animate to the destination location
                                _mapController.animateCamera(
                                  CameraUpdate.newLatLngZoom(
                                    LatLng(_destinationLocation!.latitude, _destinationLocation!.longitude),
                                    16.0,
                                  ),
                                );
                                
                                // Then, get the provider's current location if not available
                                if (_providerLocation == null) {
                                  await _getProviderCurrentLocation();
                                }
                                
                                // If we have both provider location and destination, create a route
                                if (_providerLocation != null) {
                                  await _createRouteToDestination();
                                  
                                  // Show a message
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('تم إنشاء المسار إلى وجهة العميل: ${_destinationName ?? "الوجهة"}'),
                                      backgroundColor: Colors.blue[700], // Consistent with button
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),      floatingActionButton: widget.enableNavigation ? FloatingActionButton.extended(
        onPressed: _openLocationInMaps,
        icon: const Icon(Icons.navigation),
        label: const Text('تتبع'),
        backgroundColor: Colors.blue[700], // Updated color
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
  }  void _openLocationInMaps() async {
    try {
      // تحقق من أن الـ widget لا يزال مثبتًا قبل بدء العملية
      if (!mounted) return;
      
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
        
        // تحقق من أن الـ widget لا يزال مثبتًا بعد العملية غير المتزامنة
        if (!mounted) return;
        
        if (_providerLocation != null) {
          // التحقق مما إذا وصل السائق إلى العميل وهناك وجهة نهائية
          if (_hasReachedClient() && _destinationLocation != null && !_showDestination) {
            setState(() {
              _showDestination = true;
              _updateMarker(); // تحديث العلامات لإضافة علامة الوجهة
            });
            // إنشاء مسار إلى الوجهة النهائية بدلاً من العميل
            await _createRouteToDestination();
            // إغلاق مؤشر التحميل
            if (!mounted) return;
            
            Navigator.pop(context);
            // عرض رسالة وصول للعميل وإظهار الوجهة النهائية
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تم الوصول إلى العميل! جاري عرض الوجهة النهائية: ${_destinationName ?? "الوجهة"}'),
                backgroundColor: Colors.blue,
                duration: const Duration(seconds: 3),
              ),
            );
            return;
          } else {
            // إنشاء المسار العادي إلى العميل
            await _createRoute();
            
            // تحقق من أن الـ widget لا يزال مثبتًا بعد العملية غير المتزامنة
            if (!mounted) return;
          }
        } else {
          // إذا تعذر الحصول على موقع المزود، ركز على موقع العميل فقط
          if (_mapInitialized && mounted) {
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
      if (!mounted) return;
      
      Navigator.pop(context);
      
      // إذا كانت ميزة التتبع متاحة ولم تكن مفعلة، قم بتفعيلها
      if (_showTrackingOptions && !_isTracking) {
        _startTracking();
      }
      
      // تحقق من أن الـ widget لا يزال مثبتًا قبل عرض الرسالة
      if (!mounted) return;
      
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
      if (mounted) {
        Navigator.pop(context);
        
        // عرض رسالة خطأ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء محاولة تتبع الموقع: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error opening in-app maps: $e');
    }
  }
  
  // التحقق مما إذا وصل السائق إلى موقع العميل
  bool _hasReachedClient() {
    if (_providerLocation == null) return false;
    
    // حساب المسافة بين موقع السائق والعميل
    final double distance = _calculateDistance(
      _providerLocation!,
      _currentLocation
    );
    
    // نعتبر أن السائق وصل إذا كان على بعد أقل من 100 متر
    return distance < 0.1; // 0.1 كم = 100 متر
  }
  
  // إنشاء مسار إلى الوجهة النهائية
  Future<void> _createRouteToDestination() async {
    if (_destinationLocation == null || _providerLocation == null) return;
    
    try {
      final DirectionsHelper directionsService = DirectionsHelper();
      
      setState(() {
        _polylines.clear();
      });
      
      final result = await directionsService.getRoute(
        origin: LatLng(_providerLocation!.latitude, _providerLocation!.longitude),
        destination: LatLng(_destinationLocation!.latitude, _destinationLocation!.longitude),
      );
      
      if (result == null) {
        throw Exception('لم يتم العثور على مسار إلى الوجهة النهائية');
      }
      
      // Create polyline with the route from directions service
      final PolylineId id = const PolylineId('destination_route');
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
      print('Error creating route to destination: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء إنشاء المسار إلى الوجهة النهائية: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}