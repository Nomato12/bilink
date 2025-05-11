import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bilink/screens/service_details_screen.dart';
import 'package:bilink/screens/transport_service_map_wrapper.dart'; // استيراد الملف الجديد للخريطة
import 'package:bilink/services/location_synchronizer.dart'; // Importar el sincronizador
import 'package:bilink/screens/storage_locations_map_screen.dart';
import 'package:bilink/screens/account_profile_screen.dart';
import 'package:bilink/services/chat_service.dart';
import 'package:bilink/services/auth_service.dart';
import 'package:bilink/widgets/notification_badge.dart';
import 'package:bilink/models/home_page.dart';
import 'package:bilink/screens/chat_list_screen.dart';
import 'package:bilink/painters/logistics_painters.dart'; // استيراد رسامي الزخارف اللوجستية
import 'package:bilink/screens/transport_map_fix.dart'; // Import utility functions for location handling

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  _ClientHomePageState createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> with SingleTickerProviderStateMixin {
  // متغيرات التحكم بالواجهة
  bool _isLoading = false;
  List<Map<String, dynamic>> _servicesList = [];
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  int _currentImageIndex = 0;
  
  // متغيرات القائمة الجانبية
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // الألوان الأساسية - نظام ألوان متناسق للخدمات اللوجستية
  final Color _primaryColor = const Color(0xFF0B3D91); // لون أزرق بحري عميق يرمز للموثوقية والاحترافية
  final Color _secondaryColor = const Color(0xFFFF5722); // لون برتقالي ناري يرمز للطاقة والحركة
  final Color _accentColor = const Color(0xFF00838F); // لون أزرق مخضر يرمز للابتكار والاستدامة
  final Color _lightBlue = const Color(0xFF4FC3F7); // لون أزرق فاتح للتفاصيل الخفيفة
  final Color _deepOrange = const Color(0xFFE64A19); // لون برتقالي داكن للتأكيدات المهمة
  final Color _amber = const Color(0xFFFFB300); // لون كهرماني للتنبيهات والعناصر البارزة

  // فلاتر البحث
  String _selectedRegion = 'الكل';
  String _selectedType = 'الكل';
  String _sortBy = 'التقييم';
  RangeValues _priceRange = RangeValues(0, 10000);
  // القيم الحالية للفلاتر المفعلة
  final Set<String> _activeFilters = {};

  // قائمة المناطق
  final List<String> _regions = [
    'الكل', 'أدرار', 'الشلف', 'الأغواط', 'أم البواقي', 'باتنة', 'بجاية', 'بسكرة', 'بشار', 'البليدة', 'البويرة', 'تمنراست', 'تبسة', 'تلمسان', 'تيارت', 'تيزي وزو', 'الجزائر العاصمة', 'الجلفة', 'جيجل', 'سطيف', 'سعيدة', 'سكيكدة', 'سيدي بلعباس', 'عنابة', 'قالمة', 'قسنطينة', 'المدية', 'مستغانم', 'المسيلة', 'معسكر', 'ورقلة', 'وهران', 'البيض', 'إليزي', 'برج بوعريريج', 'بومرداس', 'الطارف', 'تندوف', 'تيسمسيلت', 'الوادي', 'خنشلة', 'سوق أهراس', 'تيبازة', 'ميلة', 'عين الدفلى', 'النعامة', 'عين تموشنت', 'غرداية', 'غليزان', 'المغير', 'المنيعة',
  ];
  
  // متغيرات نطاق السعر
  double _minPrice = 0;
  double _maxPrice = 10000;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadServices();
    
    _minPrice = _priceRange.start;
    _maxPrice = _priceRange.end;
    
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        if (_tabController.index == 0) {
          _selectedType = 'تخزين';
        } else {
          _selectedType = 'نقل';
        }
        _activeFilters.removeWhere((filter) => filter.startsWith('النوع'));
        _activeFilters.add('النوع: $_selectedType');
      });
      _updateFilters();
    }
  }

  Future<void> _loadServices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Query query = FirebaseFirestore.instance
          .collection('services')
          .where('isActive', isEqualTo: true);

      if (_selectedRegion != 'الكل') {
        query = query.where('region', isEqualTo: _selectedRegion);
      }

      if (_selectedType != 'الكل') {
        query = query.where('type', isEqualTo: _selectedType);
      }

      final querySnapshot = await query.get();
      final List<Map<String, dynamic>> servicesList = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; 
        final price = data['price'] as num? ?? 0;
        if (price >= _priceRange.start && price <= _priceRange.end) {
          servicesList.add(data);
        }
      }

      if (_sortBy == 'التقييم') {
        servicesList.sort(
          (a, b) =>
              (b['rating'] as num? ?? 0).compareTo(a['rating'] as num? ?? 0),
        );
      } else if (_sortBy == 'السعر (من الأقل)') {
        servicesList.sort(
          (a, b) =>
              (a['price'] as num? ?? 0).compareTo(b['price'] as num? ?? 0),
        );
      } else if (_sortBy == 'السعر (من الأعلى)') {
        servicesList.sort(
          (a, b) =>
              (b['price'] as num? ?? 0).compareTo(a['price'] as num? ?? 0),
        );
      } else if (_sortBy == 'الأحدث') {
        servicesList.sort((a, b) {
          final aTime = a['createdAt'] as Timestamp? ?? Timestamp.now();
          final bTime = b['createdAt'] as Timestamp? ?? Timestamp.now();
          return bTime.compareTo(aTime);
        });
      }

      setState(() {
        _servicesList = servicesList;
        _isLoading = false;
      });

    } catch (e) {
      print('Error loading services: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تحميل الخدمات، يرجى المحاولة مرة أخرى'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _updateFilters() {
    _loadServices();
  }

  void _navigateToStorageLocationsMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => StorageLocationsMapScreen()),
    );
  }
  
  Future<void> _navigateToTransportServicesMap() async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,  
                  height: 20,  
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(_secondaryColor),
                  ),
                ),
                SizedBox(width: 16),
                Text('جاري تحميل خدمات النقل...'),
              ],
            ),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.all(16),
          ),
        );
      }
      final synchronizer = LocationSynchronizer();
      await synchronizer.synchronizeTransportLocations();
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TransportServiceMapWrapper()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تحميل خدمات النقل. حاول مرة أخرى.'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.all(16),
            backgroundColor: Colors.redAccent,
            ),
        );
      }
    }
  }
  
  void _openTransportLocationOnMap(LatLng location, String locationName, Map<String, dynamic> service) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransportServiceMapWrapper(
          destinationLocation: location,
          destinationName: locationName,
          serviceData: service,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _buildSideDrawer(),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: SvgPicture.asset(
                  'assets/images/pattern.svg',
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    _primaryColor.withOpacity(0.02), // Slightly reduced opacity for subtlety
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: screenSize.height * 0.32,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          _primaryColor,
                          _primaryColor.withOpacity(0.9),
                          _accentColor.withOpacity(0.8),
                        ],
                        stops: const [0.2, 0.6, 1.0],
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(45), // Slightly increased radius
                        bottomRight: Radius.circular(45),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.35), // Slightly adjusted shadow
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 20,
                    right: -50,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(90),
                      ),
                      child: CustomPaint(
                        painter: LogisticsPathPainter(
                          pathColor: Colors.white.withOpacity(0.15),
                          dotColor: _lightBlue.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -30,
                    left: -20,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            _secondaryColor.withOpacity(0.1),
                            Colors.transparent,
                          ],
                          stops: const [0.5, 1.0],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: CustomPaint(
                        painter: CircleWavePainter(
                          color: _secondaryColor.withOpacity(0.2),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: LogisticsNetworkPainter(
                        dotColor: Colors.white.withOpacity(0.3),
                        lineColor: Colors.white.withOpacity(0.1),
                        dotCount: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            NestedScrollView(
              controller: _scrollController,
              headerSliverBuilder: (context, innerBoxScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 180,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16), // Adjusted padding
                      centerTitle: true,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'الخدمات',
                              style: GoogleFonts.cairo(
                                textStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18, 
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black38, // Slightly stronger shadow for readability
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12), // Consistent rounding
                                ),
                                child: IconButton(
                                  onPressed: _showSortingOptions,
                                  icon: const Icon(Icons.filter_list, color: Colors.white, size: 22),
                                  tooltip: 'ترتيب الخدمات',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: StreamBuilder<int>(
                                  stream: ChatService(FirebaseAuth.instance.currentUser?.uid ?? '').getUnreadMessageCount(),
                                  builder: (context, snapshot) {
                                    final unreadCount = snapshot.data ?? 0;
                                    return Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.chat_outlined, color: Colors.white, size: 22),
                                          tooltip: 'المحادثات',
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (context) => ChatListScreen()),
                                            );
                                          },
                                        ),
                                        if (unreadCount > 0)
                                          Positioned(
                                            right: 4,
                                            top: 4,
                                            child: NotificationBadge(count: unreadCount),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Consumer<AuthService>(
                                builder: (context, authService, _) {
                                  final user = authService.currentUser;
                                  return GestureDetector(
                                    onTap: () {
                                      _showAccountMenu(context);
                                    },
                                    child: Container(
                                      width: 38, // Slightly smaller
                                      height: 38,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.8), // Softer border
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 5,
                                            offset: Offset(0,2)
                                          )
                                        ]
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(19),
                                        child: user?.profileImageUrl != null && user!.profileImageUrl.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: user.profileImageUrl,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => Container(
                                                  color: Colors.grey[200],
                                                  child: Icon(Icons.person, color: _primaryColor.withOpacity(0.7), size: 20),
                                                ),
                                                errorWidget: (context, url, error) => Container(
                                                  color: _primaryColor.withOpacity(0.1),
                                                  child: Icon(Icons.person, color: _primaryColor, size: 20),
                                                ),
                                              )
                                            : Container(
                                                color: _primaryColor.withOpacity(0.1),
                                                child: Icon(Icons.person, color: Colors.white, size: 20),
                                              ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container( // This container seems redundant as SliverAppBar already has a background
                            // decoration: BoxDecoration(
                            //   gradient: LinearGradient(
                            //     begin: Alignment.topLeft,
                            //     end: Alignment.bottomRight,
                            //     colors: [_primaryColor, _accentColor],
                            //   ),
                            // ),
                          ),
                          // Decorative elements are now part of the main header stack
                          Align(
                            alignment: Alignment.center,
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 50), // Adjusted padding
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Consumer<AuthService>(
                                    builder: (context, authService, _) {
                                      final user = authService.currentUser;
                                      return Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            user?.fullName ?? 'مرحباً بك',
                                            style: GoogleFonts.cairo( // Using GoogleFonts here too
                                              textStyle:TextStyle(
                                                color: Colors.white,
                                                fontSize: 20, 
                                                fontWeight: FontWeight.bold,
                                                shadows: [
                                                  Shadow(
                                                    color: Colors.black38,
                                                    blurRadius: 5,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                            )
                                          ),
                                          SizedBox(height: 4), // Reduced space
                                          Text(
                                            user?.email ?? '',
                                            style: GoogleFonts.cairo(
                                              textStyle: TextStyle(
                                                color: Colors.white.withOpacity(0.85),
                                                fontSize: 13, // Slightly smaller
                                              ),
                                            )
                                          ),
                                          SizedBox(height: 12), // Adjusted space
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              SvgPicture.asset(
                                                'assets/images/truck.svg',
                                                width: 28, // Slightly smaller
                                                height: 28,
                                                colorFilter: const ColorFilter.mode(Colors.white70, BlendMode.srcIn),
                                              ),
                                              const SizedBox(width: 12),
                                              SvgPicture.asset(
                                                'assets/images/warehouse.svg',
                                                width: 28,
                                                height: 32,
                                                colorFilter: const ColorFilter.mode(Colors.white70, BlendMode.srcIn),
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SliverToBoxAdapter(
                    child: _buildFeaturedSection(),
                  ),
                  
                  if (_activeFilters.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10), // Consistent padding
                        child: _buildActiveFilters(),
                      ),
                    ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _isLoading
                      ? _buildLoadingView()
                      : _buildServicesListView('تخزين'),
                  
                  _isLoading
                      ? _buildLoadingView()
                      : _buildServicesListView('نقل'),
                ],
              ),
            ),
          ],
        ),
      ),
      
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_selectedType == 'تخزين') {
            _navigateToStorageLocationsMap();
          } else {
            _navigateToTransportServicesMap();
          }
        },
        backgroundColor: _secondaryColor,
        tooltip: 'عرض الخريطة',
        child: const Icon(Icons.map_outlined, color: Colors.white), // Added color for FAB icon
        elevation: 6.0, // Added elevation
        highlightElevation: 12.0, // Elevation on press
      ),
    );
  }
  
  Widget _buildFeaturedSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 25, 20, 10), // Adjusted margin
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الخدمات الرئيسية',
            style: GoogleFonts.cairo(
              textStyle: TextStyle(
                fontSize: 20, // Slightly smaller for balance
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 18), // Adjusted space
          Row(
            children: [
              Expanded(
                child: _buildLargeServiceCard(
                  title: 'خدمة التخزين',
                  icon: 'assets/images/warehouse.svg',
                  color: _accentColor,
                  onTap: () {
                     _tabController.animateTo(0); // Switch to storage tab
                    _navigateToStorageLocationsMap();
                  },
                ),
              ),
              const SizedBox(width: 16), // Consistent spacing
              Expanded(
                child: _buildLargeServiceCard(
                  title: 'خدمة النقل',
                  icon: 'assets/images/truck.svg',
                  color: _secondaryColor,
                  onTap: () {
                    _tabController.animateTo(1); // Switch to transport tab
                    _navigateToTransportServicesMap();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Divider(
            color: Colors.grey.withOpacity(0.25), // Softer divider
            thickness: 1,
          ),
        ],
      ),
    );
  }
  
  Widget _buildLargeServiceCard({
    required String title,
    required String icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22), // Slightly larger radius for a softer look
        child: Container(
          height: 170, // Slightly adjusted height
          padding: const EdgeInsets.all(16), // Consistent padding
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color,
                color.withOpacity(0.75), // Adjusted opacity
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [ // Refined shadow for consistency
              BoxShadow(
                color: color.withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                icon,
                width: 55, // Adjusted size
                height: 55,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
              const SizedBox(height: 12), // Adjusted space
              Text(
                title,
                style: GoogleFonts.cairo(
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 17, // Adjusted size
                    fontWeight: FontWeight.bold,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSideDrawer() {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20), // Adjusted padding
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_primaryColor, _accentColor.withOpacity(0.8)], // Adjusted gradient
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'جميع الخدمات',
                        style: GoogleFonts.cairo(
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 22, // Adjusted size
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 26),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تصفية وعرض جميع الخدمات المتاحة',
                    style: GoogleFonts.cairo(
                      textStyle: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13, // Adjusted size
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20), // Consistent padding
                children: [
                  _buildFilterSection(
                    title: 'نوع الخدمة',
                    icon: Icons.category_outlined, // Using outlined icons
                    child: Column(
                      children: [
                        _buildFilterOption(
                          title: 'الكل',
                          isSelected: _selectedType == 'الكل',
                          onTap: () {
                            setState(() {
                              _selectedType = 'الكل';
                              _activeFilters.removeWhere((filter) => filter.startsWith('النوع'));
                            });
                            _updateFilters();
                            Navigator.pop(context);
                          },
                        ),
                        _buildFilterOption(
                          title: 'خدمات النقل',
                          isSelected: _selectedType == 'نقل',
                          onTap: () {
                            setState(() {
                              _selectedType = 'نقل';
                              _activeFilters.removeWhere((filter) => filter.startsWith('النوع'));
                              _activeFilters.add('النوع: نقل');
                              _tabController.animateTo(1);
                            });
                            _updateFilters();
                            Navigator.pop(context);
                          },
                        ),
                        _buildFilterOption(
                          title: 'خدمات التخزين',
                          isSelected: _selectedType == 'تخزين',
                          onTap: () {
                            setState(() {
                              _selectedType = 'تخزين';
                              _activeFilters.removeWhere((filter) => filter.startsWith('النوع'));
                              _activeFilters.add('النوع: تخزين');
                              _tabController.animateTo(0);
                            });
                            _updateFilters();
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const Divider(height: 30, thickness: 0.8), // Adjusted divider
                  
                  _buildFilterSection(
                    title: 'المنطقة',
                    icon: Icons.location_on_outlined,
                    child: _buildRegionDropdown(),
                  ),
                  
                  const Divider(height: 30, thickness: 0.8),
                  
                  _buildFilterSection(
                    title: 'نطاق السعر (دج)',
                    icon: Icons.attach_money_outlined,
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'الحد الأدنى',
                                  labelStyle: TextStyle(color: _primaryColor.withOpacity(0.8), fontSize: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12), // Consistent rounding
                                    borderSide: BorderSide(color: Colors.grey.shade300)
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300)
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: _primaryColor, width: 1.5)
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), // Adjusted padding
                                  // suffixText: 'دج', // Removed suffix for cleaner look, title indicates currency
                                ),
                                controller: TextEditingController(text: _priceRange.start.round().toString()),
                                onChanged: (value) {
                                  setState(() {
                                    _minPrice = double.tryParse(value) ?? 0;
                                  });
                                },
                                onSubmitted: (value) { // Apply on submit for text fields
                                   setState(() {
                                    _minPrice = double.tryParse(value) ?? 0;
                                    if (_minPrice > _maxPrice) _minPrice = _maxPrice; // Ensure min <= max
                                    _priceRange = RangeValues(_minPrice, _maxPrice);
                                    _activeFilters.removeWhere((filter) => filter.startsWith('السعر'));
                                    _activeFilters.add(
                                      'السعر: ${_priceRange.start.round()} - ${_priceRange.end.round()} دج',
                                    );
                                  });
                                  // _updateFilters(); // Consider if auto-update is needed or only by button
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'الحد الأقصى',
                                   labelStyle: TextStyle(color: _primaryColor.withOpacity(0.8), fontSize: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                     borderSide: BorderSide(color: Colors.grey.shade300)
                                  ),
                                   enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300)
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: _primaryColor, width: 1.5)
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  // suffixText: 'دج',
                                ),
                                controller: TextEditingController(text: _priceRange.end.round().toString()),
                                onChanged: (value) {
                                   setState(() {
                                    _maxPrice = double.tryParse(value) ?? 10000;
                                  });
                                },
                                onSubmitted: (value) {
                                  setState(() {
                                    _maxPrice = double.tryParse(value) ?? 10000;
                                    if (_maxPrice < _minPrice) _maxPrice = _minPrice; // Ensure max >= min
                                    _priceRange = RangeValues(_minPrice, _maxPrice);
                                     _activeFilters.removeWhere((filter) => filter.startsWith('السعر'));
                                    _activeFilters.add(
                                      'السعر: ${_priceRange.start.round()} - ${_priceRange.end.round()} دج',
                                    );
                                  });
                                  // _updateFilters();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              // Ensure minPrice isn't greater than maxPrice
                              if (_minPrice > _maxPrice) {
                                  // Optionally swap or show an error, here we cap minPrice
                                  _minPrice = _maxPrice;
                              }
                              _priceRange = RangeValues(_minPrice, _maxPrice);
                              _activeFilters.removeWhere((filter) => filter.startsWith('السعر'));
                              _activeFilters.add(
                                'السعر: ${_priceRange.start.round()} - ${_priceRange.end.round()} دج',
                              );
                            });
                            _updateFilters();
                            // Navigator.pop(context); // Keep drawer open or close based on UX preference
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size(double.infinity, 48), // Increased height
                            elevation: 4,
                          ),
                          child: Text(
                            'تطبيق نطاق السعر',
                            style: GoogleFonts.cairo(
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const Divider(height: 30, thickness: 0.8),
                  
                  _buildFilterSection(
                    title: 'المسافة',
                    icon: Icons.social_distance_outlined,
                    child: Column(
                      children: [
                        _buildFilterOption(
                          title: 'الكل',
                          isSelected: !_activeFilters.any((filter) => filter.startsWith('المسافة')),
                          onTap: () {
                            setState(() {
                              _activeFilters.removeWhere((filter) => filter.startsWith('المسافة'));
                            });
                            _updateFilters();
                            Navigator.pop(context);
                          },
                        ),
                        _buildFilterOption(
                          title: 'أقل من 5 كم',
                          isSelected: _activeFilters.contains('المسافة: أقل من 5 كم'),
                          onTap: () {
                            setState(() {
                              _activeFilters.removeWhere((filter) => filter.startsWith('المسافة'));
                              _activeFilters.add('المسافة: أقل من 5 كم');
                            });
                            _updateFilters();
                            Navigator.pop(context);
                          },
                        ),
                        _buildFilterOption(
                          title: '5 - 15 كم',
                          isSelected: _activeFilters.contains('المسافة: 5 - 15 كم'),
                          onTap: () {
                            setState(() {
                              _activeFilters.removeWhere((filter) => filter.startsWith('المسافة'));
                              _activeFilters.add('المسافة: 5 - 15 كم');
                            });
                            _updateFilters();
                            Navigator.pop(context);
                          },
                        ),
                        _buildFilterOption(
                          title: 'أكثر من 15 كم',
                          isSelected: _activeFilters.contains('المسافة: أكثر من 15 كم'),
                          onTap: () {
                            setState(() {
                              _activeFilters.removeWhere((filter) => filter.startsWith('المسافة'));
                              _activeFilters.add('المسافة: أكثر من 15 كم');
                            });
                            _updateFilters();
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24), // Space before final apply button
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: ElevatedButton(
                      onPressed: () {
                        _updateFilters();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _secondaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14), // Increased padding
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12), // Consistent rounding
                        ),
                        elevation: 5, // Added elevation
                      ),
                      child: Text(
                        'تطبيق جميع الفلاتر',
                        style: GoogleFonts.cairo(
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFilterSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: _primaryColor, size: 22), // Slightly larger icon
            const SizedBox(width: 10), // Adjusted space
            Text(
              title,
              style: GoogleFonts.cairo(
                textStyle: TextStyle(
                  fontSize: 17, // Adjusted size
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12), // Adjusted space
        Padding( // Add padding to child for better containment
          padding: const EdgeInsets.only(right: 8.0), // Indent filter options slightly
          child: child,
        )
      ],
    );
  }
  
  Widget _buildFilterOption({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10), // Consistent rounding
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8), // Adjusted padding
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, // Using rounded icons
              color: isSelected ? _secondaryColor : Colors.grey.shade500, // Adjusted unchecked color
              size: 22, // Adjusted size
            ),
            const SizedBox(width: 10), // Adjusted space
            Expanded( // Allow text to wrap if too long
              child: Text(
                title,
                style: GoogleFonts.cairo(
                  textStyle: TextStyle(
                    fontSize: 15, // Adjusted size
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? _secondaryColor : Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // _buildFeatureCard is marked as not used, so I'll keep it as is.
  Widget _buildFeatureCard({
    required String title,
    required Color color,
    required String icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: SvgPicture.asset(
                    icon,
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    textStyle: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildActiveFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Adjusted padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18), // Consistent rounding
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15), // Softer shadow
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 0.8) // Subtle border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt_outlined, size: 20, color: _primaryColor), // Outlined icon
              const SizedBox(width: 8),
              Text(
                'الفلاتر النشطة',
                style: GoogleFonts.cairo(
                  textStyle: TextStyle(
                    fontSize: 15, // Adjusted size
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _activeFilters.clear();
                    _selectedRegion = 'الكل';
                    _selectedType = 'الكل'; // Should default to current tab or 'الكل'
                    _sortBy = 'التقييم';
                    _priceRange = RangeValues(0, 10000);
                    _minPrice = 0;
                    _maxPrice = 10000;
                    // Reset tab to 'الكل' type if needed, or based on current view
                    // For now, keep current tab's type filter if "النوع" is not manually cleared.
                  });
                  _updateFilters();
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // Adjusted padding
                  foregroundColor: Colors.red[600], // Adjusted color
                ),
                child: Text(
                  'مسح الكل',
                  style: GoogleFonts.cairo(
                    textStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600), // Adjusted style
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10), // Adjusted space
          if (_activeFilters.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                'لا توجد فلاتر مفعلة حالياً.',
                style: GoogleFonts.cairo(color: Colors.grey.shade600, fontSize: 13)
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _activeFilters.map((filter) {
                return Chip(
                  label: Text(
                    filter,
                    style: GoogleFonts.cairo(
                      textStyle: const TextStyle(fontSize: 12.5, color: Colors.white, fontWeight: FontWeight.w500), // Adjusted font
                    ),
                  ),
                  backgroundColor: _accentColor.withOpacity(0.9), // Slightly adjusted opacity
                  deleteIconColor: Colors.white.withOpacity(0.8),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2), // Adjusted chip padding
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // Softer chip corners
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onDeleted: () {
                    setState(() {
                      _activeFilters.remove(filter);
                      if (filter.startsWith('النوع')) _selectedType = 'الكل';
                      else if (filter.startsWith('المنطقة')) _selectedRegion = 'الكل';
                      else if (filter.startsWith('السعر')) {
                        _priceRange = RangeValues(0, 10000);
                        _minPrice = 0; _maxPrice = 10000;
                      } else if (filter.startsWith('ترتيب')) _sortBy = 'التقييم';
                      // Add removal logic for other filters if any (e.g. distance)
                    });
                    _updateFilters();
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
  
  Widget _buildServicesListView(String type) {
    final filteredServices = _servicesList.where((service) => service['type'] == type).toList();
    
    if (filteredServices.isEmpty) {
      return Center(
        child: SingleChildScrollView( // Ensure content is scrollable if it overflows on small screens
          padding: EdgeInsets.all(20), // Add padding around the empty state message
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                type == 'تخزين' ? 'assets/images/warehouse.svg' : 'assets/images/truck.svg',
                width: 70, // Slightly smaller
                height: 70,
                colorFilter: ColorFilter.mode(Colors.grey.shade300, BlendMode.srcIn), // Softer color
              ),
              const SizedBox(height: 20), // Adjusted space
              Text(
                'لا توجد خدمات متاحة حالياً',
                style: GoogleFonts.cairo(
                  textStyle: TextStyle(
                    fontSize: 17, // Adjusted size
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700, // Darker grey
                  ),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'جرّب تغيير معايير البحث أو العودة لاحقاً.',
                style: GoogleFonts.cairo(
                  textStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14), // Adjusted size
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _loadServices,
                icon: const Icon(Icons.refresh_rounded, size: 20), // Rounded icon
                label: Text('تحديث القائمة', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)), // Adjusted text
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor.withOpacity(0.85), // Slightly transparent
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12), // Adjusted padding
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), // Consistent rounding
                  ),
                  elevation: 3,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100), // Adjusted top padding
      itemCount: filteredServices.length,
      itemBuilder: (context, index) {
        final service = filteredServices[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 22), // Slightly more space between cards
          child: _buildModernServiceCard(service),
        );
      },
    );
  }
  
  Widget _buildModernServiceCard(Map<String, dynamic> service) {
    final String title = service['title'] ?? 'خدمة بدون عنوان';
    final String type = service['type'] ?? 'غير محدد';
    final String region = service['region'] ?? 'غير محدد';
    final double price = (service['price'] as num?)?.toDouble() ?? 0.0;
    final double rating = (service['rating'] as num?)?.toDouble() ?? 0.0;
    final int reviewCount = (service['reviewCount'] as num?)?.toInt() ?? 0;
    
    List<dynamic> imageUrls = [];
    if (service['imageUrls'] != null && service['imageUrls'] is List) {
      imageUrls = List<dynamic>.from(service['imageUrls']);
    }
    // Debug print removed for cleaner code, assumed working as intended
    if (type == 'نقل' && service['vehicle'] != null && service['vehicle'] is Map) {
      if ((service['vehicle'] as Map).containsKey('imageUrls')) {
        final vehicleImgs = service['vehicle']['imageUrls'];
        if (vehicleImgs is List && vehicleImgs.isNotEmpty) {
          for (var img in vehicleImgs) {
            if (!imageUrls.contains(img)) imageUrls.add(img);
          }
        }
      }
    }
    if (type == 'تخزين' && service['storageLocationImageUrls'] != null) {
      final locationImgs = service['storageLocationImageUrls'];
      if (locationImgs is List && locationImgs.isNotEmpty) {
        for (var img in locationImgs) {
          if (!imageUrls.contains(img)) imageUrls.add(img);
        }
      }
    }
    
    final String description = service['description'] ?? '';
    final bool isStorage = type == 'تخزين';
    final Color typeColor = isStorage ? _accentColor : _deepOrange;
    final Color typeGradientStart = isStorage ? _accentColor : _secondaryColor;
    final Color typeGradientEnd = isStorage ? _accentColor.withOpacity(0.75) : _deepOrange.withOpacity(0.85); // Adjusted opacity
    final IconData typeIcon = isStorage ? Icons.warehouse_outlined : Icons.local_shipping_outlined;
    
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22), // Consistent with LargeServiceCard
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceDetailsScreen(serviceId: service['id']),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [ // Refined shadow
              BoxShadow(
                color: typeColor.withOpacity(0.12), // Adjusted for subtlety
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.grey.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: typeColor.withOpacity(0.1), // Slightly more visible border
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(22),
                      topRight: Radius.circular(22),
                    ),
                    child: Container(
                      height: 190, // Slightly taller image area
                      width: double.infinity,
                      // decoration for placeholder or if no image is used
                      // decoration: BoxDecoration(
                      //   gradient: LinearGradient(
                      //     begin: Alignment.centerLeft, end: Alignment.centerRight,
                      //     colors: [Colors.grey.shade200, Colors.grey.shade300]
                      //   )
                      // ),
                      child: imageUrls.isNotEmpty
                          ? PageView.builder(
                              itemCount: imageUrls.length,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentImageIndex = index; // This might need to be card-specific if many cards have PageViews
                                });
                              },
                              itemBuilder: (context, index) {
                                return CachedNetworkImage(
                                  imageUrl: imageUrls[index],
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Center(child: SpinKitPulse(
                                    color: typeColor,
                                    size: 35.0, // Adjusted size
                                  )),
                                  errorWidget: (context, url, error) => Center(child: Icon(
                                    typeIcon,
                                    size: 50, // Adjusted size
                                    color: Colors.grey.shade300, // Softer error icon
                                  )),
                                );
                              },
                            )
                          : Center(child: Icon( // Placeholder when no images
                              typeIcon,
                              size: 60,
                              color: Colors.grey.shade300,
                            )),
                    ),
                  ),
                  
                  Positioned( // Gradient overlay for text readability on image
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 80, // Increased height for better text background
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(22), bottomRight: Radius.circular(22)), // Match parent radius
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [ Colors.black.withOpacity(0.65), Colors.transparent ], // Stronger gradient
                          stops: [0.0, 0.9]
                        ),
                      ),
                    ),
                  ),
                  
                  if (imageUrls.length > 1)
                    Positioned(
                      bottom: 12, // Adjusted position
                      left: 0, right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          imageUrls.length,
                          (index) => AnimatedContainer( // Added animation for selected indicator
                            duration: Duration(milliseconds: 300),
                            width: index == _currentImageIndex ? 10 : 8, // Highlight current
                            height:index == _currentImageIndex ? 10 : 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3), // Adjusted margin
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(index == _currentImageIndex ? 0.95 : 0.5), // Brighter current
                              border: Border.all(color: Colors.black.withOpacity(0.1), width: 0.5) // Subtle border for indicators
                            ),
                          ),
                        ),
                      ),
                    ),
                  
                  Positioned(
                    top: 16, left: 16, // Consistent padding
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), // Adjusted padding
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [typeGradientStart, typeGradientEnd],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: typeColor.withOpacity(0.35), // Adjusted shadow
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(typeIcon, color: Colors.white, size: 15), // Adjusted size
                          const SizedBox(width: 6),
                          Text(
                            type,
                            style: GoogleFonts.cairo(
                              textStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5, // Adjusted size
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  if (reviewCount > 0)
                    Positioned(
                      top: 16, right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // Adjusted padding
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95), // More opaque for readability
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15), // Adjusted shadow
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(color: _amber.withOpacity(0.4), width: 0.8), // Slightly stronger border
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.star_rounded, color: _amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: GoogleFonts.cairo(
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.black87, // Better contrast
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '($reviewCount)',
                              style: GoogleFonts.cairo(
                                textStyle: TextStyle(color: Colors.grey.shade600, fontSize: 11.5), // Adjusted style
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  Positioned( // Title on image
                    bottom: 12, right: 16, left: 16, // Consistent padding
                    child: Text(
                      title,
                      style: GoogleFonts.cairo(
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 17, // Increased size for title
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(offset: Offset(0, 1.5), blurRadius: 4, color: Colors.black87), // Stronger shadow
                          ],
                        ),
                      ),
                      maxLines: 2, // Allow two lines for title
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              Padding(
                padding: const EdgeInsets.all(16), // Consistent padding, was 18
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row( // Region and Price row
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center, // Align items vertically
                      children: [
                        Flexible(child: _buildInfoChip(Icons.location_on_outlined, region, _accentColor)), // Wrapped with Flexible
                        const SizedBox(width: 8), // Space between chips
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), // Adjusted padding
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [typeGradientStart.withOpacity(0.9), typeGradientEnd],
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12), // Consistent rounding
                            boxShadow: [
                              BoxShadow(
                                color: typeColor.withOpacity(0.25), // Adjusted shadow
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            '${price.toStringAsFixed(0)} ${service["currency"] ?? "دج"}', // Simplified price, currency added
                            style: GoogleFonts.cairo(
                              textStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5, // Adjusted size
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12), // Adjusted space
                    
                    if (type == 'نقل' && service.containsKey('location') && service['location'] != null && service['location'] is Map)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0), // Add padding if location chip exists
                        child: GestureDetector(
                          onTap: () {
                            final locationData = service['location'] as Map<String, dynamic>?;
                            final serviceLocation = safeGetLatLng(locationData);
                            if (serviceLocation != null) {
                              _openTransportLocationOnMap(
                                serviceLocation,
                                safeGetAddress(locationData, 'موقع خدمة النقل'),
                                service
                              );
                            }
                          },
                          child: _buildInfoChip(
                            Icons.pin_drop_outlined, 
                            _formatLocationAddress(service['location'] as Map<String, dynamic>?),
                            Colors.blue.shade700,
                          ),
                        ),
                      ),
                    // Price chip was here, moved to the row above.

                    const SizedBox(height: 4), // Adjusted spacing
                    Text(
                      description.isNotEmpty ? description : "لا يوجد وصف متوفر لهذه الخدمة.", // Default text if description is empty
                      style: GoogleFonts.cairo(
                        textStyle: TextStyle(
                          fontSize: 13.5, // Adjusted size
                          color: Colors.grey.shade700, // Darker grey
                          height: 1.4, // Adjusted line height
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16), // Adjusted space
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ServiceDetailsScreen(serviceId: service['id']),
                            ),
                          );
                        },
                        icon: Icon(Icons.read_more_rounded, size: 19), // Using a more generic icon
                        label: Text(
                          'عرض التفاصيل',
                          style: GoogleFonts.cairo( // Ensure GoogleFonts is used
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5, // Adjusted size
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: typeColor.withOpacity(0.9), // Slightly transparent
                          padding: const EdgeInsets.symmetric(vertical: 13), // Adjusted padding
                          elevation: 3, // Softer elevation
                          shadowColor: typeColor.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12), // Consistent rounding
                          ),
                        ),
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
  
  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Adjusted padding
      decoration: BoxDecoration(
        color: color.withOpacity(0.08), // Slightly less opacity for background
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8), // Slightly thicker border
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color), // Adjusted size
          const SizedBox(width: 6), // Adjusted space
          Flexible( // Allow label to wrap if needed
            child: Text(
              label,
              style: GoogleFonts.cairo(
                textStyle: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w600), // Adjusted size
              ),
              overflow: TextOverflow.ellipsis, // Prevent overflow
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitChasingDots( // Changed SpinKit type for variety
            color: _accentColor,
            size: 45.0, // Adjusted size
          ),
          const SizedBox(height: 24), // Adjusted space
          Text(
            'جاري تحميل الخدمات...',
            style: GoogleFonts.cairo(
              textStyle: TextStyle(
                fontSize: 16.5, // Adjusted size
                color: _primaryColor.withOpacity(0.85), // Softer color
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showSortingOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white, // Ensure background color
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24), // Increased radius
          topRight: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Padding( // Added padding around the content
          padding: const EdgeInsets.fromLTRB(20,20,20,24), // Consistent padding, more bottom padding
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ترتيب الخدمات حسب', // Slightly rephrased title
                style: GoogleFonts.cairo(
                  textStyle: TextStyle(
                    fontSize: 19, // Adjusted size
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Divider(color: Colors.grey.shade300, thickness: 0.8), // Softer divider
              const SizedBox(height: 8),
              _buildSortOption('التقييم', Icons.star_rounded), // Rounded icon
              _buildSortOption('السعر (من الأقل)', Icons.arrow_upward_rounded),
              _buildSortOption('السعر (من الأعلى)', Icons.arrow_downward_rounded),
              _buildSortOption('الأحدث', Icons.new_releases_rounded), // More descriptive icon
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildSortOption(String title, IconData icon) {
    final bool isSelected = _sortBy == title;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _sortBy = title;
            _activeFilters.removeWhere((filter) => filter.startsWith('ترتيب')); // Keep this logic
            if (title != 'التقييم') { // Default sort doesn't need an active filter chip
                 _activeFilters.add('ترتيب: $title');
            }
          });
          _updateFilters();
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(12), // Consistent rounding
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12), // Adjusted padding
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected ? _accentColor.withOpacity(0.12) : Colors.transparent, // Adjusted opacity
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? _accentColor : Colors.grey.shade600, // Adjusted unchecked color
                size: 22, // Adjusted size
              ),
              const SizedBox(width: 16), // Adjusted space
              Expanded( // Allow text to wrap
                child: Text(
                  title,
                  style: GoogleFonts.cairo(
                    textStyle: TextStyle(
                      color: isSelected ? _accentColor : Colors.black87, // Better contrast
                      fontSize: 15.5, // Adjusted size
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_outline_rounded, // Outlined check
                  color: _accentColor,
                  size: 22, // Adjusted size
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAccountMenu(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding( // Add overall padding
            padding: const EdgeInsets.symmetric(vertical:16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding( // Padding for user info
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 28, // Slightly larger
                      backgroundColor: _primaryColor.withOpacity(0.08),
                      backgroundImage: user?.profileImageUrl != null && user!.profileImageUrl.isNotEmpty
                          ? CachedNetworkImageProvider(user.profileImageUrl) // Use provider for CircleAvatar
                          : null,
                      child: user?.profileImageUrl == null || user!.profileImageUrl.isEmpty
                          ? Icon(Icons.person_outline_rounded, color: _primaryColor, size: 30)
                          : null,
                    ),
                    title: Text(
                      user?.fullName ?? 'المستخدم',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87),
                    ),
                    subtitle: Text(
                      user?.email ?? '',
                      style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ),
                ),
                Divider(indent: 20, endIndent: 20, color: Colors.grey.shade200),
                ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 28, vertical: 4), // Adjusted padding
                  leading: Icon(Icons.person_outline_rounded, color: _primaryColor, size: 24),
                  title: Text('حسابي', style: GoogleFonts.cairo(fontSize: 16, color: Colors.black87)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => AccountProfileScreen()));
                  },
                ),
                ListTile(
                   contentPadding: EdgeInsets.symmetric(horizontal: 28, vertical: 4),
                  leading: Icon(Icons.settings_outlined, color: _primaryColor, size: 24),
                  title: Text('الإعدادات', style: GoogleFonts.cairo(fontSize: 16, color: Colors.black87)),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to settings page
                  },
                ),
                 SizedBox(height: 8), // Space before logout
                ListTile(
                   contentPadding: EdgeInsets.symmetric(horizontal: 28, vertical: 4),
                  leading: Icon(Icons.logout_rounded, color: Colors.red.shade600, size: 24),
                  title: Text('تسجيل الخروج', style: GoogleFonts.cairo(fontSize: 16, color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutConfirmDialog(context);
                  },
                ),
                 SizedBox(height: 16), // Bottom padding
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLogoutConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), // Increased radius
        clipBehavior: Clip.antiAlias,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(vertical: 24), // Adjusted padding
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFFC62828)], // Slightly darker red
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.logout_rounded, size: 48, color: Colors.white), // Adjusted size
                    SizedBox(height: 12),
                    Text(
                      'تسجيل الخروج',
                      style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(24), // Adjusted padding
                child: Column(
                  children: [
                    Text(
                      'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(fontSize: 16.5, color: Colors.black87, height: 1.4), // Adjusted style
                    ),
                    SizedBox(height: 28), // Adjusted space
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 13), // Adjusted padding
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Consistent rounding
                              side: BorderSide(color: Colors.grey.shade400, width: 1.2), // Slightly thicker border
                            ),
                            child: Text(
                              'إلغاء',
                              style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        SizedBox(width: 12), // Adjusted space
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await Provider.of<AuthService>(context, listen: false).logout();
                              if (mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => BiLinkHomePage()), // Ensure BiLinkHomePage is correct
                                  (route) => false,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700, // Darker red for confirm
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4, // Added elevation
                            ),
                            child: Text(
                              'تسجيل الخروج',
                              style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildRegionDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0), // Removed horizontal, handled by FilterSection
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12), // Internal padding for dropdown
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 1.2), // Slightly thicker border
          borderRadius: BorderRadius.circular(12), // Consistent rounding
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: _selectedRegion,
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: _primaryColor, size: 26), // Rounded icon
            elevation: 16, // Default is fine
            // padding: const EdgeInsets.symmetric(horizontal: 12), // Moved to Container
            borderRadius: BorderRadius.circular(12), // Consistent rounding
            items: _regions.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  value,
                  style: GoogleFonts.cairo(
                    textStyle: TextStyle(
                      color: _selectedRegion == value ? _secondaryColor : Colors.black87,
                      fontWeight: _selectedRegion == value ? FontWeight.bold : FontWeight.normal,
                      fontSize: 15, // Adjusted size
                    ),
                  ),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedRegion = newValue;
                  _activeFilters.removeWhere((filter) => filter.startsWith('المنطقة'));
                  if (newValue != 'الكل') {
                    _activeFilters.add('المنطقة: $newValue');
                  }
                });
                _updateFilters(); 
                // Consider if closing the drawer is desired here: Navigator.pop(context);
              }
            },
          ),
        ),
      ),
    );
  }
  
  String _formatLocationAddress(Map<String, dynamic>? location) {
    if (location == null) return 'موقع غير محدد';
    return safeGetAddress(location, 'موقع غير محدد');
  }
}

// _SliverAppBarDelegate is not actively used in the provided main build method for the header.
// If it's used elsewhere or intended for a different header configuration, it can be kept.
// For this refinement, I'll leave it as is since it doesn't affect the visible UI of ClientHomePage directly.
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar, this._container);

  final TabBar _tabBar;
  final Container _container; // This container might be for background/styling

  @override
  double get minExtent => 70; // Adjust if TabBar height or surrounding elements change
  @override
  double get maxExtent => 70; // Same as minExtent for a fixed height header part

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // The original implementation implies _container is a background and _tabBar is overlaid.
    // Ensure good contrast and that it fits visually with the rest of the SliverAppBar.
    return Container(
      color: Colors.white, // Or a theme color from the main page
      child: Stack(
        children: [
          Positioned.fill(child: _container), // Assuming _container is styled
          Center(child: _tabBar), // Ensure TabBar is styled appropriately
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return _tabBar != oldDelegate._tabBar || _container != oldDelegate._container; // Rebuild if TabBar or container changes
  }
}