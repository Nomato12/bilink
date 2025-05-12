import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bilink/screens/fix_transport_map.dart' as map_fix;
import 'package:bilink/services/directions_helper.dart';
import 'package:bilink/screens/directions_map_tracking.dart';
import 'package:bilink/screens/service_details_screen.dart';

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
  Map<String, dynamic> _directionsData = {}; // Not explicitly used after assignment, but part of directions logic
  // final bool _showDirectionsPanel = false; // Not used, can be removed

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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('لم يتم السماح باستخدام خدمة الموقع')),
            );
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
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
        }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تحديد الموقع: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
  // الحصول على خدمات النقل الحقيقية من قاعدة البيانات
  Future<void> _simulateNearbyVehicles(LatLng position) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // تحميل خدمات النقل من قاعدة البيانات
      final allVehicles = await map_fix.loadTransportServices();
      
      if (allVehicles.isEmpty) {
        print("DEBUG: No transport services found in database");
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا توجد خدمات نقل متاحة في هذه المنطقة')),
          );
        }
        
        setState(() {
          _isLoading = false;
        });
        
        return;
      }
      
      print("DEBUG: Found ${allVehicles.length} transport services in database");
      
      // البحث عن المركبات في نطاق 15 كم من الموقع المحدد
      final searchRadius = 15.0;
      final nearbyVehicles = await map_fix.findNearbyVehicles(
        allVehicles, 
        position, 
        searchRadius
      );
      
      // تحويل بيانات الخدمات إلى التنسيق المطلوب للعرض
      final formattedVehicles = _formatVehiclesForDisplay(nearbyVehicles);
      
      if (mounted) {
        setState(() {
          _availableVehicles = formattedVehicles;
          _isLoading = false;
        });
        
        // إضافة علامات المركبات على الخريطة
        _addVehiclesMarkersToMap(formattedVehicles);
      }
    } catch (e) {
      print('Error loading transport services: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تحميل خدمات النقل: $e')),
        );
        
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // تحويل بيانات المركبات من Firestore إلى التنسيق المطلوب للعرض
  List<Map<String, dynamic>> _formatVehiclesForDisplay(List<Map<String, dynamic>> vehicles) {
    return vehicles.map((vehicle) {
      // استخراج موقع المركبة
      final LatLng vehiclePosition = vehicle['calculatedPosition'] ?? 
          map_fix.extractLocation(vehicle['location']) ?? 
          _defaultLocation;
      
      // استخراج المعلومات المطلوبة للعرض
      final Map<String, dynamic> formattedVehicle = {
        'id': vehicle['id'] ?? 'unknown',
        'type': _extractVehicleType(vehicle),
        'company': vehicle['title'] ?? 'غير محدد',
        'rating': (vehicle['rating'] != null) ? (vehicle['rating'] as num).toStringAsFixed(1) : '0.0',
        'price': (vehicle['price'] != null) ? (vehicle['price'] as num).toString() : '0',
        'arrivalTime': '${_calculateArrivalTime(vehicle)} دقيقة',
        'image': _getVehicleImageUrl(vehicle),
        'position': vehiclePosition,
        'distance': vehicle['distance'] ?? '0.0',
        'description': vehicle['description'] ?? '',
      };
      
      return formattedVehicle;
    }).toList();
  }
  
  // استخراج نوع المركبة من بيانات الخدمة
  String _extractVehicleType(Map<String, dynamic> vehicle) {
    if (vehicle.containsKey('vehicle') && vehicle['vehicle'] is Map) {
      final vehicleData = vehicle['vehicle'] as Map;
      return vehicleData['type'] ?? 'مركبة نقل';
    }
    return 'مركبة نقل';
  }
  
  // تقدير وقت الوصول بناءً على المسافة
  int _calculateArrivalTime(Map<String, dynamic> vehicle) {
    final distanceStr = vehicle['distance'] ?? '5.0';
    final distance = double.tryParse(distanceStr) ?? 5.0;
    // افتراض معدل سرعة 40 كم/ساعة
    final travelTimeHours = distance / 40.0;
    final travelTimeMinutes = (travelTimeHours * 60).round();
    return travelTimeMinutes < 5 ? 5 : travelTimeMinutes;
  }
  
  // إضافة علامات المركبات على الخريطة
  void _addVehiclesMarkersToMap(List<Map<String, dynamic>> vehicles) {
    for (final vehicle in vehicles) {
      final LatLng position = vehicle['position'];
      _addVehicleMarker(position, vehicle);
    }
  }
  // إضافة علامة مركبة على الخريطة
  void _addVehicleMarker(LatLng position, Map<String, dynamic> vehicle) {
    setState(() {
      final markerId = 'vehicle_${vehicle['id']}';
      
      // إزالة أي علامة موجودة للمركبة
      _markers.removeWhere((marker) => marker.markerId.value == markerId);
      
      // إضافة علامة جديدة
      _markers.add(
        Marker(
          markerId: MarkerId(markerId),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          infoWindow: InfoWindow(
            title: vehicle['company'] ?? 'مركبة متاحة',
            snippet: '${vehicle['type']} - ${vehicle['distance']} كم',
          ),
          onTap: () {
            _showVehicleDetailsBottomSheet(vehicle);
          },
        ),
      );
    });
  }
  // الحصول على رابط صورة المركبة
  String _getVehicleImageUrl(Map<String, dynamic> vehicle) {
    // محاولة استخراج صور الخدمة من بيانات قاعدة البيانات
    if (vehicle.containsKey('imageUrls') && vehicle['imageUrls'] is List && (vehicle['imageUrls'] as List).isNotEmpty) {
      return (vehicle['imageUrls'] as List).first.toString();
    }
    
    // إذا كانت هناك صور للمركبة
    if (vehicle.containsKey('vehicle') && 
        vehicle['vehicle'] is Map && 
        vehicle['vehicle'].containsKey('imageUrls') && 
        vehicle['vehicle']['imageUrls'] is List && 
        (vehicle['vehicle']['imageUrls'] as List).isNotEmpty) {
      return (vehicle['vehicle']['imageUrls'] as List).first.toString();
    }
    
    // استخدام صور افتراضية بناءً على نوع المركبة
    final vehicleType = _extractVehicleType(vehicle).toLowerCase();
    
    if (vehicleType.contains('كبير') || vehicleType.contains('شاحنة')) {
      return 'https://i.imgur.com/3vOS33m.png'; // شاحنة كبيرة
    } else if (vehicleType.contains('صغير')) {
      return 'https://i.imgur.com/9NIAJIw.png'; // شاحنة صغيرة
    } else if (vehicleType.contains('سيارة') || vehicleType.contains('توصيل')) {
      return 'https://i.imgur.com/YJfO4Mq.png'; // سيارة توصيل
    } else if (vehicleType.contains('دراجة') || vehicleType.contains('نارية')) {
      return 'https://i.imgur.com/oiRQRUP.png'; // دراجة نارية
    }
    
    // الصورة الافتراضية
    return 'https://i.imgur.com/YJfO4Mq.png';
  }
  
  // عرض تفاصيل المركبة في نافذة منبثقة
  void _showVehicleDetailsBottomSheet(Map<String, dynamic> vehicle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // رأس النافذة المنبثقة
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'تفاصيل خدمة النقل',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // محتوى التفاصيل
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // صورة المركبة
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: vehicle['image'],
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            height: 180,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            height: 180,
                            child: Icon(
                              Icons.local_shipping,
                              size: 60,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // معلومات المركبة
                      _buildInfoRow(
                        title: 'الاسم:',
                        value: vehicle['company'],
                        icon: Icons.business,
                      ),
                      
                      _buildInfoRow(
                        title: 'نوع المركبة:',
                        value: vehicle['type'],
                        icon: Icons.local_shipping,
                      ),
                      
                      _buildInfoRow(
                        title: 'التقييم:',
                        value: '${vehicle['rating']} ★',
                        icon: Icons.star,
                        valueColor: Colors.amber,
                      ),
                      
                      _buildInfoRow(
                        title: 'السعر التقديري:',
                        value: '${vehicle['price']} دج',
                        icon: Icons.attach_money,
                        valueColor: Colors.green.shade700,
                      ),
                      
                      _buildInfoRow(
                        title: 'المسافة:',
                        value: '${vehicle['distance']} كم',
                        icon: Icons.place,
                        valueColor: Colors.red.shade700,
                      ),
                      
                      _buildInfoRow(
                        title: 'وقت الوصول المتوقع:',
                        value: vehicle['arrivalTime'],
                        icon: Icons.access_time,
                      ),
                      
                      if (vehicle['description'] != null && vehicle['description'].toString().isNotEmpty)
                        _buildInfoRow(
                          title: 'وصف الخدمة:',
                          value: vehicle['description'],
                          icon: Icons.description,
                          isMultiLine: true,
                        ),
                    ],
                  ),
                ),
              ),
              
              // أزرار الإجراءات
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ServiceDetailsScreen(serviceId: vehicle['id']),
                          ),
                        );
                      },
                      icon: const Icon(Icons.info_outline),
                      label: const Text('عرض تفاصيل الخدمة الكاملة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size(double.infinity, 0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // بناء صف معلومات
  Widget _buildInfoRow({
    required String title,
    required String value,
    required IconData icon,
    Color? valueColor,
    bool isMultiLine = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: isMultiLine ? 13 : 14,
                fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.start,
              maxLines: isMultiLine ? 3 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء حساب المسار')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                  borderRadius: const BorderRadius.only(
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
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'المركبات المتاحة',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _showVehiclesList = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ), // <<< COMMA ADDED HERE as it was the most likely cause of the described error
                    Expanded(
                      child: SizedBox(
                        height: 140, // Reduced from 150
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _availableVehicles.length,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          itemBuilder: (context, index) {
                            final vehicle = _availableVehicles[index];
                            return                            GestureDetector(
                              onTap: () {
                                _animateToPosition(vehicle['position']);
                                
                                // عرض تفاصيل المركبة عند النقر عليها
                                _showVehicleDetailsBottomSheet(vehicle);
                              },
                              child: Container(
                                width: 180,
                                margin: const EdgeInsets.symmetric(
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
                                constraints: const BoxConstraints(maxHeight: 185),
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // صورة المركبة
                                      ClipRRect(
                                        borderRadius: const BorderRadius.only(
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
                                              const Icon(Icons.error),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              vehicle['type'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              vehicle['company'],
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.star,
                                                  size: 14,
                                                  color: Colors.amber,
                                                ),
                                                const SizedBox(width: 2),
                                                Text(
                                                  vehicle['rating'],
                                                  style: const TextStyle(fontSize: 12),
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
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.location_on,
                                                  size: 14,
                                                  color: Colors.redAccent,
                                                ),
                                                const SizedBox(width: 2),
                                                Text(
                                                  '${vehicle['distance']} كم',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.redAccent,
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
                icon: const Icon(Icons.local_shipping),
                label: Text('عرض المركبات المتاحة (${_availableVehicles.length})'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
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

// Import dart:math (This class is defined locally, not importing dart:math)
// If you intended to use dart:math, you should import it: import 'dart:math' as math_library;
// and then use math_library.min and math_library.max.
// For now, this custom 'math' class will be used as per the original code.
class math {
  static double min(double a, double b) => a < b ? a : b;
  static double max(double a, double b) => a > b ? a : b;
}