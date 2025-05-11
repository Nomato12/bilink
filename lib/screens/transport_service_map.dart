import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bilink/screens/service_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bilink/screens/fix_transport_map.dart' as map_fix;
import 'package:bilink/services/location_synchronizer.dart';
import 'package:bilink/services/directions_helper.dart';
import 'package:bilink/screens/transport_map_fix.dart';

class TransportServiceMapScreen extends StatefulWidget {
  final LatLng? destinationLocation;
  final String? destinationName;
  final Map<String, dynamic>? serviceData;
  
  const TransportServiceMapScreen({
    super.key, 
    this.destinationLocation,
    this.destinationName,
    this.serviceData,
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

  // متغيرات البحث
  final TextEditingController _originSearchController = TextEditingController();
  final TextEditingController _destinationSearchController = TextEditingController();
  final bool _isSearchingOrigin = false;
  final bool _isSearchingDestination = false;

  // اقتراحات العناوين
  List<String> _originSuggestions = [];
  List<String> _destinationSuggestions = [];
  bool _showOriginSuggestions = false;
  bool _showDestinationSuggestions = false;

  // نطاق البحث عن المركبات (بالكيلومتر)
  final double _searchRadius = 15.0;

  // قائمة العناوين الأخيرة
  final List<String> _recentAddresses = [
    'الساحة المركزية، الجزائر',
    'شاطئ سيدي فرج، الجزائر',
    'جامعة الجزائر',
    'الحي الجامعي، بوزريعة',
    'قصر الثقافة، الجزائر',
  ];  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadAvailableVehicles();

    // تحميل المزامن لضمان تحديث بيانات المواقع
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLocationSynchronizer();
      
      // إذا كان هناك وجهة محددة، استخدمها مباشرة
      if (widget.destinationLocation != null) {
        setState(() {
          _destinationPosition = widget.destinationLocation;
          if (widget.destinationName != null && widget.destinationName!.isNotEmpty) {
            _destinationAddress = widget.destinationName!;
            _destinationSearchController.text = widget.destinationName!;
          } else {
            _getAddressFromLatLng(widget.destinationLocation!).then((address) {
              if (address.isNotEmpty) {
                setState(() {
                  _destinationAddress = address;
                  _destinationSearchController.text = address;
                });
              }
            });
          }
        });
        
        // إذا كان هناك معلومات خدمة، قم بتحميلها
        if (widget.serviceData != null) {
          _highlightSelectedService(widget.serviceData!);
        }
        
        // عرض المسار عندما يتم تحديد نقطة البداية
        if (_originPosition != null) {
          _showDirections();
        }
      }
    });

