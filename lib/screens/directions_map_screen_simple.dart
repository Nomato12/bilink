import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bilink/services/directions_helper.dart';

class DirectionsMapScreen extends StatefulWidget {
  final LatLng? destinationLocation;
  final String? destinationName;
  
  const DirectionsMapScreen({
    super.key, 
    this.destinationLocation,
    this.destinationName,
  });

  @override
  _DirectionsMapScreenState createState() => _DirectionsMapScreenState();
}

class _DirectionsMapScreenState extends State<DirectionsMapScreen> {
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
    _getCurrentLocation();

    // إذا كان هناك وجهة محددة، استخدمها مباشرة
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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
          final address = await _getAddressFromLatLng(_destinationPosition!);
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
        }
        
        // عندما يتم تحديد نقطة البداية، عرض المسار
        if (_originPosition != null) {
          _calculateAndDisplayRoute();
        }
      }
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
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('Error calculating route: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
              
              // زر بدء التنقل
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  icon: Icon(Icons.navigation),
                  label: Text('بدء التنقل'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    _launchGoogleMapsNavigation();
                  },
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

          // لوحة الاتجاهات
          if (_showDirectionsPanel && _directionSteps.isNotEmpty)
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
}
