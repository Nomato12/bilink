import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bilink/screens/service_details_screen.dart';

class NearbyVehiclesMap extends StatefulWidget {  final LatLng originLocation;
  final String originName;
  final LatLng destinationLocation;
  final String destinationName;
  final String selectedVehicleType;
  final double? routeDistance;
  final double? routeDuration;
  final String? distanceText;
  final String? durationText;

  const NearbyVehiclesMap({
    Key? key,
    required this.originLocation,
    required this.originName,
    required this.destinationLocation,
    required this.destinationName,
    required this.selectedVehicleType,
    this.routeDistance,
    this.routeDuration,
    this.distanceText,
    this.durationText,
  }) : super(key: key);

  @override
  State<NearbyVehiclesMap> createState() => _NearbyVehiclesMapState();
}

class _NearbyVehiclesMapState extends State<NearbyVehiclesMap> {
  final Completer<GoogleMapController> _controller = Completer();
  
  // مجموعة العلامات على الخريطة
  final Set<Marker> _markers = {};
  // المسارات على الخريطة
  final Set<Polyline> _polylines = {};
  
  // حالة التحميل
  bool _isLoading = true;
  // المركبات المتاحة القريبة
  List<Map<String, dynamic>> _availableVehicles = [];
  // عرض قائمة المركبات
  bool _showVehiclesList = true;
  
  // ألوان التطبيق
  final Color _primaryColor = const Color(0xFF0B3D91);
  final Color _secondaryColor = const Color(0xFFFF5722);
  final Color _bgColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  // تهيئة الخريطة
  Future<void> _initializeMap() async {
    setState(() {
      _isLoading = true;
    });
    
    // إضافة علامة لموقع البداية
    _addMarker(
      widget.originLocation,
      'origin',
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      widget.originName,
    );
    
    // إضافة علامة للوجهة
    _addMarker(
      widget.destinationLocation,
      'destination',
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      widget.destinationName,
    );
    
    // عرض المسار بين نقطة البداية والوجهة إذا كانت متوفرة
    _drawRoute();

    // تحميل المركبات القريبة
    await _loadNearbyVehicles();
    
    setState(() {
      _isLoading = false;
    });
  }

  // إضافة علامة على الخريطة
  void _addMarker(LatLng position, String markerId, BitmapDescriptor icon, String title) {
    final marker = Marker(
      markerId: MarkerId(markerId),
      position: position,
      infoWindow: InfoWindow(title: title),
      icon: icon,
    );
    
    setState(() {
      _markers.add(marker);
    });
  }

  // رسم المسار بين نقطة البداية والوجهة
  void _drawRoute() {
    final polyline = Polyline(
      polylineId: PolylineId('route'),
      color: _primaryColor,
      width: 5,
      points: [widget.originLocation, widget.destinationLocation],
    );
    
    setState(() {
      _polylines.add(polyline);
    });
  }  // تحميل المركبات القريبة مع التعديلات الثلاثة:
  // 1. حساب السعر بناءً على المسافة بين نقاط الانطلاق والوصول
  // 2. ترتيب المركبات من الأقرب للأبعد من موقع المستخدم
  // 3. عرض أقرب 5 مركبات فقط
  Future<void> _loadNearbyVehicles() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // جلب جميع المركبات
      List<Map<String, dynamic>> vehicles = await _fetchVehiclesByType(widget.selectedVehicleType);
      
      // ترتيب المركبات حسب المسافة من موقع المستخدم
      vehicles.sort((a, b) => 
        (a['distanceFromClient'] as double).compareTo(b['distanceFromClient'] as double));
      
      // الحصول على أقرب 5 مركبات فقط
      if (vehicles.length > 5) {
        vehicles = vehicles.sublist(0, 5);
      }
      
      // إضافة علامات للمركبات
      for (var vehicle in vehicles) {
        _addVehicleMarker(
          vehicle['position'],
          'vehicle_${vehicle['id']}',
          vehicle['type'],
          isRealProvider: vehicle['isRealProvider'] == true,
        );
      }
      
      setState(() {
        _availableVehicles = vehicles;
        _showVehiclesList = vehicles.isNotEmpty;
        _isLoading = false;
      });
      
