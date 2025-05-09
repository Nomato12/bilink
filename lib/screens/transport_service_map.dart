import 'dart:async';
import 'dart:convert';
import 'dart:math'; // Añadiendo import para poder usar la función min()
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:bilink/screens/service_details_screen.dart';

class TransportServiceMapScreen extends StatefulWidget {
  const TransportServiceMapScreen({super.key});

  @override
  _TransportServiceMapScreenState createState() =>
      _TransportServiceMapScreenState();
}

class _TransportServiceMapScreenState extends State<TransportServiceMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();

  // نقطة الانطلاق الافتراضية (الجزائر العاصمة)
  static const LatLng _defaultLocation = LatLng(36.7538, 3.0588);

  // مواقع البداية والنهاية
  LatLng? _originPosition;
  LatLng? _destinationPosition;

  // العناوين
  String _originAddress = '';
  String _destinationAddress = '';

  // مجموعة العلامات على الخريطة
  final Set<Marker> _markers = {};

  // خط المسار
  final Set<Polyline> _polylines = {};

  // معلومات المسار
  double _distance = 0.0;
  String _duration = '';

  // حالة التحميل
  bool _isLoading = false;
  bool _isSearchingRoute = false;

  // خدمات النقل المتاحة
  List<Map<String, dynamic>> _availableServices = [];

  // حالة عرض قائمة الخدمات
  bool _showServicesList = false;

  // نوع الخريطة
  MapType _currentMapType = MapType.normal;

  // متغيرات البحث
  final TextEditingController _originSearchController = TextEditingController();
  final TextEditingController _destinationSearchController =
      TextEditingController();
  bool _isSearchingOrigin = false;
  bool _isSearchingDestination = false;

  // اقتراحات العناوين
  List<String> _originSuggestions = [];
  List<String> _destinationSuggestions = [];
  bool _showOriginSuggestions = false;
  bool _showDestinationSuggestions = false;

  // قائمة العناوين الأخيرة
  final List<String> _recentAddresses = [
    'الساحة المركزية، الجزائر',
    'شاطئ سيدي فرج، الجزائر',
    'جامعة الجزائر',
    'الحي الجامعي، بوزريعة',
    'قصر الثقافة، الجزائر',
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadTransportServices();

    // إضافة مستمعين لحقول البحث للاقتراحات المباشرة
    _originSearchController.addListener(_updateOriginSuggestions);
    _destinationSearchController.addListener(_updateDestinationSuggestions);
  }

  @override
  void dispose() {
    _originSearchController.removeListener(_updateOriginSuggestions);
    _destinationSearchController.removeListener(_updateDestinationSuggestions);
    _originSearchController.dispose();
    _destinationSearchController.dispose();
    super.dispose();
  }

  // استرجاع الموقع الحالي للمستخدم
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // طلب الإذن لاستخدام خدمة الموقع
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

      // الحصول على العنوان من الإحداثيات
      _getAddressFromLatLng(_originPosition!, true);

      // تحريك الخريطة للموقع الحالي
      _animateToPosition(_originPosition!);

      // إضافة علامة للموقع الحالي
      _addMarker(
        _originPosition!,
        'origin',
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        _originAddress.isEmpty ? 'موقعك الحالي' : _originAddress,
      );
    } catch (e) {
      print('Error getting location: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء تحديد الموقع: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // جلب العنوان من الإحداثيات
  Future<void> _getAddressFromLatLng(LatLng position, bool isOrigin) async {
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        final String address = '${place.street}, ${place.locality}, ${place.country}';

        setState(() {
          if (isOrigin) {
            _originAddress = address;
            // تحديث نص حقل البحث للموقع الحالي
            _originSearchController.text = address;
          } else {
            _destinationAddress = address;
            // تحديث نص حقل البحث للوجهة
            _destinationSearchController.text = address;
          }
        });
      }
    } catch (e) {
      print('Error getting address: $e');
    }
  }

  // تحديد الإحداثيات من العنوان
  Future<void> _getLatLngFromAddress(String address, bool isOrigin) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final List<Location> locations = await locationFromAddress(address);

      if (locations.isNotEmpty) {
        final Location location = locations.first;
        final LatLng position = LatLng(location.latitude, location.longitude);

        if (isOrigin) {
          setState(() {
            _originPosition = position;
            _originAddress = address;
          });

          _addMarker(
            _originPosition!,
            'origin',
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
            _originAddress,
          );
        } else {
          setState(() {
            _destinationPosition = position;
            _destinationAddress = address;
          });

          _addMarker(
            _destinationPosition!,
            'destination',
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            _destinationAddress,
          );
        }

        _animateToPosition(position);
      }
    } catch (e) {
      print('Error getting location from address: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء البحث عن العنوان: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // تحديث اقتراحات العناوين لحقل نقطة الانطلاق أثناء الكتابة
  void _updateOriginSuggestions() {
    final text = _originSearchController.text.trim();

    if (text.isEmpty) {
      setState(() {
        _showOriginSuggestions = false;
        _originSuggestions = [];
      });
      return;
    }

    // إعداد قائمة الاقتراحات بناءً على النص المكتوب
    final suggestions =
        _recentAddresses
            .where(
              (address) => address.toLowerCase().contains(text.toLowerCase()),
            )
            .toList();

    setState(() {
      _originSuggestions = suggestions;
      _showOriginSuggestions = suggestions.isNotEmpty;
    });
  }

  // تحديث اقتراحات العناوين لحقل الوجهة أثناء الكتابة
  void _updateDestinationSuggestions() {
    final text = _destinationSearchController.text.trim();

    if (text.isEmpty) {
      setState(() {
        _showDestinationSuggestions = false;
        _destinationSuggestions = [];
      });
      return;
    }

    // إعداد قائمة الاقتراحات بناءً على النص المكتوب
    final suggestions =
        _recentAddresses
            .where(
              (address) => address.toLowerCase().contains(text.toLowerCase()),
            )
            .toList();

    setState(() {
      _destinationSuggestions = suggestions;
      _showDestinationSuggestions = suggestions.isNotEmpty;
    });
  }

  // تحريك الخريطة لموقع معين
  Future<void> _animateToPosition(LatLng position) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 15.0),
      ),
    );
  }

  // عرض كامل المسار على الخريطة
  Future<void> _showFullRoute() async {
    if (_originPosition != null && _destinationPosition != null) {
      final GoogleMapController controller = await _controller.future;

      final LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          _originPosition!.latitude < _destinationPosition!.latitude
              ? _originPosition!.latitude
              : _destinationPosition!.latitude,
          _originPosition!.longitude < _destinationPosition!.longitude
              ? _originPosition!.longitude
              : _destinationPosition!.longitude,
        ),
        northeast: LatLng(
          _originPosition!.latitude > _destinationPosition!.latitude
              ? _originPosition!.latitude
              : _destinationPosition!.latitude,
          _originPosition!.longitude > _destinationPosition!.longitude
              ? _originPosition!.longitude
              : _destinationPosition!.longitude,
        ),
      );

      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
    }
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

  // تحديد المسار بين نقطتين باستخدام مسارات الطرق الحقيقية
  Future<void> _getRoutePolyline() async {
    if (_originPosition == null || _destinationPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تحديد نقطتي البداية والنهاية')),
      );
      return;
    }

    setState(() {
      _isSearchingRoute = true;
      _polylines.clear();
    });

    try {
      print(
        "Getting directions from: ${_originPosition!.latitude},${_originPosition!.longitude} to ${_destinationPosition!.latitude},${_destinationPosition!.longitude}",
      );

      // استخدام HTTP مباشر للاتصال بـ Google Directions API
      final apiKey = 'AIzaSyCSsMQzPwR92-RwufaNA9kPpi0nB4XjAtw';
      final origin =
          '${_originPosition!.latitude},${_originPosition!.longitude}';
      final destination =
          '${_destinationPosition!.latitude},${_destinationPosition!.longitude}';

      // بناء URL الطلب مع المعلمات اللازمة وإضافة language=ar
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&mode=driving&key=$apiKey&language=ar',
      );

      print("Making request to Directions API: $url");

      // باستخدام حزمة http للحصول على الاستجابة
      final response = await http.get(url);

      if (response.statusCode == 200) {
        print(
          "Directions API response received: ${response.body.substring(0, min(200, response.body.length))}...",
        );
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          // جمع نقاط المسار من بيانات الاستجابة
          final routes = data['routes'] as List;
          final points = _decodePolyline(
            routes[0]['overview_polyline']['points'],
          );

          final List<LatLng> polylineCoordinates = [];

          // تحويل النقاط إلى إحداثيات LatLng
          for (int i = 0; i < points.length; i++) {
            polylineCoordinates.add(LatLng(points[i][0], points[i][1]));
          }

          // حساب المسافة والوقت من بيانات Google
          double totalDistance = 0;
          int totalDuration = 0;

          final legs = routes[0]['legs'] as List;
          for (var leg in legs) {
            totalDistance +=
                leg['distance']['value'] / 1000; // تحويل من متر إلى كيلومتر
            totalDuration +=
                (leg['duration']['value'] as num)
                    .toInt(); // الوقت بالثواني - تحويل صريح للنوع
          }

          // تنسيق مدة الرحلة
          final hours = totalDuration ~/ 3600;
          final minutes = (totalDuration % 3600) ~/ 60;

          setState(() {
            _distance = totalDistance;
            _duration =
                hours > 0 ? '$hours ساعة و $minutes دقيقة' : '$minutes دقيقة';

            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                color: const Color(0xFF7C3AED), // لون بنفسجي للمسار
                points: polylineCoordinates,
                width: 5,
              ),
            );
          });

          // عرض كامل المسار على الخريطة
          _showFullRoute();

          // البحث عن خدمات النقل المتاحة على المسار
          _findAvailableServicesOnRoute();
        } else {
          print('Error from Directions API: ${data['status']}');
          print(
            'Error message: ${data['error_message'] ?? "No detailed error message"}',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر العثور على مسار: ${data['status']}')),
          );

          // استخدام المسار البديل إذا فشل الحصول على مسار حقيقي
          _createFallbackRoute();
        }
      } else {
        print('Failed to get directions: ${response.statusCode}');
        print('Response body: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'فشل الاتصال بخدمة تحديد المسارات (${response.statusCode})، جاري استخدام المسار التقريبي',
            ),
          ),
        );

        // استخدام المسار البديل إذا فشل الاتصال
        _createFallbackRoute();
      }
    } catch (e) {
      print('Error getting directions: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء تحديد المسار: $e')));

      // استخدام المسار البديل في حالة حدوث أي استثناء
      _createFallbackRoute();
    } finally {
      setState(() {
        _isSearchingRoute = false;
      });
    }
  }

  // دالة فك ترميز خط المسار من استجابة Google
  List<List<double>> _decodePolyline(String encoded) {
    final List<List<double>> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      final double latD = lat / 1E5;
      final double lngD = lng / 1E5;

      poly.add([latD, lngD]);
    }

    return poly;
  }

  // إنشاء مسار بديل في حالة فشل الحصول على مسار حقيقي
  void _createFallbackRoute() {
    if (_originPosition == null || _destinationPosition == null) return;

    // إنشاء مسار تقريبي بين نقطتي البداية والنهاية
    final middleLat =
        (_originPosition!.latitude + _destinationPosition!.latitude) / 2;
    final middleLng =
        (_originPosition!.longitude + _destinationPosition!.longitude) / 2;

    // إضافة بعض الانحراف العشوائي لجعل المسار أقل استقامة
    final latOffset =
        (_originPosition!.latitude - _destinationPosition!.latitude) * 0.1;
    final lngOffset =
        (_originPosition!.longitude - _destinationPosition!.longitude) * 0.15;

    // إنشاء نقطتين وسيطتين للمسار
    final middlePoint1 = LatLng(middleLat + latOffset, middleLng - lngOffset);

    final middlePoint2 = LatLng(middleLat - latOffset, middleLng + lngOffset);

    // إنشاء المسار البديل
    final List<LatLng> polylineCoordinates = [
      _originPosition!,
      middlePoint1,
      middlePoint2,
      _destinationPosition!,
    ];

    // حساب المسافة والوقت
    double totalDistance = 0.0;
    for (int i = 0; i < polylineCoordinates.length - 1; i++) {
      totalDistance += Geolocator.distanceBetween(
        polylineCoordinates[i].latitude,
        polylineCoordinates[i].longitude,
        polylineCoordinates[i + 1].latitude,
        polylineCoordinates[i + 1].longitude,
      );
    }

    // تحويل المسافة من متر إلى كم
    totalDistance = totalDistance / 1000;

    // تقدير وقت الرحلة (متوسط سرعة 50 كم/ساعة)
    final double timeInHours = totalDistance / 50;
    final int hours = timeInHours.floor();
    final int minutes = ((timeInHours - hours) * 60).round();

    setState(() {
      _distance = totalDistance;
      _duration = hours > 0 ? '$hours ساعة و $minutes دقيقة' : '$minutes دقيقة';

      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          color: const Color(0xFF7C3AED),
          points: polylineCoordinates,
          width: 5,
        ),
      );
    });

    // عرض كامل المسار على الخريطة
    _showFullRoute();

    // البحث عن خدمات النقل المتاحة على المسار
    _findAvailableServicesOnRoute();
  }

  // فتح Google Maps للتنقل
  Future<void> _navigateInGoogleMaps() async {
    if (_originPosition == null || _destinationPosition == null) {
      return;
    }

    final originParam =
        '${_originPosition!.latitude},${_originPosition!.longitude}';
    final destParam =
        '${_destinationPosition!.latitude},${_destinationPosition!.longitude}';
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=$originParam&destination=$destParam&travelmode=driving',
    );

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح تطبيق الخرائط')));
    }
  }

  // تحميل خدمات النقل المتاحة
  Future<void> _loadTransportServices() async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('services')
              .where('type', isEqualTo: 'نقل')
              .where('isActive', isEqualTo: true)
              .get();

      final List<Map<String, dynamic>> services = [];

      for (var doc in querySnapshot.docs) {
        final Map<String, dynamic> serviceData = doc.data();
        serviceData['id'] = doc.id;
        services.add(serviceData);
      }

      setState(() {
        _availableServices = services;
      });
    } catch (e) {
      print('Error loading transport services: $e');
    }
  }

  // البحث عن خدمات النقل المتاحة على المسار
  void _findAvailableServicesOnRoute() {
    if (_originPosition == null || _destinationPosition == null) {
      return;
    }

    final List<Map<String, dynamic>> servicesOnRoute = [];

    for (var service in _availableServices) {
      if (service.containsKey('location') &&
          service['location'] != null &&
          service['location'] is Map &&
          service['location'].containsKey('latitude') &&
          service['location'].containsKey('longitude')) {
        final LatLng servicePosition = LatLng(
          service['location']['latitude'],
          service['location']['longitude'],
        );

        // حساب المسافة من موقع الخدمة إلى نقطة البداية
        final double distanceToOrigin =
            Geolocator.distanceBetween(
              servicePosition.latitude,
              servicePosition.longitude,
              _originPosition!.latitude,
              _originPosition!.longitude,
            ) /
            1000; // تحويل من متر إلى كم

        // نضيف الخدمات التي ضمن نطاق 15 كم من نقطة البداية
        if (distanceToOrigin <= 15.0) {
          service['distance'] = distanceToOrigin.toStringAsFixed(2);
          servicesOnRoute.add(service);

          // إضافة علامة الخدمة على الخريطة
          _addMarker(
            servicePosition,
            'service_${service['id']}',
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            service['title'] ?? 'خدمة نقل',
          );
        }
      }
    }

    setState(() {
      _availableServices = servicesOnRoute;
      _showServicesList = true;
    });
  }

  // تنظيف الخريطة والعودة للحالة الأولية
  void _resetMap() {
    setState(() {
      _destinationPosition = null;
      _destinationAddress = '';
      _polylines.clear();
      _markers.removeWhere((marker) => marker.markerId.value != 'origin');
      _distance = 0.0;
      _duration = '';
      _showServicesList = false;
    });

    if (_originPosition != null) {
      _animateToPosition(_originPosition!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('خدمات النقل'),
        backgroundColor: const Color(0xFF8B5CF6),
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
            onPressed: _resetMap,
            tooltip: 'إعادة ضبط',
          ),
        ],
      ),
      body: Stack(
        children: [
          // خريطة Google
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
              if (_destinationPosition == null) {
                // إذا لم يتم تحديد وجهة, فإن النقرة تحدد الوجهة
                setState(() {
                  _destinationPosition = position;
                });
                _addMarker(
                  position,
                  'destination',
                  BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed,
                  ),
                  'الوجهة',
                );
                _getAddressFromLatLng(position, false);
              }
            },
          ),

          // قسم البحث عن العناوين
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // حقل موقع الانطلاق
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.deepPurple.withOpacity(0.2),
                          ),
                          child: const Icon(
                            Icons.circle,
                            color: Colors.deepPurple,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _originSearchController,
                                decoration: InputDecoration(
                                  hintText: 'موقع الانطلاق',
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  suffixIcon:
                                      _isSearchingOrigin
                                          ? Container(
                                            height: 16,
                                            width: 16,
                                            padding: EdgeInsets.all(8),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.deepPurple,
                                            ),
                                          )
                                          : null,
                                ),
                                onSubmitted: (value) {
                                  if (value.isNotEmpty) {
                                    setState(() {
                                      _isSearchingOrigin = true;
                                      _showOriginSuggestions = false;
                                    });
                                    _getLatLngFromAddress(value, true);
                                    setState(() {
                                      _isSearchingOrigin = false;
                                    });
                                  }
                                },
                                onTap: () {
                                  if (_originSearchController.text.isNotEmpty) {
                                    _updateOriginSuggestions();
                                    setState(() {
                                      _showOriginSuggestions =
                                          _originSuggestions.isNotEmpty;
                                      _showDestinationSuggestions = false;
                                    });
                                  }
                                },
                                onChanged: (value) {
                                  _updateOriginSuggestions();
                                  setState(() {
                                    _showOriginSuggestions =
                                        _originSuggestions.isNotEmpty;
                                  });
                                },
                              ),
                              if (_showOriginSuggestions)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 5,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  margin: EdgeInsets.only(top: 4),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    itemCount: _originSuggestions.length,
                                    separatorBuilder:
                                        (context, index) => Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      return ListTile(
                                        dense: true,
                                        visualDensity: VisualDensity(
                                          horizontal: 0,
                                          vertical: -4,
                                        ),
                                        leading: Icon(
                                          Icons.history,
                                          size: 18,
                                          color: Colors.deepPurple,
                                        ),
                                        title: Text(
                                          _originSuggestions[index],
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        onTap: () {
                                          setState(() {
                                            _originSearchController.text =
                                                _originSuggestions[index];
                                            _showOriginSuggestions = false;
                                            _isSearchingOrigin = true;
                                          });
                                          _getLatLngFromAddress(
                                            _originSuggestions[index],
                                            true,
                                          );
                                          setState(() {
                                            _isSearchingOrigin = false;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.my_location,
                            color: Colors.deepPurple,
                          ),
                          onPressed: _getCurrentLocation,
                          tooltip: 'موقعي الحالي',
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // حقل الوجهة
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withOpacity(0.2),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _destinationSearchController,
                                decoration: InputDecoration(
                                  hintText: 'اختر وجهتك',
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  suffixIcon:
                                      _isSearchingDestination
                                          ? Container(
                                            height: 16,
                                            width: 16,
                                            padding: EdgeInsets.all(8),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.red,
                                            ),
                                          )
                                          : null,
                                ),
                                onSubmitted: (value) {
                                  if (value.isNotEmpty) {
                                    setState(() {
                                      _isSearchingDestination = true;
                                      _showDestinationSuggestions = false;
                                    });
                                    _getLatLngFromAddress(value, false);
                                    setState(() {
                                      _isSearchingDestination = false;
                                    });
                                  }
                                },
                                onTap: () {
                                  if (_destinationSearchController
                                      .text
                                      .isNotEmpty) {
                                    _updateDestinationSuggestions();
                                    setState(() {
                                      _showDestinationSuggestions =
                                          _destinationSuggestions.isNotEmpty;
                                      _showOriginSuggestions = false;
                                    });
                                  }
                                },
                                onChanged: (value) {
                                  _updateDestinationSuggestions();
                                  setState(() {
                                    _showDestinationSuggestions =
                                        _destinationSuggestions.isNotEmpty;
                                  });
                                },
                              ),
                              if (_showDestinationSuggestions)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 5,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  margin: EdgeInsets.only(top: 4),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    itemCount: _destinationSuggestions.length,
                                    separatorBuilder:
                                        (context, index) => Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      return ListTile(
                                        dense: true,
                                        visualDensity: VisualDensity(
                                          horizontal: 0,
                                          vertical: -4,
                                        ),
                                        leading: Icon(
                                          Icons.history,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        title: Text(
                                          _destinationSuggestions[index],
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        onTap: () {
                                          setState(() {
                                            _destinationSearchController.text =
                                                _destinationSuggestions[index];
                                            _showDestinationSuggestions = false;
                                            _isSearchingDestination = true;
                                          });
                                          _getLatLngFromAddress(
                                            _destinationSuggestions[index],
                                            false,
                                          );
                                          setState(() {
                                            _isSearchingDestination = false;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_location,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('انقر على الخريطة لتحديد الوجهة'),
                              ),
                            );
                          },
                          tooltip: 'اختر على الخريطة',
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // زر البحث عن المسار
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _originPosition != null &&
                                    _destinationPosition != null
                                ? _getRoutePolyline
                                : null,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFF8B5CF6),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child:
                            _isSearchingRoute
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                    strokeWidth: 3,
                                  ),
                                )
                                : const Text(
                                  'بحث عن المسار',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // معلومات المسار والخدمات المتاحة
          if (_distance > 0 && _showServicesList)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: DraggableScrollableSheet(
                  initialChildSize: 0.3,
                  minChildSize: 0.2,
                  maxChildSize: 0.5,
                  expand: false,
                  builder: (context, scrollController) {
                    return Column(
                      children: [
                        // مقبض التمرير
                        Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 4),
                          height: 4,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

                        // معلومات الرحلة
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'تفاصيل الرحلة',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    icon: const Icon(
                                      Icons.directions,
                                      size: 18,
                                    ),
                                    label: const Text('فتح في خرائط جوجل'),
                                    onPressed: _navigateInGoogleMaps,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildRouteInfoCard(
                                      'المسافة',
                                      '${_distance.toStringAsFixed(1)} كم',
                                      Icons.straighten,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildRouteInfoCard(
                                      'المدة التقديرية',
                                      _duration,
                                      Icons.access_time,
                                    ),
                                  ),
                                ],
                              ),

                              const Divider(height: 32),

                              // عنوان قائمة الخدمات المتاحة
                              Row(
                                children: [
                                  const Icon(
                                    Icons.local_shipping,
                                    color: Color(0xFF8B5CF6),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'الخدمات المتاحة (${_availableServices.length})',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // قائمة الخدمات المتاحة
                        Expanded(
                          child:
                              _availableServices.isEmpty
                                  ? const Center(
                                    child: Text(
                                      'لا توجد خدمات نقل متاحة في هذه المنطقة',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                  : ListView.builder(
                                    controller: scrollController,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    itemCount: _availableServices.length,
                                    itemBuilder: (context, index) {
                                      final service = _availableServices[index];
                                      return _buildServiceCard(service);
                                    },
                                  ),
                        ),
                      ],
                    );
                  },
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

      // أزرار تحكم الخريطة
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
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
            onPressed: () async {
              if (_originPosition != null) {
                _animateToPosition(_originPosition!);
              }
            },
            heroTag: 'my_location',
            backgroundColor: Colors.white,
            foregroundColor: Colors.blue,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }

  // بطاقة معلومات المسار
  Widget _buildRouteInfoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF8B5CF6)),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  // بطاقة خدمة النقل
  Widget _buildServiceCard(Map<String, dynamic> service) {
    final String title = service['title'] ?? 'خدمة بدون عنوان';
    final String type = service['type'] ?? 'نقل';
    final double price = (service['price'] as num?)?.toDouble() ?? 0.0;
    final double rating = (service['rating'] as num?)?.toDouble() ?? 0.0;
    final String distance = service['distance'] ?? '0.0';

    // الصور
    List<dynamic> imageUrls = service['imageUrls'] ?? [];
    if (imageUrls.isEmpty &&
        service.containsKey('vehicle') &&
        service['vehicle'] != null) {
      final vehicleImgs = service['vehicle']['imageUrls'];
      if (vehicleImgs is List && vehicleImgs.isNotEmpty) {
        imageUrls = vehicleImgs;
      }
    }

    // نوع المركبة
    String vehicleType = '';
    if (service.containsKey('vehicle') &&
        service['vehicle'] != null &&
        service['vehicle'] is Map &&
        service['vehicle'].containsKey('type')) {
      vehicleType = service['vehicle']['type'] ?? '';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => ServiceDetailsScreen(serviceId: service['id']),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Row(
              children: [
                // صورة الخدمة
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    image:
                        imageUrls.isNotEmpty
                            ? DecorationImage(
                              image: NetworkImage(imageUrls[0]),
                              fit: BoxFit.cover,
                            )
                            : null,
                  ),
                  child:
                      imageUrls.isEmpty
                          ? Center(
                            child: Icon(
                              Icons.local_shipping,
                              size: 40,
                              color: Colors.grey.shade400,
                            ),
                          )
                          : null,
                ),

                // معلومات الخدمة
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (vehicleType.isNotEmpty)
                          Row(
                            children: [
                              Icon(
                                Icons.directions_car,
                                size: 14,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                vehicleType,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'يبعد $distance كم',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // التقييم
                            if (rating > 0)
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),

                            // السعر
                            Text(
                              '${price.toStringAsFixed(0)} دج',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8B5CF6),
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

            // زر طلب الخدمة
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              ServiceDetailsScreen(serviceId: service['id']),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('طلب هذه الخدمة'),
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // حوار البحث عن العنوان
  Future<void> _showAddressSearchDialog(bool isOrigin) async {
    final TextEditingController controller = TextEditingController();
    final FocusNode focusNode = FocusNode();

    final List<String> recentAddresses = [
      'الساحة المركزية، الجزائر',
      'شاطئ سيدي فرج، الجزائر',
      'جامعة الجزائر',
      'الحي الجامعي، بوزريعة',
      'قصر الثقافة، الجزائر',
    ];

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isOrigin ? 'تحديد نقطة الانطلاق' : 'تحديد الوجهة',
            style: const TextStyle(fontSize: 18),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // حقل البحث
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'أدخل العنوان',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      Navigator.of(context).pop();
                      _getLatLngFromAddress(value, isOrigin);
                    }
                  },
                ),

                const SizedBox(height: 16),

                // خيارات البحث السريع
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildQuickSearchButton(
                      icon: Icons.my_location,
                      label: 'موقعي الحالي',
                      onTap: () {
                        Navigator.of(context).pop();
                        if (isOrigin) {
                          _getCurrentLocation();
                        }
                      },
                    ),
                    _buildQuickSearchButton(
                      icon: Icons.map,
                      label: 'اختر على الخريطة',
                      onTap: () {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('انقر على الخريطة لتحديد الموقع'),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // عناوين حديثة
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'العناوين الأخيرة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),

                const SizedBox(height: 8),

                // قائمة العناوين
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemCount: recentAddresses.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: const Icon(Icons.history, size: 18),
                        title: Text(
                          recentAddresses[index],
                          style: const TextStyle(fontSize: 14),
                        ),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        onTap: () {
                          Navigator.of(context).pop();
                          _getLatLngFromAddress(
                            recentAddresses[index],
                            isOrigin,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (controller.text.isNotEmpty) {
                  _getLatLngFromAddress(controller.text, isOrigin);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
              ),
              child: const Text('بحث'),
            ),
          ],
        );
      },
    );

    focusNode.dispose();
    controller.dispose();
  }

  // زر بحث سريع
  Widget _buildQuickSearchButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF8B5CF6)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
