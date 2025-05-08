import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async'; // Importando dart:async para usar Timer
import '../services/auth_service.dart';

// Controlador personalizado para el carrusel de imágenes
class CustomCarouselController {
  Function? _nextPage;
  Function? _previousPage;

  void setCallbacks(Function nextPage, Function previousPage) {
    _nextPage = nextPage;
    _previousPage = previousPage;
  }

  void nextPage() {
    if (_nextPage != null) {
      _nextPage!();
    }
  }

  void previousPage() {
    if (_previousPage != null) {
      _previousPage!();
    }
  }
}

// Widget de carrusel personalizado
class CustomImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final double height;
  final bool autoPlay;
  final Duration autoPlayInterval;
  final Function(int)? onPageChanged;
  final CustomCarouselController? controller;

  const CustomImageCarousel({
    super.key,
    required this.imageUrls,
    this.height = 300.0,
    this.autoPlay = false,
    this.autoPlayInterval = const Duration(seconds: 5),
    this.onPageChanged,
    this.controller,
  });

  @override
  _CustomImageCarouselState createState() => _CustomImageCarouselState();
}

class _CustomImageCarouselState extends State<CustomImageCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Configurar el controlador si se proporciona
    if (widget.controller != null) {
      widget.controller!.setCallbacks(
        () => _goToNextPage(),
        () => _goToPreviousPage(),
      );
    }

    // Iniciar reproducción automática si está habilitada
    if (widget.autoPlay && widget.imageUrls.length > 1) {
      _startAutoPlay();
    }
  }

  void _startAutoPlay() {
    _timer = Timer.periodic(widget.autoPlayInterval, (timer) {
      if (_currentPage < widget.imageUrls.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _goToNextPage() {
    if (_currentPage < widget.imageUrls.length - 1) {
      _currentPage++;
    } else {
      _currentPage = 0;
    }

    if (_pageController.hasClients) {
      _pageController.animateToPage(
        _currentPage,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPreviousPage() {
    if (_currentPage > 0) {
      _currentPage--;
    } else {
      _currentPage = widget.imageUrls.length - 1;
    }

    if (_pageController.hasClients) {
      _pageController.animateToPage(
        _currentPage,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          // Carrusel de imágenes
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });

              if (widget.onPageChanged != null) {
                widget.onPageChanged!(index);
              }
            },
            itemBuilder: (context, index) {
              final imageUrl = widget.imageUrls[index];
              return CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder:
                    (context, url) => Container(
                      color: Colors.grey[300],
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF9B59B6),
                          ),
                        ),
                      ),
                    ),
                errorWidget:
                    (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 40,
                              color: Colors.red,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'خطأ في تحميل الصورة',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                    ),
              );
            },
          ),

          // Indicadores de página
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.imageUrls.length,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          _currentPage == index
                              ? Colors.white
                              : Colors.white.withOpacity(0.4),
                    ),
                  ),
                ),
              ),
            ),

          // Botones de navegación
          if (widget.imageUrls.length > 1) ...[
            Positioned(
              left: 10,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _goToPreviousPage,
                child: Container(
                  width: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.transparent,
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: Center(
                    child: Icon(Icons.arrow_back_ios, color: Colors.white),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _goToNextPage,
                child: Container(
                  width: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: Center(
                    child: Icon(Icons.arrow_forward_ios, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ServiceDetailsScreen extends StatefulWidget {
  final String serviceId;

  const ServiceDetailsScreen({super.key, required this.serviceId});

  @override
  _ServiceDetailsScreenState createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _serviceData;
  int _currentImageIndex = 0;
  final CustomCarouselController _carouselController =
      CustomCarouselController();

  // Controller para el mapa
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadServiceDetails();
  }

  Future<void> _loadServiceDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final docSnapshot =
          await FirebaseFirestore.instance
              .collection('services')
              .doc(widget.serviceId)
              .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        data['id'] = docSnapshot.id;

        // Si hay datos de ubicación, configurar el marcador del mapa
        if (data.containsKey('location') &&
            data['location'] != null &&
            data['location']['latitude'] != null &&
            data['location']['longitude'] != null) {
          final location = data['location'];
          final latLng = LatLng(location['latitude'], location['longitude']);

          _markers = {
            Marker(
              markerId: MarkerId('serviceLocation'),
              position: latLng,
              infoWindow: InfoWindow(
                title: data['title'] ?? 'موقع الخدمة',
                snippet: location['address'] ?? '',
              ),
            ),
          };
        }

        // Cargar información del proveedor
        if (data.containsKey('userId') || data.containsKey('providerId')) {
          final providerId = data['userId'] ?? data['providerId'];
          if (providerId != null) {
            final providerDoc =
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(providerId)
                    .get();

            if (providerDoc.exists) {
              final providerData = providerDoc.data() as Map<String, dynamic>;
              data['providerData'] = providerData;
            }
          }
        }

        setState(() {
          _serviceData = data;
          _isLoading = false;
        });
      } else {
        // Servicio no encontrado
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('الخدمة غير موجودة')));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print('Error loading service details: $e');

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تحميل تفاصيل الخدمة')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_serviceData?['title'] ?? 'تفاصيل الخدمة'),
        backgroundColor: Color(0xFF9B59B6),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              // Implementar compartir
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('جاري تطوير ميزة المشاركة')),
              );
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(color: Color(0xFF9B59B6)),
              )
              : _buildServiceDetails(),
    );
  }

  Widget _buildServiceDetails() {
    if (_serviceData == null) {
      return Center(
        child: Text('لا توجد بيانات متاحة', style: TextStyle(fontSize: 18)),
      );
    }

    final type = _serviceData!['type'] ?? 'غير محدد';
    final region = _serviceData!['region'] ?? 'غير محدد';
    final description = _serviceData!['description'] ?? '';
    final price = (_serviceData!['price'] as num?)?.toDouble() ?? 0.0;
    final currency = _serviceData!['currency'] ?? 'دينار جزائري';
    final rating = (_serviceData!['rating'] as num?)?.toDouble() ?? 0.0;
    final reviewCount = (_serviceData!['reviewCount'] as num?)?.toInt() ?? 0;
    final List<dynamic> imageUrls = _serviceData!['imageUrls'] ?? [];

    // Extract location and vehicle information
    final Map<String, dynamic>? locationInfo =
        _serviceData!.containsKey('location')
            ? _serviceData!['location'] as Map<String, dynamic>?
            : null;

    final Map<String, dynamic>? vehicleInfo =
        type == 'نقل' && _serviceData!.containsKey('vehicle')
            ? _serviceData!['vehicle'] as Map<String, dynamic>?
            : null;

    // Extract provider information
    final Map<String, dynamic>? providerInfo =
        _serviceData!.containsKey('providerData')
            ? _serviceData!['providerData'] as Map<String, dynamic>?
            : null;

    final typeColor = type == 'تخزين' ? Colors.blue : Colors.red;
    final typeIcon = type == 'تخزين' ? Icons.warehouse : Icons.local_shipping;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imágenes del servicio en carrusel (Modificado para mejor manejo de errores)
          imageUrls.isNotEmpty
              ? Stack(
                children: [
                  CustomImageCarousel(
                    imageUrls: List<String>.from(imageUrls),
                    height: 300,
                    autoPlay: imageUrls.length > 1,
                    controller: _carouselController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentImageIndex = index;
                      });
                    },
                  ),
                  // Tipo de servicio
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(typeIcon, color: typeColor, size: 16),
                          SizedBox(width: 4),
                          Text(
                            type,
                            style: TextStyle(
                              color: typeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
              : Container(
                height: 250,
                color: Colors.grey[300],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(typeIcon, size: 80, color: Colors.grey[400]),
                      SizedBox(height: 10),
                      Text(
                        'لا توجد صور متاحة',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

          // Información del servicio
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título y valoración
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _serviceData!['title'] ?? 'خدمة بدون عنوان',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),
                    if (reviewCount > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Text(
                                rating.toStringAsFixed(1),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.star, color: Colors.amber, size: 20),
                            ],
                          ),
                          Text(
                            '$reviewCount تقييم',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                SizedBox(height: 12),

                // Precio y ubicación
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      // Precio
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.attach_money,
                                  size: 18,
                                  color: Color(0xFF9B59B6),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'السعر',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              '$price $currency',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF9B59B6),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Separador vertical
                      Container(height: 40, width: 1, color: Colors.grey[300]),

                      // Ubicación
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'المنطقة',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Text(
                                region,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // Descripción
                Text(
                  'الوصف',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.grey[800],
                  ),
                ),

                SizedBox(height: 24),

                // Información específica según el tipo de servicio
                if (type == 'تخزين') ...[
                  _buildStorageInfo(locationInfo),
                ] else if (type == 'نقل' && vehicleInfo != null) ...[
                  _buildTransportInfo(vehicleInfo, locationInfo),
                ],

                SizedBox(height: 24),

                // Información del proveedor
                _buildProviderInfo(providerInfo),

                SizedBox(height: 32),

                // Botón de solicitud de servicio
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      _showRequestServiceDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF9B59B6),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'طلب الخدمة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget para información de servicios de almacenamiento
  Widget _buildStorageInfo(Map<String, dynamic>? locationInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'معلومات مكان التخزين',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        SizedBox(height: 16),

        // Mapa de ubicación si hay datos
        if (locationInfo != null &&
            locationInfo['latitude'] != null &&
            locationInfo['longitude'] != null) ...[
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    locationInfo['latitude'],
                    locationInfo['longitude'],
                  ),
                  zoom: 14,
                ),
                markers: _markers,
                onMapCreated: (controller) {
                  _mapController = controller;
                },
                myLocationEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
              ),
            ),
          ),
          if (locationInfo['address'] != null &&
              locationInfo['address'].toString().isNotEmpty) ...[
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    locationInfo['address'],
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 16),
          // Botón para direcciones
          OutlinedButton.icon(
            onPressed: () {
              _launchMapsUrl(
                locationInfo['latitude'],
                locationInfo['longitude'],
              );
            },
            icon: Icon(Icons.directions, color: Colors.blue),
            label: Text('الحصول على الاتجاهات'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: BorderSide(color: Colors.blue),
            ),
          ),
        ] else ...[
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey[600]),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'لم يتم تحديد موقع مكان التخزين. يرجى التواصل مع مزود الخدمة للحصول على التفاصيل.',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Características del almacenamiento
        SizedBox(height: 16),
        if (_serviceData!.containsKey('storageFeatures')) ...[
          _buildFeaturesList(_serviceData!['storageFeatures']),
        ],
      ],
    );
  }

  // Widget para información de servicios de transporte
  Widget _buildTransportInfo(
    Map<String, dynamic> vehicleInfo,
    Map<String, dynamic>? locationInfo,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'معلومات المركبة',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        SizedBox(height: 16),

        // Detalles del vehículo
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              // Tipo y marca de vehículo
              _buildInfoRow(
                'نوع المركبة',
                '${vehicleInfo['make'] ?? ''} ${vehicleInfo['type'] ?? ''}',
                Icons.local_shipping,
              ),

              if (vehicleInfo['year'] != null) ...[
                SizedBox(height: 12),
                _buildInfoRow(
                  'سنة الصنع',
                  vehicleInfo['year'],
                  Icons.date_range,
                ),
              ],

              if (vehicleInfo['plate'] != null) ...[
                SizedBox(height: 12),
                _buildInfoRow(
                  'رقم اللوحة',
                  vehicleInfo['plate'],
                  Icons.confirmation_number,
                ),
              ],

              if (vehicleInfo['capacity'] != null) ...[
                SizedBox(height: 12),
                _buildInfoRow(
                  'قدرة الحمولة',
                  vehicleInfo['capacity'],
                  Icons.line_weight,
                ),
              ],

              if (vehicleInfo['dimensions'] != null) ...[
                SizedBox(height: 12),
                _buildInfoRow(
                  'الأبعاد',
                  vehicleInfo['dimensions'],
                  Icons.straighten,
                ),
              ],
            ],
          ),
        ),

        // Características especiales
        if (vehicleInfo['specialFeatures'] != null &&
            vehicleInfo['specialFeatures'].toString().isNotEmpty) ...[
          SizedBox(height: 16),
          Text(
            'ميزات خاصة',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF555555),
            ),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              vehicleInfo['specialFeatures'],
              style: TextStyle(fontSize: 14, color: Colors.grey[800]),
            ),
          ),
        ],

        // Imágenes del vehículo (Mejorado el manejo de errores)
        if (vehicleInfo['imageUrls'] != null &&
            vehicleInfo['imageUrls'] is List &&
            (vehicleInfo['imageUrls'] as List).isNotEmpty) ...[
          SizedBox(height: 24),
          Text(
            'صور المركبة',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF555555),
            ),
          ),
          SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: (vehicleInfo['imageUrls'] as List).length,
              itemBuilder: (context, index) {
                final url = (vehicleInfo['imageUrls'] as List)[index];
                return Container(
                  width: 100,
                  margin: EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder:
                          (context, url) => Container(
                            color: Colors.grey[300],
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF9B59B6),
                                ),
                              ),
                            ),
                          ),
                      errorWidget:
                          (context, url, error) => Container(
                            color: Colors.grey[300],
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red[300],
                                  size: 24,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'خطأ',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  // Widget para información del proveedor
  Widget _buildProviderInfo(Map<String, dynamic>? providerInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'معلومات مزود الخدمة',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        SizedBox(height: 16),

        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar del proveedor
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Color(0xFF9B59B6).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(Icons.person, size: 30, color: Color(0xFF9B59B6)),
                ),
              ),
              SizedBox(width: 16),

              // Información del proveedor
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      providerInfo != null && providerInfo['fullName'] != null
                          ? providerInfo['fullName']
                          : 'مزود خدمة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (providerInfo != null &&
                        providerInfo['companyName'] != null &&
                        providerInfo['companyName'].toString().isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        providerInfo['companyName'],
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 16, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'اتصال',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 16),
                        Icon(Icons.message, size: 16, color: Colors.blue),
                        SizedBox(width: 4),
                        Text(
                          'رسالة',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Indicador de verificación
              if (providerInfo != null && providerInfo['isVerified'] == true)
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.verified, color: Colors.green, size: 20),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Fila para información en formato clave-valor
  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF9B59B6).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: Color(0xFF9B59B6)),
        ),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  // Lista de características
  Widget _buildFeaturesList(Map<String, dynamic> features) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          features.entries.map((entry) {
            final bool isActive = entry.value == true;
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    isActive
                        ? Color(0xFF9B59B6).withOpacity(0.1)
                        : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      isActive
                          ? Color(0xFF9B59B6).withOpacity(0.3)
                          : Colors.grey[300]!,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isActive ? Icons.check_circle : Icons.cancel,
                    size: 16,
                    color: isActive ? Color(0xFF9B59B6) : Colors.grey,
                  ),
                  SizedBox(width: 4),
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive ? Color(0xFF9B59B6) : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  // Abrir Google Maps con la ubicación
  void _launchMapsUrl(double latitude, double longitude) async {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('لا يمكن فتح خرائط Google')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    }
  }

  // Mostrar diálogo de solicitud de servicio
  void _showRequestServiceDialog() {
    final authService = Provider.of<AuthService>(context, listen: false);

    // Verificar si el usuario está autenticado
    if (authService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يجب تسجيل الدخول لطلب الخدمة'),
          action: SnackBarAction(
            label: 'تسجيل الدخول',
            onPressed: () {
              // Navegar a la pantalla de inicio de sesión
              Navigator.pushNamed(context, '/login');
            },
          ),
        ),
      );
      return;
    }

    // Variables para el formulario
    final TextEditingController detailsController = TextEditingController();
    final TextEditingController dateController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.send_rounded, color: Color(0xFF9B59B6)),
                    SizedBox(width: 8),
                    Text('طلب الخدمة'),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'يرجى تقديم التفاصيل المطلوبة لطلب هذه الخدمة',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      SizedBox(height: 16),

                      // Campo de fecha
                      TextField(
                        controller: dateController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'التاريخ المطلوب',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        onTap: () async {
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(Duration(days: 1)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(Duration(days: 90)),
                          );

                          if (pickedDate != null) {
                            setState(() {
                              selectedDate = pickedDate;
                              dateController.text =
                                  '${pickedDate.day}/${pickedDate.month}/${pickedDate.year}';
                            });
                          }
                        },
                      ),
                      SizedBox(height: 16),

                      // Campo de detalles
                      TextField(
                        controller: detailsController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'تفاصيل الطلب',
                          hintText:
                              'اكتب هنا أي تفاصيل إضافية تود إضافتها للطلب...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Validar los campos
                      if (selectedDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('يرجى اختيار التاريخ المطلوب'),
                          ),
                        );
                        return;
                      }

                      // Enviar solicitud (aquí se implementaría la lógica real)
                      Navigator.pop(context);

                      // Mostrar mensaje de éxito
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'تم إرسال طلبك بنجاح! سيتصل بك مزود الخدمة قريبًا.',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF9B59B6),
                    ),
                    child: Text('إرسال الطلب'),
                  ),
                ],
              );
            },
          ),
    );
  }
}
