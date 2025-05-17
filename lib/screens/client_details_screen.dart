import 'package:flutter/material.dart';
import 'package:bilink/services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bilink/services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilink/utils/location_helper.dart';
import 'package:bilink/screens/chat_screen.dart';
import 'package:bilink/services/directions_service.dart';
import 'dart:math' as math;
import 'package:bilink/screens/directions_map_tracking.dart';

class ClientDetailsScreen extends StatefulWidget {
  final String clientId;
  final bool showDestinationDirectly; // جديد: خيار لفتح الوجهة مباشرة

  const ClientDetailsScreen({super.key, required this.clientId, this.showDestinationDirectly = false});

  @override
  State<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends State<ClientDetailsScreen> {
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late ChatService _chatService;

  bool _isLoading = true;
  Map<String, dynamic> _clientDetails = {};
  String? _errorMessage;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  CameraPosition? _initialCameraPosition;
  GoogleMapController? _mapController;

  bool _hasTransportRequestData = false;
  LatLng? _originLocation;
  LatLng? _destinationLocation;
  String _originName = '';
  String _destinationName = '';
  String _distanceText = '';
  String _durationText = '';
  double _price = 0;
  String _vehicleType = '';  @override
  void initState() {
    super.initState();
    _chatService = ChatService(_auth.currentUser?.uid ?? '');    _loadClientDetails().then((_) async {
      // بعد تحميل البيانات، نتأكد من إضافة علامة الوجهة وتحميل المسار
      await Future.delayed(const Duration(milliseconds: 800));
      _addDestinationMarker();
      
      // إذا كان الخيار مفعّل وهناك وجهة، افتح Google Maps مباشرة على الوجهة
      if (widget.showDestinationDirectly && _destinationLocation != null) {
        await Future.delayed(const Duration(milliseconds: 500)); // تأخير بسيط لضمان تحميل البيانات
        
        // إذا كان هناك موقع للعميل ووجهة، اعرض الاتجاهات بينهما
        if (_markers.any((marker) => marker.markerId.value == 'clientLocation')) {
          final clientMarker = _markers.firstWhere(
            (marker) => marker.markerId.value == 'clientLocation',
            orElse: () => _markers.first,
          );
          _openInGoogleMaps(clientMarker.position, destination: _destinationLocation);
        } else {
          // إذا كان هناك وجهة فقط، اعرض الوجهة
          _openInGoogleMaps(_destinationLocation!);
        }
      } else if (widget.showDestinationDirectly && _initialCameraPosition != null && _markers.isNotEmpty) {
        // إذا لم تكن هناك وجهة ولكن هناك موقع للعميل، افتح موقع العميل بدلاً من ذلك
        await Future.delayed(const Duration(milliseconds: 500));
        _openInGoogleMaps(_markers.first.position);
      } else if (widget.showDestinationDirectly) {
        // إذا لم تكن هناك أي بيانات موقع، أظهر رسالة للمستخدم
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لم يتم العثور على أي بيانات موقع لهذا العميل'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4), // زيادة المدة لضمان رؤية المستخدم للرسالة
          ),
        );
      }
    });
  }

  // Helper: Build contact tile
  Widget _buildContactTile({
    required IconData icon,
    required String title,
    required String value,
    Function()? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE9D5FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: Icon(
                  icon,
                  color: const Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[900],
                        fontWeight: FontWeight.w500,
                      ),
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

  // Helper: Build info item for transport section
  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
    Color color = Colors.black,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500)),
              Text(value, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  // Helper: Build location item for transport section
  Widget _buildLocationItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500)),
              Text(value, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }
  // Helper: Open in Google Maps
  Future<void> _openInGoogleMaps(LatLng position, {LatLng? destination}) async {
    if (_mapController == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جاري تحميل الخريطة...'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      if (destination != null) {
        // للانتقال بين نقطتين (مسار)
        final bounds = LatLngBounds(
          southwest: LatLng(
            math.min(position.latitude, destination.latitude) - 0.01,
            math.min(position.longitude, destination.longitude) - 0.01,
          ),
          northeast: LatLng(
            math.max(position.latitude, destination.latitude) + 0.01,
            math.max(position.longitude, destination.longitude) + 0.01,
          ),
        );
        
        await _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
        
        // تحميل المسار إذا لم يكن موجوداً
        if (_polylines.isEmpty) {
          _loadDirections();
        }
      } else {
        // للانتقال إلى نقطة واحدة
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(position, 15),
        );
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الانتقال إلى الموقع بنجاح'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء الانتقال إلى الموقع'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Helper: Open WhatsApp
  Future<void> _openWhatsApp(String phoneNumber) async {
    String formattedNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (!formattedNumber.startsWith('213') && !formattedNumber.startsWith('+213')) {
      if (formattedNumber.startsWith('0')) {
        formattedNumber = formattedNumber.substring(1);
      }
      formattedNumber = '213$formattedNumber';
    }
    final url = 'https://wa.me/$formattedNumber';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن فتح واتساب'), backgroundColor: Colors.red),
        );
      }
    }
  }  Future<void> _loadClientDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // تحميل معلومات العميل الأساسية
      final clientDetails = await _notificationService.getClientDetails(
        widget.clientId,
      );
      
      // تخزين بيانات العميل في متغير الحالة
      setState(() {
        _clientDetails = clientDetails;
        print('تم تحميل بيانات العميل: ${_clientDetails['name']}, صورة الملف الشخصي: ${_clientDetails['profilePicture'] != null}');
      });
      
      // استخدم دالة المساعدة للحصول على موقع العميل
      GeoPoint? clientGeoPoint = LocationHelper.getLocationFromData(clientDetails);
      String clientAddress = LocationHelper.getAddressFromData(clientDetails);
      bool isLocationRecent = LocationHelper.isLocationRecent(clientDetails);
      
      // محاولة تحميل معلومات الوجهة من مصادر متعددة
      bool hasLoadedDestination = false;
      
      if (clientGeoPoint != null) {
        print('Client location found using helper: ${clientGeoPoint.latitude}, ${clientGeoPoint.longitude}');
        // إضافة علامة لموقع العميل
        final clientLocation = LatLng(clientGeoPoint.latitude, clientGeoPoint.longitude);
        
        setState(() {
          // تهيئة الخريطة بموقع العميل
          _initialCameraPosition = CameraPosition(
            target: clientLocation,
            zoom: 15.0,
          );
          
          // إضافة علامة للعميل مع تحديثها لإظهار ما إذا كان الموقع حديثًا أم لا
          _markers = {
            Marker(
              markerId: const MarkerId('clientLocation'),
              position: clientLocation,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                isLocationRecent ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueAzure,
              ),
              infoWindow: InfoWindow(
                title: isLocationRecent ? 'موقع العميل الحالي' : 'موقع العميل',
                snippet: clientAddress.isNotEmpty ? clientAddress : 'موقع العميل',
              ),
            ),
          };
        });
      }
      
      // البحث عن بيانات مكان الوجهة من مخزن المواقع المخصص
      print('Looking for client location and destination in dedicated location storage');
      final locationData = await LocationHelper.getClientLocationData(widget.clientId);
      
      if (locationData != null) {
        print('Client location data found in dedicated storage: $locationData');
        
        // معالجة بيانات الموقع الأساسي (نقطة الانطلاق)
        if (locationData.containsKey('originLocation') && locationData['originLocation'] is GeoPoint) {
          final originGeoPoint = locationData['originLocation'] as GeoPoint;
          final originLocation = LatLng(originGeoPoint.latitude, originGeoPoint.longitude);
          final originName = locationData['originName'] ?? 'موقع العميل';
          
          // تعيين نقطة الانطلاق كموقع العميل الافتراضي إذا لم يكن لدينا موقع بالفعل
          if (clientGeoPoint == null) {
            setState(() {
              _initialCameraPosition = CameraPosition(
                target: originLocation,
                zoom: 15.0,
              );
              
              _markers = {
                Marker(
                  markerId: const MarkerId('clientLocation'),
                  position: originLocation,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                  infoWindow: InfoWindow(
                    title: 'موقع العميل',
                    snippet: originName,
                  ),
                ),
              };
            });
          }
            // إذا كانت هناك وجهة، نضيفها أيضًا
          if (locationData.containsKey('destinationLocation') && locationData['destinationLocation'] is GeoPoint) {
            final destGeoPoint = locationData['destinationLocation'] as GeoPoint;
            final destLocation = LatLng(destGeoPoint.latitude, destGeoPoint.longitude);
            final destName = locationData['destinationName'] ?? 'وجهة العميل';
              // حفظ معلومات النقل والموقع
            hasLoadedDestination = true;
            _originLocation = originLocation;
            _destinationLocation = destLocation;
            _originName = originName;
            _destinationName = destName;
            
            // إذا كانت هناك معلومات إضافية، نحفظها أيضًا
            if (locationData.containsKey('distanceText')) _distanceText = locationData['distanceText'];
            if (locationData.containsKey('durationText')) _durationText = locationData['durationText'];
            
            // إضافة علامة للوجهة مع التأكد من وضوحها
            setState(() {
              // إزالة أي علامات للوجهة موجودة مسبقاً
              _markers.removeWhere((marker) => marker.markerId.value == 'clientDestination');
              
              // إضافة علامة الوجهة الجديدة
              _markers.add(
                Marker(
                  markerId: const MarkerId('clientDestination'),
                  position: destLocation,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                  infoWindow: InfoWindow(
                    title: 'وجهة العميل',
                    snippet: destName,
                  ),
                  visible: true,
                  zIndex: 2,
                ),
              );
            });
            print('Successfully added destination marker: $destName at ${destLocation.latitude}, ${destLocation.longitude}');
          }
        }
        
        // إذا كان هناك موقع في تفاصيل العميل ولم يتم تحميله بعد
        if (clientDetails.containsKey('location') && clientDetails['location'] != null && clientGeoPoint == null) {
          // الكود الأصلي للتعامل مع بيانات الموقع المدمجة في تفاصيل العميل
          var locationData = clientDetails['location'];
          print('Client location data found directly in client details: $locationData');
          
          // If we have location data, initialize client map markers
          try {
            // Extract latitude and longitude from the location data
            if (locationData is Map<String, dynamic>) {
              double? latitude, longitude;
              
              if (locationData.containsKey('latitude') && locationData.containsKey('longitude')) {
                latitude = locationData['latitude'] is double 
                    ? locationData['latitude'] 
                    : double.tryParse(locationData['latitude'].toString());
                
                longitude = locationData['longitude'] is double 
                    ? locationData['longitude'] 
                    : double.tryParse(locationData['longitude'].toString());
                
                if (latitude != null && longitude != null) {
                  // Add a marker for client location
                  final clientLocation = LatLng(latitude, longitude);
                  
                  setState(() {
                    // Initialize map with client location
                    _initialCameraPosition = CameraPosition(
                      target: clientLocation,
                      zoom: 15.0,
                    );
                    
                    // Add client marker
                    _markers = {
                      Marker(
                        markerId: const MarkerId('clientLocation'),
                        position: clientLocation,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueAzure,
                        ),
                        infoWindow: InfoWindow(
                          title: 'موقع العميل',
                          snippet: clientDetails['address'] ?? '',
                        ),
                      ),
                    };
                  });
                  
                  print('Successfully set up client location on map: $latitude, $longitude');
                } else {
                  print('Invalid latitude or longitude values in client location data');
                }
              } else if (locationData.containsKey('geopoint') && locationData['geopoint'] is GeoPoint) {
                // استخراج البيانات من نوع GeoPoint
                final geoPoint = locationData['geopoint'] as GeoPoint;
                final clientLocation = LatLng(geoPoint.latitude, geoPoint.longitude);
                
                setState(() {
                  _initialCameraPosition = CameraPosition(
                    target: clientLocation,
                    zoom: 15.0,
                  );
                  
                  _markers = {
                    Marker(
                      markerId: const MarkerId('clientLocation'),
                      position: clientLocation,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure,
                      ),
                      infoWindow: InfoWindow(
                        title: 'موقع العميل',
                        snippet: clientDetails['address'] ?? '',
                      ),
                    ),
                  };
                });
                
                print('Successfully set up client location from geopoint: ${geoPoint.latitude}, ${geoPoint.longitude}');
              } else {
                print('Location data missing required latitude/longitude fields');
              }
            } else if (locationData is GeoPoint) {
              // التعامل مع البيانات من نوع GeoPoint مباشرة
              final clientLocation = LatLng(locationData.latitude, locationData.longitude);
              
              setState(() {
                _initialCameraPosition = CameraPosition(
                  target: clientLocation,
                  zoom: 15.0,
                );
                
                _markers = {
                  Marker(
                    markerId: const MarkerId('clientLocation'),
                    position: clientLocation,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure,
                    ),
                    infoWindow: InfoWindow(
                      title: 'موقع العميل',
                      snippet: clientDetails['address'] ?? '',
                    ),
                  ),
                };
              });
              
              print('Successfully set up client location from direct GeoPoint: ${locationData.latitude}, ${locationData.longitude}');
            } else if (locationData is String) {
              print('Location data is a string reference, not coordinates: $locationData');
            } else {
              print('Unknown location data format: ${locationData.runtimeType}');
            }
          } catch (locationError) {
            print('Error processing client location data: $locationError');
          }
        } else {
          print('No location data found in client details');
        }
      }      // تحميل معلومات طلب النقل الخاص بالعميل (إن وجد)
      final transportDetails = await _notificationService
          .getClientTransportRequestDetails(widget.clientId);

      if (transportDetails['hasLocationData'] == true && !hasLoadedDestination) {
        // استخراج معلومات النقل
        print('Transport request data found with location information');
        
        setState(() {
          _hasTransportRequestData = true;

          // معلومات الموقع
          if (transportDetails.containsKey('originLocation')) {
            final originMap =
                transportDetails['originLocation'] as Map<String, dynamic>;
            _originLocation = LatLng(
              originMap['latitude'] as double,
              originMap['longitude'] as double,
            );
            _originName = transportDetails['originName'] ?? 'نقطة الانطلاق';
          }          if (transportDetails.containsKey('destinationLocation')) {
            final destMap =
                transportDetails['destinationLocation'] as Map<String, dynamic>;
            _destinationLocation = LatLng(
              destMap['latitude'] as double,
              destMap['longitude'] as double,
            );
            _destinationName = transportDetails['destinationName'] ?? 'الوجهة';
            
            // إضافة علامة للوجهة إذا لم تكن موجودة بالفعل مع التأكد من وضوحها
            if (_destinationLocation != null) {
              print('⭐ إضافة علامة وجهة العميل من طلب النقل: ${_destinationLocation!.latitude}, ${_destinationLocation!.longitude}');
              setState(() {
                // إزالة أي علامات للوجهة قديمة (إذا وجدت)
                _markers.removeWhere((marker) => marker.markerId.value == 'clientDestination');
                
                // إضافة علامة الوجهة الجديدة
                _markers.add(
                  Marker(
                    markerId: const MarkerId('clientDestination'),
                    position: _destinationLocation!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                    infoWindow: InfoWindow(
                      title: 'وجهة العميل',
                      snippet: _destinationName,
                    ),
                    visible: true,
                    zIndex: 2,
                  ),
                );
              });
              print('✅ تمت إضافة علامة وجهة العميل من طلب النقل بنجاح! عدد العلامات: ${_markers.length}');
            }
          }// معلومات إضافية
          _distanceText = transportDetails['distanceText'] ?? '';
          _durationText = transportDetails['durationText'] ?? '';

          // تأكد من أن السعر هو رقم عشري
          try {
            var priceValue = transportDetails['price'];
            if (priceValue is int) {
              _price = priceValue.toDouble();
            } else if (priceValue is double) {
              _price = priceValue;
            } else if (priceValue is String) {
              _price = double.tryParse(priceValue) ?? 0.0;
            } else {
              _price = 0.0;
            }
          } catch (e) {
            print('Error converting price: $e');
            _price = 0.0;
          }

          _vehicleType = transportDetails['vehicleType'] ?? '';

          // إعداد موقع الكاميرا الأولي على الخريطة إذا كنا بحاجة إليه
          if (_initialCameraPosition == null && _originLocation != null && _destinationLocation != null) {
            final double avgLat =
                (_originLocation!.latitude + _destinationLocation!.latitude) /
                2;
            final double avgLng =
                (_originLocation!.longitude + _destinationLocation!.longitude) /
                2;

            // حساب مستوى التكبير بناءً على المسافة
            final double latDiff =
                (_originLocation!.latitude - _destinationLocation!.latitude)
                    .abs();
            final double lngDiff =
                (_originLocation!.longitude - _destinationLocation!.longitude)
                    .abs();
            final double maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
            final double zoom =
                maxDiff > 0.1 ? 10.0 : (maxDiff > 0.05 ? 12.0 : 14.0);

            _initialCameraPosition = CameraPosition(
              target: LatLng(avgLat, avgLng),
              zoom: zoom,
            );

            // إضافة العلامات على الخريطة
            _markers = {
              // علامة نقطة الانطلاق
              Marker(
                markerId: const MarkerId('origin'),
                position: _originLocation!,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
                infoWindow: InfoWindow(
                  title: 'نقطة الانطلاق',
                  snippet: _originName,
                ),
              ),
              // علامة الوجهة
              Marker(
                markerId: const MarkerId('destination'),
                position: _destinationLocation!,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
                infoWindow: InfoWindow(
                  title: 'الوجهة',
                  snippet: _destinationName,
                ),
              ),            };
          }
        });
        
        // تحميل معلومات المسار بين نقطة الانطلاق والوجهة
        if (_originLocation != null && _destinationLocation != null) {
          _loadDirections();
        }
      }      setState(() {
        _clientDetails = clientDetails;
        _isLoading = false;
      });
        
      // طباعة ملخص لبيانات الوجهة التي تم تحميلها
      if (_destinationLocation != null) {
        print('Client has a destination: $_destinationName at ${_destinationLocation!.latitude}, ${_destinationLocation!.longitude}');
        
        // تحميل معلومات المسار إذا كان هناك موقع للعميل والوجهة
        if (_originLocation != null || _markers.any((m) => m.markerId.value == 'clientLocation')) {
          _loadDirections();
        }
      } else {
        print('No destination found for this client');
      }
        
      // عرض تنبيه إذا لم يتم العثور على أي موقع عند طلب فتح الوجهة تلقائيًا
      if (widget.showDestinationDirectly && 
          _initialCameraPosition == null && 
          _destinationLocation == null && 
          mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لم يتم العثور على معلومات موقع أو وجهة لهذا العميل'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'فشل في تحميل بيانات العميل: \$e';
        _isLoading = false;
      });
    }
  }  // دالة تقوم بتحميل وإنشاء خط المسار بين موقع العميل والوجهة
  Future<void> _loadDirections() async {
    print('بدء تحميل المسار...');
    
    // نختار نقطة البداية إما موقع العميل أو نقطة الانطلاق
    LatLng? startLocation;
    if (_markers.any((m) => m.markerId.value == 'clientLocation')) {
      final clientMarker = _markers.firstWhere(
        (marker) => marker.markerId.value == 'clientLocation',
        orElse: () => _markers.first,
      );
      startLocation = clientMarker.position;
    } else if (_originLocation != null) {
      startLocation = _originLocation;
    }
      // تأكد من أن علامة وجهة العميل مضافة على الخريطة
    if (_destinationLocation != null && !_markers.any((m) => m.markerId.value == 'clientDestination')) {
      setState(() {
        _markers = {
          ..._markers,
          Marker(
            markerId: const MarkerId('clientDestination'),
            position: _destinationLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(
              title: 'وجهة العميل',
              snippet: _destinationName.isNotEmpty ? _destinationName : 'الوجهة',
            ),
            visible: true, // التأكد من أن العلامة مرئية
            zIndex: 2, // جعلها في الأعلى لتظهر فوق العلامات الأخرى
          ),
        };
      });
      print('✅ أضيفت علامة وجهة العميل في _loadDirections: $_destinationName');
    }
    
    // تأكد من وجود نقطة بداية ونقطة وجهة
    if (startLocation != null && _destinationLocation != null) {
      try {
        print('تحميل المسار من ${startLocation.latitude},${startLocation.longitude} إلى ${_destinationLocation!.latitude},${_destinationLocation!.longitude}');
        
        // استدعاء خدمة الاتجاهات للحصول على معلومات المسار
        final directionsService = DirectionsService();
        final directionsResult = await directionsService.getDirections(
          origin: startLocation,
          destination: _destinationLocation!,
        );

        if (directionsResult != null) {
          setState(() {
            // تحديث نص المسافة والمدة إذا كانت فارغة
            if (_distanceText.isEmpty) {
              _distanceText = directionsResult.distanceText;
            }
            if (_durationText.isEmpty) {
              _durationText = directionsResult.durationText;
            }

            // إنشاء خط المسار على الخريطة
            _polylines = {
              Polyline(
                polylineId: const PolylineId('route'),
                points: directionsResult.polylinePoints,
                color: Colors.blue,
                width: 5,
                endCap: Cap.roundCap,
                startCap: Cap.roundCap,
                geodesic: true,
              ),
            };
          });
          
          print('✅ تم تحميل معلومات المسار بنجاح: ${directionsResult.distanceText}, ${directionsResult.durationText}');
          print('✅ عدد نقاط المسار: ${directionsResult.polylinePoints.length}');
        } else {
          print('❌ لم يتم تحميل معلومات المسار - لم ترجع خدمة الاتجاهات أي نتائج');
        }
      } catch (e) {
        print('❌ خطأ أثناء تحميل معلومات المسار: $e');
      }
    } else {
      print('❌ لا يمكن تحميل المسار: نقطة البداية (${startLocation?.latitude},${startLocation?.longitude}) أو نقطة الوجهة (${_destinationLocation?.latitude},${_destinationLocation?.longitude}) غير متوفرة');
    }
  }  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      // معالجة رقم الهاتف بطريقة مختلفة لمعالجة المشكلة
      String formattedNumber = phoneNumber.trim();
      
      // حذف الأحرف الخاصة مثل المسافات والشرطات والأقواس
      formattedNumber = formattedNumber.replaceAll(RegExp(r'[\s\-)(]+'), '');
      
      // طريقة أخرى لتشكيل رابط الاتصال بدون استخدام الشكل الكامل +213
      final url = 'tel:$formattedNumber';
      final uri = Uri.parse(url);
      
      // عرض رسالة للمستخدم
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('جاري الاتصال بالرقم $formattedNumber'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
      
      print('محاولة الاتصال بالرقم: $formattedNumber عبر الرابط: $url');
      
      // استخدام طريقة أخرى للاتصال مع تحديد وضع التطبيق
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('لا يمكن الاتصال بهذا الرقم، تأكد من وجود تطبيق اتصال على جهازك'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء محاولة الاتصال: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri emailUri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن فتح تطبيق البريد الإلكتروني'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  // دالة مخصصة لإضافة علامة وجهة العميل إلى الخريطة
  void _addDestinationMarker() {
    if (_destinationLocation != null) {
      print('⭐ إضافة علامة وجهة العميل: ${_destinationLocation!.latitude}, ${_destinationLocation!.longitude}');
      setState(() {
        // إزالة أي علامات للوجهة قديمة (إذا وجدت)
        _markers.removeWhere((marker) => marker.markerId.value == 'clientDestination');
        
        // إضافة علامة الوجهة الجديدة باستخدام add للتأكد من الإضافة الصحيحة
        _markers.add(
          Marker(
            markerId: const MarkerId('clientDestination'),
            position: _destinationLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(
              title: 'وجهة العميل',
              snippet: _destinationName.isNotEmpty ? _destinationName : 'الوجهة',
            ),
            visible: true, // التأكد من أن العلامة مرئية
            zIndex: 2, // جعلها في الأعلى لتظهر فوق العلامات الأخرى
          ),
        );
        print('✅ تمت إضافة علامة وجهة العميل بنجاح. عدد العلامات الحالي: ${_markers.length}');      });
      
      // تحديث مستوى تكبير الخريطة لتشمل جميع العلامات إذا كان هناك علامتان على الأقل
      if (_markers.length >= 2 && _initialCameraPosition != null) {
        _updateCameraToFitAllMarkers();
      }
    } else {
      print('❌ لا توجد بيانات وجهة (destinationLocation) لإضافتها إلى الخريطة');
    }
  }
  
  // دالة مساعدة لتحديث موقع الكاميرا لتشمل جميع العلامات
  void _updateCameraToFitAllMarkers() {
    if (_markers.isEmpty) return;
    
    try {
      // حساب الحدود التي تشمل جميع العلامات
      double minLat = double.infinity;
      double maxLat = -double.infinity;
      double minLng = double.infinity;
      double maxLng = -double.infinity;
      
      for (final marker in _markers) {
        if (marker.position.latitude < minLat) minLat = marker.position.latitude;
        if (marker.position.latitude > maxLat) maxLat = marker.position.latitude;
        if (marker.position.longitude < minLng) minLng = marker.position.longitude;
        if (marker.position.longitude > maxLng) maxLng = marker.position.longitude;
      }
      
      // إضافة هامش للحدود
      final latPadding = (maxLat - minLat) * 0.1;
      final lngPadding = (maxLng - minLng) * 0.1;
      
      minLat -= latPadding;
      maxLat += latPadding;
      minLng -= lngPadding;
      maxLng += lngPadding;
      
      // تحديث موقع الكاميرا
      final southwest = LatLng(minLat, minLng);
      final northeast = LatLng(maxLat, maxLng);
      
      // حساب المركز الجديد
      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;
      
      // تقدير مستوى التكبير المناسب
      final latDiff = (maxLat - minLat).abs();
      final lngDiff = (maxLng - minLng).abs();
      final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
      final zoom = maxDiff > 0.1 ? 10.0 : (maxDiff > 0.05 ? 12.0 : 14.0);
      
      // تعيين موقع الكاميرا الجديد
      _initialCameraPosition = CameraPosition(
        target: LatLng(centerLat, centerLng),
        zoom: zoom,
      );
      
      print('✅ تم تحديث موقع الكاميرا ليشمل جميع العلامات. مستوى التكبير: $zoom');
    } catch (e) {
      print('❌ خطأ في تحديث موقع الكاميرا: $e');
    }
  }

  // فتح شاشة الخريطة كاملة الشاشة مع التتبع المباشر
  void _openFullScreenMap() {
    if (_originLocation == null && !_markers.any((m) => m.markerId.value == 'clientLocation')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن فتح الخريطة: موقع العميل غير متوفر'), backgroundColor: Colors.red),
      );
      return;
    }

    // تحديد نقطة البداية (موقع العميل)
    LatLng originPos;
    if (_markers.any((m) => m.markerId.value == 'clientLocation')) {
      final clientMarker = _markers.firstWhere(
        (marker) => marker.markerId.value == 'clientLocation',
        orElse: () => _markers.first,
      );
      originPos = clientMarker.position;
    } else {
      originPos = _originLocation!;
    }

    // التأكد من تحميل المسار إذا كانت الوجهة متوفرة
    if (_destinationLocation != null && _polylines.isEmpty) {
      _loadDirections();
    }

    // فتح شاشة الخريطة كاملة الشاشة
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LiveTrackingMapScreen(
          originLocation: originPos,
          originName: _originName.isEmpty ? 'موقع العميل' : _originName,
          destinationLocation: _destinationLocation,
          destinationName: _destinationName.isEmpty ? 'وجهة العميل' : _destinationName,
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    // استخدام اسم العميل في عنوان الصفحة إذا كان متاحًا
    final String clientName = _clientDetails['name'] ?? 'معلومات العميل';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(clientName),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 60,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loadClientDetails,
                        child: const Text('إعادة المحاولة'),
                      ),
                      ],
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Card
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [                                // Profile Picture with hero animation for smoother transitions and CachedNetworkImage
                                Hero(
                                  tag: 'client-profile-${widget.clientId}',
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFE9D5FF),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(50),
                                      child: _clientDetails['profilePicture'] != null && 
                                             _clientDetails['profilePicture'].toString().isNotEmpty
                                        ? Image.network(
                                            _clientDetails['profilePicture'],
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              print('Error loading profile image: $error');
                                              return const Icon(
                                                Icons.person,
                                                size: 60,
                                                color: Color(0xFF8B5CF6),
                                              );
                                            },
                                          )
                                        : const Icon(
                                            Icons.person,
                                            size: 60,
                                            color: Color(0xFF8B5CF6),
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Name with improved styling
                                Text(
                                  _clientDetails['name'] ?? 'عميل',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D3748),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                // User role badge
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE9D5FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _clientDetails['userRole'] == 'provider' ? 'مزود خدمة' : 'عميل',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF8B5CF6),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                      ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Contact Information
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'معلومات الاتصال',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF8B5CF6),
                                  ),
                                ),
                                const Divider(),
                                const SizedBox(height: 8),
                                _buildContactTile(
                                  icon: Icons.email,
                                  title: 'البريد الإلكتروني',
                                  value: _clientDetails['email'] ?? 'غير متوفر',
                                  onTap:
                                      _clientDetails['email'] != null &&
                                              _clientDetails['email'].isNotEmpty
                                          ? () =>
                                              _sendEmail(_clientDetails['email'])
                                          : null,
                                ),                                // رقم الهاتف مع تنسيق مميز
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: InkWell(
                                    onTap: _clientDetails['phone'] != null && _clientDetails['phone'].isNotEmpty
                                        ? () => _makePhoneCall(_clientDetails['phone'])
                                        : null,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF8B5CF6).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.all(8),
                                            child: const Icon(
                                              Icons.phone_android,
                                              color: Color(0xFF8B5CF6),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'رقم الهاتف',
                                                  style: TextStyle(
                                                    color: Colors.grey[700],
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Text(
                                                      _clientDetails['phone'] ?? 'غير متوفر',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.grey[900],
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    if (_clientDetails['phone'] != null && _clientDetails['phone'].isNotEmpty)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: Colors.green.withOpacity(0.2),
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: const Text(
                                                          'اضغط للاتصال',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: Colors.green,
                                                            fontWeight: FontWeight.bold,
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
                                ),
                                _buildContactTile(
                                  icon: Icons.location_on,
                                  title: 'العنوان',
                                  value: _clientDetails['address'] ?? 'غير متوفر',
                                ),                                const SizedBox(height: 16),
                                if (_clientDetails['phone'] != null && _clientDetails['phone'].toString().isNotEmpty)
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.3),
                                          spreadRadius: 1,
                                          blurRadius: 5,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton.icon(
                                      onPressed: () => _makePhoneCall(_clientDetails['phone']),
                                      icon: const Icon(Icons.phone_in_talk, color: Colors.white, size: 24),
                                      label: Text(
                                        'اتصال بالرقم ${_clientDetails['phone']}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade600,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                      ],
                            ),
                          ),
                        ),                        const SizedBox(height: 16),

                        // عرض رسالة عند عدم وجود بيانات موقع
                        if (_initialCameraPosition == null && !_hasTransportRequestData)
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.location_off,
                                    size: 50,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'لم يتم العثور على بيانات موقع لهذا العميل',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'العميل لم يشارك موقعه أو ليس لديه طلبات نقل نشطة',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),                        // إضافة قسم لموقع العميل إذا كان متاحاً
                        if (_initialCameraPosition != null && _markers.isNotEmpty && !_hasTransportRequestData)
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.person_pin_circle,
                                        color: Color(0xFF8B5CF6),
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _destinationLocation != null ? 'موقع العميل و الوجهة' : 'موقع العميل',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF8B5CF6),
                                        ),
                                      ),
                                      if (_destinationLocation != null) ...[
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade100,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.red.shade300),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.flag, color: Colors.red, size: 16),
                                              SizedBox(width: 4),
                                              Text('يريد الذهاب إلى وجهة',
                                                style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (_destinationLocation != null) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildLocationItem(
                                          icon: Icons.trip_origin,
                                          title: 'موقع العميل الحالي',
                                          value: _markers.where((m) => m.markerId.value == 'clientLocation').isNotEmpty 
                                              ? (_markers.firstWhere((m) => m.markerId.value == 'clientLocation').infoWindow.snippet ?? 'موقع العميل')
                                              : 'موقع العميل',
                                          color: Colors.green,
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.only(left: 12, top: 4, bottom: 4),
                                          child: VerticalDivider(
                                            width: 2,
                                            thickness: 2,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        _buildLocationItem(
                                          icon: Icons.flag,
                                          title: 'الوجهة المطلوبة',
                                          value: _destinationName.isNotEmpty ? _destinationName : 'وجهة العميل',
                                          color: Colors.red,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),                                ],                                // شرح العلامات على الخريطة
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_markers.any((m) => m.markerId.value == 'currentLocation'))
                                        const Row(children: [
                                          Icon(Icons.circle, color: Colors.green, size: 14),
                                          SizedBox(width: 4),
                                          Text('موقعك', style: TextStyle(fontSize: 12)),
                                          SizedBox(width: 8),
                                        ]),
                                      if (_markers.any((m) => m.markerId.value == 'clientLocation'))
                                        const Row(children: [
                                          Icon(Icons.circle, color: Colors.red, size: 14),
                                          SizedBox(width: 4),
                                          Text('موقع العميل', style: TextStyle(fontSize: 12)),
                                          SizedBox(width: 8),
                                        ]),
                                      if (_markers.any((m) => m.markerId.value == 'clientDestination'))
                                        const Row(children: [
                                          Icon(Icons.circle, color: Colors.orange, size: 14),
                                          SizedBox(width: 4),
                                          Text('وجهة العميل', style: TextStyle(fontSize: 12)),
                                        ]),
                                    ],
                                  ),
                                ),                                Container(
                                  height: 250,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.vertical(
                                      bottom: _destinationLocation == null ? Radius.circular(16) : Radius.zero,
                                    ),
                                  ),
                                  child: GoogleMap(
                                    initialCameraPosition: _initialCameraPosition!,
                                    markers: _markers,
                                    polylines: _polylines,
                                    myLocationEnabled: false,
                                    myLocationButtonEnabled: false,
                                    zoomControlsEnabled: true,
                                    mapToolbarEnabled: true,
                                    onMapCreated: (controller) {
                                      _mapController = controller;
                                    },
                                  ),
                                ),
                                if (_destinationLocation != null) ...[
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      children: [                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(double.infinity, 50),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            elevation: 3,
                                          ),
                                          onPressed: () {
                                            // Get the client's current location marker
                                            final clientMarker = _markers.firstWhere(
                                              (marker) => marker.markerId.value == 'clientLocation',
                                              orElse: () => _markers.first,
                                            );
                                            // تحميل المسار قبل عرض الاتجاهات
                                            _loadDirections();
                                            // فتح تطبيق الخرائط مع الاتجاهات
                                            _openInGoogleMaps(clientMarker.position, destination: _destinationLocation);
                                          },
                                          icon: const Icon(Icons.directions),
                                          label: const Text(
                                            'عرض طريق من الموقع إلى الوجهة',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(double.infinity, 50),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            elevation: 3,
                                          ),
                                          onPressed: _openFullScreenMap,
                                          icon: const Icon(Icons.fullscreen),
                                          label: const Text(
                                            'فتح خريطة كاملة مع تتبع المسار',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(double.infinity, 50),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            elevation: 3,
                                          ),
                                          onPressed: () => _openInGoogleMaps(_destinationLocation!),
                                          icon: const Icon(Icons.flag),
                                          label: const Text(
                                            'الملاحة إلى وجهة العميل',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(double.infinity, 50),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          onPressed: () {
                                            // Get the client location marker
                                            final clientMarker = _markers.firstWhere(
                                              (marker) => marker.markerId.value == 'clientLocation',
                                              orElse: () => _markers.first,
                                            );
                                            _openInGoogleMaps(clientMarker.position);
                                          },
                                          icon: const Icon(Icons.person_pin_circle),
                                          label: const Text(
                                            'الملاحة إلى موقع العميل',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(double.infinity, 50),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),                                      onPressed: () {
                                        // Get the first marker (client location)
                                        final clientMarker = _markers.first;
                                        _openInGoogleMaps(clientMarker.position);
                                      },
                                      icon: const Icon(Icons.navigation),
                                      label: const Text(
                                        'تتبع موقع العميل',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.purple,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(double.infinity, 50),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: _openFullScreenMap,
                                      icon: const Icon(Icons.fullscreen),
                                      label: const Text(
                                        'فتح خريطة كاملة الشاشة',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),

                        // إضافة قسم للخريطة عندما تكون بيانات النقل متاحة
                        if (_hasTransportRequestData) ...[
                          // معلومات النقل
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.local_shipping,
                                        color: const Color(0xFF8B5CF6),
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'معلومات خدمة النقل',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF8B5CF6),
                                        ),
                                      ),
                      ],
                                  ),
                                  const Divider(),
                                  const SizedBox(height: 12),

                                  // نوع المركبة والسعر
                                  if (_vehicleType.isNotEmpty || _price > 0) ...[
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (_vehicleType.isNotEmpty)
                                          _buildInfoItem(
                                            icon: Icons.directions_car,
                                            title: 'نوع المركبة',
                                            value: _vehicleType,
                                          ),
                                        if (_price > 0)
                                          _buildInfoItem(
                                            icon: Icons.attach_money,
                                            title: 'التكلفة',
                                            value: '\${_price.toStringAsFixed(2)}',
                                          ),
                      ],
                                    ),
                                    const SizedBox(height: 16),
                      ],

                                  // المسافة والمدة
                                  if (_distanceText.isNotEmpty ||
                                      _durationText.isNotEmpty) ...[
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (_distanceText.isNotEmpty)
                                          _buildInfoItem(
                                            icon: Icons.straighten,
                                            title: 'المسافة',
                                            value: _distanceText,
                                          ),
                                        if (_durationText.isNotEmpty)
                                          _buildInfoItem(
                                            icon: Icons.timelapse,
                                            title: 'المدة',
                                            value: _durationText,
                                          ),
                      ],
                                    ),
                                    const SizedBox(height: 16),
                      ],

                                  // تفاصيل نقاط الانطلاق والوصول
                                  const Text(
                                    'المسار',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildLocationItem(
                                    icon: Icons.trip_origin,
                                    title: 'نقطة الانطلاق',
                                    value: _originName,
                                    color: Colors.green,
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.only(
                                        left: 12, top: 4, bottom: 4),
                                    child: VerticalDivider(
                                      width: 2,
                                      thickness: 2,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  _buildLocationItem(
                                    icon: Icons.location_on,
                                    title: 'الوجهة',
                                    value: _destinationName,
                                    color: Colors.red,
                                  ),
                      ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // خريطة المسار
                          if (_initialCameraPosition != null) ...[
                            Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'خريطة المسار',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF8B5CF6),
                                      ),
                                    ),                                  ),                                  // شرح العلامات على الخريطة
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (_markers.any((m) => m.markerId.value == 'originLocation'))
                                          const Row(children: [
                                            Icon(Icons.circle, color: Colors.green, size: 14),
                                            SizedBox(width: 4),
                                            Text('نقطة الانطلاق', style: TextStyle(fontSize: 12)),
                                            SizedBox(width: 8),
                                          ]),
                                        if (_markers.any((m) => m.markerId.value == 'clientLocation'))
                                          const Row(children: [
                                            Icon(Icons.circle, color: Colors.red, size: 14),
                                            SizedBox(width: 4),
                                            Text('موقع العميل', style: TextStyle(fontSize: 12)),
                                            SizedBox(width: 8),
                                          ]),
                                        if (_markers.any((m) => m.markerId.value == 'clientDestination'))
                                          const Row(children: [
                                            Icon(Icons.circle, color: Colors.orange, size: 14),
                                            SizedBox(width: 4),
                                            Text('وجهة العميل', style: TextStyle(fontSize: 12)),
                                          ]),
                                      ],
                                    ),
                                  ),                                  Container(
                                    height: 250,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(16),
                                      ),
                                    ),
                                    child: GoogleMap(
                                      initialCameraPosition: _initialCameraPosition!,
                                      markers: _markers,
                                      polylines: _polylines,
                                      myLocationEnabled: false,
                                      myLocationButtonEnabled: false,
                                      zoomControlsEnabled: true,
                                      mapToolbarEnabled: true,
                                      onMapCreated: (controller) {
                                        _mapController = controller;
                                      },
                                    ),
                                  ),Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      children: [
                                        // أولا: زر لعرض الاتجاهات بين الموقع الحالي والوجهة
                                        if (_originLocation != null && _destinationLocation != null)
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue,
                                              foregroundColor: Colors.white,
                                              minimumSize: Size(double.infinity, 50),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                            onPressed: () => {
                                              // تحميل المسار قبل عرض الاتجاهات
                                              _loadDirections(),
                                              _openInGoogleMaps(_originLocation!, destination: _destinationLocation)
                                            },
                                            icon: const Icon(Icons.directions),
                                            label: const Text('عرض الطريق بين الموقعين'),
                                          ),
                                        if (_originLocation != null && _destinationLocation != null)
                                          const SizedBox(height: 8),
                                        
                                        // أزرار الموقع الفردية
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  foregroundColor: Colors.white,
                                                  minimumSize: Size(double.infinity, 50),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                ),
                                                onPressed: _originLocation != null
                                                    ? () => _openInGoogleMaps(_originLocation!)
                                                    : null,
                                                icon: const Icon(
                                                    Icons.trip_origin),
                                                label: const Text('الانطلاق'),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                  minimumSize: Size(double.infinity, 50),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                ),
                                                onPressed: _destinationLocation != null
                                                    ? () => _openInGoogleMaps(
                                                        _destinationLocation!)
                                                    : null,
                                                icon: const Icon(Icons.location_on),
                                                label: const Text('الوجهة'),
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
                      ],
                      ],                        // Action Buttons for Call and Chat
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            // Call Button
                            if (_clientDetails.containsKey('phone') &&
                                _clientDetails['phone'] != null &&
                                _clientDetails['phone'].isNotEmpty)
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4CAF50), // اللون الأخضر للإتصال
                                    foregroundColor: Colors.white,
                                    minimumSize: Size(double.infinity, 50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _makePhoneCall(_clientDetails['phone']),
                                  icon: const Icon(Icons.call),
                                  label: Text(
                                    'اتصل (${_clientDetails['phone']})',
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),

                            // Spacing between buttons
                            if (_clientDetails.containsKey('phone') &&
                                _clientDetails['phone'] != null &&
                                _clientDetails['phone'].isNotEmpty)
                              const SizedBox(width: 12),

                            // Chat Button
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B5CF6), // App's theme color
                                  foregroundColor: Colors.white,
                                  minimumSize: Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () => _startChat(),
                                icon: const Icon(Icons.chat),
                                label: const Text(
                                  'محادثة',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                      ],
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  // دالة لبدء محادثة داخل التطبيق مع العميل
  Future<void> _startChat() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يجب تسجيل الدخول لبدء محادثة'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    try {
      final chatId = await _chatService.createOrGetChat(
        userId1: currentUser.uid,
        userId2: widget.clientId,
        userName1: currentUser.displayName ?? 'مستخدم',
        userName2: _clientDetails['name'] ?? 'عميل',
        userImage1: currentUser.photoURL ?? '',
        userImage2: _clientDetails['profilePicture'] ?? '',
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              otherUserId: widget.clientId,
              otherUserName: _clientDetails['name'] ?? 'عميل',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في بدء المحادثة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // التخلص من متحكم الخريطة عند إغلاق الصفحة
    if (_mapController != null) {
      _mapController!.dispose();
    }
    super.dispose();
  }
}
