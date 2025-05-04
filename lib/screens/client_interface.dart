import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../models/service_model.dart';
import '../services/service_service.dart';

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  _ClientHomePageState createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  int _currentIndex = 0;
  final _searchController = TextEditingController();
  String _selectedLocation = 'الكل';
  RangeValues _priceRange = RangeValues(100, 5000);
  double _minRating = 3.0;

  // الخدمات المميزة
  final List<Map<String, dynamic>> _featuredServices = [
    {
      'id': '1',
      'title': 'مستودع حديث للإيجار',
      'category': 'تخزين',
      'image': 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d',
      'location': 'سيدي بلعباس',
      'price': 1200,
      'size': 500,
      'rating': 4.7,
    },
    {
      'id': '2',
      'title': 'خدمة نقل سريعة',
      'category': 'نقل',
      'image': 'https://images.unsplash.com/photo-1601628828688-632f38a5a7d0',
      'location': 'الجزائر العاصمة',
      'price': 850,
      'capacity': '3 طن',
      'rating': 4.5,
    },
    {
      'id': '3',
      'title': 'مستودع مبرد للمواد الغذائية',
      'category': 'تخزين',
      'image': 'https://images.unsplash.com/photo-1635070041078-e363dbe005cb',
      'location': 'وهران',
      'price': 2000,
      'size': 300,
      'rating': 4.9,
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomePage();
      case 1:
        return _buildSearchPage();
      case 2:
        return _buildOrdersPage();
      case 3:
        return _buildProfilePage();
      default:
        return _buildHomePage();
    }
  }

  Widget _buildHomePage() {
    return Container(
      decoration: BoxDecoration(color: Colors.grey[100]),
      child: CustomScrollView(
        slivers: [
          _buildHomeAppBar(),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverToBoxAdapter(child: _buildCategoriesSection()),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverToBoxAdapter(child: _buildFeaturedSection()),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverToBoxAdapter(child: _buildRecentSection()),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverToBoxAdapter(child: _buildSpecialOffersSection()),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeAppBar() {
    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF6B3B), Color(0xFFFF5775), Color(0xFF9B59B6)],
              stops: [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مرحباً بك في',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'BiLink',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: CircleAvatar(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        radius: 20,
                        child: Icon(
                          Icons.notifications_none,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن خدمات التخزين والنقل...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                        ),
                        prefixIcon: Icon(Icons.search, color: Colors.white),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 15),
                      ),
                      onTap: () {
                        setState(() {
                          _currentIndex = 1;
                        });
                      },
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

  Widget _buildCategoriesSection() {
    final categories = [
      {'icon': Icons.warehouse, 'title': 'تخزين', 'color': Color(0xFF5DADE2)},
      {
        'icon': Icons.local_shipping,
        'title': 'نقل',
        'color': Color(0xFFE74C3C),
      },
      {'icon': Icons.addchart, 'title': 'تتبع', 'color': Color(0xFF27AE60)},
      {'icon': Icons.more_horiz, 'title': 'المزيد', 'color': Color(0xFFF39C12)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'الفئات',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Spacer(),
            TextButton(
              onPressed: () {},
              child: Text(
                'عرض الكل',
                style: TextStyle(
                  color: Color(0xFF9B59B6),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children:
              categories.map((category) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentIndex = 1;
                    });
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: category['color'] as Color,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: (category['color'] as Color).withOpacity(
                                0.3,
                              ),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          category['icon'] as IconData,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        category['title'] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildFeaturedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 24),
        Row(
          children: [
            Text(
              'خدمات مميزة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Spacer(),
            TextButton(
              onPressed: () {},
              child: Text(
                'عرض الكل',
                style: TextStyle(
                  color: Color(0xFF9B59B6),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _featuredServices.length,
            itemBuilder: (context, index) {
              final service = _featuredServices[index];
              return _buildFeaturedServiceCard(service);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedServiceCard(Map<String, dynamic> service) {
    final isStorageService = service['category'] == 'تخزين';

    return GestureDetector(
      onTap: () {
        _navigateToServiceDetails(service['id']);
      },
      child: Container(
        width: 220,
        margin: EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: service['image'],
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) =>
                            Container(color: Colors.grey[300], height: 140),
                    errorWidget:
                        (context, url, error) => Container(
                          color: Colors.grey[300],
                          height: 140,
                          child: Icon(Icons.error, color: Colors.red),
                        ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            isStorageService
                                ? Color(0xFF5DADE2)
                                : Color(0xFFE74C3C),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        service['category'],
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 16),
                          SizedBox(width: 4),
                          Text(
                            service['rating'].toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service['title'],
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.grey, size: 16),
                      SizedBox(width: 4),
                      Text(
                        service['location'],
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        isStorageService
                            ? Icons.aspect_ratio
                            : Icons.local_shipping,
                        color: Colors.grey,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        isStorageService
                            ? '${service['size']} متر مربع'
                            : service['capacity'],
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${service['price']} د.ج / الشهر',
                        style: TextStyle(
                          color: Color(0xFF9B59B6),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.favorite_border,
                          color: Colors.grey[400],
                        ),
                        onPressed: () {},
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 24),
        Row(
          children: [
            Text(
              'خدمات شاهدتها مؤخراً',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Spacer(),
            TextButton(
              onPressed: () {},
              child: Text(
                'عرض الكل',
                style: TextStyle(
                  color: Color(0xFF9B59B6),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _featuredServices.length,
            itemBuilder: (context, index) {
              final service = _featuredServices[index];
              return _buildRecentServiceCard(service);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentServiceCard(Map<String, dynamic> service) {
    return GestureDetector(
      onTap: () {
        _navigateToServiceDetails(service['id']);
      },
      child: Container(
        width: 300,
        margin: EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: CachedNetworkImage(
                imageUrl: service['image'],
                height: 120,
                width: 100,
                fit: BoxFit.cover,
                placeholder:
                    (context, url) => Container(
                      color: Colors.grey[300],
                      height: 120,
                      width: 100,
                    ),
                errorWidget:
                    (context, url, error) => Container(
                      color: Colors.grey[300],
                      height: 120,
                      width: 100,
                      child: Icon(Icons.error, color: Colors.red),
                    ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            service['category'] == 'تخزين'
                                ? Color(0xFF5DADE2).withOpacity(0.2)
                                : Color(0xFFE74C3C).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        service['category'],
                        style: TextStyle(
                          color:
                              service['category'] == 'تخزين'
                                  ? Color(0xFF5DADE2)
                                  : Color(0xFFE74C3C),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      service['title'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.grey, size: 14),
                        SizedBox(width: 4),
                        Text(
                          service['location'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        Spacer(),
                        Text(
                          '${service['price']} د.ج',
                          style: TextStyle(
                            color: Color(0xFF9B59B6),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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
      ),
    );
  }

  Widget _buildSpecialOffersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 24),
        Row(
          children: [
            Text(
              'عروض خاصة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Spacer(),
            TextButton(
              onPressed: () {},
              child: Text(
                'عرض الكل',
                style: TextStyle(
                  color: Color(0xFF9B59B6),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          height: 150,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF9B59B6), Color(0xFF3498DB)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF9B59B6).withOpacity(0.3),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                bottom: -40,
                left: -30,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'خصم 20% على جميع خدمات التخزين',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'استخدم الكود: BILINK20',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Color(0xFF9B59B6),
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'استفد الآن',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.local_offer,
                      size: 80,
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSearchPage() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: Text('البحث عن الخدمات'),
          floating: true,
          pinned: true,
          backgroundColor: Color(0xFF9B59B6),
          actions: [
            IconButton(
              icon: Icon(Icons.filter_list),
              onPressed: () {
                _showFilterBottomSheet();
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(60.0),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'ابحث عن خدمات التخزين والنقل...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  contentPadding: EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
          ),
        ),
        _buildFilterChips(),
        _buildSearchResults(),
      ],
    );
  }

  Widget _buildFilterChips() {
    final serviceTypes = ['الكل', 'تخزين', 'نقل'];
    final locations = ['الكل', 'الجزائر العاصمة', 'وهران', 'سيدي بلعباس'];

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'الفلاتر المطبقة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                ...serviceTypes.map(
                  (type) => ChoiceChip(
                    label: Text(type),
                    selected: type == 'الكل',
                    selectedColor: Color(0xFF9B59B6).withOpacity(0.2),
                    onSelected: (selected) {},
                  ),
                ),
                SizedBox(width: 8),
                ...locations.map(
                  (location) => ChoiceChip(
                    label: Text(location),
                    selected: location == _selectedLocation,
                    selectedColor: Color(0xFF9B59B6).withOpacity(0.2),
                    onSelected: (selected) {
                      setState(() {
                        _selectedLocation = location;
                      });
                    },
                  ),
                ),
                SizedBox(width: 8),
                ChoiceChip(
                  label: Text(
                    'السعر: ${_priceRange.start.toInt()} - ${_priceRange.end.toInt()} د.ج',
                  ),
                  selected: true,
                  selectedColor: Color(0xFF9B59B6).withOpacity(0.2),
                  onSelected: (selected) {
                    _showFilterBottomSheet();
                  },
                ),
                SizedBox(width: 8),
                ChoiceChip(
                  label: Text('التقييم: $_minRating+'),
                  selected: true,
                  selectedColor: Color(0xFF9B59B6).withOpacity(0.2),
                  onSelected: (selected) {
                    _showFilterBottomSheet();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return SliverPadding(
      padding: EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final service = _featuredServices[index % _featuredServices.length];
            return _buildServiceCard(service);
          },
          childCount: 6, // Example count
        ),
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final isStorageService = service['category'] == 'تخزين';

    return GestureDetector(
      onTap: () {
        _navigateToServiceDetails(service['id']);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: service['image'],
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) =>
                            Container(color: Colors.grey[300], height: 120),
                    errorWidget:
                        (context, url, error) => Container(
                          color: Colors.grey[300],
                          height: 120,
                          child: Icon(Icons.error, color: Colors.red),
                        ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            isStorageService
                                ? Color(0xFF5DADE2)
                                : Color(0xFFE74C3C),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        service['category'],
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service['title'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.grey, size: 12),
                        SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            service['location'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${service['price']} د.ج',
                          style: TextStyle(
                            color: Color(0xFF9B59B6),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 14),
                            SizedBox(width: 2),
                            Text(
                              service['rating'].toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
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

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'فلترة النتائج',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'المنطقة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children:
                        [
                              'الكل',
                              'الجزائر العاصمة',
                              'وهران',
                              'سيدي بلعباس',
                              'قسنطينة',
                            ]
                            .map(
                              (location) => ChoiceChip(
                                label: Text(location),
                                selected: _selectedLocation == location,
                                selectedColor: Color(
                                  0xFF9B59B6,
                                ).withOpacity(0.2),
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedLocation = location;
                                  });
                                },
                              ),
                            )
                            .toList(),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'نطاق السعر (د.ج / الشهر)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  RangeSlider(
                    values: _priceRange,
                    min: 0,
                    max: 10000,
                    divisions: 100,
                    activeColor: Color(0xFF9B59B6),
                    labels: RangeLabels(
                      _priceRange.start.round().toString(),
                      _priceRange.end.round().toString(),
                    ),
                    onChanged: (values) {
                      setState(() {
                        _priceRange = values;
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Text('0 د.ج'), Text('10,000 د.ج')],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'الحد الأدنى للتقييم',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Slider(
                    value: _minRating,
                    min: 0,
                    max: 5,
                    divisions: 10,
                    activeColor: Color(0xFF9B59B6),
                    label: _minRating.toString(),
                    onChanged: (value) {
                      setState(() {
                        _minRating = value;
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Text('0'), Text('5')],
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // Apply filters and refresh search results
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF9B59B6),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'تطبيق الفلاتر',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedLocation = 'الكل';
                          _priceRange = RangeValues(100, 5000);
                          _minRating = 3.0;
                        });
                      },
                      child: Text(
                        'إعادة ضبط الفلاتر',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _navigateToServiceDetails(String serviceId) {
    // Navigate to service details page
    print('Navigating to service $serviceId');
    // Implement navigation logic here
  }

  Widget _buildOrdersPage() {
    final orders = [
      {
        'id': 'O-12345',
        'service': 'مستودع حديث للإيجار',
        'date': '22 أبريل 2025',
        'amount': '1,200 د.ج',
        'status': 'نشط',
        'statusColor': Colors.green,
      },
      {
        'id': 'O-12340',
        'service': 'خدمة نقل سريعة',
        'date': '15 أبريل 2025',
        'amount': '850 د.ج',
        'status': 'مكتمل',
        'statusColor': Colors.blue,
      },
      {
        'id': 'O-12339',
        'service': 'مستودع مبرد للمواد الغذائية',
        'date': '5 أبريل 2025',
        'amount': '2,000 د.ج',
        'status': 'مكتمل',
        'statusColor': Colors.blue,
      },
    ];

    return Scaffold(
      appBar: AppBar(title: Text('طلباتي'), backgroundColor: Color(0xFF9B59B6)),
      body:
          orders.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'لا توجد طلبات حالية',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'ابدأ باستكشاف الخدمات وقم بحجز ما يناسب احتياجاتك',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _currentIndex = 0;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF9B59B6),
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('استكشف الخدمات'),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'رقم الطلب: ${order['id']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: (order['statusColor'] as Color)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  order['status'] as String,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: order['statusColor'] as Color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Divider(height: 24),
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Color(0xFF9B59B6).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.business,
                                  color: Color(0xFF9B59B6),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order['service'] as String,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'تاريخ الحجز: ${order['date']}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'المبلغ: ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  Text(
                                    order['amount'] as String,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF9B59B6),
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () {
                                  // Navigate to order details
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Color(0xFF9B59B6),
                                ),
                                child: Text('عرض التفاصيل'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }

  Widget _buildProfilePage() {
    return Scaffold(
      appBar: AppBar(
        title: Text('حسابي'),
        backgroundColor: Color(0xFF9B59B6),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(children: [_buildProfileHeader(), _buildProfileMenu()]),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Color(0xFF9B59B6).withOpacity(0.1),
            child: Text(
              'أ م',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9B59B6),
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'أحمد محمود',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            'ahmed.mahmoud@example.com',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              // Edit profile
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Color(0xFF9B59B6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'تعديل الحساب',
              style: TextStyle(color: Color(0xFF9B59B6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileMenu() {
    final menuItems = [
      {
        'title': 'المعلومات الشخصية',
        'icon': Icons.person_outline,
        'onTap': () {},
      },
      {
        'title': 'العناوين المحفوظة',
        'icon': Icons.location_on_outlined,
        'onTap': () {},
      },
      {
        'title': 'وسائل الدفع',
        'icon': Icons.credit_card_outlined,
        'onTap': () {},
      },
      {
        'title': 'الخدمات المفضلة',
        'icon': Icons.favorite_border,
        'onTap': () {},
      },
      {
        'title': 'التقييمات والمراجعات',
        'icon': Icons.star_border,
        'onTap': () {},
      },
      {'title': 'المساعدة والدعم', 'icon': Icons.help_outline, 'onTap': () {}},
      {
        'title': 'تسجيل الخروج',
        'icon': Icons.logout,
        'onTap': () {
          // Handle logout
          final authService = Provider.of<AuthService>(context, listen: false);
          authService.signOut();
        },
        'color': Colors.red,
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Text(
              'إعدادات الحساب',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          SizedBox(height: 8),
          ...menuItems.map(
            (item) => _buildProfileMenuItem(
              title: item['title'] as String,
              icon: item['icon'] as IconData,
              onTap: item['onTap'] as Function(),
              color: item.containsKey('color') ? item['color'] as Color : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileMenuItem({
    required String title,
    required IconData icon,
    required Function onTap,
    Color? color,
  }) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: ListTile(
        leading: Icon(icon, color: color ?? Color(0xFF9B59B6)),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w500, color: color),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () => onTap(),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      selectedItemColor: Color(0xFF9B59B6),
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'الرئيسية',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.search_outlined),
          activeIcon: Icon(Icons.search),
          label: 'البحث',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_outlined),
          activeIcon: Icon(Icons.receipt),
          label: 'طلباتي',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'حسابي',
        ),
      ],
    );
  }
}