    // إضافة مستمعين لحقول البحث للاقتراحات المباشرة
    _originSearchController.addListener(_updateOriginSuggestions);
    _destinationSearchController.addListener(_updateDestinationSuggestions);
  }
  // تحميل وتشغيل مزامن الموقع
  Future<void> _loadLocationSynchronizer() async {
    try {
      final synchronizer = LocationSynchronizer();
      await synchronizer.synchronizeTransportLocations();
      print("DEBUG: Location synchronization completed on map init");
      
      // إذا كان هناك بيانات خدمة معينة، قم بتمييزها بعد مزامنة المواقع
      if (widget.serviceData != null) {
        _highlightSelectedService(widget.serviceData!);
      }
    } catch (e) {
      print("ERROR: Failed to synchronize locations: $e");
    }
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
      
      // البحث عن المركبات القريبة
      await _findNearbyVehicles();
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
  }  // جلب العنوان من الإحداثيات
  Future<String> _getAddressFromLatLng(LatLng position, [bool? isOrigin]) async {
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        final String address = '${place.street}, ${place.locality}, ${place.country}';

        if (isOrigin != null) {
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
        
        return address;
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    
    return '';
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
          
          // البحث عن المركبات القريبة من الموقع الجديد
          _findNearbyVehicles();
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

  // إضافة علامة مركبة على الخريطة مع تفاصيل
  void _addVehicleMarker(LatLng position, Map<String, dynamic> vehicle) {
    final String vehicleId = vehicle['id'] ?? DateTime.now().toString();
    
    print("DEBUG: Adding vehicle marker for ID: $vehicleId at ${position.latitude}, ${position.longitude}");
    
    setState(() {
      // إزالة العلامة القديمة إذا كانت موجودة
      _markers.removeWhere((marker) => marker.markerId.value == 'vehicle_$vehicleId');

      // إضافة العلامة الجديدة
      _markers.add(
        Marker(
          markerId: MarkerId('vehicle_$vehicleId'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: vehicle['title'] ?? 'مركبة نقل',
            snippet: 'انقر لعرض التفاصيل',          
          ),
          onTap: () {
            _showVehicleDetailsBottomSheet(vehicle);
          },
        ),
      );
    });
  }
  // تحميل خدمات النقل المتاحة
  Future<void> _loadAvailableVehicles() async {
    try {
      // استخدام الوظيفة المحسنة لتحميل خدمات النقل
      final vehicles = await map_fix.loadTransportServices();
      
      setState(() {
        _availableVehicles = vehicles;
      });
      
      // إذا كان الموقع الحالي معروف، نبحث عن المركبات القريبة فورًا
      if (_originPosition != null) {
        await _findNearbyVehicles();
      }
    } catch (e) {
      print('Error loading transport vehicles: $e');
    }
  }// البحث عن المركبات القريبة من الموقع
  Future<void> _findNearbyVehicles() async {
    if (_originPosition == null) {
      return;
    }

    setState(() {
      _markers.removeWhere((marker) => 
        marker.markerId.value != 'origin' && 
        marker.markerId.value != 'destination'
      );
    });

    // استخدام الوظيفة المحسنة للبحث عن المركبات القريبة
    final List<Map<String, dynamic>> nearbyVehicles = 
        await map_fix.findNearbyVehicles(
          _availableVehicles,
          _originPosition,
          _searchRadius
        );
      // إضافة علامات المركبات على الخريطة
    for (var vehicle in nearbyVehicles) {
      if (vehicle.containsKey('calculatedPosition')) {
        final LatLng vehiclePosition = vehicle['calculatedPosition'] as LatLng;
        print("DEBUG: Adding marker for vehicle ${vehicle['id']} at position ${vehiclePosition.latitude}, ${vehiclePosition.longitude}");
        
        // إضافة علامة المركبة على الخريطة
        _addVehicleMarker(
          vehiclePosition,
          vehicle,
        );
      } else {
        print("DEBUG: Vehicle ${vehicle['id']} has no calculatedPosition");
      }
    }
    
    setState(() {
      _availableVehicles = nearbyVehicles;
      _showVehiclesList = true; // دائمًا نظهر القائمة، حتى لو كانت فارغة
    });
    
    // إظهار رسالة إعلامية
    if (nearbyVehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لم يتم العثور على مركبات في نطاق ${_searchRadius.toInt()} كم. حاول توسيع نطاق البحث.'),
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      // التحريك للتركيز على المنطقة التي تحتوي على المركبات
      _animateToPosition(_originPosition!);
    }
  }

  // تنظيف الخريطة والعودة للحالة الأولية
  void _resetMap() {
    setState(() {          _destinationPosition = null;
      _destinationAddress = '';
      _markers.removeWhere((marker) => marker.markerId.value != 'origin');
      _showVehiclesList = false;
      _destinationSearchController.clear();
    });

    if (_originPosition != null) {
      _animateToPosition(_originPosition!);
      _findNearbyVehicles();
    }
  }

  // عرض تفاصيل المركبة في شريط سفلي
  void _showVehicleDetailsBottomSheet(Map<String, dynamic> vehicle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // مقبض السحب
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 10),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // عنوان التفاصيل
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.directions_car, color: Color(0xFF8B5CF6)),
                    const SizedBox(width: 10),
                    Text(
                      'تفاصيل المركبة',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    )
                  ],
                ),
              ),
              
              const Divider(),
              
              // محتوى التفاصيل
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // صور المركبة
                      if (vehicle.containsKey('imageUrls') && vehicle['imageUrls'] is List && (vehicle['imageUrls'] as List).isNotEmpty)
                        SizedBox(
                          height: 200,
                          child: PageView.builder(
                            itemCount: (vehicle['imageUrls'] as List).length,
                            itemBuilder: (context, index) {
                              return CachedNetworkImage(
                                imageUrl: vehicle['imageUrls'][index],
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: (context, url, error) => Icon(
                                  Icons.error,
                                  color: Colors.red,
                                ),
                              );
                            },
                          ),
                        )
                      else if (vehicle.containsKey('vehicle') && 
                               vehicle['vehicle'] != null && 
                               vehicle['vehicle'] is Map && 
                               vehicle['vehicle'].containsKey('imageUrls') && 
                               vehicle['vehicle']['imageUrls'] is List && 
                               (vehicle['vehicle']['imageUrls'] as List).isNotEmpty)
                        SizedBox(
                          height: 200,
                          child: PageView.builder(
                            itemCount: (vehicle['vehicle']['imageUrls'] as List).length,
                            itemBuilder: (context, index) {
                              return CachedNetworkImage(
                                imageUrl: vehicle['vehicle']['imageUrls'][index],
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: (context, url, error) => Icon(
                                  Icons.error,
                                  color: Colors.red,
                                ),
                              );
                            },
                          ),
                        )
                      else
                        Container(
                          height: 200,
                          color: Colors.grey.shade200,
                          child: Center(
                            child: Icon(
                              Icons.directions_car,
                              size: 80,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                        
                      const SizedBox(height: 20),
                      
                      // معلومات المركبة
                      _buildVehicleInfoItem(
                        icon: Icons.title,
                        title: 'اسم الخدمة',
                        value: vehicle['title'] ?? 'غير محدد',
                      ),
                      
                      if (vehicle.containsKey('vehicle') && vehicle['vehicle'] != null && vehicle['vehicle'] is Map)
                        _buildVehicleInfoItem(
                          icon: Icons.local_shipping,
                          title: 'نوع المركبة',
                          value: vehicle['vehicle']['type'] ?? 'غير محدد',
                        ),
                        
                      _buildVehicleInfoItem(
                        icon: Icons.location_on,
                        title: 'المسافة',
                        value: '${vehicle['distance'] ?? '0'} كم',
                        valueColor: Colors.red,
                      ),
                      
                      _buildVehicleInfoItem(
                        icon: Icons.attach_money,
                        title: 'السعر',
                        value: '${(vehicle['price'] as num?)?.toDouble() ?? 0.0} دج',
                        valueColor: const Color(0xFF8B5CF6),
                      ),
                      
                      if (vehicle.containsKey('providerInfo') && vehicle['providerInfo'] != null && vehicle['providerInfo'] is Map) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'معلومات مزود الخدمة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 10),
                        
                        _buildVehicleInfoItem(
                          icon: Icons.person,
                          title: 'الاسم',
                          value: vehicle['providerInfo']['name'] ?? 'غير محدد',
                        ),
                        
                        if (vehicle['providerInfo'].containsKey('phone') && vehicle['providerInfo']['phone'] != null)
                          _buildVehicleInfoItem(
                            icon: Icons.phone,
                            title: 'رقم الهاتف',
                            value: vehicle['providerInfo']['phone'],
                            isPhone: true,
                          ),
                      ],
                      
                      const SizedBox(height: 20),
                      
                      // زر الاتصال بمزود الخدمة
                      if (vehicle.containsKey('providerInfo') && 
                          vehicle['providerInfo'] != null && 
                          vehicle['providerInfo'] is Map && 
                          vehicle['providerInfo'].containsKey('phone') && 
                          vehicle['providerInfo']['phone'] != null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.phone),
                            label: const Text('اتصل بمزود الخدمة'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: const Color(0xFF4CAF50),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              final Uri phoneUri = Uri.parse('tel:${vehicle['providerInfo']['phone']}');
                              launchUrl(phoneUri);
                            },
                          ),
                        ),
                        
                      const SizedBox(height: 10),
                      
                      // زر طلب الخدمة
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: const Color(0xFF8B5CF6),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('طلب هذه الخدمة'),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ServiceDetailsScreen(serviceId: vehicle['id']),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );  }
  
  // بناء عنصر معلومات المركبة
  Widget _buildVehicleInfoItem({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
    bool isPhone = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF8B5CF6)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              isPhone
                  ? GestureDetector(
                      onTap: () {
                        final Uri phoneUri = Uri.parse('tel:$value');
                        launchUrl(phoneUri);
                      },
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    )
                  : Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: valueColor ?? const Color(0xFF1F2937),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

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

  // عرض المسار على الخريطة
  Future<void> _showDirections() async {
    if (_originPosition == null || _destinationPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تحديد نقطة البداية والوجهة أولاً')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _calculateAndDisplayRoute();
      _drawRoute();
    } catch (e) {
      print('Error showing directions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء عرض المسار: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  // رسم المسار على الخريطة
  void _drawRoute() {
    if (_polylines.isEmpty || _originPosition == null || _destinationPosition == null) {
      return;
    }

    setState(() {
      // ضمان وجود علامات للنقاط
      _addMarker(
        _originPosition!,
        'origin',
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        _originAddress.isEmpty ? 'موقعك الحالي' : _originAddress,
      );
      
      _addMarker(
        _destinationPosition!,
        'destination',
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        _destinationAddress.isEmpty ? 'الوجهة' : _destinationAddress,
      );
    });  }
  
  // تمييز الخدمة المحددة وعرض معلوماتها على الخريطة
    // تسليط الضوء على الخدمة المختارة
  void _highlightSelectedService(Map<String, dynamic> service) {
    // استخدام الوظائف المساعدة من ملف transport_map_fix.dart
    final serviceLocation = safeGetLatLng(service['location'] as Map<String, dynamic>?);
    if (serviceLocation != null) {
      final String serviceId = service['id'] ?? DateTime.now().toString();
      final String address = safeGetAddress(service['location'] as Map<String, dynamic>?, 'انقر للتفاصيل');
      
      // إنشاء علامة مميزة
      setState(() {
        // إزالة العلامة القديمة إذا كانت موجودة
        _markers.removeWhere((marker) => marker.markerId.value == 'selected_service_$serviceId');
        
        // إضافة العلامة الجديدة
        _markers.add(
          Marker(
            markerId: MarkerId('selected_service_$serviceId'),
            position: serviceLocation,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
            infoWindow: InfoWindow(
              title: service['title'] ?? 'خدمة نقل',
              snippet: service['description'] != null
                ? (service['description'].toString().length > 50 
                    ? '${service['description'].toString().substring(0, 50)}...' 
                    : service['description'])
                : address,
            ),
            onTap: () {
              _showVehicleDetailsBottomSheet(service);
            },
          ),
        );
        
        // إضافة الخدمة إلى قائمة المركبات المتاحة إذا لم تكن موجودة
        if (!_availableVehicles.any((v) => v['id'] == service['id'])) {
          _availableVehicles.add(service);
        }
        
        // عرض قائمة المركبات
        _showVehiclesList = true;
      });
      
      // تحريك الخريطة إلى موقع الخدمة
      _animateToPosition(serviceLocation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.destinationName ?? 'خريطة النقل'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetMap,
            tooltip: 'إعادة تعيين الخريطة',
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. خريطة جوجل
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _originPosition ?? _defaultLocation,
                    zoom: 14,
                  ),
                  mapType: _currentMapType,
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                  },
                ),

          // 2. حقول البحث
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    // حقل البحث لنقطة الانطلاق
                    TextField(
                      controller: _originSearchController,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        hintText: 'نقطة الانطلاق',
                        hintTextDirection: TextDirection.rtl,
                        prefixIcon: Icon(
                          Icons.my_location,
                          color: _isSearchingOrigin ? Colors.blue : Colors.grey,
                        ),
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            final text = _originSearchController.text.trim();
                            if (text.isNotEmpty) {
                              _getLatLngFromAddress(text, true);
                            }
                          },
                        ),
                      ),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          _getLatLngFromAddress(value, true);
                        }
                      },
                    ),

                    // فاصل بين الحقلين
                    const Divider(height: 1),

                    // حقل البحث للوجهة
                    TextField(
                      controller: _destinationSearchController,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        hintText: 'الوجهة',
                        hintTextDirection: TextDirection.rtl,
                        prefixIcon: Icon(
                          Icons.location_on,
                          color: _isSearchingDestination ? Colors.blue : Colors.grey,
                        ),
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            final text = _destinationSearchController.text.trim();
                            if (text.isNotEmpty) {
                              _getLatLngFromAddress(text, false);
                            }
                          },
                        ),
                      ),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          _getLatLngFromAddress(value, false);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // اقتراحات البحث لنقطة الانطلاق
          if (_showOriginSuggestions && _originSuggestions.isNotEmpty)
            Positioned(
              top: 70,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                margin: EdgeInsets.zero,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _originSuggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _originSuggestions[index];
                    return ListTile(
                      title: Text(suggestion),
                      onTap: () {
                        setState(() {
                          _originSearchController.text = suggestion;
                          _showOriginSuggestions = false;
                        });
                        _getLatLngFromAddress(suggestion, true);
                      },
                    );
                  },
                ),
              ),
            ),

          // اقتراحات البحث للوجهة
          if (_showDestinationSuggestions && _destinationSuggestions.isNotEmpty)
            Positioned(
              top: 120,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                margin: EdgeInsets.zero,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _destinationSuggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _destinationSuggestions[index];
                    return ListTile(
                      title: Text(suggestion),
                      onTap: () {
                        setState(() {
                          _destinationSearchController.text = suggestion;
                          _showDestinationSuggestions = false;
                        });
                        _getLatLngFromAddress(suggestion, false);
                      },
                    );
                  },
                ),
              ),
            ),

          // 3. زر عرض المسار
          if (_originPosition != null && _destinationPosition != null)
            Positioned(
              bottom: 120,
              left: 16,
              right: 16,
              child: ElevatedButton.icon(
                onPressed: _showDirections,
                icon: const Icon(Icons.directions),
                label: const Text('عرض المسار'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

          // 4. لوحة معلومات المسار
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'المسافة: ${_tripInfo['distance']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'الوقت التقديري: ${_tripInfo['duration']}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _showDirectionsPanel = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    // قائمة خطوات المسار
                    Expanded(
                      child: ListView.builder(
                        itemCount: _directionSteps.length,
                        itemBuilder: (context, index) {
                          final step = _directionSteps[index];
                          return ListTile(
                            leading: Icon(
                              _getDirectionIcon(step['maneuver'] ?? ''),
                              color: Colors.deepPurple,
                            ),
                            title: Text(
                              step['instruction'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text('${step['distance'] ?? ''} • ${step['duration'] ?? ''}'),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 5. قائمة المركبات المتاحة
          if (_showVehiclesList && _availableVehicles.isNotEmpty)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _availableVehicles.length,
                  itemBuilder: (context, index) {
                    final vehicle = _availableVehicles[index];
                    return GestureDetector(
                      onTap: () {
                        _showVehicleDetailsBottomSheet(vehicle);
                      },
                      child: Container(
                        width: 150,
                        margin: const EdgeInsets.only(right: 10),
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
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vehicle['title'] ?? 'مركبة نقل',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                vehicle['description'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Colors.amber[700],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${vehicle['rating'] ?? 4.5}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
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
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // زر تحديد الموقع الحالي
          FloatingActionButton(
            heroTag: 'btn1',
            onPressed: _getCurrentLocation,
            backgroundColor: Colors.white,
            child: const Icon(Icons.my_location, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          // زر تغيير نوع الخريطة
          FloatingActionButton(
            heroTag: 'btn2',            onPressed: () {
              setState(() {
                _currentMapType = _currentMapType == MapType.normal
                    ? MapType.satellite
                    : MapType.normal;
              });
            },
            backgroundColor: Colors.white,
            child: const Icon(Icons.map, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  // تحديد أيقونة مناسبة لكل نوع من أنواع المناورات
  IconData _getDirectionIcon(String maneuver) {
    switch (maneuver.toLowerCase()) {
      case 'turn-right':
        return Icons.turn_right;
      case 'turn-left':
        return Icons.turn_left;
      case 'roundabout-right':
      case 'roundabout-left':
        return Icons.roundabout_right;
      case 'uturn-right':
      case 'uturn-left':
        return Icons.u_turn_right;
      case 'turn-slight-right':
        return Icons.turn_slight_right;
      case 'turn-slight-left':
        return Icons.turn_slight_left;
      case 'turn-sharp-right':
        return Icons.turn_sharp_right;
      case 'turn-sharp-left':
        return Icons.turn_sharp_left;
      case 'keep-right':
        return Icons.arrow_forward;
      case 'keep-left':
        return Icons.arrow_back;
      case 'merge':
        return Icons.merge_type;
      case 'ramp-right':
      case 'ramp-left':
        return Icons.exit_to_app;
      case 'ferry':
        return Icons.directions_boat;
      case 'ferry-train':
        return Icons.train;
      default:
        return Icons.straight;
    }
  }
}
