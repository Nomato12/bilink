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
import 'package:bilink/screens/storage_locations_map_screen.dart';
import 'package:bilink/screens/account_profile_screen.dart';
import 'package:bilink/services/chat_service.dart';
import 'package:bilink/services/auth_service.dart';
import 'package:bilink/widgets/notification_badge.dart';
import 'package:bilink/models/home_page.dart';
import 'package:bilink/screens/chat_list_screen.dart';

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
  
  // الألوان الأساسية
  final Color _primaryColor = const Color(0xFF1A237E); // لون أزرق داكن 
  final Color _secondaryColor = const Color(0xFFFF6F00); // لون برتقالي للتباين
  final Color _accentColor = const Color(0xFF4A148C); // لون أرجواني للتفاصيل

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
  }

  // توجيه المستخدم إلى صفحة مواقع التخزين
  void _navigateToStorageLocationsMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => StorageLocationsMapScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // الحصول على حجم الشاشة
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
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
            ),
            
            // رأس الصفحة المنحني مع الخلفية المتدرجة
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: screenSize.height * 0.3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [_primaryColor, _accentColor],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(35),
                    bottomRight: Radius.circular(35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
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
                        children: [
                          Flexible(  // Added Flexible to prevent overflow
                            child: Text(
                              'الخدمات اللوجستية',
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
                          // شعار الخدمات اللوجستية
                          Align(
                            alignment: Alignment.center,
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 80),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
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
                                              fontSize: 22,
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
                                          SizedBox(height: 20),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              SvgPicture.asset(
                                                'assets/images/truck.svg',
                                                width: 35,
                                                height: 35,
                                                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                              ),
                                              const SizedBox(width: 15),
                                              SvgPicture.asset(
                                                'assets/images/warehouse.svg',
                                                width: 35,
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TransportServiceMapScreen(),
              ),
            );
          }
        },
        backgroundColor: _secondaryColor,
        child: const Icon(Icons.map),
        tooltip: 'عرض الخريطة',
      ),
    );
  }
  
  // بناء قسم الميزات في أعلى الصفحة
  Widget _buildFeaturedSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                'ابحث بسهولة',
                style: GoogleFonts.cairo(
                  textStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFeatureCard(
                  title: 'تتبع الشحنات',
                  color: const Color(0xFF2E7D32), // أخضر
                  icon: 'assets/images/tracking.svg',
                  onTap: () {
                    // تنفيذ وظيفة تتبع الشحنات
                  },
                ),
                _buildFeatureCard(
                  title: 'مراكز الخدمة',
                  color: const Color(0xFF673AB7), // أرجواني
                  icon: 'assets/images/logistics_hub.svg',
                  onTap: () {
                    // عرض مراكز الخدمة
                  },
                ),
                _buildFeatureCard(
                  title: 'التخزين',
                  color: const Color(0xFF1565C0), // أزرق
                  icon: 'assets/images/warehouse.svg',
                  onTap: () {
                    _navigateToStorageLocationsMap();
                  },
                ),
                _buildFeatureCard(
                  title: 'النقل',
                  color: const Color(0xFFFF6F00), // برتقالي
                  icon: 'assets/images/truck.svg',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TransportServiceMapScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Divider(
            color: Colors.grey.withOpacity(0.3),
            thickness: 1,
          ),
        ],
      ),
    );
  }
  
  // بناء بطاقة ميزة في الشريط العلوي
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
  
  // بناء بطاقة خدمة بتصميم عصري
  Widget _buildModernServiceCard(Map<String, dynamic> service) {
    final String title = service['title'] ?? 'خدمة بدون عنوان';
    final String type = service['type'] ?? 'غير محدد';
    final String region = service['region'] ?? 'غير محدد';
    final double price = (service['price'] as num?)?.toDouble() ?? 0.0;
    final double rating = (service['rating'] as num?)?.toDouble() ?? 0.0;
    final int reviewCount = (service['reviewCount'] as num?)?.toInt() ?? 0;
    
    // معالجة الصور لخدمات النقل
    List<dynamic> imageUrls = service['imageUrls'] ?? [];
    if (type == 'نقل' &&
        (imageUrls.isEmpty ||
            (imageUrls.length == 1 &&
                (imageUrls[0] == null || imageUrls[0].toString().isEmpty)))) {
      if (service['vehicle'] != null &&
          service['vehicle'] is Map &&
          (service['vehicle'] as Map).containsKey('imageUrls')) {
        final vehicleImgs = service['vehicle']['imageUrls'];
        if (vehicleImgs is List && vehicleImgs.isNotEmpty) {
          imageUrls = vehicleImgs;
        }
      }
    }
    
    final String description = service['description'] ?? '';
    final Color typeColor = type == 'تخزين' ? _primaryColor : _secondaryColor;
    final IconData typeIcon = type == 'تخزين' ? Icons.warehouse : Icons.local_shipping;
    
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
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
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
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black12, Colors.black26],
                        ),
                      ),
                      child: imageUrls.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrls[0],
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
                            Colors.black.withOpacity(0),
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // شريط نوع الخدمة
                  Positioned(
                    top: 15,
                    left: 15,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [typeColor, typeColor.withOpacity(0.7)],
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
                          Icon(typeIcon, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            type,
                            style: GoogleFonts.cairo(
                              textStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // شريط التقييم
                  if (reviewCount > 0)
                    Positioned(
                      top: 15,
                      right: 15,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 3),
                            Text(
                              rating.toStringAsFixed(1),
                              style: GoogleFonts.cairo(
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 1),
                            Text(
                              '($reviewCount)',
                              style: GoogleFonts.cairo(
                                textStyle: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 10,
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
              
              // معلومات الخدمة
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    const SizedBox(height: 15),
                    
                    // تفاصيل إضافية
                    Row(
                      children: [
                        _buildInfoChip(Icons.location_on, region, Colors.blue[700]!),
                        const SizedBox(width: 10),
                        _buildInfoChip(Icons.attach_money, '$price', Colors.green[700]!),
                      ],
                    ),
                    const SizedBox(height: 15),
                    
                    // زر العرض
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ServiceDetailsScreen(
                                serviceId: service['id'],
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: typeColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'عرض التفاصيل',
                          style: GoogleFonts.cairo(
                            textStyle: const TextStyle(
                              fontSize: 15,
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
