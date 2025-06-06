import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bilink/services/directions_helper.dart';

class LiveTrackingMapScreen extends StatefulWidget {
  final LatLng? destinationLocation;
  final String? destinationName;
  final LatLng? originLocation; // إضافة نقطة البداية
  final String? originName; // إضافة عنوان نقطة البداية
  
  const LiveTrackingMapScreen({
    super.key, 
    this.destinationLocation,
    this.destinationName,
    this.originLocation,
    this.originName,
  });

  @override
  _LiveTrackingMapScreenState createState() => _LiveTrackingMapScreenState();
}

class _LiveTrackingMapScreenState extends State<LiveTrackingMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();

  // نقطة الانطلاق الافتراضية (الجزائر العاصمة)
  static const LatLng _defaultLocation = LatLng(36.7538, 3.0588);

  // مواقع البداية والوجهة
  LatLng? _originPosition;
  LatLng? _destinationPosition;
  
  // الموقع الحالي أثناء التنقل
  LatLng? _currentNavigationPosition;

  // العناوين
  String _originAddress = '';
  String _destinationAddress = '';

  // مجموعة العلامات على الخريطة
  final Set<Marker> _markers = {};

  // حالة التحميل
  bool _isLoading = false;
  
  // حالة التتبع والملاحة المباشرة
  bool _isTracking = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _navigationUpdateTimer;
  int _remainingTimeInSeconds = 0;
  double _progressPercentage = 0.0;
  int _currentStepIndex = 0;

  // نوع الخريطة
  MapType _currentMapType = MapType.normal;

  // بيانات المسار والاتجاهات
  Set<Polyline> _polylines = {};
  Map<String, dynamic> _directionsData = {};
  bool _showDirectionsPanel = false;
  List<Map<String, dynamic>> _directionSteps = [];
  Map<String, String> _tripInfo = {
    'distance': '',
    'duration': '',
    'startAddress': '',
    'endAddress': '',
  };

  // Additional variables for enhanced navigation
  double _remainingDistanceKm = 0.0;
  String _currentInstruction = '';
  bool _showRealtimePanel = false;
  final double _arrowSize = 40.0;

  // متغير لتتبع وضع العرض
  bool _followingMode = true;

  @override
  void initState() {
    super.initState();
    
    // استخدام نقطة البداية المحددة إذا كانت متوفرة، وإلا استخدام الموقع الحالي
    if (widget.originLocation != null) {
      setState(() {
        _originPosition = widget.originLocation;
      });
      
      if (widget.originName != null && widget.originName!.isNotEmpty) {
        setState(() {
          _originAddress = widget.originName!;
        });
        
        // إضافة علامة لنقطة البداية
        _addMarker(
          _originPosition!,
          'origin',
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          _originAddress,
        );
      } else {
        _getAddressFromLatLng(_originPosition!).then((address) {
          if (address.isNotEmpty) {
            setState(() {
              _originAddress = address;
            });
            
            // إضافة علامة لنقطة البداية
            _addMarker(
              _originPosition!,
              'origin',
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              _originAddress,
            );
          }
        });
      }
    } else {
      _getCurrentLocation();
    }

    // إذا كان هناك وجهة محددة، استخدمها مباشرة
    if (widget.destinationLocation != null) {
      setState(() {
        _destinationPosition = widget.destinationLocation;
      });
      
      if (widget.destinationName != null && widget.destinationName!.isNotEmpty) {
        setState(() {
          _destinationAddress = widget.destinationName!;
        });
        
        // إضافة علامة للوجهة
        _addMarker(
          _destinationPosition!,
          'destination',
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          _destinationAddress,
        );
      } else {
        _getAddressFromLatLng(_destinationPosition!).then((address) {
          if (address.isNotEmpty) {
            setState(() {
              _destinationAddress = address;
            });
            
            // إضافة علامة للوجهة
            _addMarker(
              _destinationPosition!,
              'destination',
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              _destinationAddress,
            );
          }
        });
      }
    }
      // حساب المسار وبدء التتبع المباشر تلقائياً بمجرد توفر نقطة البداية والوجهة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_originPosition != null && _destinationPosition != null) {
        _calculateAndDisplayRoute().then((_) {
          // بدء التتبع المباشر تلقائياً بعد حساب المسار
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _startTracking();
            }
          });
        });
      }
    });
  }

  @override
  void dispose() {
    // Cancel all timers to prevent callbacks after widget disposal
    _navigationUpdateTimer?.cancel();
    
    // Cancel any active position stream subscriptions
    _positionStreamSubscription?.cancel();
    
    super.dispose();
  }
  
  // بدء تتبع الموقع الحالي في الوقت الفعلي
  void _startTracking() async {
    if (_originPosition == null || _destinationPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد نقطة البداية والوجهة أولاً')),
      );
      return;
    }
    
    // التحقق من صلاحيات تحديد الموقع
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم منح صلاحيات الوصول إلى الموقع')),
        );
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('صلاحيات الموقع مرفوضة بشكل دائم، يرجى تغييرها من إعدادات الجهاز')),
      );
      return;
    }
      // بدء حالة التتبع
    setState(() {
      _isTracking = true;
      _currentNavigationPosition = _originPosition;
    });
    
    // تنبيه صوتي وتنبيه على الشاشة لبدء التنقل
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('بدء التنقل في الوقت الفعلي'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
    
    // حساب الوقت المتبقي بالثواني بشكل دقيق
    if (_tripInfo.containsKey('duration') && _tripInfo['duration']!.isNotEmpty) {
      final durationText = _tripInfo['duration']!;
      final RegExp regExp = RegExp(r'(\d+)');
      final match = regExp.firstMatch(durationText);
      if (match != null) {
        final minutes = int.tryParse(match.group(1) ?? "0") ?? 0;
        _remainingTimeInSeconds = minutes * 60;
      }
    }      // إنشاء مؤقت لتحديث بيانات الملاحة كل ثانية
    _navigationUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTimeInSeconds > 0) {
        // تأكد من أن الـ widget لا يزال متاحًا قبل تحديث الحالة
        if (mounted) {
          // Use a try-catch block to catch any errors related to setState
          try {
            setState(() {
              _remainingTimeInSeconds--;
              // تحديث نسبة التقدم
              final totalTime = int.tryParse(_tripInfo['duration']?.replaceAll(RegExp(r'[^0-9]'), '') ?? "0") ?? 0;
              if (totalTime > 0) {
                _progressPercentage = 1.0 - (_remainingTimeInSeconds / (totalTime * 60));
                _progressPercentage = _progressPercentage.clamp(0.0, 1.0);
                
                // تحديث الخطوة الحالية بناءً على النسبة المئوية
                if (_directionSteps.isNotEmpty) {
                  _currentStepIndex = (_progressPercentage * (_directionSteps.length - 1)).floor();
                  _currentStepIndex = _currentStepIndex.clamp(0, _directionSteps.length - 1);
                }
              }
            });
          } catch (e) {
            // If an error occurs during setState, cancel the timer
            print('Error updating navigation: $e');
            timer.cancel();
          }
        } else {
          // إذا كان الـ widget غير متاح، إلغاء المؤقت
          timer.cancel();
        }
      } else {
        // إذا انتهى الوقت، أوقف التتبع
        _stopTracking();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لقد وصلت إلى وجهتك!')),
          );
        }
      }
    });      // الاشتراك في تحديثات الموقع في الوقت الفعلي
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation, // تحسين الدقة للملاحة
      distanceFilter: 2, // تحديث كل 2 متر للحصول على تتبع أكثر سلاسة
      timeLimit: Duration(milliseconds: 500), // تحديث كل 500 مللي ثانية كحد أقصى للوقت
    );
    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) async {
      // تأكد من أن الـ widget لا يزال متاحًا قبل تحديث الحالة
      if (!mounted) return;
      
      final newPosition = LatLng(position.latitude, position.longitude);
      
      // Use a try-catch block to prevent errors when setting state
      try {
        setState(() {
          _currentNavigationPosition = newPosition;
        });
        
        // تحديث علامة الموقع الحالي
        _updateCurrentLocationMarker(newPosition);
      } catch (e) {
        print('Error updating location state: $e');
        // If there's an error, consider canceling the subscription
        _positionStreamSubscription?.cancel();
        return;
      }
        try {        // تحريك الخريطة لمتابعة الموقع الحالي بحركة سلسة
        if (mounted) {
          final GoogleMapController controller = await _controller.future;
          
          // حساب المسافة المتبقية للوجهة
          final double distanceToDestination = Geolocator.distanceBetween(
            newPosition.latitude,
            newPosition.longitude,
            _destinationPosition!.latitude,
            _destinationPosition!.longitude,
          );
          
          // تعديل مستوى التكبير ديناميكياً بناءً على المسافة المتبقية
          double zoomLevel = 17.0; // المستوى الافتراضي للتكبير
          double tiltAngle = 45.0; // زاوية الميل الافتراضية
          
          if (distanceToDestination > 5000) { // أكثر من 5 كم
            zoomLevel = 14.0;
            tiltAngle = 30.0;
          } else if (distanceToDestination > 1000) { // بين 1 و 5 كم
            zoomLevel = 15.0;
            tiltAngle = 35.0;
          } else if (distanceToDestination > 500) { // بين 500 متر و 1 كم
            zoomLevel = 16.0;
            tiltAngle = 40.0;
          }
          
          controller.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: newPosition,
                zoom: zoomLevel,
                tilt: tiltAngle,
                bearing: position.heading, // توجيه الخريطة حسب اتجاه الحركة
              ),
            ),
          );
        }
          
        // حساب المسافة المتبقية للوجهة
        final double distanceToDestination = Geolocator.distanceBetween(
          newPosition.latitude,
          newPosition.longitude,
          _destinationPosition!.latitude,
          _destinationPosition!.longitude,
        );
          
        // إذا وصلنا إلى مسافة قريبة من الوجهة (أقل من 30 متر)
        if (distanceToDestination < 30 && _isTracking) {
          _stopTracking();
          
          // تنبيه صوتي وشاشة عند الوصول للوجهة
          if (mounted) {
            try {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('لقد وصلت إلى وجهتك!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 5),
                ),
              );
            } catch (e) {
              print('Error showing arrival snackbar: $e');
            }
            
            try {
              // تحريك الكاميرا لإظهار الوجهة
              final GoogleMapController controller = await _controller.future;
              controller.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                  target: _destinationPosition!,
                  zoom: 18.0,
                  tilt: 0,
                  bearing: 0,
                ),
              ),
            );
            } catch (e) {
              print('Error animating camera on arrival: $e');
            }
          }
        }
      } catch (e) {
        // التعامل مع الأخطاء التي قد تحدث أثناء تحديث الموقع
        print('Error updating location: $e');
      }
    });
    
    // عرض شريط التتبع
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('بدء التتبع في الوقت الفعلي...'),
        duration: Duration(seconds: 2),
      ),
    );
  }
    // إيقاف التتبع وتنظيف الموارد
  void _stopTracking() {    
    if (_navigationUpdateTimer != null) {
      _navigationUpdateTimer!.cancel();
      _navigationUpdateTimer = null;
    }
    
    if (_positionStreamSubscription != null) {
      _positionStreamSubscription!.cancel();
      _positionStreamSubscription = null;
    }
    
    // تأكد من أن الـ widget لا يزال متاحًا قبل تحديث الحالة
    if (mounted) {
      try {
        setState(() {
          _isTracking = false;
        });
      } catch (e) {
        print('Error updating tracking state: $e');
        // Just set the variable without setState
        _isTracking = false;
      }
    } else {
      // إذا كان الـ widget غير متاح، فقط قم بتحديث المتغير
      _isTracking = false;
    }
  }// تحديث علامة الموقع الحالي مع السهم للإشارة إلى الاتجاه
  void _updateCurrentLocationMarker(LatLng position) {
    if (!mounted) return;
    
    // استخدام setState فقط إذا كان الـ widget لا يزال نشط
    try {
      setState(() {
        // إزالة علامة الموقع الحالي إذا كانت موجودة
        _markers.removeWhere((marker) => marker.markerId.value == 'current_location');
        
        // إضافة علامة جديدة للموقع الحالي مع سهم لإظهار الاتجاه
        _markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: const InfoWindow(title: 'موقعك الحالي'),
            flat: true,
            anchor: const Offset(0.5, 0.5),
            zIndex: 2,
          ),
        );
        
        // تحديث المسافة المتبقية للوجهة
        if (_destinationPosition != null) {
          _remainingDistanceKm = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            _destinationPosition!.latitude,
            _destinationPosition!.longitude,
          ) / 1000; // تحويل من متر إلى كيلومتر
          
          // تحديث التعليمات الحالية بناءً على الخطوة الحالية
          if (_directionSteps.isNotEmpty && _currentStepIndex < _directionSteps.length) {
            _currentInstruction = _directionSteps[_currentStepIndex]['html_instructions'] ?? 'اتجه نحو الوجهة';
          }
        }
      });
      
      // عرض لوحة التتبع في الوقت الفعلي
      _showRealtimePanel = true;
    } catch (e) {
      print('Error updating location marker: $e');
      // If there's an error during setState, it might indicate a lifecycle issue
      // Consider canceling any active subscriptions
      if (_positionStreamSubscription != null) {
        _positionStreamSubscription!.cancel();
      }
    }
  }
  // استرجاع الموقع الحالي للمستخدم
  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    
    try {
      setState(() {
        _isLoading = true;
      });
    } catch (e) {
      print('Error setting loading state: $e');
      return;
    }

    try {
      // طلب الإذن لاستخدام خدمة الموقع
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('لم يتم السماح باستخدام خدمة الموقع')),
            );
          }
          
          if (mounted) {
            try {
              setState(() {
                _isLoading = false;
              });
            } catch (stateError) {
              print('Error updating loading state: $stateError');
            }
          }
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
        
        if (mounted) {
          try {
            setState(() {
              _isLoading = false;
            });
          } catch (stateError) {
            print('Error updating loading state: $stateError');
          }
        }
        return;
      }      // الحصول على الموقع الحالي
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      
      try {
        setState(() {
          _originPosition = LatLng(position.latitude, position.longitude);
        });
      } catch (e) {
        print('Error updating position state: $e');
        if (!mounted) return;
      }

      // الحصول على العنوان من الإحداثيات
      final address = await _getAddressFromLatLng(_originPosition!);
      
      if (!mounted) return;
      
      if (address.isNotEmpty) {
        try {
          setState(() {
            _originAddress = address;
          });
        } catch (e) {
          print('Error updating address state: $e');
          if (!mounted) return;
        }
      }

      // تحريك الخريطة للموقع الحالي
      if (mounted) {
        _animateToPosition(_originPosition!);

        // إضافة علامة للموقع الحالي
        _addMarker(
          _originPosition!,
          'origin',
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          _originAddress.isEmpty ? 'موقعك الحالي' : _originAddress,
        );
        
        // إذا كانت الوجهة محددة، قم بحساب المسار
        if (_destinationPosition != null) {
          _calculateAndDisplayRoute();
        }
      }
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء تحديد الموقع: $e')));
      }
    } finally {
      if (mounted) {
        try {
          setState(() {
            _isLoading = false;
          });
        } catch (stateError) {
          print('Error updating final loading state: $stateError');
        }
      }
    }
  }

  // جلب العنوان من الإحداثيات
  Future<String> _getAddressFromLatLng(LatLng position) async {
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        final String address = '${place.street}, ${place.locality}, ${place.country}';
        return address;
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    return '';
  }

  // تحريك الخريطة لموقع معين
  Future<void> _animateToPosition(LatLng position) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 15.0),
      ),
    );
  }  // إضافة علامة على الخريطة
  void _addMarker(
    LatLng position,
    String markerId,
    BitmapDescriptor icon,
    String title,
  ) {
    if (!mounted) return;
    
    try {
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
    } catch (e) {
      print('Error adding marker: $e');
      // This error might indicate a widget lifecycle issue
    }
  }  // حساب وعرض المسار بين نقطتين
  Future<void> _calculateAndDisplayRoute() async {
    if (_originPosition == null || _destinationPosition == null) {
      return;
    }
    
    if (!mounted) return;
    
    try {
      setState(() {
        _isLoading = true;
      });
    } catch (e) {
      print('Error setting loading state: $e');
      return;
    }
    
    try {
      // الحصول على بيانات المسار من خدمة الاتجاهات
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
      
      // الحصول على معلومات الرحلة
      _tripInfo = DirectionsHelper.getTripInfo(_directionsData);
      
      // الحصول على خطوات الاتجاهات
      _directionSteps = DirectionsHelper.getDirectionSteps(_directionsData);
        // تحريك الخريطة لتظهر المسار بأكمله
      _fitBoundsForRoute();
      
      if (!mounted) return;
      
      // عرض لوحة الاتجاهات
      try {
        setState(() {
          _showDirectionsPanel = true;
          _isLoading = false;
        });
      } catch (e) {
        print('Error updating UI after route calculation: $e');
        return;
      }
      
      // عرض رسالة إعلامية
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حساب المسار: ${_tripInfo['distance']} (${_tripInfo['duration']})'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error calculating route: $e');
      if (mounted) {
        try {
          setState(() {
            _isLoading = false;
          });
        } catch (stateError) {
          print('Error updating loading state: $stateError');
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء حساب المسار'),
          ),
        );
      }
    }
  }
    // ضبط حدود الخريطة لتناسب المسار بأكمله
  Future<void> _fitBoundsForRoute() async {
    if (_originPosition == null || _destinationPosition == null) {
      return;
    }
    
    try {
      // تكوين حدود تشمل نقطة البداية والنهاية
      final bounds = LatLngBounds(
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
      
      // الحصول على تحكم الخريطة وضبط الحدود
      final GoogleMapController controller = await _controller.future;
      
      // حساب المسافة بين نقطة البداية والوجهة
      double distanceBetweenPoints = Geolocator.distanceBetween(
        _originPosition!.latitude,
        _originPosition!.longitude,
        _destinationPosition!.latitude,
        _destinationPosition!.longitude,
      );
      
      // تعديل نسبة التكبير بناءً على المسافة
      double padding = 100; // القيمة الافتراضية
      
      if (distanceBetweenPoints > 10000) { // أكثر من 10 كم
        padding = 50; // تقليل التكبير للمسافات الطويلة
      } else if (distanceBetweenPoints < 1000) { // أقل من 1 كم
        padding = 150; // زيادة التكبير للمسافات القصيرة
      }
      
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, padding),
      );
    } catch (e) {
      print('Error fitting bounds: $e');
    }
  }
  
  // عرض شريط تقدم الرحلة أثناء التتبع  
  Widget _buildTrackingProgressBar() {
    final durationInMinutes = _remainingTimeInSeconds ~/ 60;
    final seconds = _remainingTimeInSeconds % 60;
    final formattedDuration = '$durationInMinutes:${seconds.toString().padLeft(2, '0')}';
    final percentComplete = (_progressPercentage * 100).toInt();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.navigation, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _directionSteps.isNotEmpty && _currentStepIndex < _directionSteps.length
                          ? _parseHtmlInstructions(_directionSteps[_currentStepIndex]['instruction'])
                          : 'متابعة السير',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'الوقت المتبقي: $formattedDuration',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          '$percentComplete%',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _stopTracking,
                color: Colors.grey[600],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progressPercentage,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                percentComplete > 75 ? Colors.green : Colors.blue
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // بناء لوحة الاتجاهات التفصيلية
  Widget _buildDirectionsPanel() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4,
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

              // ملخص الرحلة
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // معلومات الرحلة
                    Row(
                      children: [
                        Icon(Icons.directions, color: Colors.blue, size: 30),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'المسافة: ${_tripInfo['distance']}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'الوقت التقريبي: ${_tripInfo['duration']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _fitBoundsForRoute,
                          style: ElevatedButton.styleFrom(
                            shape: CircleBorder(),
                            padding: EdgeInsets.all(12),
                            backgroundColor: Colors.blue,
                          ),
                          child: Icon(Icons.fullscreen, color: Colors.white),
                        ),
                      ],
                    ),
                    
                    Divider(height: 24),
                  ],
                ),
              ),

              // تفاصيل خطوات الاتجاهات
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _directionSteps.length,
                  separatorBuilder: (context, index) => Divider(height: 1),
                  itemBuilder: (context, index) {
                    final step = _directionSteps[index];
                    return ListTile(
                      leading: Icon(
                        index == 0 
                            ? Icons.trip_origin 
                            : index == _directionSteps.length - 1 
                              ? Icons.location_on 
                              : Icons.arrow_forward,
                        color: index == 0 
                            ? Colors.green 
                            : index == _directionSteps.length - 1 
                              ? Colors.red 
                              : Colors.blue,
                      ),
                      title: Text.rich(
                        TextSpan(
                          children: [
                            // تحويل العلامات HTML إلى نصوص مفهومة
                            TextSpan(
                              text: _parseHtmlInstructions(step['instruction']),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      subtitle: Text(
                        '${step['distance']} • ${step['duration']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8, 
                        vertical: 4,
                      ),
                      dense: true,
                    );
                  },
                ),
              ),
                // زر بدء التنقل (فتح خرائط Google)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  icon: Icon(Icons.navigation),
                  label: Text('خرائط Google'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _launchGoogleMapsNavigation,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  // تنقية التعليمات HTML وتحويلها إلى نص عادي
  String _parseHtmlInstructions(String htmlInstructions) {
    // إزالة وسوم HTML
    return htmlInstructions
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
  
  // فتح تطبيق خرائط جوجل للتنقل
  void _launchGoogleMapsNavigation() async {
    if (_originPosition == null || _destinationPosition == null) {
      return;
    }
    
    final url =
        'https://www.google.com/maps/dir/?api=1&origin=${_originPosition!.latitude},${_originPosition!.longitude}&destination=${_destinationPosition!.latitude},${_destinationPosition!.longitude}&travelmode=driving';
    
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لا يمكن فتح تطبيق خرائط Google')),
      );
    }
  }

  // Build navigation direction arrow based on current maneuver
  Widget _buildDirectionArrow() {
    IconData arrowIcon = Icons.arrow_upward;
    Color arrowColor = Colors.blue;
    
    // Get maneuver type from current step
    if (_directionSteps.isNotEmpty && _currentStepIndex < _directionSteps.length) {
      final String maneuver = _directionSteps[_currentStepIndex]['maneuver'] ?? 'straight';
      
      // Determine arrow direction based on maneuver
      switch (maneuver) {
        case 'turn-right':
          arrowIcon = Icons.arrow_forward;
          arrowColor = Colors.blue;
          break;
        case 'turn-sharp-right':
          arrowIcon = Icons.turn_right;
          arrowColor = Colors.blue;
          break;
        case 'turn-slight-right':
          arrowIcon = Icons.turn_slight_right;
          arrowColor = Colors.blue;
          break;
        case 'turn-left':
          arrowIcon = Icons.arrow_back;
          arrowColor = Colors.blue;
          break;
        case 'turn-sharp-left':
          arrowIcon = Icons.turn_left;
          arrowColor = Colors.blue;
          break;
        case 'turn-slight-left':
          arrowIcon = Icons.turn_slight_left;
          arrowColor = Colors.blue;
          break;
        case 'uturn-right':
        case 'uturn-left':
          arrowIcon = Icons.u_turn_left;
          arrowColor = Colors.orange;
          break;
        case 'straight':
        default:
          arrowIcon = Icons.arrow_upward;
          arrowColor = Colors.green;
          break;
      }
    }
    
    return Container(
      width: _arrowSize,
      height: _arrowSize,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        arrowIcon,
        color: arrowColor,
        size: _arrowSize * 0.6,
      ),
    );
  }
  
  // Build real-time navigation panel showing current instruction and progress
  Widget _buildRealtimeNavigationPanel() {
    // Only show if we're tracking and have started navigation
    if (!_isTracking || !_showRealtimePanel) return const SizedBox.shrink();
    
    return Positioned(
      top: 16.0,
      left: 16.0,
      right: 16.0,
      child: Card(
        elevation: 4.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Top section with direction arrow and instruction
              Row(
                children: [
                  _buildDirectionArrow(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _stripHtmlTags(_currentInstruction),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'المسافة المتبقية: ${_remainingDistanceKm.toStringAsFixed(1)} كم',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Progress bar showing route completion
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progressPercentage,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _progressPercentage > 0.9 ? Colors.green : Colors.blue,
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              // Timer & ETA
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الوقت المتبقي: ${(_remainingTimeInSeconds / 60).ceil()} دقيقة',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'الوصول: ${_calculateETA()}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Calculate estimated time of arrival based on remaining time
  String _calculateETA() {
    final DateTime now = DateTime.now();
    final DateTime eta = now.add(Duration(seconds: _remainingTimeInSeconds));
    
    // Format time as HH:MM
    final String hour = eta.hour.toString().padLeft(2, '0');
    final String minute = eta.minute.toString().padLeft(2, '0');
    
    return '$hour:$minute';
  }
  
  // Strip HTML tags from instruction text
  String _stripHtmlTags(String htmlText) {
    // Remove HTML tags
    final RegExp exp = RegExp(r"<[^>]*>", multiLine: true);
    return htmlText.replaceAll(exp, ' ').replaceAll('&nbsp;', ' ').trim();
  }

  // إضافة زر لتبديل وضع عرض الخريطة
  Widget _buildMapViewModeButton() {
    return Positioned(
      top: 16,
      left: 16,
      child: Column(
        children: [
          FloatingActionButton.small(
            heroTag: 'map_view_mode',
            backgroundColor: Colors.white,
            onPressed: _toggleMapViewMode,
            child: Icon(_followingMode ? Icons.navigation : Icons.map, color: Colors.blue),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _followingMode ? 'وضع التتبع' : 'كامل المسار',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // تبديل وضع عرض الخريطة
  void _toggleMapViewMode() {
    setState(() {
      _followingMode = !_followingMode;
    });

    if (_followingMode) {
      // وضع التتبع المباشر: التركيز على الموقع الحالي
      if (_currentNavigationPosition != null) {
        _animateCameraToCurrentLocation();
      }
    } else {
      // وضع عرض المسار الكامل: إظهار المسار بأكمله
      _fitBoundsForRoute();
    }
    
    // عرض رسالة توضيحية
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_followingMode 
          ? 'تم التبديل إلى وضع التتبع المباشر' 
          : 'تم التبديل إلى وضع عرض المسار الكامل'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // الانتقال إلى الموقع الحالي
  Future<void> _animateCameraToCurrentLocation() async {
    if (_currentNavigationPosition == null) return;
    
    try {
      final controller = await _controller.future;
      final position = await Geolocator.getCurrentPosition();
      final heading = position.heading;
      
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentNavigationPosition!,
            zoom: 17.0,
            tilt: 45,
            bearing: heading,
          ),
        ),
      );
    } catch (e) {
      print('Error animating to current location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الاتجاهات'),
        backgroundColor: Colors.blue,
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
              // تنفيذ إجراء عند النقر على الخريطة
            },
          ),

          // لوحة الملاحة في الوقت الفعلي
          _buildRealtimeNavigationPanel(),

          // لوحة الاتجاهات
          if (_showDirectionsPanel && _directionSteps.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // معلومات الرحلة (المسافة والوقت)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'المسافة: ${_tripInfo['distance'] ?? ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'الوقت: ${_tripInfo['duration'] ?? ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // قائمة الخطوات
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _directionSteps.length,
                        itemBuilder: (context, index) {
                          final step = _directionSteps[index];
                          final isCurrentStep = index == _currentStepIndex;
                          
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isCurrentStep ? Colors.blue : Colors.grey.shade300,
                              child: Icon(
                                _getIconForManeuver(step['maneuver']),
                                color: isCurrentStep ? Colors.white : Colors.black54,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              _stripHtmlTags(step['html_instructions'] ?? ''),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isCurrentStep ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text('${step['distance'] ?? ''} • ${step['duration'] ?? ''}'),
                          );
                        },
                      ),
                    ),
                    
                    // Button to toggle directions panel
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ElevatedButton.icon(
                        onPressed: _isTracking ? _stopTracking : _startTracking,
                        icon: Icon(_isTracking ? Icons.stop : Icons.navigation),
                        label: Text(_isTracking ? 'إيقاف التتبع' : 'بدء التتبع'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isTracking ? Colors.red : Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // مؤشر التحميل
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),

          // زر تبديل وضع عرض الخريطة
          _buildMapViewModeButton(),
        ],
      ),

      // أزرار تحكم الخريطة
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Toggle directions panel button
          FloatingActionButton(
            onPressed: () {
              setState(() {
                _showDirectionsPanel = !_showDirectionsPanel;
              });
            },
            heroTag: 'toggle_directions',
            backgroundColor: _showDirectionsPanel ? Colors.blue : Colors.white,
            foregroundColor: _showDirectionsPanel ? Colors.white : Colors.blue,
            child: Icon(_showDirectionsPanel ? Icons.list : Icons.directions),
          ),
          const SizedBox(height: 16),
          
          // Zoom controls
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
              if (_isTracking && _currentNavigationPosition != null) {
                _animateToPosition(_currentNavigationPosition!);
              } else if (_originPosition != null) {
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
  
  // Get icon for the maneuver type
  IconData _getIconForManeuver(String? maneuver) {
    switch (maneuver) {
      case 'turn-right':
        return Icons.turn_right;
      case 'turn-sharp-right':
        return Icons.turn_sharp_right;
      case 'turn-slight-right':
        return Icons.turn_slight_right;
      case 'turn-left':
        return Icons.turn_left;
      case 'turn-sharp-left':
        return Icons.turn_sharp_left;
      case 'turn-slight-left':
        return Icons.turn_slight_left;
      case 'uturn-right':
      case 'uturn-left':
        return Icons.u_turn_left;
      case 'straight':
        return Icons.arrow_upward;
      case 'ramp-right':
        return Icons.ramp_right;
      case 'ramp-left':
        return Icons.ramp_left;
      case 'roundabout-right':
      case 'roundabout-left':
        return Icons.roundabout_left;
      case 'merge':
        return Icons.merge;
      case 'fork-right':
      case 'fork-left':
        return Icons.fork_right;
      default:
        return Icons.directions;
    }
  }
}
