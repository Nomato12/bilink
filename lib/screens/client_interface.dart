import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'service_details_screen.dart';
import 'transport_service_map.dart'; // إضافة استيراد صفحة خريطة خدمة النقل
import 'chat_list_screen.dart'; // إضافة استيراد صفحة قائمة المحادثات
import 'storage_locations_map_screen.dart'; // إضافة استيراد صفحة مواقع التخزين

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  _ClientHomePageState createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  // متغيرات التحكم بالواجهة
  final int _currentIndex = 0;
  bool _isLoading = false;
  List<Map<String, dynamic>> _servicesList = [];

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
    _loadServices();
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

      print('تم العثور على ${querySnapshot.docs.length} خدمة نشطة');

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

      print('تم تحميل ${servicesList.length} خدمة بنجاح');
    } catch (e) {
      print('Error loading services: $e');
      setState(() {
        _isLoading = false;
      });

      // عرض رسالة خطأ للمستخدم
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تحميل الخدمات، يرجى المحاولة مرة أخرى'),
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B5CF6), Color(0xFF60A5FA)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('لوحة العميل'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          actions: [
            // زر المحادثات
            IconButton(
              icon: Icon(Icons.chat),
              tooltip: 'المحادثات',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ChatListScreen()),
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
                : _buildBody(),
      ),
    );
  }

  // بناء جسم الصفحة الرئيسية
  Widget _buildBody() {
    if (_servicesList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'لا توجد خدمات متاحة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'جرّب تغيير معايير البحث أو العودة لاحقاً',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadServices,
              icon: Icon(Icons.refresh),
              label: Text('تحديث'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF9B59B6),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عرض معلومات الفلترة النشطة
          if (_activeFilters.isNotEmpty) _buildActiveFilters(),

          // فئات الخدمات الأساسية فقط: التخزين والنقل
          Text(
            "الخدمات المتاحة",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          SizedBox(height: 16),

          // عرض فقط التخزين والنقل
          Row(
            children: [
              Expanded(
                child: _buildServiceCategory(
                  title: "التخزين",
                  details: "مستودعات ومساحات تخزين آمنة بالقرب منك",
                  icon: Icons.warehouse,
                  color: Colors.blue,
                  onTap: () {
                    setState(() {
                      _selectedType = 'تخزين';
                      _activeFilters.add('النوع: تخزين');
                    });
                    _updateFilters();
                    // توجيه المستخدم إلى صفحة مواقع التخزين
                    _navigateToStorageLocationsMap();
                  },
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildServiceCategory(
                  title: "النقل",
                  details: "خدمات النقل والشحن لجميع احتياجاتك",
                  icon: Icons.local_shipping,
                  color: Colors.orange,
                  onTap: () {
                    setState(() {
                      _selectedType = 'نقل';
                      _activeFilters.add('النوع: نقل');
                    });
                    _updateFilters();
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 32),

          // عنوان قسم الخدمات المتاحة - يظهر فقط إذا تم اختيار فئة
          if (_selectedType != 'الكل') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedType == 'تخزين'
                      ? "خدمات التخزين المتاحة"
                      : "خدمات النقل المتاحة",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                Text(
                  "${_servicesList.length} خدمة",
                  style: TextStyle(
                    color: Color(0xFF9B59B6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // عرض قائمة الخدمات
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _servicesList.length,
              itemBuilder: (context, index) {
                final service = _servicesList[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: _buildServiceCard(service),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // بناء عرض الفلاتر النشطة
  Widget _buildActiveFilters() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          Row(
            children: [
              Icon(Icons.filter_list, size: 18, color: Color(0xFF9B59B6)),
              SizedBox(width: 8),
              Text(
                'الفلاتر النشطة',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF9B59B6),
                ),
              ),
              Spacer(),
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
                  minimumSize: Size(0, 0),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                child: Text(
                  'مسح الكل',
                  style: TextStyle(color: Colors.red[700], fontSize: 12),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _activeFilters.map((filter) {
                  return Chip(
                    label: Text(
                      filter,
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    backgroundColor: Color(0xFF9B59B6),
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

  // إظهار حوار تصفية الخدمات
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.filter_list, color: Color(0xFF9B59B6)),
                    SizedBox(width: 8),
                    Text('تصفية الخدمات', style: TextStyle(fontSize: 18)),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // نوع الخدمة
                      Text(
                        'نوع الخدمة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9B59B6),
                        ),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children:
                            ['الكل', 'تخزين', 'نقل'].map((type) {
                              return ChoiceChip(
                                label: Text(type),
                                selected: _selectedType == type,
                                onSelected: (selected) {
                                  setDialogState(() {
                                    _selectedType = selected ? type : 'الكل';
                                  });
                                },
                              );
                            }).toList(),
                      ),
                      SizedBox(height: 16),

                      // المنطقة
                      Text(
                        'المنطقة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9B59B6),
                        ),
                      ),
                      SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedRegion,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items:
                            [
                              'الكل',
                              'الجزائر',
                              'وهران',
                              'قسنطينة',
                              'عنابة',
                              'سطيف',
                              'بليدة',
                              'باتنة',
                              'تلمسان',
                              'أخرى',
                            ].map((region) {
                              return DropdownMenuItem(
                                value: region,
                                child: Text(region),
                              );
                            }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              _selectedRegion = value;
                            });
                          }
                        },
                      ),
                      SizedBox(height: 16),

                      // الترتيب حسب
                      Text(
                        'ترتيب حسب',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9B59B6),
                        ),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children:
                            [
                              'التقييم',
                              'السعر (من الأقل)',
                              'السعر (من الأعلى)',
                              'الأحدث',
                            ].map((sort) {
                              return ChoiceChip(
                                label: Text(sort),
                                selected: _sortBy == sort,
                                onSelected: (selected) {
                                  setDialogState(() {
                                    _sortBy = selected ? sort : 'التقييم';
                                  });
                                },
                              );
                            }).toList(),
                      ),
                      SizedBox(height: 16),

                      // نطاق السعر
                      Text(
                        'نطاق السعر',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9B59B6),
                        ),
                      ),
                      SizedBox(height: 8),
                      RangeSlider(
                        values: _priceRange,
                        min: 0,
                        max: 10000,
                        divisions: 100,
                        labels: RangeLabels(
                          '${_priceRange.start.round()}',
                          '${_priceRange.end.round()}',
                        ),
                        onChanged: (values) {
                          setDialogState(() {
                            _priceRange = values;
                          });
                        },
                        activeColor: Color(0xFF9B59B6),
                      ),
                      Center(
                        child: Text(
                          'من ${_priceRange.start.round()} إلى ${_priceRange.end.round()} د.ج',
                          style: TextStyle(color: Colors.grey[700]),
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
                      // تحديث مجموعة الفلاتر النشطة
                      setState(() {
                        _activeFilters.clear();

                        if (_selectedType != 'الكل') {
                          _activeFilters.add('النوع: $_selectedType');
                        }

                        if (_selectedRegion != 'الكل') {
                          _activeFilters.add('المنطقة: $_selectedRegion');
                        }

                        if (_priceRange.start > 0 || _priceRange.end < 10000) {
                          _activeFilters.add(
                            'السعر: ${_priceRange.start.round()} - ${_priceRange.end.round()} د.ج',
                          );
                        }

                        if (_sortBy != 'التقييم') {
                          _activeFilters.add('الترتيب: $_sortBy');
                        }
                      });

                      Navigator.pop(context);
                      _updateFilters();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF9B59B6),
                    ),
                    child: Text('تطبيق'),
                  ),
                ],
              );
            },
          ),
    );
  }

  // بناء بطاقة فئة الخدمة
  Widget _buildServiceCategory({
    required String title,
    required String details,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    // عرض زر الخريطة إذا كانت الخدمة هي النقل
    final bool isTransport = title == "النقل";

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        details,
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // زر إضافي للنقل - البحث بالخريطة
        if (isTransport)
          Container(
            margin: EdgeInsets.only(top: 8),
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TransportServiceMapScreen(),
                  ),
                );
              },
              icon: Icon(Icons.map_outlined, size: 18),
              label: Text('استخدام الخريطة للبحث'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 10),
                elevation: 0,
                textStyle: TextStyle(fontSize: 13),
              ),
            ),
          ),
      ],
    );
  }

  // بناء بطاقة عرض خدمة
  Widget _buildServiceCard(Map<String, dynamic> service) {
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
    final Color typeColor = type == 'تخزين' ? Colors.blue : Colors.red;
    final IconData typeIcon =
        type == 'تخزين' ? Icons.warehouse : Icons.local_shipping;

    return InkWell(
      onTap: () {
        // عند النقر على الخدمة، افتح صفحة التفاصيل
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ServiceDetailsScreen(serviceId: service['id']),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 4),
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
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child:
                      imageUrls.isNotEmpty
                          ? CachedNetworkImage(
                            imageUrl: imageUrls[0],
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder:
                                (context, url) => Container(
                                  height: 180,
                                  color: Colors.grey[200],
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
                                  height: 180,
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: Icon(
                                      typeIcon,
                                      size: 60,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ),
                          )
                          : Container(
                            height: 180,
                            color: Colors.grey[200],
                            child: Center(
                              child: Icon(
                                typeIcon,
                                size: 60,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                ),
                // شريط نوع الخدمة والتقييم
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                // شريط التقييم
                if (reviewCount > 0)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          Icon(Icons.star, color: Colors.amber, size: 16),
                          SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(width: 2),
                          Text(
                            '($reviewCount)',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // معلومات الخدمة
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // العنوان
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),

                  // الوصف المختصر
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 12),

                  // المنطقة
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.grey, size: 16),
                      SizedBox(width: 4),
                      Text(
                        region,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  // السعر وزر العرض
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // السعر
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'السعر',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '$price',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF9B59B6),
                            ),
                          ),
                        ],
                      ),

                      // زر العرض
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => ServiceDetailsScreen(
                                    serviceId: service['id'],
                                  ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF9B59B6),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text('عرض التفاصيل'),
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
}