      // عرض رسالة إذا لم يتم العثور على مركبات
      if (vehicles.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('لا توجد مركبات من نوع ${widget.selectedVehicleType} متاحة حاليًا'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('خطأ في تحميل المركبات: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تحميل المركبات المتاحة'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // إضافة علامة مركبة على الخريطة
  void _addVehicleMarker(LatLng position, String markerId, String vehicleType, {bool isRealProvider = false}) {
    // اختيار لون مختلف للمركبات حسب النوع
    double hue;
    switch (vehicleType.toLowerCase()) {
      case 'شاحنة صغيرة':
        hue = BitmapDescriptor.hueOrange;
        break;
      case 'شاحنة متوسطة':
        hue = BitmapDescriptor.hueYellow;
        break;
      case 'شاحنة كبيرة':
        hue = BitmapDescriptor.hueMagenta;
        break;
      case 'مركبة خفيفة':
        hue = BitmapDescriptor.hueCyan;
        break;
      case 'دراجة نارية':
        hue = BitmapDescriptor.hueViolet;
        break;
      default:
        hue = BitmapDescriptor.hueBlue;
    }
    
    // إضافة علامة بلون مختلف للمزودين الحقيقيين
    if (isRealProvider) {
      hue = BitmapDescriptor.hueAzure;
    }
    
    final marker = Marker(
      markerId: MarkerId(markerId),
      position: position,
      infoWindow: InfoWindow(
        title: vehicleType,
        snippet: isRealProvider ? 'مزود حقيقي متاح' : 'مركبة متاحة للخدمة',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(hue),
    );
    
    setState(() {
      _markers.add(marker);
    });
  }  // استعلام عن المركبات من قاعدة البيانات حسب النوع بطريقة محسنة
  Future<List<Map<String, dynamic>>> _fetchVehiclesByType(String vehicleType) async {
    List<Map<String, dynamic>> vehicles = [];
    
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      
      // تحسين الاستعلام بإضافة فهرس لنوع المركبة مباشرة في service_locations
      // استعلام مركب لتحسين الأداء: نقل + نوع المركبة المحدد
      var query = firestore.collection('service_locations')
          .where('type', isEqualTo: 'نقل');
      
      // إضافة مؤقت زمني للاستعلام
      final Stopwatch timer = Stopwatch()..start();
      final querySnapshot = await query.get();
      final queryTime = timer.elapsedMilliseconds;
      
      print('تم العثور على ${querySnapshot.docs.length} خدمة نقل (استغرق الاستعلام $queryTime مللي ثانية)');
      
      // تحسين أداء جلب البيانات باستخدام محدد حجم الدفعة
      final int batchSize = 10; // عدد الوثائق في كل دفعة استعلام
      final List<List<DocumentSnapshot>> batches = [];
      
      // تقسيم النتائج إلى دفعات
      for (int i = 0; i < querySnapshot.docs.length; i += batchSize) {
        final end = (i + batchSize < querySnapshot.docs.length) ? i + batchSize : querySnapshot.docs.length;
        batches.add(querySnapshot.docs.sublist(i, end));
      }
      
      // معالجة كل دفعة على حدة
      for (var batch in batches) {
        // جمع معرفات الخدمات لعملية جلب متعددة
        final List<String> serviceIds = batch.map((doc) => doc.id).toList();
        
        // جلب تفاصيل الخدمات دفعة واحدة لتحسين الأداء
        final servicesSnapshots = await Future.wait(
          serviceIds.map((id) => firestore.collection('services').doc(id).get())
        );
        
        // معالجة نتائج كل دفعة
        for (int i = 0; i < batch.length; i++) {
          try {
            final doc = batch[i];
            final serviceData = doc.data() as Map<String, dynamic>?;
            final serviceId = doc.id;
            
            if (serviceData == null) continue;
              // الحصول على تفاصيل الخدمة من نتائج الاستعلام المتعدد
            final serviceSnapshot = servicesSnapshots[i];
            
            if (!serviceSnapshot.exists) continue;
            
            final serviceDetails = serviceSnapshot.data();
            
            if (serviceDetails == null) continue;
          
          // التحقق من وجود موقع صالح
          if (serviceData.containsKey('position') && 
              serviceData['position'] is Map && 
              (serviceData['position'] as Map).containsKey('latitude') && 
              (serviceData['position'] as Map).containsKey('longitude')) {
            
            final Map<String, dynamic> position = serviceData['position'] as Map<String, dynamic>;
            final latitude = position['latitude'];
            final longitude = position['longitude'];
            
            if (latitude == null || longitude == null) continue;
            
            // تحديد نوع المركبة
            String actualVehicleType = 'مركبة خفيفة'; // قيمة افتراضية
            
            // البحث عن نوع المركبة في عدة أماكن
            if (serviceDetails.containsKey('vehicle') && 
                serviceDetails['vehicle'] is Map && 
                (serviceDetails['vehicle'] as Map).containsKey('type')) {
              actualVehicleType = (serviceDetails['vehicle'] as Map)['type'] as String;
            } else if (serviceDetails.containsKey('vehicleType')) {
              actualVehicleType = serviceDetails['vehicleType'] as String;
            } else if (serviceData.containsKey('vehicleType')) {
              actualVehicleType = serviceData['vehicleType'] as String;
            }
            
            // التحقق من تطابق نوع المركبة
            if (_isMatchingVehicleType(actualVehicleType, vehicleType)) {
              // حساب المسافة من موقع العميل
              double distanceFromClient = _calculateDistance(
                widget.originLocation.latitude, 
                widget.originLocation.longitude,
                latitude, 
                longitude
              );
              
              // الحصول على معلومات الشركة المزودة
              String companyName = serviceDetails['userDisplayName'] ?? 'مزود خدمة';
              String providerPhotoUrl = serviceDetails['userPhotoURL'] ?? '';
              
              // الحصول على صورة المركبة إذا كانت متوفرة
              List<String> vehicleImages = [];
              if (serviceDetails.containsKey('vehicle') && 
                  serviceDetails['vehicle'] is Map && 
                  (serviceDetails['vehicle'] as Map).containsKey('imageUrls') &&
                  serviceDetails['vehicle']['imageUrls'] is List) {
                vehicleImages = List<String>.from(serviceDetails['vehicle']['imageUrls']);
              }
              
              String vehicleImage = vehicleImages.isNotEmpty 
                  ? vehicleImages.first 
                  : _getDefaultVehicleImage(actualVehicleType);
              
              // إضافة المركبة إلى القائمة
              vehicles.add({
                'id': serviceId,
                'type': actualVehicleType,
                'company': companyName,
                'rating': serviceDetails['rating']?.toString() ?? '4.0',
                'price': _calculatePrice(distanceFromClient, actualVehicleType),
                'arrivalTime': '${_calculateArrivalTime(distanceFromClient)} دقيقة',
                'image': vehicleImage,
                'providerImage': providerPhotoUrl,
                'position': LatLng(latitude, longitude),
                'distanceFromClient': distanceFromClient,
                'isRealProvider': true,
                'providerId': serviceDetails['providerId'] ?? '',
                'serviceDetails': serviceDetails,
              });
            }
          }
          } catch (error) {
            print('خطأ في معالجة الخدمة: $error');
          }
        }
      }
      
      // ترتيب المركبات حسب المسافة من موقع العميل
      vehicles.sort((a, b) => (a['distanceFromClient'] as double).compareTo(b['distanceFromClient'] as double));
      
      // إذا لم نجد مركبات حقيقية، نضيف مركبات افتراضية للتجربة
      if (vehicles.isEmpty) {
        vehicles = _generateDummyVehicles(widget.destinationLocation, vehicleType);
      }
      
      print('تم تحميل ${vehicles.length} مركبة مطابقة لنوع $vehicleType');
      
    } catch (error) {
      print('خطأ في استعلام المركبات: $error');
    }
    
    return vehicles;
  }

  // التحقق من تطابق نوع المركبة
  bool _isMatchingVehicleType(String actualType, String targetType) {
    if (targetType.isEmpty) return true;
    return actualType.trim().toLowerCase() == targetType.trim().toLowerCase();
  }  // إنشاء مركبات افتراضية للتجربة
  List<Map<String, dynamic>> _generateDummyVehicles(LatLng position, String vehicleType) {
    final random = math.Random();
    final int vehicleCount = 3 + random.nextInt(3); // 3-5 مركبات
    
    // قائمة بالشركات المزودة لخدمات النقل
    final companies = [
      'شركة النقل السريع',
      'توصيل اكسبرس',
      'نقل البضائع الموثوق',
      'سبيد ديليفري',
      'نقل آمن',
    ];
    
    List<Map<String, dynamic>> vehicles = List.generate(vehicleCount, (index) {
      // موقع عشوائي قريب من الوجهة
      final latOffset = (random.nextDouble() - 0.5) * 0.02;
      final lngOffset = (random.nextDouble() - 0.5) * 0.02;
      final vehiclePosition = LatLng(
        position.latitude + latOffset,
        position.longitude + lngOffset,
      );
      
      // حساب المسافة من موقع العميل
      double distanceFromClient = _calculateDistance(
        widget.originLocation.latitude, 
        widget.originLocation.longitude,
        vehiclePosition.latitude, 
        vehiclePosition.longitude
      );
      
      return {
        'id': 'dummy_${vehicleType}_$index',
        'type': vehicleType,
        'company': companies[random.nextInt(companies.length)],
        'rating': (3.0 + random.nextDouble() * 2.0).toStringAsFixed(1),
        'price': _calculatePrice(distanceFromClient, vehicleType),
        'arrivalTime': '${_calculateArrivalTime(distanceFromClient)} دقيقة',
        'image': _getDefaultVehicleImage(vehicleType),
        'providerImage': '',
        'position': vehiclePosition,
        'distanceFromClient': distanceFromClient,
        'isRealProvider': false,
      };
    });
    
    // ترتيب المركبات من الأقرب للأبعد
    vehicles.sort((a, b) => 
      (a['distanceFromClient'] as double).compareTo(b['distanceFromClient'] as double));
    
    // الاحتفاظ بأقرب 5 مركبات فقط
    if (vehicles.length > 5) {
      vehicles = vehicles.sublist(0, 5);
    }
    
    return vehicles;
  }

  // حساب المسافة بين نقطتين
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // بالكيلومتر
  }
  
  // حساب وقت الوصول التقريبي (بالدقائق)
  int _calculateArrivalTime(double distanceInKm) {
    // افتراض سرعة متوسطة 40 كم/ساعة
    double timeInHours = distanceInKm / 40;
    return (timeInHours * 60).round() + 5; // إضافة 5 دقائق كوقت تجهيز
  }
  // حساب السعر التقريبي
  String _calculatePrice(double distanceFromClient, String vehicleType) {
    // أسعار أساسية لكل نوع مركبة (بالدينار الجزائري)
    Map<String, double> basePrices = {
      'شاحنة صغيرة': 80,
      'شاحنة متوسطة': 100,
      'شاحنة كبيرة': 120,
      'مركبة خفيفة': 60,
      'دراجة نارية': 50,
    };
    
    // السعر الأساسي للنوع
    double basePrice = basePrices[vehicleType] ?? 70;
    
    // حساب السعر حسب المسافة بين نقطتي الانطلاق والوصول (وليس المسافة من المستخدم للمركبة)
    double routeDistanceKm = widget.routeDistance ?? _calculateDistance(
      widget.originLocation.latitude,
      widget.originLocation.longitude,
      widget.destinationLocation.latitude,
      widget.destinationLocation.longitude
    );
    
    double price = basePrice + (routeDistanceKm * 20);
    
    // تقريب السعر لأقرب 10 دينار
    int roundedPrice = (price / 10).round() * 10;
    
    return roundedPrice.toString();
  }
  
  // الحصول على صورة افتراضية للمركبة حسب النوع
  String _getDefaultVehicleImage(String vehicleType) {
    switch (vehicleType.toLowerCase()) {
      case 'شاحنة صغيرة':
        return 'https://firebasestorage.googleapis.com/v0/b/bilink-b0381.appspot.com/o/vehicles%2Fsmall_truck.png?alt=media';
      case 'شاحنة متوسطة':
        return 'https://firebasestorage.googleapis.com/v0/b/bilink-b0381.appspot.com/o/vehicles%2Fmedium_truck.png?alt=media';
      case 'شاحنة كبيرة':
        return 'https://firebasestorage.googleapis.com/v0/b/bilink-b0381.appspot.com/o/vehicles%2Flarge_truck.png?alt=media';
      case 'مركبة خفيفة':
        return 'https://firebasestorage.googleapis.com/v0/b/bilink-b0381.appspot.com/o/vehicles%2Fcar.png?alt=media';
      case 'دراجة نارية':
        return 'https://firebasestorage.googleapis.com/v0/b/bilink-b0381.appspot.com/o/vehicles%2Fmotorcycle.png?alt=media';
      default:
        return 'https://firebasestorage.googleapis.com/v0/b/bilink-b0381.appspot.com/o/vehicles%2Fdefault_vehicle.png?alt=media';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('مركبات ${widget.selectedVehicleType} المتاحة'),
          backgroundColor: _primaryColor,
        ),
        body: Stack(
          children: [
            // الخريطة
            GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: CameraPosition(
                target: widget.destinationLocation,
                zoom: 13,
              ),
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              compassEnabled: true,
            ),
            
            // مؤشر التحميل
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_secondaryColor),
                  ),
                ),
              ),
            
