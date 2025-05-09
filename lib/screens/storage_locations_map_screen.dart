import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:bilink/screens/service_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StorageLocationsMapScreen extends StatefulWidget {
  const StorageLocationsMapScreen({super.key});

  @override
  _StorageLocationsMapScreenState createState() =>
      _StorageLocationsMapScreenState();
}

class _StorageLocationsMapScreenState extends State<StorageLocationsMapScreen> {
  // متغيرات الخريطة
  GoogleMapController? _mapController;
  CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(36.7525, 3.0422), // الجزائر العاصمة كموقع مبدئي
    zoom: 12,
  );

  // متغيرات الموقع
  Position? _currentPosition;
  bool _isLoading = true;
  final Set<Marker> _markers = {};

  // متغيرات البحث
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // متغيرات الخدمات
  List<Map<String, dynamic>> _nearbyStorageServices = [];
  bool _isLoadingServices = false;
  Map<String, dynamic>? _selectedService;
  final double _searchRadius = 20.0; // بالكيلومتر

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // الحصول على إذن الموقع والموقع الحالي
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // التحقق من تفعيل خدمة الموقع
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('الرجاء تفعيل خدمة الموقع للاستمرار'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // التحقق من إذن الوصول للموقع
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('لم يتم السماح بالوصول للموقع'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
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
          SnackBar(
            content: Text(
              'تم رفض إذن الموقع بشكل دائم. الرجاء تغيير الإعدادات',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'فتح الإعدادات',
              textColor: Colors.white,
              onPressed: () async {
                await Geolocator.openAppSettings();
              },
            ),
          ),
        );
        return;
      }

      // الحصول على الموقع الحالي بدقة عالية
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      );

      setState(() {
        _currentPosition = position;
        _initialCameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 14,
        );
        _isLoading = false;
      });

      // إضافة علامة للموقع الحالي
      _addCurrentLocationMarker();

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(_initialCameraPosition),
        );
      }

      // البحث عن خدمات التخزين القريبة
      _findNearbyStorageServices();
    } catch (e) {
      print('Error getting current location: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تحديد الموقع الحالي: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // إضافة علامة للموقع الحالي
  void _addCurrentLocationMarker() {
    if (_currentPosition == null) return;

    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId('current_location'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          infoWindow: InfoWindow(title: 'موقعك الحالي'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    });
  }

  // حساب المسافة بين نقطتين جغرافيتين بالكيلومتر
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  // البحث عن خدمات التخزين القريبة
  Future<void> _findNearbyStorageServices() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى تحديد موقعك الحالي أولاً'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoadingServices = true;
      _markers.clear();
      _addCurrentLocationMarker();
    });

    try {
      // استعلام لجلب خدمات التخزين النشطة
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('services')
              .where('type', isEqualTo: 'تخزين')
              .where('isActive', isEqualTo: true)
              .get();

      final List<Map<String, dynamic>> services = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;

        // فحص ما إذا كانت الخدمة تحتوي على معلومات الموقع
        if (data.containsKey('location') &&
            data['location'] != null &&
            data['location']['latitude'] != null &&
            data['location']['longitude'] != null) {
          // حساب المسافة بين موقع المستخدم وموقع الخدمة
          final double distance = _calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            data['location']['latitude'],
            data['location']['longitude'],
          );

          // إضافة الخدمة إذا كانت ضمن نطاق البحث
          if (distance <= _searchRadius) {
            data['distance'] = distance.toStringAsFixed(1);

            // جلب بيانات مزود الخدمة إذا كانت متوفرة
            if (data.containsKey('providerId') && data['providerId'] != null) {
              try {
                final providerDoc =
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(data['providerId'])
                        .get();

                if (providerDoc.exists) {
                  data['providerData'] = providerDoc.data();
                }
              } catch (e) {
                print('Error fetching provider data: $e');
              }
            }

            services.add(data);

            // إضافة علامة للخدمة على الخريطة
            _addStorageServiceMarker(data);
          }
        }
      }

      // فرز الخدمات حسب المسافة (الأقرب أولاً)
      services.sort((a, b) {
        final distanceA = double.parse(a['distance'] as String);
        final distanceB = double.parse(b['distance'] as String);
        return distanceA.compareTo(distanceB);
      });

      setState(() {
        _nearbyStorageServices = services;
        _isLoadingServices = false;
      });

      // عرض رسالة بعدد الخدمات المتوفرة
      if (_nearbyStorageServices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('لا توجد خدمات تخزين قريبة في النطاق المحدد'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم العثور على ${_nearbyStorageServices.length} خدمة تخزين قريبة',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error finding nearby storage services: $e');
      setState(() {
        _isLoadingServices = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء البحث عن خدمات التخزين: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // إضافة علامة لخدمة تخزين على الخريطة
  void _addStorageServiceMarker(Map<String, dynamic> service) {
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId('service_${service['id']}'),
          position: LatLng(
            service['location']['latitude'],
            service['location']['longitude'],
          ),
          infoWindow: InfoWindow(
            title: service['title'] ?? 'خدمة تخزين',
            snippet: 'المسافة: ${service['distance']} كم',
            onTap: () {
              // عرض تفاصيل الخدمة عند النقر على العلامة
              _showServiceDetails(service);
            },
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          onTap: () {
            setState(() {
              _selectedService = service;
            });
          },
        ),
      );
    });
  }

  // عرض تفاصيل الخدمة المحددة
  void _showServiceDetails(Map<String, dynamic> service) {
    setState(() {
      _selectedService = service;
    });
  }

  // دالة البحث عن موقع
  Future<void> _searchLocation() async {
    final String searchQuery = _searchController.text.trim();
    if (searchQuery.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final List<Location> locations = await locationFromAddress(
        searchQuery,
        localeIdentifier: 'ar',
      );

      if (locations.isNotEmpty) {
        final Location location = locations.first;
        final LatLng newLocation = LatLng(
          location.latitude,
          location.longitude,
        );

        // تغيير موقع الكاميرا إلى الموقع الذي تم البحث عنه
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(newLocation, 15),
        );

        // تحديث الموقع الحالي والبحث مجدداً عن خدمات قريبة
        setState(() {
          _currentPosition = Position(
            latitude: location.latitude,
            longitude: location.longitude,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
        });

        // إعادة البحث عن خدمات التخزين القريبة من الموقع الجديد
        _findNearbyStorageServices();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لم يتم العثور على الموقع. يرجى التحقق من العنوان المدخل',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ في البحث: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('خدمات التخزين القريبة'),
        backgroundColor: Color(0xFF3498DB),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () {
              _getCurrentLocation();
              _findNearbyStorageServices();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // خريطة جوجل
          _isLoading && _currentPosition == null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF3498DB)),
                    SizedBox(height: 16),
                    Text(
                      'جاري تحديد موقعك الحالي...',
                      style: TextStyle(
                        color: Color(0xFF3498DB),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
              : GoogleMap(
                initialCameraPosition: _initialCameraPosition,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: true,
                mapToolbarEnabled: true,
                compassEnabled: true,
                markers: _markers,
                onMapCreated: (controller) {
                  setState(() {
                    _mapController = controller;
                  });
                },
              ),

          // شريط البحث
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'ابحث عن موقع أو عنوان...',
                  hintTextDirection: TextDirection.rtl,
                  prefixIcon:
                      _isSearching
                          ? Container(
                            padding: EdgeInsets.all(10),
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF3498DB),
                            ),
                          )
                          : IconButton(
                            icon: Icon(Icons.search),
                            onPressed: _searchLocation,
                            color: Color(0xFF3498DB),
                          ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _searchLocation(),
              ),
            ),
          ),

          // قائمة خدمات التخزين القريبة
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 140, // تقليل الارتفاع أكثر
              padding: EdgeInsets.symmetric(vertical: 2), // تقليل الهامش
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  ),
                ],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // عنوان القائمة
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ), // تقليل الهامش
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'خدمات التخزين القريبة',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3498DB),
                          ),
                        ),
                        if (_nearbyStorageServices.isNotEmpty)
                          Text(
                            '${_nearbyStorageServices.length} خدمة',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // قائمة الخدمات
                  Expanded(
                    child:
                        _isLoadingServices
                            ? Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF3498DB),
                              ),
                            )
                            : _nearbyStorageServices.isEmpty
                            ? Center(
                              child: Text(
                                'لا توجد خدمات تخزين قريبة',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            )
                            : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              itemCount: _nearbyStorageServices.length,
                              itemBuilder: (context, index) {
                                final service = _nearbyStorageServices[index];
                                final bool isSelected =
                                    _selectedService != null &&
                                    _selectedService!['id'] == service['id'];
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedService = service;
                                    });
                                    _mapController?.animateCamera(
                                      CameraUpdate.newLatLngZoom(
                                        LatLng(
                                          service['location']['latitude'],
                                          service['location']['longitude'],
                                        ),
                                        16,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 220,
                                    margin: EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isSelected
                                              ? Color(0xFFE3F2FD)
                                              : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color:
                                            isSelected
                                                ? Color(0xFF3498DB)
                                                : Colors.grey[300]!,
                                        width: isSelected ? 2 : 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 3,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.only(
                                            topRight: Radius.circular(8),
                                            bottomRight: Radius.circular(8),
                                          ),
                                          child:
                                              service.containsKey(
                                                        'imageUrls',
                                                      ) &&
                                                      service['imageUrls']
                                                          is List &&
                                                      (service['imageUrls']
                                                              as List)
                                                          .isNotEmpty
                                                  ? CachedNetworkImage(
                                                    imageUrl:
                                                        service['imageUrls'][0],
                                                    width: 55,
                                                    height: 75,
                                                    fit: BoxFit.cover,
                                                    placeholder:
                                                        (
                                                          context,
                                                          url,
                                                        ) => Container(
                                                          color:
                                                              Colors.grey[200],
                                                          child: Icon(
                                                            Icons.warehouse,
                                                            color:
                                                                Colors
                                                                    .grey[400],
                                                            size: 22,
                                                          ),
                                                        ),
                                                    errorWidget:
                                                        (
                                                          context,
                                                          url,
                                                          error,
                                                        ) => Container(
                                                          color:
                                                              Colors.grey[200],
                                                          child: Icon(
                                                            Icons.warehouse,
                                                            color:
                                                                Colors
                                                                    .grey[400],
                                                            size: 22,
                                                          ),
                                                        ),
                                                  )
                                                  : Container(
                                                    width: 55,
                                                    height: 75,
                                                    color: Colors.grey[200],
                                                    child: Icon(
                                                      Icons.warehouse,
                                                      color: Colors.grey[400],
                                                      size: 22,
                                                    ),
                                                  ),
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.all(5),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  service['title'] ??
                                                      'خدمة تخزين',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.location_on,
                                                      color: Color(0xFF3498DB),
                                                      size: 12,
                                                    ),
                                                    SizedBox(width: 2),
                                                    Text(
                                                      'المسافة: ${service['distance']} كم',
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (service.containsKey(
                                                      'providerData',
                                                    ) &&
                                                    service['providerData'] !=
                                                        null &&
                                                    service['providerData']['fullName'] !=
                                                        null)
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.person,
                                                        color: Colors.grey[600],
                                                        size: 12,
                                                      ),
                                                      SizedBox(width: 2),
                                                      Expanded(
                                                        child: Text(
                                                          service['providerData']['fullName'],
                                                          style: TextStyle(
                                                            color:
                                                                Colors
                                                                    .grey[700],
                                                            fontSize: 10,
                                                          ),
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.monetization_on,
                                                      color: Colors.green[600],
                                                      size: 12,
                                                    ),
                                                    SizedBox(width: 2),
                                                    Text(
                                                      '${service['price']} دج',
                                                      style: TextStyle(
                                                        color:
                                                            Colors.green[700],
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: SizedBox(
                                                    height: 20,
                                                    child: ElevatedButton(
                                                      onPressed: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder:
                                                                (
                                                                  context,
                                                                ) => ServiceDetailsScreen(
                                                                  serviceId:
                                                                      service['id'],
                                                                ),
                                                          ),
                                                        );
                                                      },
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Color(
                                                          0xFF3498DB,
                                                        ),
                                                        foregroundColor:
                                                            Colors.white,
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 0,
                                                            ),
                                                        minimumSize: Size(
                                                          60,
                                                          20,
                                                        ),
                                                        textStyle: TextStyle(
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                      child: Text('التفاصيل'),
                                                    ),
                                                  ),
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

          // بطاقة تفاصيل الخدمة المحددة
          if (_selectedService != null)
            Positioned(
              top: 80,
              right: 16,
              child: Container(
                width: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                      spreadRadius: 1,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // عنوان الخدمة
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _selectedService!['title'] ?? 'خدمة تخزين',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF3498DB),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedService = null;
                            });
                          },
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    Divider(),

                    // المسافة
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Color(0xFF3498DB),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'المسافة: ${_selectedService!['distance']} كم',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),

                    // معلومات مزود الخدمة
                    if (_selectedService!.containsKey('providerData') &&
                        _selectedService!['providerData'] != null) ...[
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 6),
                          Text(
                            'المزود: ${_selectedService!['providerData']['fullName'] ?? 'غير معروف'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                    ],

                    // معلومات الاتصال
                    if (_selectedService!.containsKey('providerData') &&
                        _selectedService!['providerData'] != null &&
                        _selectedService!['providerData']['phoneNumber'] !=
                            null) ...[
                      Row(
                        children: [
                          Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 6),
                          Text(
                            _selectedService!['providerData']['phoneNumber'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                    ],

                    // السعر
                    Row(
                      children: [
                        Icon(
                          Icons.monetization_on,
                          size: 14,
                          color: Colors.green[600],
                        ),
                        SizedBox(width: 6),
                        Text(
                          'السعر: ${_selectedService!['price']} دج',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),

                    // زر عرض التفاصيل
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => ServiceDetailsScreen(
                                    serviceId: _selectedService!['id'],
                                  ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3498DB),
                          foregroundColor: Colors.white,
                        ),
                        child: Text('عرض التفاصيل'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // مؤشر التحميل
          if (_isLoadingServices)
            Container(
              color: Colors.black.withOpacity(0.1),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF3498DB)),
              ),
            ),
        ],
      ),
    );
  }
}
