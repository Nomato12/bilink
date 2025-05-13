import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bilink/screens/fix_transport_map.dart' as map_fix;
import 'package:bilink/screens/directions_map_tracking.dart';

// إضافة مفتاح لتخزين الإشارة إلى زر "بدء" التتبع في الوقت الفعلي في الزاوية السفلية
GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class TransportServiceMapScreen extends StatefulWidget {
  final LatLng? destinationLocation;
  final String? destinationName;
  final LatLng? originLocation;
  final String? originName;
  final String? selectedVehicleType;
  
  const TransportServiceMapScreen({
    super.key, 
    this.destinationLocation,
    this.destinationName,
    this.originLocation,
    this.originName,
    this.selectedVehicleType,
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
  final Set<Polyline> _polylines = {};
  final Map<String, dynamic> _directionsData = {};
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
    }
  }

  // الحصول على الموقع الحالي للمستخدم
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // التحقق من صلاحيات الموقع
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
        });
        
        // يمكن عرض رسالة للمستخدم بأن خدمة الموقع غير مفعلة
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى تفعيل خدمة الموقع للوصول إلى مزايا الخريطة بشكل كامل.'),
          ),
        );
        
        return;
      }

      // التحقق من إذن الوصول للموقع
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم رفض إذن الوصول للموقع. بعض الميزات قد لا تعمل.'),
            ),
          );
          
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('إذن الوصول للموقع مرفوض بشكل دائم. يرجى تغيير الإعدادات.'),
          ),
        );
        
        return;
      }

      // الحصول على الموقع الحالي
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // تحديث موقع المستخدم وإضافة علامة
      setState(() {
        if (_originPosition == null) {
          _originPosition = LatLng(position.latitude, position.longitude);
          _addMarker(
            _originPosition!,
            'origin',
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            _originAddress.isEmpty ? 'موقعك الحالي' : _originAddress,
          );
        }
      });
      
      // محاولة الحصول على العنوان من الإحداثيات
      final address = await _getAddressFromLatLng(_originPosition!);
      setState(() {
        _originAddress = address;
      });
      
      _isStartTrackingVisible = true;
      
      if (_destinationPosition != null) {
        _calculateAndDisplayRoute();
        
        // إنشاء مركبات بعد تحديد الموقع الحالي والوجهة
        _simulateNearbyVehicles(_destinationPosition!);
      }
      
      _animateToPosition(_originPosition!);
    } catch (e) {
      print('Error getting current location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ أثناء تحديد موقعك الحالي.'),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // الحصول على العنوان من الإحداثيات
  Future<String> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
        localeIdentifier: 'ar',
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        return [
          place.street,
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
          place.country,
        ].where((element) => element != null && element.isNotEmpty).join(', ');
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    return '';
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
      
      // إضافة العلامة الجديدة
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
  
  // قائمة بأنواع المركبات المتاحة للتوضيح
  void _simulateNearbyVehicles(LatLng position) {
    // مسح المركبات الحالية قبل إنشاء قائمة جديدة
    _markers.removeWhere((marker) => marker.markerId.value.startsWith('vehicle_'));
    _availableVehicles.clear();
    
    // طباعة نوع المركبة المحدد للتأكد من وصوله
    print('Selected Vehicle Type: ${widget.selectedVehicleType}');
    
    // قائمة بأنواع المركبات المتاحة
    final vehicleTypes = [
      'شاحنة كبيرة',
      'شاحنة صغيرة',
      'شاحنة متوسطة',
      'مركبة خفيفة',
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

    // إنشاء قائمة من المركبات
    final random = map_fix.Random();
    
    // زيادة عدد المركبات لضمان وجود بعض المركبات من النوع المحدد
    final vehicleCount = 15 + random.nextInt(10); // 15-25 مركبة
    
    // تأكد من أن هناك عدد كافي من المركبات من النوع المحدد (على الأقل 5)
    final guaranteed = 5;
    
    // إنشاء قائمة مؤقتة لجميع المركبات
    final allVehicles = List.generate(vehicleCount, (index) {
      // موقع عشوائي حول الوجهة (مع زيادة النطاق للعثور على المزيد من المركبات)
      final latOffset = (random.nextDouble() - 0.5) * 0.04;
      final lngOffset = (random.nextDouble() - 0.5) * 0.04;
      final vehiclePosition = LatLng(
        position.latitude + latOffset,
        position.longitude + lngOffset,
      );

      // نوع المركبة - نتأكد من وجود بعض المركبات من النوع المحدد
      String vehicleType;
      if (widget.selectedVehicleType != null && index < guaranteed) {
        // ضمان وجود عدد محدد من المركبات من النوع المطلوب
        vehicleType = widget.selectedVehicleType!;
      } else {
        // اختيار عشوائي لباقي المركبات
        vehicleType = vehicleTypes[random.nextInt(vehicleTypes.length)];
      }

      // حساب المسافة من موقع العميل
      double distanceFromClient = 0.0;
      if (_originPosition != null) {
        distanceFromClient = _calculateDistance(
          _originPosition!.latitude, 
          _originPosition!.longitude,
          vehiclePosition.latitude, 
          vehiclePosition.longitude
        );
      }

      // بيانات المركبة
      return {
        'id': 'v$index',
        'type': vehicleType,
        'company': companies[random.nextInt(companies.length)],
        'rating': (3.0 + random.nextDouble() * 2.0).toStringAsFixed(1),
        'price': (50 + random.nextInt(150)).toString(),
        'arrivalTime': '${5 + random.nextInt(20)} دقيقة',
        'image': _getVehicleImageUrl(vehicleType),
        'position': vehiclePosition,
        'distanceFromClient': distanceFromClient,
      };
    });

    // تصفية المركبات حسب النوع المحدد إذا كان متوفرًا
    List<Map<String, dynamic>> filteredVehicles = allVehicles;
    if (widget.selectedVehicleType != null && widget.selectedVehicleType!.isNotEmpty) {
      filteredVehicles = allVehicles.where((vehicle) => 
        vehicle['type'] == widget.selectedVehicleType).toList();
      
      // طباعة عدد المركبات من النوع المحدد للتأكد من وجودها
      print('Number of vehicles of type ${widget.selectedVehicleType}: ${filteredVehicles.length}');
      
      // إذا لم نجد أي مركبات من النوع المطلوب (وهذا لن يحدث الآن بسبب الضمان)
      if (filteredVehicles.isEmpty) {
        // إضافة مركبات من النوع المطلوب 
        filteredVehicles = _generateVehiclesOfType(position, widget.selectedVehicleType!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إنشاء مركبات من نوع ${widget.selectedVehicleType}')),
        );
      }
    }
    
    // ترتيب المركبات حسب المسافة من موقع العميل
    if (_originPosition != null) {
      filteredVehicles.sort((a, b) => 
        (a['distanceFromClient'] as double).compareTo(b['distanceFromClient'] as double));
    }
    
    setState(() {
      _availableVehicles = filteredVehicles;
      
      // إضافة علامات للمركبات المصفاة على الخريطة
      for (var vehicle in filteredVehicles) {
        _addVehicleMarker(
          vehicle['position'], 
          'vehicle_${vehicle['id']}', 
          vehicle['type']
        );
      }
      
      // عرض قائمة المركبات إذا كان هناك مركبات متاحة
      _showVehiclesList = filteredVehicles.isNotEmpty;
      
      // طباعة تأكيد
      print('تم عرض ${filteredVehicles.length} مركبة على الخريطة');
    });
  }
  
  // دالة إضافية لإنشاء مركبات من نوع محدد إذا لم يتم العثور على أي منها
  List<Map<String, dynamic>> _generateVehiclesOfType(LatLng position, String vehicleType) {
    final random = map_fix.Random();
    final vehicleCount = 5 + random.nextInt(5); // 5-10 مركبات
    
    // قائمة بالشركات المزودة لخدمات النقل
    final companies = [
      'شركة النقل السريع',
      'توصيل اكسبرس',
      'نقل البضائع الموثوق',
      'سبيد ديليفري',
      'نقل آمن',
    ];
    
    return List.generate(vehicleCount, (index) {
      // موقع عشوائي بمسافة أقرب من الوجهة لزيادة فرصة ظهورها
      final latOffset = (random.nextDouble() - 0.5) * 0.015;
      final lngOffset = (random.nextDouble() - 0.5) * 0.015;
      final vehiclePosition = LatLng(
        position.latitude + latOffset,
        position.longitude + lngOffset,
      );
      
      // حساب المسافة التقريبية من موقع العميل
      double distanceFromClient = 0.0;
      if (_originPosition != null) {
        distanceFromClient = _calculateDistance(
          _originPosition!.latitude, 
          _originPosition!.longitude,
          vehiclePosition.latitude, 
          vehiclePosition.longitude
        );
      }
      
      return {
        'id': 'guaranteed_${vehicleType}_$index',
        'type': vehicleType,
        'company': companies[random.nextInt(companies.length)],
        'rating': (3.5 + random.nextDouble() * 1.5).toStringAsFixed(1), // تقييمات أعلى
        'price': (50 + random.nextInt(150)).toString(),
        'arrivalTime': '${3 + random.nextInt(10)} دقيقة', // وقت وصول أقل
        'image': _getVehicleImageUrl(vehicleType),
        'position': vehiclePosition,
        'distanceFromClient': distanceFromClient,
      };
    });
  }
  
  // دالة لحساب المسافة بين نقطتين (بالكيلومتر)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // نصف قطر الأرض بالكيلومتر
    
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);
    
    double a = 
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) * 
      math.sin(dLon / 2) * math.sin(dLon / 2);
      
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    double distance = earthRadius * c;
    
    return distance;
  }
  
  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
  
  // إضافة علامة مركبة على الخريطة
  void _addVehicleMarker(LatLng position, String markerId, String vehicleType) {
    // تحديد لون العلامة بناءً على نوع المركبة
    BitmapDescriptor icon;
    switch (vehicleType) {
      case 'شاحنة كبيرة':
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
        break;
      case 'شاحنة صغيرة':
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
        break;
      case 'شاحنة متوسطة':
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
        break;
      case 'مركبة خفيفة':
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
        break;
      case 'دراجة نارية':
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);
        break;
      default:
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
    }
    
    _markers.add(
      Marker(
        markerId: MarkerId(markerId),
        position: position,
        icon: icon,
        infoWindow: InfoWindow(
          title: 'مركبة متاحة',
          snippet: vehicleType,
        ),
        onTap: () {
          // تحريك الخريطة إلى موقع المركبة عند النقر
          _animateToPosition(position);
        },
      ),
    );
  }

  // الحصول على رابط صورة المركبة
  String _getVehicleImageUrl(String vehicleType) {
    // تحديد صورة المركبة بناءً على نوعها
    switch (vehicleType) {
      case 'شاحنة كبيرة':
        return 'https://i.imgur.com/3vOS33m.png';
      case 'شاحنة صغيرة':
      case 'شاحنة متوسطة':
        return 'https://i.imgur.com/9NIAJIw.png';
      case 'مركبة خفيفة':
        return 'https://i.imgur.com/YJfO4Mq.png';
      case 'دراجة نارية':
        return 'https://i.imgur.com/oiRQRUP.png';
      default:
        return 'https://i.imgur.com/YJfO4Mq.png';
    }
  }

  // حساب وعرض المسار بين نقطتين
  Future<void> _calculateAndDisplayRoute() async {
    if (_originPosition == null || _destinationPosition == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // حدود الخريطة لتضمين نقطتي البداية والنهاية
    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
        math.min(_originPosition!.latitude, _destinationPosition!.latitude),
        math.min(_originPosition!.longitude, _destinationPosition!.longitude),
      ),
      northeast: LatLng(
        math.max(_originPosition!.latitude, _destinationPosition!.latitude),
        math.max(_originPosition!.longitude, _destinationPosition!.longitude),
      ),
    );

    // التحريك لعرض المسار بالكامل
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));

    setState(() {
      _isLoading = false;
    });
  }

  // فتح شاشة التتبع في الوقت الفعلي
  void _openRealTimeTracking() {
    if (_originPosition == null || _destinationPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد موقعك ووجهتك أولاً'),
        ),
      );
      return;
    }

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

  // تحريك الخريطة لموقع معين
  Future<void> _animateToPosition(LatLng position) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: position,
          zoom: 15,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.selectedVehicleType != null 
            ? 'المركبات المتاحة (${widget.selectedVehicleType})'
            : 'خدمات النقل'
        ),
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
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _defaultLocation,
              zoom: 14.0,
            ),
            markers: _markers,
            polylines: _polylines,
            mapType: _currentMapType,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              
              // تحديد الموقع الحالي عند تهيئة الخريطة
              if (_originPosition == null) {
                setState(() {
                  _getCurrentLocation();
                });
              }
            },
            onTap: (LatLng position) {
              // عند النقر على الخريطة، نضيف علامة الوجهة
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
                    BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                    _originAddress.isEmpty ? 'موقعك الحالي' : _originAddress,
                  );
                  
                  if (_destinationPosition != null) {
                    _calculateAndDisplayRoute();
                    
                    // إعادة إنشاء المركبات بعد تحديد الموقع
                    _simulateNearbyVehicles(_destinationPosition!);
                  }
                });
              }
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
                    BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    _destinationAddress.isEmpty ? 'الوجهة' : _destinationAddress,
                  );
                  
                  _calculateAndDisplayRoute();
                  
                  // إنشاء المركبات بعد تحديد الوجهة
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
                height: 300,
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
                  children: [
                    // عنوان القائمة مع زر الإغلاق
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            widget.selectedVehicleType != null 
                              ? 'مركبات ${widget.selectedVehicleType} المتاحة (${_availableVehicles.length})' 
                              : 'المركبات المتاحة (${_availableVehicles.length})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const Spacer(),
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
                    
                    // قائمة المركبات
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.all(8),
                        itemCount: _availableVehicles.length,
                        itemBuilder: (context, index) {
                          final vehicle = _availableVehicles[index];
                          return Card(
                            margin: EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () {
                                _animateToPosition(vehicle['position']);
                              },
                              child: Row(
                                children: [
                                  // صورة المركبة
                                  SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: CachedNetworkImage(
                                      imageUrl: vehicle['image'],
                                      fit: BoxFit.contain,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey[200],
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
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment: 
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            vehicle['type'],
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            vehicle['company'],
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          SizedBox(height: 4),
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
                                              const Spacer(),
                                              Text(
                                                '${vehicle['price']} دج',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                          // إضافة معلومات المسافة
                                          if (vehicle['distanceFromClient'] != null)
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.location_on_outlined,
                                                  size: 14,
                                                  color: Colors.blue,
                                                ),
                                                SizedBox(width: 2),
                                                Text(
                                                  '${(vehicle['distanceFromClient'] as double).toStringAsFixed(1)} كم',
                                                  style: TextStyle(fontSize: 12),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  'الوصول خلال: ${vehicle['arrivalTime']}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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
                label: Text(
                  widget.selectedVehicleType != null 
                    ? 'عرض مركبات ${widget.selectedVehicleType} المتاحة (${_availableVehicles.length})'
                    : 'عرض المركبات المتاحة (${_availableVehicles.length})'
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B3D91),
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
