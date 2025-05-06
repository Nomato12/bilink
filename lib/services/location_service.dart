import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:location/location.dart' as loc;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationService {
  // متغيرات عامة
  static final LocationService _instance = LocationService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<Position>? _locationSubscription;

  // تحويل الكلاس إلى Singleton
  factory LocationService() {
    return _instance;
  }

  LocationService._internal();

  // التحقق من صلاحيات الوصول للموقع
  Future<bool> _checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // Método para verificar y solicitar permisos de ubicación con contexto
  Future<bool> requestLocationPermission(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Los servicios de ubicación no están habilitados
      _showLocationDisabledDialog(context);
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Los permisos son denegados
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم رفض الوصول إلى الموقع. بعض وظائف التطبيق قد لا تعمل بشكل صحيح.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Los permisos son denegados permanentemente
      _showPermissionsDeniedForeverDialog(context);
      return false;
    }

    // Los permisos han sido concedidos
    return true;
  }

  // الحصول على الموقع الحالي للمستخدم (بدون سياق)
  Future<Position?> getCurrentLocation() async {
    if (!await _checkPermission()) {
      return null;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return position;
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  // الحصول على الموقع الحالي للمستخدم (مع سياق للإشعارات)
  Future<Position?> getCurrentLocationWithContext(BuildContext context) async {
    final hasPermission = await requestLocationPermission(context);

    if (!hasPermission) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء الحصول على الموقع: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  // عنوان مقروء من الإحداثيات
  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      Placemark place = placemarks[0];
      return '${place.street}, ${place.locality}, ${place.administrativeArea}';
    } catch (e) {
      print('Error getting address: $e');
      return 'غير معروف';
    }
  }

  // بدء تتبع موقع المستخدم وتحديث قاعدة البيانات (للسائق)
  Future<bool> startTracking(String userId, String serviceId) async {
    // التحقق من صلاحيات الموقع
    if (!await _checkPermission()) {
      return false;
    }

    try {
      // إنشاء مرجع لتخزين موقع السائق
      final driverLocationRef = _firestore
          .collection('services')
          .doc(serviceId)
          .collection('tracking')
          .doc(userId);

      // بدء الاستماع للتغييرات في الموقع
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // تحديث كل 10 متر
        ),
      ).listen((Position position) async {
        // تحديث موقع السائق في قاعدة البيانات
        await driverLocationRef.set({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'heading': position.heading,
          'speed': position.speed,
          'timestamp': FieldValue.serverTimestamp(),
          'driverId': userId,
        }, SetOptions(merge: true));
      });

      return true;
    } catch (e) {
      print('Error starting location tracking: $e');
      return false;
    }
  }

  // إيقاف تتبع موقع المستخدم
  void stopTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  // حفظ موقع مساحة التخزين في قاعدة البيانات
  Future<bool> saveStorageLocation(
    String serviceId,
    double latitude,
    double longitude,
    String address,
  ) async {
    try {
      await _firestore.collection('services').doc(serviceId).update({
        'location': {
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
          'timestamp': FieldValue.serverTimestamp(),
        },
      });
      return true;
    } catch (e) {
      print('Error saving storage location: $e');
      return false;
    }
  }

  // التحقق من دعم تتبع الموقع في الجهاز
  Future<bool> isBackgroundLocationAvailable() async {
    final loc.Location location = loc.Location();
    bool isBackgroundModeEnabled = await location.isBackgroundModeEnabled();
    return isBackgroundModeEnabled;
  }

  // طلب تفعيل وضع التتبع في الخلفية
  Future<bool> enableBackgroundMode() async {
    try {
      final loc.Location location = loc.Location();
      bool success = await location.enableBackgroundMode(enable: true);
      return success;
    } catch (e) {
      print('Error enabling background mode: $e');
      return false;
    }
  }

  // تمثيل الخطأ البشري في تحديد الموقع
  Stream<Position> getMockedDriverRoute(LatLng start, LatLng end) {
    // يمكن هنا إنشاء مسار وهمي للسائق للاختبار بين نقطتين
    // تنفيذ متقدم يتطلب خوارزميات لتوليد مسار واقعي
    StreamController<Position> controller = StreamController<Position>();

    // هذه مجرد طريقة للاختبار وتمثيل حركة وهمية
    Timer.periodic(Duration(seconds: 3), (timer) {
      if (controller.isClosed) {
        timer.cancel();
        return;
      }

      // توليد موقع عشوائي في المسار
      controller.add(
        Position(
          latitude:
              start.latitude +
              (end.latitude - start.latitude) * (timer.tick / 20),
          longitude:
              start.longitude +
              (end.longitude - start.longitude) * (timer.tick / 20),
          timestamp: DateTime.now(),
          altitude: 0,
          accuracy: 0,
          heading: 0,
          speed: 30,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        ),
      );

      // توقف التوليد عند الوصول للهدف
      if (timer.tick >= 20) {
        timer.cancel();
        controller.close();
      }
    });

    return controller.stream;
  }

  // Mostrar diálogo cuando los servicios de ubicación están deshabilitados
  void _showLocationDisabledDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'خدمة الموقع معطلة',
            style: TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'يرجى تفعيل خدمة تحديد الموقع في إعدادات جهازك للاستفادة من جميع مزايا التطبيق.',
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            TextButton(
              child: Text('إلغاء'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('فتح الإعدادات'),
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openLocationSettings();
              },
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          actionsAlignment: MainAxisAlignment.center,
        );
      },
    );
  }

  // Mostrar diálogo cuando los permisos han sido denegados permanentemente
  void _showPermissionsDeniedForeverDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'تم حظر إذن الموقع',
            style: TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'لقد قمت بحظر إذن الوصول إلى الموقع بشكل دائم. يرجى تمكينه في إعدادات جهازك للاستفادة من جميع مزايا التطبيق.',
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            TextButton(
              child: Text('إلغاء'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('فتح الإعدادات'),
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openAppSettings();
              },
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          actionsAlignment: MainAxisAlignment.center,
        );
      },
    );
  }
}
