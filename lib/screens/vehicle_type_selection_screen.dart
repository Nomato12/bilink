import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bilink/screens/nearby_vehicles_map.dart';  // استيراد صفحة المركبات القريبة
import 'package:geolocator/geolocator.dart';

class VehicleTypeSelectionScreen extends StatefulWidget {
  final LatLng originLocation;
  final String originName;
  final LatLng destinationLocation;
  final String destinationName;
  final double? routeDistance;  // المسافة الحقيقية على الطريق بالكيلومتر
  final double? routeDuration;  // الوقت المتوقع بالدقائق
  final String? distanceText;  // نص المسافة
  final String? durationText;  // نص الوقت المتوقع
  
  const VehicleTypeSelectionScreen({
    super.key,
    required this.originLocation,
    required this.originName,
    required this.destinationLocation,
    required this.destinationName,
    this.routeDistance,
    this.routeDuration,
    this.distanceText,
    this.durationText,
  });

  @override
  State<VehicleTypeSelectionScreen> createState() => _VehicleTypeSelectionScreenState();
}

class _VehicleTypeSelectionScreenState extends State<VehicleTypeSelectionScreen> {
  double _distanceInKm = 0.0;
  bool _isCalculatingDistance = true;

  @override
  void initState() {
    super.initState();
    _calculateDistance();
  }
  // حساب المسافة بين نقطتي الانطلاق والوصول
  void _calculateDistance() async {
    setState(() {
      _isCalculatingDistance = true;
    });
    
    // استخدام المسافة الحقيقية على الطريق إذا كانت متوفرة
    if (widget.routeDistance != null && widget.routeDistance! > 0) {
      _distanceInKm = widget.routeDistance!;
      // تقريب المسافة إلى رقمين عشريين
      _distanceInKm = double.parse(_distanceInKm.toStringAsFixed(2));
      setState(() {
        _isCalculatingDistance = false;
      });
      return;
    }
    
    // فالباك إلى المسافة المباشرة إذا لم تكن المسافة الحقيقية متوفرة
    _distanceInKm = Geolocator.distanceBetween(
      widget.originLocation.latitude,
      widget.originLocation.longitude,
      widget.destinationLocation.latitude,
      widget.destinationLocation.longitude,
    ) / 1000; // تحويل المسافة من متر إلى كيلومتر
    
    // تقريب المسافة إلى رقمين عشريين
    _distanceInKm = double.parse(_distanceInKm.toStringAsFixed(2));
    
    setState(() {
      _isCalculatingDistance = false;
    });
  }  // حساب السعر بناء على المسافة ونوع المركبة
  String _calculatePriceEstimate(VehicleTypeOption vehicleType) {
    if (_isCalculatingDistance) {
      return 'جاري الحساب...';
    }
    
    double price = vehicleType.minPricePerKm * _distanceInKm;
    
    // تقريب السعر إلى أقرب عدد صحيح
    price = price.roundToDouble();
    
    return '${price.toInt()} دج';
  }
  
  // الحصول على السعر كرقم للاستخدام في معالجة الطلب
  double _getNumericPrice(VehicleTypeOption vehicleType) {
    if (_isCalculatingDistance) {
      return 0.0;
    }
    
    double price = vehicleType.minPricePerKm * _distanceInKm;
    return price.roundToDouble();
  }
  // نفس أنواع المركبات المستخدمة في شاشة إضافة الخدمة
  final List<VehicleTypeOption> _vehicleTypes = [
    VehicleTypeOption(
      name: 'شاحنة صغيرة',
      icon: Icons.local_shipping,
      description: 'مناسبة للحمولات الخفيفة والمتوسطة',
      color: Colors.blue,
      minPricePerKm: 60,
      maxPricePerKm: 60,
    ),
    VehicleTypeOption(
      name: 'شاحنة متوسطة',
      icon: Icons.local_shipping,
      description: 'مناسبة للحمولات المتوسطة والكبيرة',
      color: Colors.green,
      minPricePerKm: 80,
      maxPricePerKm: 80,
    ),
    VehicleTypeOption(
      name: 'شاحنة كبيرة',
      icon: Icons.fire_truck,
      description: 'مناسبة للحمولات الثقيلة والكبيرة',
      color: Colors.orange,
      minPricePerKm: 110,
      maxPricePerKm: 110,
    ),
    VehicleTypeOption(
      name: 'مركبة خفيفة',
      icon: Icons.directions_car,
      description: 'مناسبة للطرود والحمولات الصغيرة',
      color: Colors.purple,
      minPricePerKm: 40,
      maxPricePerKm: 40,
    ),
    VehicleTypeOption(
      name: 'دراجة نارية',
      icon: Icons.motorcycle,
      description: 'مناسبة للتوصيل السريع للطرود الصغيرة',
      color: Colors.red,
      minPricePerKm: 30,
      maxPricePerKm: 30,
    ),
  ];

  String? _selectedVehicleType;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختر نوع المركبة'),
        backgroundColor: const Color(0xFF0B3D91),
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.blue.shade50,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // عنوان الصفحة والشرح
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.local_shipping_outlined,
                    size: 48,
                    color: Color(0xFF0B3D91),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ما نوع المركبة الذي تحتاجه؟',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B3D91),
                    ),                  ),
                  const SizedBox(height: 8),
                  Text(
                    'اختر نوع المركبة المناسب لحمولتك',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B3D91).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.route,
                              color: Color(0xFF0B3D91),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'المسافة: ${_isCalculatingDistance ? 'جاري الحساب...' : widget.distanceText ?? '$_distanceInKm كم'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0B3D91),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.durationText != null) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00A651).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.access_time,
                                color: Color(0xFF00A651),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'الوقت: ${widget.durationText}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00A651),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // قائمة أنواع المركبات
            Expanded(
              child: ListView.builder(
                itemCount: _vehicleTypes.length,
                itemBuilder: (context, index) {
                  final vehicleType = _vehicleTypes[index];
                  final isSelected = vehicleType.name == _selectedVehicleType;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedVehicleType = vehicleType.name;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? vehicleType.color.withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? vehicleType.color : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: vehicleType.color.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                vehicleType.icon,
                                size: 32,
                                color: vehicleType.color,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,                                children: [                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          vehicleType.name,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? vehicleType.color : Colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    vehicleType.description,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: vehicleType.color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.payments_outlined,
                                          color: vehicleType.color,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'السعر: ${_calculatePriceEstimate(vehicleType)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: vehicleType.color,
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: vehicleType.color,
                                size: 28,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // زر بحث عن المركبات
            ElevatedButton(              onPressed: _selectedVehicleType == null
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NearbyVehiclesMap(
                            originLocation: widget.originLocation,
                            originName: widget.originName,
                            destinationLocation: widget.destinationLocation,
                            destinationName: widget.destinationName,
                            selectedVehicleType: _selectedVehicleType!,
                            routeDistance: widget.routeDistance,
                            routeDuration: widget.routeDuration,
                            distanceText: widget.distanceText,
                            durationText: widget.durationText,
                          ),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B3D91),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: Text(
                'البحث عن المركبات (${_selectedVehicleType ?? 'اختر نوع المركبة أولاً'})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VehicleTypeOption {
  final String name;
  final IconData icon;
  final String description;
  final Color color;
  final double minPricePerKm; // السعر الأدنى للكيلومتر
  final double maxPricePerKm; // السعر الأعلى للكيلومتر
  
  VehicleTypeOption({
    required this.name,
    required this.icon,
    required this.description,
    required this.color,
    required this.minPricePerKm,
    required this.maxPricePerKm,
  });
}
