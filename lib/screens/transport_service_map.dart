import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bilink/screens/service_details_screen.dart';
import 'package:bilink/screens/fullscreen_image_viewer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bilink/screens/fix_transport_map.dart' as map_fix;
import 'package:bilink/services/location_synchronizer.dart';

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
  bool _isSearchingOrigin = false;
  bool _isSearchingDestination = false;

  // اقتراحات العناوين
  List<String> _originSuggestions = [];
  List<String> _destinationSuggestions = [];
  bool _showOriginSuggestions = false;
  bool _showDestinationSuggestions = false;

  // نطاق البحث عن المركبات (بالكيلومتر)
  double _searchRadius = 15.0;

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
    _loadAvailableVehicles();

    // تحميل المزامن لضمان تحديث بيانات المواقع
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLocationSynchronizer();
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
    );
  }
  
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

  // بناء بطاقة المركبة
  Widget _buildVehicleCard(Map<String, dynamic> vehicle) {
    final String title = vehicle['title'] ?? 'خدمة بدون عنوان';
    final double price = (vehicle['price'] as num?)?.toDouble() ?? 0.0;
    final double rating = (vehicle['rating'] as num?)?.toDouble() ?? 0.0;
    final String distance = vehicle['distance'] ?? '0.0';

    // الصور
    List<dynamic> imageUrls = vehicle['imageUrls'] ?? [];
    if (imageUrls.isEmpty &&
        vehicle.containsKey('vehicle') &&
        vehicle['vehicle'] != null) {
      final vehicleImgs = vehicle['vehicle']['imageUrls'];
      if (vehicleImgs is List && vehicleImgs.isNotEmpty) {
        imageUrls = vehicleImgs;
      }
    }

    // نوع المركبة
    String vehicleType = '';
    if (vehicle.containsKey('vehicle') &&
        vehicle['vehicle'] != null &&
        vehicle['vehicle'] is Map &&
        vehicle['vehicle'].containsKey('type')) {
      vehicleType = vehicle['vehicle']['type'] ?? '';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () {
          _showVehicleDetailsBottomSheet(vehicle);
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Row(
              children: [
                // صورة المركبة
                GestureDetector(
                  onTap: imageUrls.isNotEmpty
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FullScreenImageViewer(
                                imageUrls: List<String>.from(imageUrls),
                                initialIndex: 0,
                              ),
                            ),
                          );
                        }
                      : null,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      image: imageUrls.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(imageUrls[0]),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: imageUrls.isEmpty
                        ? Center(
                            child: Icon(
                              Icons.local_shipping,
                              size: 40,
                              color: Colors.grey.shade400,
                            ),
                          )
                        : imageUrls.length > 1
                            ? Align(
                                alignment: Alignment.topRight,
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '+${imageUrls.length - 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                            : null,
                  ),
                ),

                // معلومات المركبة
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

            // زر الاتصال أو طلب الخدمة
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ElevatedButton(
                onPressed: () {
                  _showVehicleDetailsBottomSheet(vehicle);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('عرض تفاصيل المركبة'),
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
  // عرض منزلق لضبط نطاق البحث
  void _showRadiusSlider() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.all(20),
              height: 160,
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.search, color: Color(0xFF8B5CF6)),
                      SizedBox(width: 10),
                      Text(
                        'اختر نطاق البحث عن المركبات',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Text('5 كم', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Slider(
                          value: _searchRadius,
                          min: 5,
                          max: 50,
                          divisions: 9,
                          activeColor: Color(0xFF8B5CF6),
                          label: '${_searchRadius.toInt()} كم',
                          onChanged: (value) {
                            setModalState(() {
                              setState(() {
                                _searchRadius = value;
                              });
                            });
                          },
                        ),
                      ),
                      Text('50 كم', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _findNearbyVehicles();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                    ),
                    child: Text('تطبيق وبحث'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(      appBar: AppBar(
        title: const Text('البحث عن مركبات النقل'),
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
            tooltip: 'تغيير نوع الخريطة',          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetMap,
            tooltip: 'إعادة ضبط',
          ),
          // زر جديد للبحث عن المركبات المتوفرة
          IconButton(
            icon: const Icon(Icons.local_shipping),
            onPressed: () {
              if (_originPosition != null) {
                _findNearbyVehicles();
                _showRadiusSlider();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('الرجاء تحديد موقعك أولاً قبل البحث عن مركبات'),
                  ),
                );
              }
            },
            tooltip: 'البحث عن مركبات متوفرة',
          ),
          // زر جديد للبحث عن المركبات المتوفرة
          IconButton(
            icon: const Icon(Icons.local_shipping),
            onPressed: () {
              if (_originPosition != null) {
                _findNearbyVehicles();
                _showRadiusSlider();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('الرجاء تحديد موقعك أولاً قبل البحث عن مركبات'),
                  ),
                );
              }
            },
            tooltip: 'البحث عن مركبات متوفرة',
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
                _addMarker(
                  position,
                  'origin',
                  BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueViolet,
                  ),
                  'موقعك الحالي',
                );
                _getAddressFromLatLng(position, true);
                _findNearbyVehicles();
              } else {
                // إذا تم تحديد موقع البداية بالفعل، فإن النقرة تحدد الوجهة
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
                                  hintText: 'موقعك الحالي',
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

                    const SizedBox(height: 16),                    // ضبط نطاق البحث
                    Row(
                      children: [
                        const Icon(
                          Icons.search,
                          color: Color(0xFF8B5CF6),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'نطاق البحث: ${_searchRadius.toInt()} كم',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(
                            value: _searchRadius,
                            min: 5,
                            max: 50,
                            divisions: 9,
                            activeColor: const Color(0xFF8B5CF6),
                            inactiveColor: Colors.grey.shade300,
                            label: '${_searchRadius.toInt()} كم',
                            onChanged: (value) {
                              setState(() {
                                _searchRadius = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    // زر البحث عن المركبات
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(top: 8),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _findNearbyVehicles();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('جاري البحث عن المركبات المتاحة في نطاق ${_searchRadius.toInt()} كم'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: Icon(Icons.local_shipping),
                        label: Text('البحث عن المركبات المتاحة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // قائمة المركبات المتاحة
          if (_showVehiclesList && _availableVehicles.isNotEmpty)
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

                        // عنوان قائمة المركبات
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.local_shipping,
                                color: Color(0xFF8B5CF6),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'المركبات المتاحة (${_availableVehicles.length})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // قائمة المركبات المتاحة
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            itemCount: _availableVehicles.length,
                            itemBuilder: (context, index) {
                              final vehicle = _availableVehicles[index];
                              return _buildVehicleCard(vehicle);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

          // رسالة عدم وجود مركبات
          if (_showVehiclesList && _availableVehicles.isEmpty)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF8B5CF6),
                      size: 36,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'لا توجد مركبات متاحة في هذه المنطقة',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'حاول زيادة نطاق البحث أو تغيير موقعك',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
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
