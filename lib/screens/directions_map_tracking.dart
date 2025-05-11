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
    
    // حساب المسار بمجرد توفر نقطة البداية والوجهة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_originPosition != null && _destinationPosition != null) {
        _calculateAndDisplayRoute();
      }
    });
  }

  @override
  void dispose() {
    // إلغاء الاشتراك في تحديثات الموقع عند إنهاء الشاشة
    _stopTracking();
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
    }
    
    // إنشاء مؤقت لتحديث بيانات الملاحة كل ثانية
    _navigationUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTimeInSeconds > 0) {
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
      } else {
        // إذا انتهى الوقت، أوقف التتبع
        _stopTracking();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لقد وصلت إلى وجهتك!')),
        );
      }
    });
    
    // الاشتراك في تحديثات الموقع في الوقت الفعلي
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best, 
      distanceFilter: 5, // تحديث كل 5 أمتار
    );
    
    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) async {
      final newPosition = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _currentNavigationPosition = newPosition;
      });
      
      // تحديث علامة الموقع الحالي
      _updateCurrentLocationMarker(newPosition);
        // تحريك الخريطة لمتابعة الموقع الحالي بحركة سلسة
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: newPosition,
            zoom: 17.0,
            tilt: 45, // إضافة زاوية مائلة لتحسين عرض الملاحة
            bearing: position.heading, // توجيه الخريطة حسب اتجاه الحركة
          ),
        ),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لقد وصلت إلى وجهتك!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
        
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
    
    setState(() {
      _isTracking = false;
    });
  }
  
  // تحديث علامة الموقع الحالي مع السهم للإشارة إلى الاتجاه
  void _updateCurrentLocationMarker(LatLng position) async {
    setState(() {
      // إزالة علامة الموقع الحالي إذا كانت موجودة
      _markers.removeWhere((marker) => marker.markerId.value == 'current_location');
      
      // إضافة علامة جديدة للموقع الحالي
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
    });
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
      final address = await _getAddressFromLatLng(_originPosition!);
      if (address.isNotEmpty) {
        setState(() {
          _originAddress = address;
        });
      }

      // تحريك الخريطة للموقع الحالي
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

  // حساب وعرض المسار بين نقطتين
  Future<void> _calculateAndDisplayRoute() async {
    if (_originPosition == null || _destinationPosition == null) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
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
      
      // عرض لوحة الاتجاهات
      setState(() {
        _showDirectionsPanel = true;
      });
      
      // عرض رسالة إعلامية
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حساب المسار: ${_tripInfo['distance']} (${_tripInfo['duration']})'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('Error calculating route: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ أثناء حساب المسار'),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
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
              if (_originPosition == null) {
                // إذا لم يتم تحديد موقع البداية, فإن النقرة تحدد موقع البداية
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
                      BitmapDescriptor.hueViolet,
                    ),
                    address.isEmpty ? 'موقعك الحالي' : address,
                  );
                  
                  if (_destinationPosition != null) {
                    _calculateAndDisplayRoute();
                  }
                });
              } else if (_destinationPosition == null) {
                // إذا تم تحديد موقع البداية بالفعل ولكن ليس الوجهة، فإن النقرة تحدد الوجهة
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
                });
              }
            },
          ),

          // شريط تقدم التتبع
          if (_isTracking)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _buildTrackingProgressBar(),
            ),

          // لوحة الاتجاهات
          if (_showDirectionsPanel && _directionSteps.isNotEmpty && !_isTracking)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildDirectionsPanel(),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // زر بدء أو إيقاف التتبع
            Container(
              margin: const EdgeInsets.only(bottom: 30),
              child: FloatingActionButton.extended(
                onPressed: _isTracking ? _stopTracking : _startTracking,
                icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                label: Text(_isTracking ? 'إيقاف التتبع' : 'بدء التتبع'),
                backgroundColor: _isTracking ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                elevation: 4,
                heroTag: 'toggle_tracking',
              ),
            ),
            
            // أزرار التحكم بالخريطة
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
      ),
    );
  }
}
