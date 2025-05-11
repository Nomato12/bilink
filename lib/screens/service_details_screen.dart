import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async'; // Importando dart:async para usar Timer
import 'package:bilink/services/auth_service.dart';
import 'package:bilink/services/chat_service.dart'; // Añadir importación de chat_service
import 'package:bilink/screens/chat_screen.dart'; // Añadir importación de chat_screen
import 'package:bilink/services/notification_service.dart'; // Importar el servicio de notificaciones
import 'package:bilink/screens/fullscreen_image_viewer.dart'; // لعرض الصور بملء الشاشة
import 'package:bilink/screens/service_details_fix.dart'; // Import our fix for image handling
import 'package:bilink/screens/directions_map_screen_simple.dart'; // إضافة استيراد شاشة خريطة الاتجاهات البسيطة
import 'package:bilink/screens/directions_map_tracking.dart'; // إضافة استيراد شاشة خريطة التتبع في الوقت الفعلي
import 'package:bilink/screens/transport_map_fix.dart'; // Import utility functions for location handling

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

    // Debug: Print received image URLs
    print(
      "CustomImageCarousel received ${widget.imageUrls.length} images: ${widget.imageUrls}",
    );

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

  // فتح عارض الصور بملء الشاشة
  void _openFullScreenImageViewer(BuildContext context, int index) {
    // إيقاف التشغيل التلقائي مؤقتًا عند فتح الصورة بملء الشاشة
    _timer?.cancel();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => FullScreenImageViewer(
              imageUrls: widget.imageUrls,
              initialIndex: index,
            ),
      ),
    ).then((_) {
      // إعادة تشغيل التشغيل التلقائي بعد العودة من عرض الشاشة الكاملة
      if (widget.autoPlay && widget.imageUrls.length > 1) {
        _startAutoPlay();
      }
    });
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
    // Debug print showing how many images the carousel has
    print(
      'CustomImageCarousel build with ${widget.imageUrls.length} images: ${widget.imageUrls}',
    );

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
            itemBuilder: (context, index) {              final imageUrl = widget.imageUrls[index];
              print('Building image at index $index: $imageUrl');
              
              // تحقق أن URL الصورة سليم
              bool isValidUrl = imageUrl.isNotEmpty && 
                  (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));
              
              if (!isValidUrl) {
                return Container(
                  color: Colors.grey[300],
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          size: 40,
                          color: Colors.grey[600],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'رابط الصورة غير صالح',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              return GestureDetector(
                onTap: () => _openFullScreenImageViewer(context, index),
                child: Hero(
                  tag: 'image-$index-${widget.imageUrls.hashCode}',                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF9B59B6),
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
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
  final int _currentImageIndex = 0;
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
        data['id'] = docSnapshot.id;        // استخدام الدالة المساعدة لاستخراج بيانات الموقع بشكل آمن
        final serviceLocation = safeGetLatLng(data['location'] as Map<String, dynamic>?);
        if (serviceLocation != null) {
          final locationAddress = safeGetAddress(data['location'] as Map<String, dynamic>?, '');
          
          _markers = {
            Marker(
              markerId: MarkerId('serviceLocation'),
              position: serviceLocation,
              infoWindow: InfoWindow(
                title: data['title'] ?? 'موقع الخدمة',
                snippet: locationAddress,
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

        // Print debug information for imageUrls
        if (data.containsKey('imageUrls')) {
          print(
            'ServiceDetailsScreen: Service ${widget.serviceId} has ${(data['imageUrls'] as List?)?.length ?? 0} images: ${data['imageUrls']}',
          );
        } else {
          print(
            'ServiceDetailsScreen: Service ${widget.serviceId} has no imageUrls field',
          );
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _serviceData?['title'] ?? 'تفاصيل الخدمة',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('جاري تطوير ميزة المشاركة')),
              );
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF8B5CF6),
                        ),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'جاري تحميل تفاصيل الخدمة...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
              )
              : _buildServiceDetails(),
      floatingActionButton:
          _serviceData != null
              ? FloatingActionButton.extended(
                onPressed: () => _showRequestServiceDialog(),
                backgroundColor: Color(0xFF8B5CF6),
                icon: const Icon(Icons.send_rounded),
                label: const Text(
                  'طلب الخدمة',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                elevation: 3,
              )
              : null,
    );
  }

  Widget _buildServiceDetails() {
    final type = _serviceData!['type'] ?? 'غير محدد';
    final region = _serviceData!['region'] ?? 'غير محدد';
    final description = _serviceData!['description'] ?? '';
    final price = (_serviceData!['price'] as num?)?.toDouble() ?? 0.0;
    final currency = _serviceData!['currency'] ?? 'دينار جزائري';
    final rating = (_serviceData!['rating'] as num?)?.toDouble() ?? 0.0;
    final reviewCount = (_serviceData!['reviewCount'] as num?)?.toInt() ?? 0;    // جمع جميع الصور المتاحة للخدمة
    List<String> imageUrls = [];    try {
      // إضافة الصور الرئيسية للخدمة
      if (_serviceData!['imageUrls'] != null && _serviceData!['imageUrls'] is List) {
        // تحويل القائمة بأمان وفلترة أي قيم null أو غير صالحة
        List<dynamic> rawImages = List<dynamic>.from(_serviceData!['imageUrls']);
        for (var img in rawImages) {
          if (img != null && img.toString().isNotEmpty && 
              (img.toString().startsWith('http://') || img.toString().startsWith('https://'))) {
            imageUrls.add(img.toString());
          }
        }
      }

      // Debug print to check image URLs after filtering
      print(
        'Service ${widget.serviceId} has ${imageUrls.length} filtered main images: $imageUrls',
      );

      // إضافة صور المركبة لخدمات النقل إذا كانت متوفرة
      if (type == 'نقل' &&
          _serviceData!['vehicle'] != null &&
          _serviceData!['vehicle'] is Map) {
        if ((_serviceData!['vehicle'] as Map).containsKey('imageUrls')) {
          final vehicleImgs = _serviceData!['vehicle']['imageUrls'];
          if (vehicleImgs is List && vehicleImgs.isNotEmpty) {
            // إضافة صور المركبة إلى قائمة الصور الحالية بعد فلترة القيم غير الصالحة
            for (var img in vehicleImgs) {
              if (img != null && img.toString().isNotEmpty && 
                  (img.toString().startsWith('http://') || img.toString().startsWith('https://')) &&
                  !imageUrls.contains(img.toString())) {
                imageUrls.add(img.toString());
              }
            }
            print('Added vehicle images, total now: ${imageUrls.length} images');
          }
        }
      }

      // إضافة صور موقع التخزين لخدمات التخزين إذا كانت متوفرة
      if (type == 'تخزين' && _serviceData!['storageLocationImageUrls'] != null) {
        final locationImgs = _serviceData!['storageLocationImageUrls'];
        if (locationImgs is List && locationImgs.isNotEmpty) {
          // إضافة صور موقع التخزين إلى قائمة الصور الحالية بعد فلترة القيم غير الصالحة
          for (var img in locationImgs) {
            if (img != null && img.toString().isNotEmpty && 
                (img.toString().startsWith('http://') || img.toString().startsWith('https://')) &&
                !imageUrls.contains(img.toString())) {
              imageUrls.add(img.toString());
            }
          }
          print('Added storage location images, total now: ${imageUrls.length} images');
        }
      }
        
      // تحقق إضافي من صحة الروابط في قائمة الصور النهائية
      print('Final image URLs count: ${imageUrls.length}');
      for (int i = 0; i < imageUrls.length; i++) {
        print('Image $i: ${imageUrls[i]} (${imageUrls[i].runtimeType})');
      }
    } catch (e) {
      print('Error processing image URLs: $e');
      // في حالة حدوث أي خطأ، نحتفظ بقائمة فارغة
      imageUrls = [];
    }

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

    final typeColor = type == 'تخزين' ? Color(0xFF3B82F6) : Color(0xFFEF4444);
    final typeIcon = type == 'تخزين' ? Icons.warehouse : Icons.local_shipping;
    final gradientColors =
        type == 'تخزين'
            ? [Color(0xFF3B82F6), Color(0xFF2563EB)]
            : [Color(0xFFEF4444), Color(0xFFDC2626)];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Hero image section with gradient overlay
        SliverToBoxAdapter(
          child: Stack(
            children: [              // Main image or placeholder
              SizedBox(
                height: 350,
                width: double.infinity,
                child: imageUrls.isNotEmpty 
                  ? Hero(
                      tag: 'service-image-${widget.serviceId}',
                      child: SafeImageCarousel(
                        imageUrls: imageUrls,
                        height: 350,
                        onPageChanged: (index) {
                          // Optional page change handling
                        },
                      ),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(typeIcon, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'لا توجد صورة متاحة',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
              ),

              // Gradient overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,                      colors: [
                        Colors.transparent,
                        const Color(0xCC000000), // استخدام لون ثابت مع قيمة ألفا تساوي 0.8
                      ],
                    ),
                  ),
                ),
              ),

              // Service type badge
              Positioned(
                top: 100,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors[0].withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(typeIcon, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        type,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Rating badge
              if (reviewCount > 0)
                Positioned(
                  top: 100,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '($reviewCount)',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Service title at the bottom
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _serviceData!['title'] ?? 'خدمة بدون عنوان',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 3,
                            color: Colors.black45,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          region,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.attach_money,
                          size: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$price $currency',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Multiple images indicator
              if (imageUrls.length > 1)
                Positioned(
                  bottom: 80,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.photo_library,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${imageUrls.length} صور',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Content Sections
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description Section
                _buildSectionTitle('وصف الخدمة', Icons.description_outlined),
                const SizedBox(height: 12),
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
                  child: Text(
                    description,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: Colors.grey[800],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Provider Info Section
                _buildSectionTitle(
                  'معلومات مزود الخدمة',
                  Icons.person_outlined,
                ),
                const SizedBox(height: 12),
                _buildProviderCard(providerInfo),

                const SizedBox(height: 24),

                // Service Details Section
                _buildSectionTitle(
                  type == 'تخزين' ? 'معلومات مكان التخزين' : 'معلومات المركبة',
                  type == 'تخزين'
                      ? Icons.warehouse_outlined
                      : Icons.local_shipping_outlined,
                ),
                const SizedBox(height: 12),

                // Service Details Card
                if (type == 'تخزين') ...[
                  _buildStorageDetailsCard(locationInfo),
                ] else if (type == 'نقل' && vehicleInfo != null) ...[
                  _buildVehicleDetailsCard(vehicleInfo, locationInfo),
                ],

                // Add extra space at the bottom for the floating action button
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
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
        // Location information for transport service
        if (locationInfo != null) ...[
          Text(
            'معلومات الموقع',
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
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  'العنوان',
                  locationInfo['address'] ?? 'غير محدد',
                  Icons.location_on,
                ),
                if (locationInfo['latitude'] != null &&
                    locationInfo['longitude'] != null) ...[
                  SizedBox(height: 16),
                  SizedBox(
                    height: 150,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(
                            locationInfo['latitude'],
                            locationInfo['longitude'],
                          ),
                          zoom: 15,
                        ),
                        markers: {
                          Marker(
                            markerId: MarkerId('serviceLocation'),
                            position: LatLng(
                              locationInfo['latitude'],
                              locationInfo['longitude'],
                            ),
                            infoWindow: InfoWindow(
                              title: 'موقع الخدمة',
                              snippet: locationInfo['address'] ?? '',
                            ),
                          ),
                        },
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        myLocationButtonEnabled: false,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 24),
        ],

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

  // Widget لعرض معلومات مزود الخدمة
  Widget _buildProviderInfo(Map<String, dynamic>? providerInfo) {
    // الحصول على معرف مقدم الخدمة من بيانات الخدمة
    final String providerId =
        _serviceData?['providerId'] ?? _serviceData?['userId'] ?? '';

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
              // صورة مزود الخدمة
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

              // معلومات مزود الخدمة
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
                        // زر الاتصال
                        InkWell(
                          onTap: () {
                            // التحقق من وجود رقم هاتف لمزود الخدمة
                            if (providerInfo != null &&
                                providerInfo['phoneNumber'] != null &&
                                providerInfo['phoneNumber']
                                    .toString()
                                    .isNotEmpty) {
                              _callProvider(providerInfo['phoneNumber']);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('رقم الهاتف غير متوفر')),
                              );
                            }
                          },
                          child: Row(
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
                            ],
                          ),
                        ),
                        SizedBox(width: 16),
                        // زر المراسلة
                        InkWell(
                          onTap: () {
                            // التحقق من وجود معرف مزود الخدمة
                            if (providerId.isNotEmpty) {
                              _startChat(
                                providerId,
                                providerInfo?['fullName'] ?? 'مزود الخدمة',
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'غير قادر على بدء محادثة مع هذا المزود',
                                  ),
                                ),
                              );
                            }
                          },
                          child: Row(
                            children: [
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
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // مؤشر التحقق
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

  // دالة للاتصال بمزود الخدمة
  Future<void> _callProvider(String phoneNumber) async {
    final url = 'tel:$phoneNumber';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('لا يمكن الاتصال بالرقم')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء محاولة الاتصال')));
    }
  }

  // دالة لبدء محادثة مع مزود الخدمة
  Future<void> _startChat(String providerId, String providerName) async {
    try {
      // التحقق من تسجيل دخول المستخدم
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('يجب تسجيل الدخول للتواصل مع مزود الخدمة'),
            action: SnackBarAction(
              label: 'تسجيل الدخول',
              onPressed: () {
                // توجيه المستخدم لصفحة تسجيل الدخول
                Navigator.pushNamed(context, '/login');
              },
            ),
          ),
        );
        return;
      } // تحضير البيانات اللازمة لإنشاء محادثة
      final currentUser = authService.currentUser!;

      // Verificación adicional del UID del usuario
      if (currentUser.uid.isEmpty) {
        print('Error: current user ID is empty, reloading user data');
        // Intentar recargar los datos del usuario
        await authService.checkPreviousLogin();

        // Verificar si el usuario ahora es válido
        if (authService.currentUser == null ||
            authService.currentUser!.uid.isEmpty) {
          // Si después de recargar sigue siendo nulo o vacío, intentar cerrar sesión y volver a iniciarla
          print('ERROR: User ID still empty after reload, forcing logout');
          await authService.logout();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'خطأ في بيانات المستخدم. الرجاء إعادة تسجيل الدخول',
              ),
              action: SnackBarAction(
                label: 'تسجيل الدخول',
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/login');
                },
              ),
            ),
          );
          return;
        }
      }

      final serviceId = _serviceData?['id'] ?? '';
      final serviceTitle = _serviceData?['title'] ?? 'خدمة';

      // Verificar que el UID del usuario no esté vacío antes de iniciar el chat
      final String userIdForChat = authService.currentUser!.uid;
      if (userIdForChat.isEmpty) {
        print(
          'ERROR: Cannot create chat service - User ID is still empty after reload',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لا يمكن بدء المحادثة. الرجاء إعادة تسجيل الدخول وحاول مرة أخرى',
            ),
          ),
        );
        return;
      }

      print('Creating chat service with user ID: $userIdForChat');
      final chatService = ChatService(userIdForChat);

      // إنشاء محادثة جديدة أو استخدام محادثة موجودة
      final chatId = await chatService.createChat(
        receiverId: providerId,
        receiverName: providerName.isNotEmpty ? providerName : 'مقدم الخدمة',
        senderName:
            currentUser.fullName.isNotEmpty ? currentUser.fullName : 'مستخدم',
        serviceId: serviceId,
        serviceTitle: serviceTitle,
      );

      // فتح شاشة الدردشة
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ChatScreen(
                  chatId: chatId,
                  otherUserId: providerId, // Corrected parameter name
                  otherUserName: providerName, // Corrected parameter name
                  serviceId: serviceId,
                  serviceTitle: serviceTitle,
                ),
          ),
        );
      }
    } catch (e) {
      print('Error starting chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء محاولة بدء المحادثة: ${e.toString()}'),
        ),
      );
    }
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
  }  // Abrir Google Maps con la ubicación  
  Future<void> _launchMapsUrl(double latitude, double longitude) async {
    // بدلا من فتح Google Maps، سننتقل إلى خريطة التطبيق مع تحديد الوجهة
    final Map<String, dynamic>? locationInfo = _serviceData != null && _serviceData!.containsKey('location') 
        ? _serviceData!['location'] as Map<String, dynamic>? 
        : null;
        
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveTrackingMapScreen(
          destinationLocation: LatLng(latitude, longitude),
          destinationName: locationInfo?['name'] ?? _serviceData?['title'] ?? '',
        ),
      ),
    );
  }

  // Mostrar diálogo de solicitud de خدمة
  void _showRequestServiceDialog() {
    final authService = Provider.of<AuthService>(context, listen: false);

    // Verificar si el usuario está autenticado
    if (authService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يجب تسجيل الدخول لطلب الخدمة'),
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
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Row(
              children: const [
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
                  const SizedBox(height: 16),

                  // Campo de fecha
                  TextField(
                    controller: dateController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'التاريخ المطلوب',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: () async {
                      final DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
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
                  const SizedBox(height: 16),

                  // Campo de detalles
                  TextField(
                    controller: detailsController,
                    maxLines: 4,
                    decoration: const InputDecoration(
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
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Validar los campos
                  if (selectedDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('يرجى اختيار التاريخ المطلوب'),
                      ),
                    );
                    return;
                  }

                  try {
                    // Mostrar indicador de carga
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                    );

                    // Crear instancia del servicio de notificaciones
                    final notificationService = NotificationService();

                    // Enviar la solicitud y notificación al proveedor
                    await notificationService.sendServiceRequest(
                      serviceId: widget.serviceId,
                      providerId: _serviceData!['providerId'],
                      serviceName: _serviceData!['title'] ?? 'خدمة',
                      details: detailsController.text,
                      requestDate: selectedDate!,
                    );

                    // Cerrar el diálogo de carga y el formulario
                    if (mounted) Navigator.pop(context); // Cierra el indicador de carga
                    if (mounted) Navigator.pop(context); // Cierra el formulario

                    // Mostrar mensaje de éxito
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'تم إرسال طلبك بنجاح! سيتصل بك مزود الخدمة قريبًا.',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    // Cerrar el diálogo de carga
                    if (mounted) Navigator.pop(context);
                    
                    // Mostrar mensaje de error
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('حدث خطأ أثناء إرسال الطلب: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9B59B6),
                ),
                child: const Text('إرسال الطلب'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Method to build section titles with a modern look
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF8B5CF6).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
      ],
    );
  }

  // Method to build provider card with modern UI
  Widget _buildProviderCard(Map<String, dynamic>? providerInfo) {
    // Get provider ID from service data
    final String providerId =
        _serviceData?['providerId'] ?? _serviceData?['userId'] ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            children: [
              // Provider profile image with gradient border
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 36, color: Color(0xFF8B5CF6)),
                ),
              ),
              const SizedBox(width: 16),

              // Provider details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          providerInfo != null &&
                                  providerInfo['fullName'] != null
                              ? providerInfo['fullName']
                              : 'مزود خدمة',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (providerInfo != null &&
                            providerInfo['isVerified'] == true)
                          const Icon(
                            Icons.verified,
                            color: Colors.blue,
                            size: 18,
                          ),
                      ],
                    ),
                    if (providerInfo != null &&
                        providerInfo['companyName'] != null &&
                        providerInfo['companyName'].toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        providerInfo['companyName'],
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          providerInfo?['rating']?.toString() ?? '4.5',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '(${providerInfo?['reviews']?.toString() ?? '0'})',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Contact buttons with modern design
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (providerInfo != null &&
                        providerInfo['phoneNumber'] != null &&
                        providerInfo['phoneNumber'].toString().isNotEmpty) {
                      _callProvider(providerInfo['phoneNumber']);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('رقم الهاتف غير متوفر')),
                      );
                    }
                  },
                  icon: const Icon(Icons.phone, size: 16),
                  label: const Text('اتصال', style: TextStyle(fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (providerId.isNotEmpty) {
                      _startChat(
                        providerId,
                        providerInfo?['fullName'] ?? 'مزود الخدمة',
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'غير قادر على بدء محادثة مع هذا المزود',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.message, size: 16),
                  label: const Text('رسالة', style: TextStyle(fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Method to build storage details card with modern UI
  Widget _buildStorageDetailsCard(Map<String, dynamic>? locationInfo) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location map if available
          if (locationInfo != null &&
              locationInfo['latitude'] != null &&
              locationInfo['longitude'] != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                ),
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

            const SizedBox(height: 16),

            // Location address with icon
            if (locationInfo['address'] != null &&
                locationInfo['address'].toString().isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 18, color: Color(0xFF8B5CF6)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        locationInfo['address'],
                        style: TextStyle(color: Colors.grey[800], fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],

            // Get directions button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _launchMapsUrl(
                    locationInfo['latitude'],
                    locationInfo['longitude'],
                  );
                },
                icon: const Icon(Icons.directions),
                label: const Text('الحصول على الاتجاهات'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Color(0xFF3B82F6),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ] else ...[
            // No location data available
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[600], size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'لم يتم تحديد موقع مكان التخزين. يرجى التواصل مع مزود الخدمة للحصول على التفاصيل.',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Storage features if available
          if (_serviceData!.containsKey('storageFeatures')) ...[
            const Text(
              'ميزات مكان التخزين',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF555555),
              ),
            ),
            const SizedBox(height: 12),
            _buildFeaturesList(_serviceData!['storageFeatures']),
          ],
        ],
      ),
    );
  }

  // Method to build vehicle details card with modern UI
  Widget _buildVehicleDetailsCard(
    Map<String, dynamic> vehicleInfo,
    Map<String, dynamic>? locationInfo,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location information for transport service
          if (locationInfo != null) ...[
            Row(
              children: [
                Icon(Icons.location_on, color: Color(0xFFEF4444), size: 24),
                SizedBox(width: 10),
                Text(
                  'معلومات الموقع',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    'العنوان',
                    locationInfo['address'] ?? 'غير محدد',
                    Icons.location_on,
                  ),
                  if (locationInfo['latitude'] != null &&
                      locationInfo['longitude'] != null) ...[
                    SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        height: 150,
                        width: double.infinity,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(
                              locationInfo['latitude'],
                              locationInfo['longitude'],
                            ),
                            zoom: 15,
                          ),
                          markers: {
                            Marker(
                              markerId: MarkerId('serviceLocation'),
                              position: LatLng(
                                locationInfo['latitude'],
                                locationInfo['longitude'],
                              ),
                              infoWindow: InfoWindow(
                                title: 'موقع الخدمة',
                                snippet: locationInfo['address'] ?? '',
                              ),
                            ),
                          },
                          zoomControlsEnabled: false,
                          mapToolbarEnabled: false,
                          myLocationButtonEnabled: false,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 24),
          ],

          // Vehicle title
          Row(
            children: [
              Icon(Icons.local_shipping, color: Color(0xFFEF4444), size: 24),
              SizedBox(width: 10),
              Text(
                'معلومات المركبة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Vehicle details with modern cards
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            childAspectRatio: 2.5,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              if (vehicleInfo['type'] != null || vehicleInfo['make'] != null)
                _buildVehicleInfoCard(
                  'نوع المركبة',
                  '${vehicleInfo['make'] ?? ''} ${vehicleInfo['type'] ?? ''}',
                  Icons.local_shipping,
                ),
              if (vehicleInfo['year'] != null)
                _buildVehicleInfoCard(
                  'سنة الصنع',
                  vehicleInfo['year'],
                  Icons.date_range,
                ),
              if (vehicleInfo['plate'] != null)
                _buildVehicleInfoCard(
                  'رقم اللوحة',
                  vehicleInfo['plate'],
                  Icons.confirmation_number,
                ),
              if (vehicleInfo['capacity'] != null)
                _buildVehicleInfoCard(
                  'قدرة الحمولة',
                  vehicleInfo['capacity'],
                  Icons.line_weight,
                ),
              if (vehicleInfo['dimensions'] != null)
                _buildVehicleInfoCard(
                  'الأبعاد',
                  vehicleInfo['dimensions'],
                  Icons.straighten,
                ),
            ],
          ),

          // Special features section if available
          if (vehicleInfo['specialFeatures'] != null &&
              vehicleInfo['specialFeatures'].toString().isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'ميزات خاصة',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF555555),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                vehicleInfo['specialFeatures'],
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ],

          // Vehicle images gallery if available
          if (vehicleInfo['imageUrls'] != null &&
              vehicleInfo['imageUrls'] is List &&
              (vehicleInfo['imageUrls'] as List).isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(
                  Icons.collections,
                  color: Color(0xFF8B5CF6),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'صور المركبة',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF555555),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: (vehicleInfo['imageUrls'] as List).length,
                itemBuilder: (context, index) {
                  final url = (vehicleInfo['imageUrls'] as List)[index];
                  return Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder:
                            (context, url) => Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF8B5CF6),
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
                                  const SizedBox(height: 4),
                                  const Text(
                                    'خطأ',
                                    style: TextStyle(
                                      color: Colors.grey,
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
      ),
    );
  } // Helper method for vehicle info cards

  Widget _buildVehicleInfoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8), // Reduced padding
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      height: 50, // Fixed height to prevent overflow
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6), // Smaller padding
            decoration: BoxDecoration(
              color: Color(0xFF8B5CF6).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 14,
              color: Color(0xFF8B5CF6),
            ), // Smaller icon
          ),
          const SizedBox(width: 6), // Smaller spacing
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center, // Center vertically
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 10, // Smaller font
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1), // Smaller spacing
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12, // Smaller font
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
