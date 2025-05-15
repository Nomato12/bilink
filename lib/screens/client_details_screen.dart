import 'package:flutter/material.dart';
import 'package:bilink/services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bilink/services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilink/utils/location_helper.dart';
import 'package:bilink/screens/chat_screen.dart';

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
  CameraPosition? _initialCameraPosition;

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
    _chatService = ChatService(_auth.currentUser?.uid ?? '');
    _loadClientDetails().then((_) async {
      // إذا كان الخيار مفعّل وهناك وجهة، افتح Google Maps مباشرة على الوجهة
      if (widget.showDestinationDirectly && _destinationLocation != null) {
        await Future.delayed(const Duration(milliseconds: 500)); // تأخير بسيط لضمان تحميل البيانات
        _openInGoogleMaps(_destinationLocation!);
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
  Future<void> _openInGoogleMaps(LatLng position) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن فتح تطبيق الخرائط'), backgroundColor: Colors.red),
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
  }

  Future<void> _loadClientDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // تحميل معلومات العميل الأساسية
      final clientDetails = await _notificationService.getClientDetails(
        widget.clientId,
      );
      
      // استخدم دالة المساعدة للحصول على موقع العميل
      GeoPoint? clientGeoPoint = LocationHelper.getLocationFromData(clientDetails);
      String clientAddress = LocationHelper.getAddressFromData(clientDetails);
      bool isLocationRecent = LocationHelper.isLocationRecent(clientDetails);
      
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
      } else {
        // إذا لم يتم العثور على موقع في بيانات العميل، نحاول الحصول عليه من تخزين المواقع المنفصل
        print('Looking for client location in dedicated location storage');
        final locationData = await LocationHelper.getClientLocationData(widget.clientId);
        
        if (locationData != null) {
          print('Client location found in dedicated storage: $locationData');
          
          // معالجة بيانات الموقع الأساسي (نقطة الانطلاق)
          if (locationData.containsKey('originLocation') && locationData['originLocation'] is GeoPoint) {
            final originGeoPoint = locationData['originLocation'] as GeoPoint;
            final originLocation = LatLng(originGeoPoint.latitude, originGeoPoint.longitude);
            final originName = locationData['originName'] ?? 'موقع العميل';
            
            // تعيين نقطة الانطلاق كموقع العميل الافتراضي
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
            
            // إذا كانت هناك وجهة، نضيفها أيضًا
            if (locationData.containsKey('destinationLocation') && locationData['destinationLocation'] is GeoPoint) {
              final destGeoPoint = locationData['destinationLocation'] as GeoPoint;
              final destLocation = LatLng(destGeoPoint.latitude, destGeoPoint.longitude);
              final destName = locationData['destinationName'] ?? 'وجهة العميل';
              
              // حفظ معلومات النقل والموقع
              _hasTransportRequestData = true;
              _originLocation = originLocation;
              _destinationLocation = destLocation;
              _originName = originName;
              _destinationName = destName;
              
              // إذا كانت هناك معلومات إضافية، نحفظها أيضًا
              if (locationData.containsKey('distanceText')) _distanceText = locationData['distanceText'];
              if (locationData.containsKey('durationText')) _durationText = locationData['durationText'];
              
              // إضافة علامة للوجهة
              setState(() {
                _markers = {
                  ..._markers,
                  Marker(
                    markerId: const MarkerId('destination'),
                    position: destLocation,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    infoWindow: InfoWindow(
                      title: 'وجهة العميل',
                      snippet: destName,
                    ),
                  ),
                };
              });
            }          }
        } else if (clientDetails.containsKey('location') && clientDetails['location'] != null) {
          // الكود الأصلي للتعامل مع بيانات الموقع المدمجة في تفاصيل العميل
          var locationData = clientDetails['location'];
          print('Client location data found directly: $locationData');
          
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
      }
        // تحميل معلومات طلب النقل الخاص بالعميل (إن وجد)
      final transportDetails = await _notificationService
          .getClientTransportRequestDetails(widget.clientId);

      if (transportDetails['hasLocationData'] == true) {
        // استخراج معلومات النقل
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
          }

          if (transportDetails.containsKey('destinationLocation')) {
            final destMap =
                transportDetails['destinationLocation'] as Map<String, dynamic>;
            _destinationLocation = LatLng(
              destMap['latitude'] as double,
              destMap['longitude'] as double,
            );
          }

          // معلومات إضافية
          _originName = transportDetails['originName'] ?? 'نقطة الانطلاق';
          _destinationName = transportDetails['destinationName'] ?? 'الوجهة';
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
            print('Error converting price: \$e');
            _price = 0.0;
          }

          _vehicleType = transportDetails['vehicleType'] ?? '';

          // إعداد موقع الكاميرا الأولي على الخريطة
          if (_originLocation != null && _destinationLocation != null) {
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
              ),
            };
          }
        });
      }      setState(() {
        _clientDetails = clientDetails;
        _isLoading = false;
      });
        // عرض تنبيه إذا لم يتم العثور على أي موقع عند طلب فتح الوجهة تلقائيًا
      if (widget.showDestinationDirectly && 
          _initialCameraPosition == null && 
          !_hasTransportRequestData && 
          mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لم يتم العثور على معلومات موقع أو طلب نقل لهذا العميل'),
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
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن الاتصال بهذا الرقم'),
            backgroundColor: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('معلومات العميل'),
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
                              children: [
                                // Profile Picture
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: const Color(0xFFE9D5FF),
                                  backgroundImage:
                                      _clientDetails['profilePicture'] != null &&
                                              _clientDetails['profilePicture']
                                                  .isNotEmpty
                                          ? NetworkImage(
                                              _clientDetails['profilePicture'],
                                            )
                                          : null,
                                  child:
                                      _clientDetails['profilePicture'] == null ||
                                              _clientDetails['profilePicture']
                                                  .isEmpty
                                          ? const Icon(
                                              Icons.person,
                                              size: 60,
                                              color: Color(0xFF8B5CF6),
                                            )
                                          : null,
                                ),
                                const SizedBox(height: 16),
                                // Name
                                Text(
                                  _clientDetails['name'] ?? 'عميل',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
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
                                ),
                                _buildContactTile(
                                  icon: Icons.phone,
                                  title: 'رقم الهاتف',
                                  value: _clientDetails['phone'] ?? 'غير متوفر',
                                  onTap:
                                      _clientDetails['phone'] != null &&
                                              _clientDetails['phone'].isNotEmpty
                                          ? () => _makePhoneCall(
                                                _clientDetails['phone'],
                                              )
                                          : null,
                                ),
                                _buildContactTile(
                                  icon: Icons.location_on,
                                  title: 'العنوان',
                                  value: _clientDetails['address'] ?? 'غير متوفر',
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
                          ),

                        // إضافة قسم لموقع العميل إذا كان متاحاً
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
                                  child: Text(
                                    'موقع العميل',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF8B5CF6),
                                    ),
                                  ),
                                ),
                                Container(
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
                                    myLocationEnabled: false,
                                    myLocationButtonEnabled: false,
                                    zoomControlsEnabled: true,
                                    mapToolbarEnabled: true,
                                    onMapCreated: (controller) {},
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      minimumSize: Size(double.infinity, 50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () {
                                      // Get the first marker (client location)
                                      final clientMarker = _markers.first;
                                      _openInGoogleMaps(clientMarker.position);
                                    },                                    icon: const Icon(Icons.navigation),
                                    label: const Text(
                                      'تتبع موقع العميل',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
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
                                    ),
                                  ),
                                  Container(
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
                                      myLocationEnabled: false,
                                      myLocationButtonEnabled: false,
                                      zoomControlsEnabled: true,
                                      mapToolbarEnabled: true,
                                      onMapCreated: (controller) {},
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
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
                                  ),
                      ],
                              ),
                            ),
                      ],
                      ],

                        // Action Buttons for WhatsApp and Chat
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            // WhatsApp Button
                            if (_clientDetails.containsKey('phone') &&
                                _clientDetails['phone'] != null &&
                                _clientDetails['phone'].isNotEmpty)
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366), // WhatsApp color
                                    foregroundColor: Colors.white,
                                    minimumSize: Size(double.infinity, 50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _openWhatsApp(_clientDetails['phone']),
                                  icon: const Icon(Icons.message),
                                  label: const Text(
                                    'واتساب',
                                    style: TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold),
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
}
