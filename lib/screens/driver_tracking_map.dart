import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:async';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class DriverTrackingMapPage extends StatefulWidget {
  final String serviceId;
  final bool autoStartTracking;
  final Function(double, double, String)? onLocationSelected;

  const DriverTrackingMapPage({
    super.key,
    required this.serviceId,
    this.autoStartTracking = true, // تغيير القيمة الافتراضية إلى true
    this.onLocationSelected,
  });

  @override
  _DriverTrackingMapPageState createState() => _DriverTrackingMapPageState();
}

class _DriverTrackingMapPageState extends State<DriverTrackingMapPage> {
  // متغيرات الخريطة
  GoogleMapController? _mapController;
  CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(36.7525, 3.0422), // الجزائر العاصمة كموقع مبدئي
    zoom: 12,
  );

  // متغيرات الموقع
  Position? _currentPosition;
  LatLng? _originLocation;
  LatLng? _destinationLocation;
  String _originAddress = "موقع الانطلاق غير محدد";
  String _destinationAddress = "موقع الوصول غير محدد";
  bool _isLoading = true;
  final Set<Marker> _markers = {};

  // متغيرات المسار
  final Set<Polyline> _polylines = {};
  final List<LatLng> _polylineCoordinates = [];
  final PolylinePoints _polylinePoints = PolylinePoints();

  // متغيرات الصور ورفع الملفات
  final List<File> _originImages = [];
  bool _isUploading = false;

  // متغيرات التتبع المباشر
  Timer? _locationUpdateTimer;
  bool _isLiveTracking = false;
  final List<LatLng> _trackingHistory = [];

  // الألوان والتنسيق
  final Color _primaryColor = Color(0xFFE67E22);
  final Color _secondaryColor = Color(0xFF3498DB);

  @override
  void initState() {
    super.initState();
    _getCurrentLocation().then((_) {
      // تحقق مما إذا كان يجب بدء التتبع تلقائيًا
      if (widget.autoStartTracking) {
        _startLiveTrackingAutomatically();
      }
    });
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  // دالة جديدة لبدء التتبع المباشر تلقائياً
  void _startLiveTrackingAutomatically() {
    if (!_isLiveTracking && _currentPosition != null) {
      setState(() {
        _isLiveTracking = true;
        _trackingHistory.clear();
        _trackingHistory.add(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        );
      });

      // إضافة العلامة للموقع الحالي
      _updateOriginLocationFromCurrentPosition();

      // بدء تحديثات الموقع الدورية
      _startLocationUpdates();

      // رسالة للمستخدم
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم بدء التتبع المباشر تلقائياً. موقعك يُرسل الآن مباشرة إلى العملاء',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // تحديث موقع الانطلاق باستخدام الموقع الحالي
  void _updateOriginLocationFromCurrentPosition() {
    if (_currentPosition != null) {
      setState(() {
        _originLocation = LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      });
      _updateMarkerAndAddress();

      // تحديث الموقع في قاعدة البيانات فوراً
      _updateDriverLocation(_originLocation!);
    }
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
        _originLocation = LatLng(position.latitude, position.longitude);
        _initialCameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 15,
        );
        _isLoading = false;

        // إضافة نقطة وصول افتراضية تلقائياً إذا كان التتبع يبدأ تلقائياً
        if (widget.autoStartTracking) {
          // لا نحتاج لتحديد نقطة وصول حقيقية للتتبع المباشر
          _destinationLocation = null;
        }
      });

      _updateMarkerAndAddress();

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(_initialCameraPosition),
        );
      }

      // جلب البيانات المحفوظة سابقاً (إن وجدت)
      _loadSavedRouteData();
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

  // جلب بيانات المسار المحفوظة مسبقاً
  Future<void> _loadSavedRouteData() async {
    try {
      final routeData =
          await FirebaseFirestore.instance
              .collection('driver_routes')
              .doc(widget.serviceId)
              .get();

      if (routeData.exists && routeData.data() != null) {
        final data = routeData.data()!;

        // استرجاع موقع البداية
        if (data.containsKey('origin') && data['origin'] != null) {
          final originData = data['origin'];
          setState(() {
            _originLocation = LatLng(
              originData['latitude'],
              originData['longitude'],
            );
            _originAddress = originData['address'] ?? 'موقع الانطلاق';
          });
        }

        // استرجاع موقع الوصول
        if (data.containsKey('destination') && data['destination'] != null) {
          final destinationData = data['destination'];
          setState(() {
            _destinationLocation = LatLng(
              destinationData['latitude'],
              destinationData['longitude'],
            );
            _destinationAddress = destinationData['address'] ?? 'موقع الوصول';
          });
        }

        // تحديث العلامات والمسار
        _updateMarkerAndAddress();
        if (_originLocation != null && _destinationLocation != null) {
          _getPolylinePoints();
        }
      }
    } catch (e) {
      print('Error loading saved route data: $e');
      // لا نعرض رسالة خطأ للمستخدم هنا لتجنب الإزعاج
    }
  }

  // تحديث العلامات على الخريطة والعناوين النصية
  Future<void> _updateMarkerAndAddress() async {
    setState(() {
      _markers.clear();

      // إضافة علامة موقع الانطلاق
      if (_originLocation != null) {
        _markers.add(
          Marker(
            markerId: MarkerId('origin_location'),
            position: _originLocation!,
            infoWindow: InfoWindow(title: 'موقع الانطلاق'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
          ),
        );
      }

      // إضافة علامة موقع الوصول
      if (_destinationLocation != null) {
        _markers.add(
          Marker(
            markerId: MarkerId('destination_location'),
            position: _destinationLocation!,
            infoWindow: InfoWindow(title: 'موقع الوصول'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
          ),
        );
      }
    });

    // تحديث عنوان موقع الانطلاق
    if (_originLocation != null) {
      try {
        final List<Placemark> placemarks = await placemarkFromCoordinates(
          _originLocation!.latitude,
          _originLocation!.longitude,
          localeIdentifier: 'ar',
        );

        if (placemarks.isNotEmpty) {
          final Placemark place = placemarks[0];
          _formatAddress(place).then((address) {
            setState(() {
              _originAddress = address;
            });
          });
        }
      } catch (e) {
        print('Error getting origin address: $e');
      }
    }

    // تحديث عنوان موقع الوصول
    if (_destinationLocation != null) {
      try {
        final List<Placemark> placemarks = await placemarkFromCoordinates(
          _destinationLocation!.latitude,
          _destinationLocation!.longitude,
          localeIdentifier: 'ar',
        );

        if (placemarks.isNotEmpty) {
          final Placemark place = placemarks[0];
          _formatAddress(place).then((address) {
            setState(() {
              _destinationAddress = address;
            });
          });
        }
      } catch (e) {
        print('Error getting destination address: $e');
      }
    }
  }

  // تنسيق العنوان من كائن Placemark
  Future<String> _formatAddress(Placemark place) async {
    String address = '';

    if (place.street != null && place.street!.isNotEmpty) {
      address += '${place.street}';
    }

    if (place.locality != null && place.locality!.isNotEmpty) {
      if (address.isNotEmpty) address += '، ';
      address += '${place.locality}';
    }

    if (place.administrativeArea != null &&
        place.administrativeArea!.isNotEmpty) {
      if (address.isNotEmpty) address += '، ';
      address += '${place.administrativeArea}';
    }

    if (place.country != null && place.country!.isNotEmpty) {
      if (address.isNotEmpty) address += '، ';
      address += '${place.country}';
    }

    return address.isNotEmpty ? address : 'العنوان غير متوفر';
  }

  // رسم المسار بين موقعي الانطلاق والوصول
  Future<void> _getPolylinePoints() async {
    if (_originLocation == null || _destinationLocation == null) return;

    setState(() {
      _polylineCoordinates.clear();
      _polylines.clear();
    });

    try {
      // استخدام نهج بسيط لرسم خط مستقيم بين النقطتين
      _polylineCoordinates.add(_originLocation!);
      _polylineCoordinates.add(_destinationLocation!);

      setState(() {
        _polylines.add(
          Polyline(
            polylineId: PolylineId('route'),
            points: _polylineCoordinates,
            color: _primaryColor,
            width: 5,
          ),
        );
      });

      // ضبط حدود الخريطة لتظهر المسار كاملاً
      _fitMapToBounds();
    } catch (e) {
      print('Error getting polyline: $e');
      // في حالة الخطأ، نرسم خط مستقيم بين النقطتين
      setState(() {
        _polylineCoordinates.add(_originLocation!);
        _polylineCoordinates.add(_destinationLocation!);
        _polylines.add(
          Polyline(
            polylineId: PolylineId('route'),
            points: _polylineCoordinates,
            color: _primaryColor,
            width: 5,
          ),
        );
      });
    }
  }

  // ضبط حدود الخريطة لتظهر المسار كاملاً
  void _fitMapToBounds() {
    if (_originLocation == null ||
        _destinationLocation == null ||
        _mapController == null) {
      return;
    }

    final LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
        _originLocation!.latitude < _destinationLocation!.latitude
            ? _originLocation!.latitude
            : _destinationLocation!.latitude,
        _originLocation!.longitude < _destinationLocation!.longitude
            ? _originLocation!.longitude
            : _destinationLocation!.longitude,
      ),
      northeast: LatLng(
        _originLocation!.latitude > _destinationLocation!.latitude
            ? _originLocation!.latitude
            : _destinationLocation!.latitude,
        _originLocation!.longitude > _destinationLocation!.longitude
            ? _originLocation!.longitude
            : _destinationLocation!.longitude,
      ),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
  }

  // إضافة صور لموقع الانطلاق
  Future<void> _pickOriginImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        setState(() {
          _originImages.addAll(
            images.map((xFile) => File(xFile.path)).toList(),
          );
        });
      }
    } catch (e) {
      print('Error picking origin images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء اختيار الصور: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // بدء/إيقاف التتبع المباشر
  void _toggleLiveTracking() {
    if (_isLiveTracking) {
      // إيقاف التتبع
      _locationUpdateTimer?.cancel();
      setState(() {
        _isLiveTracking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إيقاف التتبع المباشر'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // بدء التتبع
      setState(() {
        _isLiveTracking = true;
        _trackingHistory.clear();

        if (_currentPosition != null) {
          _trackingHistory.add(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          );
        }
      });

      _startLocationUpdates();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تفعيل التتبع المباشر'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // تحديث الموقع بشكل دوري
  void _startLocationUpdates() {
    _locationUpdateTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
      try {
        final Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        setState(() {
          _currentPosition = position;
          final newLocation = LatLng(position.latitude, position.longitude);
          _trackingHistory.add(newLocation);

          // رسم مسار التتبع
          _polylines.removeWhere(
            (polyline) => polyline.polylineId.value == 'tracking',
          );
          _polylines.add(
            Polyline(
              polylineId: PolylineId('tracking'),
              points: _trackingHistory,
              color: Colors.blue,
              width: 5,
              patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            ),
          );

          // تحديث موقع السائق في قاعدة البيانات
          _updateDriverLocation(newLocation);
        });
      } catch (e) {
        print('Error updating location: $e');
      }
    });
  }

  // تحديث موقع السائق في قاعدة البيانات
  Future<void> _updateDriverLocation(LatLng location) async {
    try {
      await FirebaseFirestore.instance
          .collection('driver_tracking')
          .doc(widget.serviceId)
          .set({
            'serviceId': widget.serviceId,
            'latitude': location.latitude,
            'longitude': location.longitude,
            'timestamp': FieldValue.serverTimestamp(),
            'geoPoint': GeoPoint(location.latitude, location.longitude),
          }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating driver location: $e');
    }
  }

  // حفظ المسار في قاعدة البيانات
  Future<void> _saveRoute() async {
    if (_originLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الرجاء تحديد موقع الانطلاق'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _isUploading = true;
      });

      // تحميل صور موقع الانطلاق (إذا كانت موجودة)
      final List<String> originImageUrls = [];

      if (_originImages.isNotEmpty) {
        for (var imageFile in _originImages) {
          try {
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final imageName =
                'origin_${timestamp}_${originImageUrls.length}.jpg';
            final storageRef = FirebaseStorage.instance.ref().child(
              'routes/${widget.serviceId}/origin/$imageName',
            );

            final uploadTask = storageRef.putFile(
              imageFile,
              SettableMetadata(
                contentType: 'image/jpeg',
                customMetadata: {
                  'latitude': _originLocation!.latitude.toString(),
                  'longitude': _originLocation!.longitude.toString(),
                  'address': _originAddress,
                },
              ),
            );

            final TaskSnapshot snapshot = await uploadTask;
            final String imageUrl = await snapshot.ref.getDownloadURL();
            originImageUrls.add(imageUrl);
          } catch (e) {
            print('Error uploading origin image: $e');
            continue;
          }
        }
      }

      // حفظ بيانات المسار في Firestore
      final Map<String, dynamic> routeData = {
        'serviceId': widget.serviceId,
        'timestamp': FieldValue.serverTimestamp(),
        'origin': {
          'latitude': _originLocation!.latitude,
          'longitude': _originLocation!.longitude,
          'address': _originAddress,
          'geoPoint': GeoPoint(
            _originLocation!.latitude,
            _originLocation!.longitude,
          ),
          'imageUrls': originImageUrls,
        },
        'isLiveTracking': _isLiveTracking || widget.autoStartTracking,
      };

      // إضافة بيانات مسار التتبع إذا كان موجوداً
      if (_trackingHistory.isNotEmpty) {
        final List<Map<String, dynamic>> trackingPoints =
            _trackingHistory
                .map(
                  (point) => {
                    'latitude': point.latitude,
                    'longitude': point.longitude,
                    'geoPoint': GeoPoint(point.latitude, point.longitude),
                  },
                )
                .toList();

        routeData['trackingHistory'] = trackingPoints;
      }

      // حفظ البيانات في Firestore
      await FirebaseFirestore.instance
          .collection('driver_routes')
          .doc(widget.serviceId)
          .set(routeData);

      setState(() {
        _isLoading = false;
        _isUploading = false;
      });

      // عرض رسالة نجاح وإغلاق الصفحة
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تفعيل تتبع الموقع بنجاح'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // إعداد البيانات التي سيتم إرجاعها
      final Map<String, dynamic> result = {
        'latitude': _originLocation!.latitude,
        'longitude': _originLocation!.longitude,
        'address': _originAddress,
        'isLiveTracking': true,
      };
      
      // استدعاء دالة رد النداء (callback) إذا كانت متوفرة
      if (widget.onLocationSelected != null) {
        widget.onLocationSelected!(
          _originLocation!.latitude,
          _originLocation!.longitude,
          _originAddress,
        );
      }

      Navigator.of(context).pop(result);
    } catch (e) {
      print('Error saving route: $e');
      setState(() {
        _isLoading = false;
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء حفظ المسار: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تفعيل تتبع موقع الشحنة'),
        backgroundColor: _primaryColor,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'تحديث الموقع الحالي',
            onPressed: _getCurrentLocation,
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
                    CircularProgressIndicator(color: _primaryColor),
                    SizedBox(height: 16),
                    Text(
                      'جاري تحديد موقعك الحالي...',
                      style: TextStyle(
                        color: _primaryColor,
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
                polylines: _polylines,
                onMapCreated: (controller) {
                  setState(() {
                    _mapController = controller;
                  });
                },
                onTap: (LatLng location) {
                  // تم تغيير السلوك ليكون فقط لتحديد موقع الانطلاق
                  setState(() {
                    _originLocation = location;
                  });
                  _updateMarkerAndAddress();
                },
              ),

          // واجهة التحكم بالطريق ونقاط الانطلاق
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              children: [
                // أزرار التحكم
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // زر مسح المسار
                      FloatingActionButton.small(
                        heroTag: 'clear_route',
                        onPressed: () {
                          setState(() {
                            _originLocation = null;
                            _markers.clear();
                            _polylines.clear();
                            _polylineCoordinates.clear();
                            _originImages.clear();
                            _trackingHistory.clear();
                            _isLiveTracking = false;
                          });
                          _locationUpdateTimer?.cancel();
                        },
                        backgroundColor: Colors.red,
                        tooltip: 'مسح الموقع',
                        child: Icon(Icons.clear, color: Colors.white),
                      ),

                      // زر التتبع المباشر
                      FloatingActionButton.small(
                        heroTag: 'live_tracking',
                        onPressed: _toggleLiveTracking,
                        backgroundColor:
                            _isLiveTracking ? Colors.red : Colors.green,
                        tooltip:
                            _isLiveTracking
                                ? 'إيقاف التتبع'
                                : 'بدء التتبع المباشر',
                        child: Icon(
                          _isLiveTracking
                              ? Icons.location_off
                              : Icons.location_on,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // معلومات المسار
                Card(
                  margin: EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 6,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // عنوان البطاقة
                        Row(
                          children: [
                            Icon(Icons.location_on, color: _primaryColor),
                            SizedBox(width: 8),
                            Text(
                              'تفاصيل التتبع المباشر',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        // موقع الانطلاق
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.my_location,
                                color: Colors.green,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'موقعك الحالي:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    _originLocation == null
                                        ? 'سيتم استخدام موقعك الحالي للتتبع المباشر'
                                        : _originAddress,
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  if (_originLocation != null) ...[
                                    SizedBox(height: 4),
                                    Text(
                                      'الإحداثيات: ${_originLocation!.latitude.toStringAsFixed(6)}, ${_originLocation!.longitude.toStringAsFixed(6)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),

                        // زر إضافة صور لموقع الانطلاق
                        if (_originLocation != null && _originImages.isEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 8, right: 40),
                            child: OutlinedButton.icon(
                              onPressed: _pickOriginImages,
                              icon: Icon(
                                Icons.add_a_photo,
                                size: 16,
                                color: Colors.green,
                              ),
                              label: Text(
                                'إضافة صور للموقع',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                side: BorderSide(color: Colors.green),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),

                        // عرض الصور المحددة لموقع الانطلاق
                        if (_originImages.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 8, right: 40),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'تم اختيار ${_originImages.length} صورة',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                  ),
                                ),
                                Spacer(),
                                InkWell(
                                  onTap: _pickOriginImages,
                                  child: Text(
                                    'إضافة المزيد',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 12,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (_trackingHistory.isNotEmpty) ...[
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                Icons.timeline,
                                color: Colors.blue,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'تم تسجيل ${_trackingHistory.length} نقطة تتبع',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],

                        if (_isLiveTracking || widget.autoStartTracking) ...[
                          SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'التتبع المباشر مفعل. سيتم إرسال موقعك تلقائيًا للعملاء كل 10 ثوانٍ.',
                                    style: TextStyle(
                                      color: Colors.green[800],
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        SizedBox(height: 20),

                        // زر حفظ التتبع
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                _originLocation != null ||
                                        _isLiveTracking ||
                                        widget.autoStartTracking
                                    ? _saveRoute
                                    : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              disabledBackgroundColor: Colors.grey[300],
                            ),
                            child:
                                _isUploading
                                    ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text('جاري الحفظ...'),
                                      ],
                                    )
                                    : Text('تأكيد تفعيل التتبع'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // مؤشر التحميل
          if (_isLoading && !(_isLoading && _currentPosition == null))
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