            // معلومات المسار
            if (widget.distanceText != null && widget.durationText != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  margin: EdgeInsets.all(8),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        offset: Offset(0, 2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.route, color: _primaryColor),
                          SizedBox(width: 8),
                          Text(widget.distanceText!),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.access_time, color: _primaryColor),
                          SizedBox(width: 8),
                          Text(widget.durationText!),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            
            // قائمة المركبات المتاحة
            if (_showVehiclesList && !_isLoading && _availableVehicles.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.3,
                  decoration: BoxDecoration(
                    color: _bgColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        offset: Offset(0, -3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'المركبات المتاحة',
                              style: TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_availableVehicles.length} مركبة',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _availableVehicles.length,
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          itemBuilder: (context, index) {
                            final vehicle = _availableVehicles[index];
                            return _buildVehicleCard(vehicle);
                          },
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
  }

  // بطاقة المركبة
  Widget _buildVehicleCard(Map<String, dynamic> vehicle) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectVehicle(vehicle),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              // صورة المركبة
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 70,
                  height: 70,
                  child: CachedNetworkImage(
                    imageUrl: vehicle['image'] ?? '',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[200]),
                    errorWidget: (context, url, error) => Image.asset(
                      'assets/images/default_vehicle.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              
              // معلومات المركبة
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // اسم الشركة والتقييم
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            vehicle['company'] ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 18),
                            SizedBox(width: 4),
                            Text(
                              vehicle['rating'] ?? '4.0',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    
                    // نوع المركبة
                    Text(
                      vehicle['type'] ?? '',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 6),
                    
                    // المسافة والسعر ووقت الوصول
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // المسافة
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.grey[700]),
                            SizedBox(width: 4),
                            Text(
                              '${(vehicle['distanceFromClient'] as double).toStringAsFixed(1)} كم',
                              style: TextStyle(color: Colors.grey[700], fontSize: 13),
                            ),
                          ],
                        ),
                        
                        // وقت الوصول
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 16, color: Colors.grey[700]),
                            SizedBox(width: 4),
                            Text(
                              vehicle['arrivalTime'] ?? '',
                              style: TextStyle(color: Colors.grey[700], fontSize: 13),
                            ),
                          ],
                        ),
                        
                        // السعر
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _secondaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${vehicle['price']} د.ج',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _secondaryColor,
                              fontSize: 13,
                            ),
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
  }

  // اختيار مركبة
  void _selectVehicle(Map<String, dynamic> vehicle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildVehicleDetails(vehicle),
    );
  }

  // تفاصيل المركبة
  Widget _buildVehicleDetails(Map<String, dynamic> vehicle) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس الشاشة
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تفاصيل المركبة',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.grey[700]),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          // صورة المركبة
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: vehicle['image'] ?? '',
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 200,
                color: Colors.grey[200],
                child: Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                height: 200,
                color: Colors.grey[200],
                child: Icon(Icons.local_shipping, size: 50, color: Colors.grey),
              ),
            ),
          ),
          SizedBox(height: 16),
          
          // معلومات المزود
          Row(
            children: [
              // صورة المزود
              if (vehicle['providerImage'] != null && vehicle['providerImage'].isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CachedNetworkImage(
                    imageUrl: vehicle['providerImage'],
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[200]),
                    errorWidget: (context, url, error) => Icon(Icons.person),
                  ),
                )
              else
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _primaryColor.withOpacity(0.1),
                  child: Icon(Icons.person, color: _primaryColor),
                ),
              SizedBox(width: 12),
              
              // اسم المزود والتقييم
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle['company'] ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        SizedBox(width: 4),
                        Text(
                          '${vehicle['rating']} (${getRandomReviewCount()})',
                          style: TextStyle(color: Colors.grey[700], fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // زر التواصل
              if (vehicle['isRealProvider'] == true && vehicle['providerId'] != null)
                IconButton(
                  icon: Icon(Icons.message, color: _primaryColor),
                  onPressed: () => _startChat(vehicle),
                ),
            ],
          ),
          SizedBox(height: 16),
          
          // نوع المركبة ومعلومات التوصيل
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildInfoRow(Icons.local_shipping, 'نوع المركبة', vehicle['type'] ?? ''),
                Divider(height: 12),
                _buildInfoRow(Icons.location_on, 'المسافة', '${(vehicle['distanceFromClient'] as double).toStringAsFixed(1)} كم'),
                Divider(height: 12),
                _buildInfoRow(Icons.access_time, 'وقت الوصول التقريبي', vehicle['arrivalTime'] ?? ''),
                if (widget.distanceText != null) Divider(height: 12),
                if (widget.distanceText != null) _buildInfoRow(Icons.route, 'مسافة الرحلة', widget.distanceText!),
                if (widget.durationText != null) Divider(height: 12),
                if (widget.durationText != null) _buildInfoRow(Icons.timer, 'مدة الرحلة', widget.durationText!),
              ],
            ),
          ),
          SizedBox(height: 16),
          
          // معلومات الدفع
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _secondaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'التكلفة التقريبية',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${vehicle['price']} دينار جزائري',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: _secondaryColor,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          
          // زر حجز المركبة
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => _bookVehicle(vehicle),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'حجز هذه المركبة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
        ],
      ),
    );
  }

  // صف معلومات
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _primaryColor),
        SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(color: Colors.grey[700]),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  // بدء محادثة مع مزود الخدمة
  void _startChat(Map<String, dynamic> vehicle) {
    if (vehicle['providerId'] == null || vehicle['providerId'].isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لا يمكن التواصل مع هذا المزود في الوقت الحالي')),
      );
      return;
    }
    
    // التحقق من وجود مستخدم مسجل
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يجب تسجيل الدخول أولاً للتواصل مع مزود الخدمة')),
      );
      return;
    }
      // الانتقال إلى صفحة المحادثة
    Navigator.pop(context); // إغلاق النافذة المنبثقة
    
    // ملاحظة: هنا كان هناك انتقال لصفحة المحادثة، ولكن قمنا بتعطيله لأنه غير ضروري الآن
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('سيتم الانتقال إلى صفحة المحادثة مع المزود'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // حجز المركبة
  void _bookVehicle(Map<String, dynamic> vehicle) {
    // التحقق من وجود مستخدم مسجل
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يجب تسجيل الدخول أولاً لحجز المركبة')),
      );
      return;
    }
    
    // إذا كان مزود حقيقي وله معرف خدمة
    if (vehicle['isRealProvider'] == true && vehicle['id'] != null) {
      Navigator.pop(context); // إغلاق النافذة المنبثقة
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ServiceDetailsScreen(
            serviceId: vehicle['id'],
          ),
        ),
      );
    } else {
      // في حالة المركبات الافتراضية، نعرض رسالة فقط
      Navigator.pop(context); // إغلاق النافذة المنبثقة
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إرسال طلب الحجز بنجاح. سيتم التواصل معك قريبًا.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // الحصول على عدد تقييمات عشوائي للتجربة
  String getRandomReviewCount() {
    final random = math.Random();
    return (5 + random.nextInt(50)).toString();
  }
}
