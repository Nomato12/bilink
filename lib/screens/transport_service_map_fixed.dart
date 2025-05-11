// Complete fix for transport_service_map_updated.dart
// This version fixes both the RenderFlex overflow and the structural/syntax issues

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
// Commented out unused imports
// import 'package:url_launcher/url_launcher.dart';
// import 'package:bilink/screens/service_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bilink/screens/fix_transport_map.dart' as map_fix;
// import 'package:bilink/services/location_synchronizer.dart';
import 'package:bilink/services/directions_helper.dart';
import 'package:bilink/screens/directions_map_tracking.dart';

// إضافة مفتاح لتخزين الإشارة إلى زر "بدء" التتبع في الوقت الفعلي في الزاوية السفلية
GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class TransportServiceMapScreen extends StatefulWidget {
  final LatLng? destinationLocation;
  final String? destinationName;
  
  const TransportServiceMapScreen({
    super.key, 
    this.destinationLocation,
    this.destinationName,
  });

  @override
  _TransportServiceMapScreenState createState() =>
      _TransportServiceMapScreenState();
}

class _TransportServiceMapScreenState extends State<TransportServiceMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();

  // نقطة الانطلاق الافتراضية (الجزائر العاصمة)
  static const LatLng _defaultLocation = LatLng(36.7538, 3.0588);

  // مواقع البداية والوجهة
  LatLng? _originPosition;
  LatLng? _destinationPosition;

  // العناوين
  String _originAddress = '';
  String _destinationAddress = '';

  // مجموعة العلامات على الخريطة
  final Set<Marker> _markers = {};
  // حالة التحميل
  bool _isLoading = false;
  // خدمات النقل المتاحة في المنطقة
  List<Map<String, dynamic>> _availableVehicles = [];
  // حالة عرض قائمة المركبات
  bool _showVehiclesList = false;

  // نوع الخريطة
  MapType _currentMapType = MapType.normal;

  // بيانات المسار والاتجاهات
  Set<Polyline> _polylines = {};
  // Used when calculating routes
  Map<String, dynamic> _directionsData = {};
  // For future use
  final bool _showDirectionsPanel = false;
  
  // زر بدء التتبع في الوقت الفعلي
  bool _isStartTrackingVisible = false;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  // تهيئة الخريطة
  Future<void> _initializeMap() async {
    // الحصول على الموقع الحالي للمستخدم
    _getCurrentLocation();

    // إذا كان هناك وجهة محددة
    if (widget.destinationLocation != null) {
      setState(() {
        _destinationPosition = widget.destinationLocation;
        _destinationAddress = widget.destinationName ?? '';
      });

      // التحقق من وجود عنوان للوجهة
      if (_destinationAddress.isEmpty) {
        final address = await _getAddressFromLatLng(_destinationPosition!);
        if (address.isNotEmpty) {
          setState(() {
            _destinationAddress = address;
          });
        }
      }

      // إضافة علامة للوجهة
      _addMarker(
        _destinationPosition!,
        'destination',
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        _destinationAddress.isEmpty ? 'الوجهة' : _destinationAddress,
      );

      // محاكاة البحث عن مركبات قريبة من الوجهة
      _simulateNearbyVehicles(_destinationPosition!);
    }
  }

  // الحصول على الموقع الحالي
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // التحقق من إذن الوصول إلى الموقع
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لم يتم السماح باستخدام خدمة الموقع')),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تم حظر استخدام خدمة الموقع. يرجى تفعيلها من إعدادات الجهاز',
            ),
            action: SnackBarAction(
              label: 'الإعدادات',
              onPressed: () => Geolocator.openAppSettings(),
            ),
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // الحصول على الموقع الحالي
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _originPosition = LatLng(position.latitude, position.longitude);
      });

      // الحصول على العنوان من الموقع
      final address = await _getAddressFromLatLng(_originPosition!);
      if (address.isNotEmpty) {
        setState(() {
          _originAddress = address;
        });
      }

      // تحريك الخريطة إلى الموقع الحالي
      _animateToPosition(_originPosition!);

      // إضافة علامة للموقع الحالي
      _addMarker(
        _originPosition!,
        'origin',
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        _originAddress.isEmpty ? 'موقعك الحالي' : _originAddress,
      );

      // إذا تم تحديد وجهة، حساب المسار
      if (_destinationPosition != null) {
        _calculateAndDisplayRoute();
      }
    } catch (e) {
      print('Error getting location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تحديد الموقع: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // تحريك الخريطة إلى موقع محدد
  Future<void> _animateToPosition(LatLng position) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 15.0),
      ),
    );
  }

  // الحصول على العنوان من الإحداثيات
  Future<String> _getAddressFromLatLng(LatLng position) async {
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        return '${place.street}, ${place.locality}, ${place.country}';
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    return '';
  }

  // محاكاة وجود مركبات قريبة من موقع محدد
  void _simulateNearbyVehicles(LatLng position) {
    // قائمة بأنواع المركبات المتاحة للتوضيح
    final vehicleTypes = [
      'شاحنة كبيرة',
      'شاحنة صغيرة',
      'سيارة توصيل',
      'دراجة نارية',
    ];

    // قائمة بالشركات المزودة لخدمات النقل
    final companies = [
      'شركة النقل السريع',
      'توصيل اكسبرس',
      'نقل البضائع الموثوق',
      'سبيد ديليفري',
      'نقل آمن',
    ];

    // إنشاء قائمة عشوائية من المركبات المتاحة
    final random = map_fix.Random();
    final vehicleCount = 3 + random.nextInt(5); // 3-7 مركبات

    setState(() {
      _availableVehicles = List.generate(vehicleCount, (index) {
        // موقع عشوائي قريب من الوجهة
        final latOffset = (random.nextDouble() - 0.5) * 0.02;
        final lngOffset = (random.nextDouble() - 0.5) * 0.02;
        final vehiclePosition = LatLng(
          position.latitude + latOffset,
          position.longitude + lngOffset,
        );

        // إضافة علامة للمركبة على الخريطة
        _addVehicleMarker(vehiclePosition, 'vehicle_$index');

        // بيانات المركبة
        return {
          'id': 'v$index',
          'type': vehicleTypes[random.nextInt(vehicleTypes.length)],
          'company': companies[random.nextInt(companies.length)],
          'rating': (3.0 + random.nextDouble() * 2.0).toStringAsFixed(1),
          'price': (50 + random.nextInt(150)).toString(),
          'arrivalTime': '${5 + random.nextInt(20)} دقيقة',
          'image': _getVehicleImageUrl(random.nextInt(4)),
          'position': vehiclePosition,
        };
      });
    });
  }

  // إضافة علامة مركبة على الخريطة
  void _addVehicleMarker(LatLng position, String markerId) {
    _markers.add(
      Marker(
        markerId: MarkerId(markerId),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
        infoWindow: InfoWindow(title: 'مركبة متاحة'),
      ),
    );
  }

  // الحصول على رابط صورة المركبة
  String _getVehicleImageUrl(int index) {
    final vehicleImages = [
      'https://i.imgur.com/3vOS33m.png', // شاحنة كبيرة
      'https://i.imgur.com/9NIAJIw.png', // شاحنة صغيرة
      'https://i.imgur.com/YJfO4Mq.png', // سيارة توصيل
      'https://i.imgur.com/oiRQRUP.png', // دراجة نارية
    ];
    return vehicleImages[index % vehicleImages.length];
  }

  // إضافة علامة على الخريطة
  void _addMarker(
    LatLng position,
    String markerId,
    BitmapDescriptor icon,
    String title,
  ) {
    setState(() {
      // إزالة العلامة القديمة إذا كانت موجودة
      _markers.removeWhere((marker) => marker.markerId.value == markerId);

      // إضافة علامة جديدة
      _markers.add(
        Marker(
          markerId: MarkerId(markerId),
          position: position,
          icon: icon,
          infoWindow: InfoWindow(title: title),
        ),
      );
    });  
  }

  // حساب وعرض المسار بين نقطتين
  Future<void> _calculateAndDisplayRoute() async {
    if (_originPosition == null || _destinationPosition == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      // إعادة تعيين حالة زر التتبع
      _isStartTrackingVisible = false;
    });

    try {
      // الحصول على بيانات المسار
      _directionsData = await DirectionsHelper.getDirections(
        _originPosition!,
        _destinationPosition!,
      );

      // إنشاء خطوط المسار على الخريطة
      _polylines = await DirectionsHelper.createPolylines(
        _originPosition!,
        _destinationPosition!,
        color: Colors.blue,
        width: 5,
      );

      // تحريك الخريطة لإظهار المسار بالكامل
      _fitBoundsForRoute();

      // عرض زر بدء التتبع بعد حساب المسار
      setState(() {
        _isStartTrackingVisible = true;
      });

    } catch (e) {
      print('Error calculating route: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حساب المسار')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ضبط حدود الخريطة لتناسب المسار
  Future<void> _fitBoundsForRoute() async {
    if (_originPosition == null || _destinationPosition == null) {
      return;
    }

    try {
      // إنشاء حدود تشمل نقطتي البداية والنهاية
      final bounds = LatLngBounds(
        southwest: LatLng(
          math.min(_originPosition!.latitude, _destinationPosition!.latitude),
          math.min(_originPosition!.longitude, _destinationPosition!.longitude),
        ),
        northeast: LatLng(
          math.max(_originPosition!.latitude, _destinationPosition!.latitude),
          math.max(_originPosition!.longitude, _destinationPosition!.longitude),
        ),
      );

      // تطبيق الحدود الجديدة على الخريطة
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    } catch (e) {
      print('Error fitting bounds: $e');
    }
  }

  // فتح شاشة التنقل في الوقت الفعلي مع التتبع
  void _openRealTimeTracking() {
    if (_originPosition == null || _destinationPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد نقطة البداية والوجهة أولاً')),
      );
      return;
    }
    
    // فتح شاشة التتبع المباشر وإرسال نقطة البداية والوجهة
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveTrackingMapScreen(
          destinationLocation: _destinationPosition,
          destinationName: _destinationAddress,
          originLocation: _originPosition,
          originName: _originAddress,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('خدمات النقل'),
        actions: [
          IconButton(
            icon: Icon(
              _currentMapType == MapType.normal
                  ? Icons.map_outlined
                  : Icons.map,
            ),
            onPressed: () {
              setState(() {
                _currentMapType =
                    _currentMapType == MapType.normal
                        ? MapType.satellite
                        : MapType.normal;
              });
            },
            tooltip: 'تغيير نوع الخريطة',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getCurrentLocation,
            tooltip: 'تحديث الموقع',
          ),
        ],
      ),
      body: Stack(
        children: [
          // خريطة جوجل
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _defaultLocation,
              zoom: 14,
            ),
            markers: _markers,
            polylines: _polylines,
            mapType: _currentMapType,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _controller.complete(controller);
            },
            onTap: (position) {
              // إذا لم يتم تحديد موقع البداية بعد
              if (_originPosition == null) {
                setState(() {
                  _originPosition = position;
                });
                
                _getAddressFromLatLng(position).then((address) {
                  setState(() {
                    _originAddress = address;
                  });
                  
                  _addMarker(
                    position,
                    'origin',
                    BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueBlue,
                    ),
                    address.isEmpty ? 'موقعك الحالي' : address,
                  );
                  
                  if (_destinationPosition != null) {
                    _calculateAndDisplayRoute();
                  }
                });
              }
              // إذا تم تحديد موقع البداية ولكن ليس الوجهة
              else if (_destinationPosition == null) {
                setState(() {
                  _destinationPosition = position;
                });
                
                _getAddressFromLatLng(position).then((address) {
                  setState(() {
                    _destinationAddress = address;
                  });
                  
                  _addMarker(
                    position,
                    'destination',
                    BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed,
                    ),
                    address.isEmpty ? 'الوجهة' : address,
                  );
                  
                  _calculateAndDisplayRoute();
                  _simulateNearbyVehicles(position);
                });
              }
            },
          ),

          // قائمة المركبات المتاحة
          if (_showVehiclesList && _availableVehicles.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 190, // Reduced from 200
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Added to minimize column height
                  children: [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'المركبات المتاحة',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _showVehiclesList = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 140, // Reduced from 150
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _availableVehicles.length,
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          itemBuilder: (context, index) {
                            final vehicle = _availableVehicles[index];
                            return GestureDetector(
                              onTap: () {
                                _animateToPosition(vehicle['position']);
                              },
                              child: Container(
                                width: 180,
                                margin: EdgeInsets.symmetric(
                                  horizontal: 8, 
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 5,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                constraints: BoxConstraints(maxHeight: 185),
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // صورة المركبة
                                      ClipRRect(
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(10),
                                          topRight: Radius.circular(10),
                                        ),
                                        child: CachedNetworkImage(
                                          imageUrl: vehicle['image'],
                                          height: 80, // Reduced from 90
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            color: Colors.grey[200],
                                            height: 80, // Reduced from original height
                                            child: Icon(
                                              Icons.local_shipping,
                                              size: 40,
                                              color: Colors.grey[400],
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => 
                                              Icon(Icons.error),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        child: Column(
                                          crossAxisAlignment: 
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              vehicle['type'],
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              vehicle['company'],
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.star,
                                                  size: 14,
                                                  color: Colors.amber,
                                                ),
                                                SizedBox(width: 2),
                                                Text(
                                                  vehicle['rating'],
                                                  style: TextStyle(fontSize: 12),
                                                ),
                                                Spacer(),
                                                Text(
                                                  '${vehicle['price']} دج',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green[700],
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // زر عرض المركبات المتاحة
          if (_availableVehicles.isNotEmpty && !_showVehiclesList)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showVehiclesList = true;
                  });
                },
                icon: Icon(Icons.local_shipping),
                label: Text('عرض المركبات المتاحة (${_availableVehicles.length})'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            
          // مؤشر التحميل
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min, // Added for better sizing
          children: [
            // زر بدء التتبع - إضافة في الأعلى من عمود أزرار FAB بمساحة كافية
            if (_isStartTrackingVisible)
              Container(
                margin: const EdgeInsets.only(bottom: 30),
                child: FloatingActionButton.extended(
                  onPressed: _openRealTimeTracking,
                  icon: const Icon(Icons.navigation),
                  label: const Text('بدء التتبع'),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  heroTag: 'start_tracking',
                ),
              ),
              
            // أزرار التحكم في الخريطة
            FloatingActionButton.small(
              onPressed: () async {
                final GoogleMapController controller = await _controller.future;
                controller.animateCamera(CameraUpdate.zoomIn());
              },
              heroTag: 'zoom_in',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              child: const Icon(Icons.add),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              onPressed: () async {
                final GoogleMapController controller = await _controller.future;
                controller.animateCamera(CameraUpdate.zoomOut());
              },
              heroTag: 'zoom_out',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              child: const Icon(Icons.remove),
            ),
            const SizedBox(height: 8),
            FloatingActionButton(
              onPressed: _getCurrentLocation,
              heroTag: 'my_location',
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              child: const Icon(Icons.my_location),
            ),
          ],
        ),
      ),
    );
  }
}

// Import dart:math
class math {
  static double min(double a, double b) => a < b ? a : b;
  static double max(double a, double b) => a > b ? a : b;
}
