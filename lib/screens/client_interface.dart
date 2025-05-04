import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

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

  // User data variables
  late UserModel _userData;
  bool _isUserDataLoaded = false;
  String _profileImageUrl = '';

  // Controllers for editing user information
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

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
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // دالة لتحميل بيانات المستخدم من قاعدة البيانات
  Future<void> _loadUserData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      // التأكد من وجود مستخدم مسجل الدخول
      if (authService.currentUser != null) {
        setState(() {
          _userData = authService.currentUser!;
          _isUserDataLoaded = true;

          // تعبئة حقول التعديل بالمعلومات الحالية
          _nameController.text = _userData.fullName;
          _phoneController.text = _userData.phoneNumber;

          // التحقق من وجود بيانات إضافية
          if (_userData.additionalData.containsKey('address')) {
            _addressController.text = _userData.additionalData['address'];
          }

          // التحقق من وجود صورة شخصية
          if (_userData.profileImageUrl.isNotEmpty) {
            _profileImageUrl = _userData.profileImageUrl;
          }
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  // دالة لاختيار والتقاط صورة شخصية
  Future<void> _pickAndUploadProfileImage() async {
    try {
      // تهيئة ImagePicker
      final ImagePicker picker = ImagePicker();
      
      // عرض خيارات التقاط الصورة للمستخدم
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024, // تقليل حجم الصورة
        maxHeight: 1024,
        imageQuality: 85, // ضغط الصورة للتقليل من حجمها
      );

      if (image != null) {
        // التحقق من حجم الصورة
        final File imageFile = File(image.path);
        final fileSize = await imageFile.length();
        
        // إذا كان حجم الملف كبيرًا جدًا (أكثر من 5 ميجابايت)
        if (fileSize > 5 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حجم الصورة كبير جدًا. يرجى اختيار صورة أصغر')),
          );
          return;
        }

        // إظهار مؤشر التحميل
        _showLoadingDialog('جاري رفع الصورة...');

        // التحقق من وجود معلومات المستخدم الحالي
        final authService = Provider.of<AuthService>(context, listen: false);
        
        // التحقق من أن المستخدم ما زال مسجل الدخول
        if (authService.currentUser == null) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(); // إغلاق مؤشر التحميل
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('يرجى تسجيل الدخول أولاً')),
          );
          return;
        }
        
        // التأكد من وجود معرف المستخدم
        final userId = authService.currentUser!.uid;
        if (userId.isEmpty) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في معرف المستخدم، يرجى إعادة تسجيل الدخول')),
          );
          return;
        }
        
        // إعادة المصادقة قبل محاولة الرفع لضمان وجود توكن حديث
        try {
          // إعداد المرجع في Firebase Storage
          final storageRef = FirebaseStorage.instance.ref();
          
          // تجنب مسارات غير صالحة في Firebase Storage
          final safeUserId = userId.replaceAll(RegExp(r'[^\w-]'), '_');
          
          // بناء المسار بطريقة منظمة
          final userProfilePath = 'users/$safeUserId/profile_images';
          final userFolder = storageRef.child(userProfilePath);
          
          // إنشاء اسم فريد للصورة
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = 'profile_$timestamp.jpg';
          
          // مرجع الصورة النهائي
          final profileImageRef = userFolder.child(fileName);

          // إعداد البيانات الوصفية
          final metadata = SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'userId': userId,
              'uploadTime': DateTime.now().toString(),
              'purpose': 'profile_image'
            },
          );

          // رفع الصورة
          final uploadTask = profileImageRef.putFile(imageFile, metadata);

          // مراقبة حالة الرفع للتعامل مع الأخطاء
          uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
            switch (snapshot.state) {
              case TaskState.error:
                // إغلاق مؤشر التحميل في حالة الخطأ
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                // تحليل الخطأ وعرض رسالة مناسبة
                final error = snapshot.error;
                String errorMessage = 'حدث خطأ أثناء رفع الصورة. يرجى المحاولة مرة أخرى';
                if (error != null && error.toString().contains('unauthorized')) {
                  errorMessage = 'ليس لديك صلاحية رفع الصور. تحقق من إعدادات الأمان في Firebase Storage';
                  // طباعة تفاصيل الخطأ للتشخيص
                  print('Firebase Storage Authorization Error: $error');
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(errorMessage)),
                );
                break;
              default:
                break;
            }
          });

          // انتظار اكتمال الرفع
          final snapshot = await uploadTask;
          
          if (snapshot.state == TaskState.success) {
            try {
              // الحصول على رابط التنزيل
              final downloadUrl = await profileImageRef.getDownloadURL();
              
              // تحديث عنوان الصورة في Firestore
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .update({'profileImageUrl': downloadUrl});

              // تحديث الواجهة
              setState(() {
                _profileImageUrl = downloadUrl;
                _userData = _userData.copyWith(profileImageUrl: downloadUrl);
              });

              // إغلاق مؤشر التحميل
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }

              // عرض رسالة نجاح
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تم تحديث الصورة الشخصية بنجاح')),
              );
            } catch (urlError) {
              // معالجة خطأ في الحصول على الرابط
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              print('Error getting download URL: $urlError');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تم رفع الصورة ولكن حدث خطأ في الحصول على الرابط')),
              );
            }
          }
        } catch (storageError) {
          // إغلاق مؤشر التحميل في حالة الخطأ
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          
          print('Storage error: $storageError');
          
          String errorMessage = 'حدث خطأ أثناء الوصول لخدمة التخزين. يرجى المحاولة مرة أخرى لاحقاً';
          if (storageError.toString().contains('unauthorized') || 
              storageError.toString().contains('permission-denied')) {
            errorMessage = 'ليس لديك صلاحية رفع الصور. تأكد من إعدادات الأمان في Firebase Storage';
          } else if (storageError.toString().contains('object-not-found')) {
            errorMessage = 'المسار غير موجود في خدمة التخزين';
          } else if (storageError.toString().contains('quota-exceeded')) {
            errorMessage = 'تم تجاوز الحد المسموح للتخزين';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
    } catch (e) {
      // إغلاق مؤشر التحميل في حالة الخطأ
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      print('Error in image picker process: $e');
      
      String errorMessage = 'حدث خطأ أثناء تحميل الصورة. يرجى المحاولة مرة أخرى';
      if (e.toString().contains('permission-denied') || e.toString().contains('unauthorized')) {
        errorMessage = 'ليس لديك صلاحية الوصول إلى الصور أو رفعها';
      } else if (e.toString().contains('canceled')) {
        errorMessage = 'تم إلغاء عملية اختيار الصورة';
      } else if (e.toString().contains('network')) {
        errorMessage = 'حدث خطأ في الاتصال بالشبكة. يرجى التحقق من اتصالك بالإنترنت';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  // دالة لتحديث بيانات المستخدم
  Future<void> _updateUserInfo() async {
    try {
      // التحقق من صحة البيانات
      if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('يرجى ملء جميع الحقول المطلوبة')),
        );
        return;
      }

      // إظهار مؤشر التحميل
      _showLoadingDialog('جاري تحديث البيانات...');

      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser!.uid;

      // تحديث البيانات الإضافية
      Map<String, dynamic> additionalData = {..._userData.additionalData};

      if (_addressController.text.isNotEmpty) {
        additionalData['address'] = _addressController.text;
      }

      // تحديث بيانات المستخدم في Firestore
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);
      await userRef.update({
        'fullName': _nameController.text,
        'phoneNumber': _phoneController.text,
        'additionalData': additionalData,
      });

      // إعادة تحميل بيانات المستخدم
      await _loadUserData();

      // إغلاق مؤشر التحميل
      Navigator.of(context).pop();

      // إغلاق نافذة التعديل إذا كانت مفتوحة
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // عرض رسالة نجاح
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم تحديث البيانات بنجاح')));
    } catch (e) {
      // إغلاق مؤشر التحميل في حالة الخطأ
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      print('Error updating user info: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء تحديث البيانات')));
    }
  }

  // عرض مؤشر التحميل
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: Color(0xFF9B59B6)),
              SizedBox(width: 16),
              Text(message),
            ],
          ),
        );
      },
    );
  }

  // عرض مربع حوار تعديل الملف الشخصي
  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Center(child: Text('تعديل البيانات الشخصية')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickAndUploadProfileImage();
                  },
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF9B59B6).withOpacity(0.1),
                      border: Border.all(color: Color(0xFF9B59B6), width: 2),
                    ),
                    child: Center(
                      child:
                          _profileImageUrl.isNotEmpty
                              ? CircleAvatar(
                                radius: 48,
                                backgroundImage: CachedNetworkImageProvider(
                                  _profileImageUrl,
                                ),
                              )
                              : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo,
                                    color: Color(0xFF9B59B6),
                                    size: 32,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'إضافة صورة',
                                    style: TextStyle(
                                      color: Color(0xFF9B59B6),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'الاسم الكامل',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 12),
                TextField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'العنوان',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateUserInfo();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF9B59B6),
              ),
              child: Text('حفظ التغييرات'),
            ),
          ],
        );
      },
    );
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
      child:
          _isUserDataLoaded
              ? Column(
                children: [
                  // إظهار صورة المستخدم إذا كانت موجودة، وإلا إظهار الحروف الأولى من اسمه
                  _profileImageUrl.isNotEmpty
                      ? CircleAvatar(
                        radius: 50,
                        backgroundImage: CachedNetworkImageProvider(
                          _profileImageUrl,
                        ),
                      )
                      : CircleAvatar(
                        radius: 50,
                        backgroundColor: Color(0xFF9B59B6).withOpacity(0.2),
                        child: Text(
                          _userData.fullName.isNotEmpty
                              ? _userData.fullName
                                  .split(' ')
                                  .map((e) => e.isNotEmpty ? e[0] : '')
                                  .take(2)
                                  .join(' ')
                              : 'U',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF9B59B6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  SizedBox(height: 16),
                  Text(
                    _userData.fullName,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _userData.email,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _showEditProfileDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF9B59B6).withOpacity(0.1),
                      foregroundColor: Color(0xFF9B59B6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text('تعديل الملف الشخصي'),
                  ),
                ],
              )
              : Center(
                child: CircularProgressIndicator(color: Color(0xFF9B59B6)),
              ),
    );
  }

  Widget _buildProfileMenu() {
    final menuItems = [
      {
        'title': 'معلوماتي الشخصية',
        'icon': Icons.person_outline,
        'color': Colors.blue,
      },
      {'title': 'طرق الدفع', 'icon': Icons.credit_card, 'color': Colors.green},
      {
        'title': 'العناوين المحفوظة',
        'icon': Icons.location_on_outlined,
        'color': Colors.orange,
      },
      {
        'title': 'الخدمات المفضلة',
        'icon': Icons.favorite_outline,
        'color': Colors.red,
      },
      {
        'title': 'الإشعارات',
        'icon': Icons.notifications_none,
        'color': Colors.purple,
      },
      {'title': 'الأمان', 'icon': Icons.lock_outline, 'color': Colors.teal},
      {
        'title': 'مساعدة ودعم',
        'icon': Icons.help_outline,
        'color': Colors.indigo,
      },
      {'title': 'تسجيل الخروج', 'icon': Icons.logout, 'color': Colors.grey},
    ];

    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children:
            menuItems.map((item) {
              return Container(
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (item['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: item['color'] as Color,
                    ),
                  ),
                  title: Text(
                    item['title'] as String,
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    if (item['title'] == 'تسجيل الخروج') {
                      // Call logout
                      final authService = Provider.of<AuthService>(
                        context,
                        listen: false,
                      );
                      authService.logout();
                    } else {
                      // Navigate to respective pages
                    }
                  },
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
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
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'طلباتي',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'حسابي',
            ),
          ],
        ),
      ),
    );
  }
}
