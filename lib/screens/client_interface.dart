import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:bilink/screens/service_details_screen.dart';
import 'package:bilink/screens/transport_service_map.dart';
import 'package:bilink/services/location_synchronizer.dart'; // Importar el sincronizador
import 'package:bilink/screens/storage_locations_map_screen.dart';
import 'package:bilink/screens/account_profile_screen.dart';
import 'package:bilink/services/chat_service.dart';
import 'package:bilink/services/auth_service.dart';
import 'package:bilink/widgets/notification_badge.dart';
import 'package:bilink/models/home_page.dart';
import 'package:bilink/screens/chat_list_screen.dart';
import 'package:bilink/painters/logistics_painters.dart'; // استيراد رسامي الزخارف اللوجستية

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadServices();
    
    // استخدام رسالة النظام لضبط شريط الحالة
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

  // استجابة لتغيير التبويب
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

  // تحميل الخدمات من Firestore
  Future<void> _loadServices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // استعلام أساسي لجلب جميع الخدمات النشطة
      Query query = FirebaseFirestore.instance
          .collection('services')
          .where('isActive', isEqualTo: true);

      // تطبيق فلتر المنطقة
      if (_selectedRegion != 'الكل') {
        query = query.where('region', isEqualTo: _selectedRegion);
      }

      // تطبيق فلتر نوع الخدمة
      if (_selectedType != 'الكل') {
        query = query.where('type', isEqualTo: _selectedType);
      }

      // تنفيذ الاستعلام
      final querySnapshot = await query.get();

      final List<Map<String, dynamic>> servicesList = [];

      // تحويل وثائق Firestore إلى قائمة من البيانات
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // إضافة معرف الوثيقة

        // تطبيق فلتر نطاق السعر (لا يمكن تطبيقه مباشرة في الاستعلام)
        final price = data['price'] as num? ?? 0;
        if (price >= _priceRange.start && price <= _priceRange.end) {
          servicesList.add(data);
        }
      }

      // فرز النتائج حسب الاختيار
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

      // عرض رسالة خطأ للمستخدم
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تحميل الخدمات، يرجى المحاولة مرة أخرى'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  // تحديث خيارات الفلتر وإعادة تحميل البيانات
  void _updateFilters() {
    _loadServices();
  }  // توجيه المستخدم إلى صفحة مواقع التخزين
  void _navigateToStorageLocationsMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => StorageLocationsMapScreen()),
    );
  }
  
  // توجيه المستخدم إلى خريطة خدمات النقل مع مزامنة البيانات
  Future<void> _navigateToTransportServicesMap() async {
    try {
      // عرض مؤشر التحميل
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20, 
                height: 20, 
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(_secondaryColor),
                ),
              ),
              SizedBox(width: 12),
              Text('جاري تحميل خدمات النقل...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
      
      // استخدام مزامن المواقع لتحديث بيانات المواقع
      final synchronizer = LocationSynchronizer();
      await synchronizer.synchronizeTransportLocations();
      
      // التنقل إلى شاشة خريطة النقل
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TransportServiceMapScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تحميل خدمات النقل. حاول مرة أخرى.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // الحصول على حجم الشاشة
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _buildSideDrawer(),
      body: SafeArea(
        child: Stack(
          children: [
            // خلفية مخصصة مع نمط
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: SvgPicture.asset(
                  'assets/images/pattern.svg',
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    _primaryColor.withOpacity(0.03),
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),              // رأس الصفحة المنحني مع الخلفية المتدرجة وزخارف لوجستية
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: screenSize.height * 0.32,
              child: Stack(
                children: [
                  // الخلفية الرئيسية مع تدرج لوني متطور
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
                        bottomLeft: Radius.circular(40),
                        bottomRight: Radius.circular(40),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.4),
                          blurRadius: 25,
                          offset: const Offset(0, 12),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  
                  // زخارف لوجستية - خطوط متقطعة تشبه مسارات الشحن
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
                  
                  // زخرفة دائرية في الأسفل
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
                  
                  // زخرفة نقاط متصلة تشبه شبكة لوجستية
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
            
            // محتوى الصفحة
            NestedScrollView(
              controller: _scrollController,
              headerSliverBuilder: (context, innerBoxScrolled) {
                return [
                  // رأس الصفحة
                  SliverAppBar(
                    expandedHeight: 180,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.only(left: 20, bottom: 16, right: 20),
                      centerTitle: true,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [                              Flexible(  // Added Flexible to prevent overflow
                            child: Text(
                              'الخدمات',
                              style: GoogleFonts.cairo(
                                textStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,  // Reduced font size from 22 to 18
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black26,
                                      blurRadius: 5,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              overflow: TextOverflow.ellipsis,  // Added text overflow handling
                            ),
                          ),
                          Row(
                            children: [
                              // زر الفلترة
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: IconButton(
                                  onPressed: _showSortingOptions,
                                  icon: const Icon(Icons.filter_list, color: Colors.white),
                                  tooltip: 'ترتيب الخدمات',
                                ),
                              ),
                              const SizedBox(width: 10),
                              // زر تنبيهات المحادثات
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: StreamBuilder<int>(
                                  stream: ChatService(FirebaseAuth.instance.currentUser?.uid ?? '').getUnreadMessageCount(),
                                  builder: (context, snapshot) {
                                    final unreadCount = snapshot.data ?? 0;
                                    
                                    return Stack(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.chat_outlined, color: Colors.white),
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
                                            right: 8,
                                            top: 8,
                                            child: NotificationBadge(count: unreadCount),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              // زر الملف الشخصي
                              Consumer<AuthService>(
                                builder: (context, authService, _) {
                                  final user = authService.currentUser;
                                  return GestureDetector(
                                    onTap: () {
                                      _showAccountMenu(context);
                                    },
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: user?.profileImageUrl != null && user!.profileImageUrl.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: user.profileImageUrl,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => Container(
                                                  color: Colors.grey[300],
                                                  child: Icon(
                                                    Icons.person,
                                                    color: _primaryColor,
                                                    size: 24,
                                                  ),
                                                ),
                                                errorWidget: (context, url, error) => Container(
                                                  color: _primaryColor.withOpacity(0.2),
                                                  child: Icon(
                                                    Icons.person,
                                                    color: _primaryColor,
                                                    size: 24,
                                                  ),
                                                ),
                                              )
                                            : Container(
                                                color: _primaryColor.withOpacity(0.2),
                                                child: Icon(
                                                  Icons.person,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
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
                          // خلفية إضافية للعنوان
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [_primaryColor, _accentColor],
                              ),
                            ),
                          ),
                          // زخرفة للخلفية
                          Positioned(
                            right: -50,
                            top: -50,
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Positioned(
                            left: -30,
                            bottom: -30,
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          // شعار الخدمات
                          Align(
                            alignment: Alignment.center,
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 60), // تقليل التباعد السفلي من 80 الى 60
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min, // اضافة لضمان أن يأخذ العمود أقل حجم ممكن
                                children: [
                                  Consumer<AuthService>(
                                    builder: (context, authService, _) {
                                      final user = authService.currentUser;
                                      return Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            user?.fullName ?? 'مرحباً بك',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 20, // تقليل حجم الخط من 22 الى 20
                                              fontWeight: FontWeight.bold,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black26,
                                                  blurRadius: 5,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(height: 5),
                                          Text(
                                            user?.email ?? '',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.9),
                                              fontSize: 14,
                                            ),
                                          ),
                                          SizedBox(height: 10), // تقليل المساحة من 20 الى 10
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              SvgPicture.asset(
                                                'assets/images/truck.svg',
                                                width: 30,
                                                height: 30, // تقليل حجم الأيقونة
                                                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                              ),
                                              const SizedBox(width: 10), // تقليل المسافة بين الأيقونات
                                              SvgPicture.asset(
                                                'assets/images/warehouse.svg',
                                                width: 30, // تقليل حجم الأيقونة
                                                height: 35,
                                                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
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
                  
                  // قائمة التبويبات
                  SliverPersistentHeader(
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        controller: _tabController,
                        indicatorColor: _secondaryColor,
                        indicatorWeight: 3,
                        labelColor: _primaryColor,
                        unselectedLabelColor: Colors.grey,
                        labelStyle: GoogleFonts.cairo(
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        unselectedLabelStyle: GoogleFonts.cairo(
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        tabs: [
                          Tab(
                            icon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SvgPicture.asset(
                                  'assets/images/warehouse.svg',
                                  width: 20,
                                  height: 20,
                                  colorFilter: ColorFilter.mode(
                                    _tabController.index == 0 ? _primaryColor : Colors.grey,
                                    BlendMode.srcIn,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text('خدمات التخزين'),
                              ],
                            ),
                          ),
                          Tab(
                            icon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SvgPicture.asset(
                                  'assets/images/truck.svg',
                                  width: 20,
                                  height: 20,
                                  colorFilter: ColorFilter.mode(
                                    _tabController.index == 1 ? _primaryColor : Colors.grey,
                                    BlendMode.srcIn,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text('خدمات النقل'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 5,
                        ),
                      ),
                    ),
                    pinned: true,
                  ),
                  
                  // القسم العلوي المميز
                  SliverToBoxAdapter(
                    child: _buildFeaturedSection(),
                  ),
                  
                  // عرض الفلاتر النشطة
                  if (_activeFilters.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 5),
                        child: _buildActiveFilters(),
                      ),
                    ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  // قسم خدمات التخزين
                  _isLoading
                      ? _buildLoadingView()
                      : _buildServicesListView('تخزين'),
                  
                  // قسم خدمات النقل
                  _isLoading
                      ? _buildLoadingView()
                      : _buildServicesListView('نقل'),
                ],
              ),
            ),
          ],
        ),
      ),
      
      // زر التنقل العائم
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // التوجه إلى الخريطة حسب نوع الخدمة المحددة
          if (_selectedType == 'تخزين') {
            _navigateToStorageLocationsMap();
          } else {
            _navigateToTransportServicesMap();
          }
        },
        backgroundColor: _secondaryColor,
        tooltip: 'عرض الخريطة',
        child: const Icon(Icons.map),
      ),
    );
  }
  
  // بناء قسم الميزات في أعلى الصفحة
  Widget _buildFeaturedSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                'الخدمات الرئيسية',
                style: GoogleFonts.cairo(
                  textStyle: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 20),
          // خدمتي النقل والتخزين كأيقونتين كبيرتين
          Row(
            children: [
              // خدمة التخزين
              Expanded(
                child: _buildLargeServiceCard(
                  title: 'خدمة التخزين',
                  icon: 'assets/images/warehouse.svg',
                  color: _accentColor,
                  onTap: () {
                    _navigateToStorageLocationsMap();
                  },
                ),
              ),
              const SizedBox(width: 15),
              // خدمة النقل
              Expanded(
                child: _buildLargeServiceCard(
                  title: 'خدمة النقل',
                  icon: 'assets/images/truck.svg',
                  color: _secondaryColor,          onTap: () {
                    _navigateToTransportServicesMap();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Divider(
            color: Colors.grey.withOpacity(0.3),
            thickness: 1,
          ),
        ],
      ),
    );
  }
  
  // بناء بطاقة خدمة كبيرة
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
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 180,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color,
                color.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                icon,
                width: 60,
                height: 60,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
              const SizedBox(height: 15),
              Text(
                title,
                style: GoogleFonts.cairo(
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
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
  
  // بناء القائمة الجانبية
  Widget _buildSideDrawer() {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // رأس القائمة الجانبية
            Container(
              padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_primaryColor, _accentColor],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'جميع الخدمات',
                        style: GoogleFonts.cairo(
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'تصفية وعرض جميع الخدمات المتاحة',
                    style: GoogleFonts.cairo(
                      textStyle: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // قسم الفلاتر
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // فلتر نوع الخدمة
                  _buildFilterSection(
                    title: 'نوع الخدمة',
                    icon: Icons.category,
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
                  
                  const Divider(),
                  
                  // فلتر المنطقة/الولاية
                  _buildFilterSection(
                    title: 'المنطقة',
                    icon: Icons.location_on,
                    child: Column(
                      children: [
                        _buildFilterOption(
                          title: 'الكل',
                          isSelected: _selectedRegion == 'الكل',
                          onTap: () {
                            setState(() {
                              _selectedRegion = 'الكل';
                              _activeFilters.removeWhere((filter) => filter.startsWith('المنطقة'));
                            });
                            _updateFilters();
                            Navigator.pop(context);
                          },
                        ),
                        _buildFilterOption(
                          title: 'الجزائر العاصمة',
                          isSelected: _selectedRegion == 'الجزائر العاصمة',
                          onTap: () {
                            setState(() {
                              _selectedRegion = 'الجزائر العاصمة';
                              _activeFilters.removeWhere((filter) => filter.startsWith('المنطقة'));
                              _activeFilters.add('المنطقة: الجزائر العاصمة');
                            });
                            _updateFilters();
                            Navigator.pop(context);
                          },
                        ),
                        _buildFilterOption(
                          title: 'وهران',
                          isSelected: _selectedRegion == 'وهران',
                          onTap: () {
                            setState(() {
                              _selectedRegion = 'وهران';
                              _activeFilters.removeWhere((filter) => filter.startsWith('المنطقة'));
                              _activeFilters.add('المنطقة: وهران');
                            });
                            _updateFilters();
                            Navigator.pop(context);
                          },
                        ),
                        _buildFilterOption(
                          title: 'قسنطينة',
                          isSelected: _selectedRegion == 'قسنطينة',
                          onTap: () {
                            setState(() {
                              _selectedRegion = 'قسنطينة';
                              _activeFilters.removeWhere((filter) => filter.startsWith('المنطقة'));
                              _activeFilters.add('المنطقة: قسنطينة');
                            });
                            _updateFilters();
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const Divider(),
                  
                  // فلتر السعر
                  _buildFilterSection(
                    title: 'نطاق السعر',
                    icon: Icons.attach_money,
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        RangeSlider(
                          values: _priceRange,
                          min: 0,
                          max: 10000,
                          divisions: 20,
                          activeColor: _primaryColor,
                          inactiveColor: Colors.grey.shade300,
                          labels: RangeLabels(
                            '${_priceRange.start.round()} دج',
                            '${_priceRange.end.round()} دج',
                          ),
                          onChanged: (RangeValues values) {
                            setState(() {
                              _priceRange = values;
                            });
                          },
                          onChangeEnd: (RangeValues values) {
                            setState(() {
                              _activeFilters.removeWhere((filter) => filter.startsWith('السعر'));
                              _activeFilters.add(
                                'السعر: ${_priceRange.start.round()} - ${_priceRange.end.round()} دج',
                              );
                            });
                            _updateFilters();
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_priceRange.start.round()} دج',
                                style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${_priceRange.end.round()} دج',
                                style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const Divider(),
                  
                  // فلتر المسافة
                  _buildFilterSection(
                    title: 'المسافة',
                    icon: Icons.social_distance,
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
                  
                  const Divider(),
                  
                  // زر تطبيق الفلاتر
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'تطبيق الفلاتر',
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
  
  // بناء قسم فلتر في القائمة الجانبية
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
            Icon(icon, color: _primaryColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.cairo(
                textStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
  
  // بناء خيار فلتر في القائمة الجانبية
  Widget _buildFilterOption({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? _secondaryColor : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.cairo(
                textStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? _secondaryColor : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // بناء بطاقة ميزة في الشريط العلوي (لم تعد مستخدمة)
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
  
  // بناء الفلاتر النشطة
  Widget _buildActiveFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, size: 18, color: _primaryColor),
              const SizedBox(width: 8),
              Text(
                'الفلاتر النشطة',
                style: GoogleFonts.cairo(
                  textStyle: TextStyle(
                    fontSize: 14,
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
                    _selectedType = 'الكل';
                    _sortBy = 'التقييم';
                    _priceRange = RangeValues(0, 10000);
                  });
                  _updateFilters();
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                child: Text(
                  'مسح الكل',
                  style: GoogleFonts.cairo(
                    textStyle: TextStyle(color: Colors.red[700], fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _activeFilters.map((filter) {
              return Chip(
                label: Text(
                  filter,
                  style: GoogleFonts.cairo(
                    textStyle: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
                backgroundColor: _accentColor,
                deleteIconColor: Colors.white,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onDeleted: () {
                  setState(() {
                    _activeFilters.remove(filter);
                    
                    // تحديث الفلاتر المناسبة
                    if (filter.startsWith('النوع')) {
                      _selectedType = 'الكل';
                    } else if (filter.startsWith('المنطقة')) {
                      _selectedRegion = 'الكل';
                    } else if (filter.startsWith('السعر')) {
                      _priceRange = RangeValues(0, 10000);
                    }
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
  
  // بناء قائمة الخدمات
  Widget _buildServicesListView(String type) {
    final filteredServices = _servicesList.where((service) => service['type'] == type).toList();
    
    if (filteredServices.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                type == 'تخزين' ? 'assets/images/warehouse.svg' : 'assets/images/truck.svg',
                width: 80,
                height: 80,
                colorFilter: ColorFilter.mode(Colors.grey[400]!, BlendMode.srcIn),
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد خدمات متاحة',
                style: GoogleFonts.cairo(
                  textStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'جرّب تغيير معايير البحث أو العودة لاحقاً',
                style: GoogleFonts.cairo(
                  textStyle: TextStyle(color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadServices,
                icon: const Icon(Icons.refresh),
                label: const Text('تحديث'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 5, 20, 100), // إضافة مساحة أسفل القائمة للزر العائم
      itemCount: filteredServices.length,
      itemBuilder: (context, index) {
        final service = filteredServices[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: _buildModernServiceCard(service),
        );
      },
    );
  }
  
  // بناء بطاقة خدمة بتصميم عصري للخدمات اللوجستية
  Widget _buildModernServiceCard(Map<String, dynamic> service) {
    final String title = service['title'] ?? 'خدمة بدون عنوان';
    final String type = service['type'] ?? 'غير محدد';
    final String region = service['region'] ?? 'غير محدد';
    final double price = (service['price'] as num?)?.toDouble() ?? 0.0;
    final double rating = (service['rating'] as num?)?.toDouble() ?? 0.0;
    final int reviewCount = (service['reviewCount'] as num?)?.toInt() ?? 0;
    
    // معالجة الصور لجميع الخدمات
    List<dynamic> imageUrls = [];
    
    // جلب جميع الصور المتاحة للخدمة
    if (service['imageUrls'] != null && service['imageUrls'] is List) {
      imageUrls = List<dynamic>.from(service['imageUrls']);
    }
    
    // Debug print for service images
    print('ClientInterface: Service ${service['id']} has ${imageUrls.length} images: $imageUrls');
    
    // إضافة صور المركبة لخدمات النقل إذا كانت متوفرة
    if (type == 'نقل' && service['vehicle'] != null && service['vehicle'] is Map) {
      if ((service['vehicle'] as Map).containsKey('imageUrls')) {
        final vehicleImgs = service['vehicle']['imageUrls'];
        if (vehicleImgs is List && vehicleImgs.isNotEmpty) {
          // إضافة صور المركبة إلى قائمة الصور الحالية
          for (var img in vehicleImgs) {
            if (!imageUrls.contains(img)) {
              imageUrls.add(img);
            }
          }
          print('ClientInterface: Added vehicle images, total now: ${imageUrls.length} images');
        }
      }
    }
    
    // إضافة صور موقع التخزين لخدمات التخزين إذا كانت متوفرة
    if (type == 'تخزين' && service['storageLocationImageUrls'] != null) {
      final locationImgs = service['storageLocationImageUrls'];
      if (locationImgs is List && locationImgs.isNotEmpty) {
        // إضافة صور موقع التخزين إلى قائمة الصور الحالية
        for (var img in locationImgs) {
          if (!imageUrls.contains(img)) {
            imageUrls.add(img);
          }
        }
        print('ClientInterface: Added storage location images, total now: ${imageUrls.length} images');
      }
    }
    
    final String description = service['description'] ?? '';
    
    // ألوان مخصصة لكل نوع خدمة
    final bool isStorage = type == 'تخزين';
    final Color typeColor = isStorage ? _accentColor : _deepOrange;
    final Color typeGradientStart = isStorage ? _accentColor : _secondaryColor;
    final Color typeGradientEnd = isStorage ? _accentColor.withOpacity(0.7) : _deepOrange;
    final IconData typeIcon = isStorage ? Icons.warehouse_outlined : Icons.local_shipping_outlined;
    
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
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
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: typeColor.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: typeColor.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // صورة الخدمة
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: const BoxDecoration(                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [const Color(0x1F000000), const Color(0x42000000)],
                        ),
                      ),
                      child: imageUrls.isNotEmpty
                          ? PageView.builder(
                              itemCount: imageUrls.length,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentImageIndex = index;
                                });
                              },
                              itemBuilder: (context, index) {
                                return CachedNetworkImage(
                                  imageUrl: imageUrls[index],
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => SpinKitPulse(
                                    color: typeColor,
                                    size: 30,
                                  ),
                                  errorWidget: (context, url, error) => Icon(
                                    typeIcon,
                                    size: 60,
                                    color: Colors.grey[400],
                                  ),
                                );
                              },
                            )
                          : Icon(
                              typeIcon,
                              size: 60,
                              color: Colors.grey[400],
                            ),
                    ),
                  ),
                  
                  // شريط مزدوج شفاف تحت الصورة لإضافة عمق
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            const Color(0xB3000000), // استخدام لون ثابت مع قيمة ألفا تساوي 0.7 (حوالي 0xB3)
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // مؤشرات الصفحات (Page Indicators)
                  if (imageUrls.length > 1)
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          imageUrls.length,
                          (index) => Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(
                                index == _currentImageIndex ? 0.9 : 0.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  
                  // شريط نوع الخدمة بتصميم عصري
                  Positioned(
                    top: 15,
                    left: 15,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [typeGradientStart, typeGradientEnd],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: typeColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(typeIcon, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            type,
                            style: GoogleFonts.cairo(
                              textStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // شريط التقييم بتصميم عصري
                  if (reviewCount > 0)
                    Positioned(
                      top: 15,
                      right: 15,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: _amber.withOpacity(0.3),
                            width: 1,
                          ),
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
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '($reviewCount)',
                              style: GoogleFonts.cairo(
                                textStyle: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                  // إضافة اسم الخدمة على الصورة
                  Positioned(
                    bottom: 10,
                    right: 15,
                    left: 15,
                    child: Text(
                      title,
                      style: GoogleFonts.cairo(
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 3,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              // معلومات الخدمة بتصميم عصري
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // المنطقة والسعر
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoChip(
                          Icons.location_on_outlined,
                          region,
                          _accentColor,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                typeGradientStart.withOpacity(0.8),
                                typeGradientEnd.withOpacity(0.9),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: typeColor.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '$price ${service["currency"] ?? "دينار جزائري"}',
                            style: GoogleFonts.cairo(
                              textStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),                    // تفاصيل إضافية
                    Row(
                      children: [
                        _buildInfoChip(Icons.attach_money, '$price', Colors.green[700]!),
                        const SizedBox(width: 8),
                        // إضافة معلومات الموقع إذا كانت متوفرة لخدمة النقل
                        if (type == 'نقل' && service.containsKey('location') && service['location'] != null && service['location'] is Map)
                          _buildInfoChip(
                            Icons.location_on, 
                            service['location']['address'] != null && service['location']['address'].toString().isNotEmpty
                                ? service['location']['address'].toString().length > 15
                                    ? '${service['location']['address'].toString().substring(0, 15)}...'
                                    : service['location']['address']
                                : 'موقع متاح',
                            Colors.blue[700]!,
                          ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    
                    // الوصف المختصر
                    Text(
                      description,
                      style: GoogleFonts.cairo(
                        textStyle: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.3,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    
                    // زر العرض بتصميم عصري
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
                        icon: Icon(
                          type == 'تخزين' ? Icons.warehouse_outlined : Icons.local_shipping_outlined,
                          size: 18,
                        ),
                        label: const Text(
                          'عرض التفاصيل',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: typeColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 2,
                          shadowColor: typeColor.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
  
  // إنشاء رقاقات المعلومات
  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.cairo(
              textStyle: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
  
  // عرض الشاشة أثناء التحميل
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitCircle(
            color: _accentColor,
            size: 50.0,
          ),
          const SizedBox(height: 20),
          Text(
            'جاري تحميل الخدمات...',
            style: GoogleFonts.cairo(
              textStyle: TextStyle(
                fontSize: 16,
                color: _primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // عرض خيارات الترتيب
  void _showSortingOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ترتيب الخدمات',
                style: GoogleFonts.cairo(
                  textStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Divider(),
              _buildSortOption('التقييم', Icons.star),
              _buildSortOption('السعر (من الأقل)', Icons.arrow_upward),
              _buildSortOption('السعر (من الأعلى)', Icons.arrow_downward),
              _buildSortOption('الأحدث', Icons.timer),
            ],
          ),
        );
      },
    );
  }
  
  // بناء خيار الترتيب
  Widget _buildSortOption(String title, IconData icon) {
    final bool isSelected = _sortBy == title;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _sortBy = title;
            if (title != 'التقييم') {
              _activeFilters.removeWhere((filter) => filter.startsWith('ترتيب'));
              _activeFilters.add('ترتيب: $title');
            }
          });
          _updateFilters();
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isSelected ? _accentColor.withOpacity(0.1) : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? _accentColor : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 15),
              Text(
                title,
                style: GoogleFonts.cairo(
                  textStyle: TextStyle(
                    color: isSelected ? _accentColor : Colors.black,
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              const Spacer(),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: _accentColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // عرض قائمة الحساب
  void _showAccountMenu(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // معلومات المستخدم
                ListTile(
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: _primaryColor.withOpacity(0.1),
                    backgroundImage: user?.profileImageUrl != null && user!.profileImageUrl.isNotEmpty
                        ? NetworkImage(user.profileImageUrl)
                        : null,
                    child: user?.profileImageUrl == null || user!.profileImageUrl.isEmpty
                        ? Icon(Icons.person, color: _primaryColor)
                        : null,
                  ),
                  title: Text(
                    user?.fullName ?? 'المستخدم',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(user?.email ?? ''),
                ),
                Divider(),
                // خيارات الحساب
                ListTile(
                  leading: Icon(Icons.person_outline, color: _primaryColor),
                  title: Text('حسابي'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AccountProfileScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.settings_outlined, color: _primaryColor),
                  title: Text('الإعدادات'),
                  onTap: () {
                    Navigator.pop(context);
                    // يمكن إضافة توجيه لصفحة الإعدادات هنا
                  },
                ),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('تسجيل الخروج'),
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutConfirmDialog(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // عرض خيارات تسجيل الخروج
  void _showLogoutConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // جزء علوي
              Container(
                padding: EdgeInsets.symmetric(vertical: 20),
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      size: 50,
                      color: Colors.white,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'تسجيل الخروج',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // محتوى
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    SizedBox(height: 25),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              'إلغاء',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await Provider.of<AuthService>(
                                context,
                                listen: false,
                              ).logout();
                              if (mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => BiLinkHomePage(),
                                  ),
                                  (route) => false,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'تسجيل الخروج',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
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
}

// مكون مساعد للحفاظ على شريط التبويبات
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar, this._container);

  final TabBar _tabBar;
  final Container _container;

  @override
  double get minExtent => 70;
  @override
  double get maxExtent => 70;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          _container,
          Positioned.fill(
            child: Center(
              child: _tabBar,
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return true;
  }
}
