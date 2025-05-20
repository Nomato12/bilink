import 'package:flutter/material.dart' hide InkWell;
import 'package:flutter/material.dart' as material show InkWell;
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../widgets/notification_badge.dart';
import '../widgets/request_tabs.dart';
import 'driver_tracking_map.dart';
import 'storage_location_map.dart';
import 'add_service_screen.dart';
import 'chat_list_screen.dart';
import '../models/home_page.dart';
import 'notifications_screen.dart';
import 'provider_statistics_page_scrollable.dart';
import '../services/provider_statistics_service.dart';

// Circles painter for logistics network pattern
class LogisticsCirclesPainter extends CustomPainter {
  final Color color;
  
  LogisticsCirclesPainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
      
    // Draw concentric circles
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, size.width * i / 5, paint);
    }
    
    // Draw connecting lines
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
      
    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      final x = center.dx + math.cos(angle) * size.width;
      final y = center.dy + math.sin(angle) * size.height;
      canvas.drawLine(center, Offset(x, y), linePaint);
    }
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// Wave painter for logistics flow visualization
class LogisticsWavePainter extends CustomPainter {
  final Color color;
  final double amplitude;
  
  LogisticsWavePainter({
    required this.color,
    this.amplitude = 10.0,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    
    final path = Path();
    path.moveTo(0, size.height / 2);
    
    for (double i = 0; i < size.width; i++) {
      path.lineTo(
        i, 
        size.height / 2 + math.sin(i / 20) * amplitude
      );
    }
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// Dotted path painter for logistics routes
class LogisticsPathPainter extends CustomPainter {
  final Color pathColor;
  
  LogisticsPathPainter({required this.pathColor});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = pathColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    
    // Draw a dotted path
    final dashWidth = 6.0;
    final dashSpace = 4.0;
    double startX = 0;
    
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint
      );
      startX += dashWidth + dashSpace;
    }
    
    // Draw small circles at the start and end
    canvas.drawCircle(Offset(0, size.height / 2), 4, paint);
    canvas.drawCircle(Offset(size.width, size.height / 2), 4, paint);
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// إضافة استيراد أيقونة الإشعارات

class ServiceProviderHomePage extends StatefulWidget {
  const ServiceProviderHomePage({super.key});

  @override
  _ServiceProviderHomePageState createState() =>
      _ServiceProviderHomePageState();
}

class _ServiceProviderHomePageState extends State<ServiceProviderHomePage> {
  int _currentIndex = 0;
  final int _currentImageIndex =
      0; // إضافة متغير لتتبع الصورة الحالية في عارض الصور

  // نموذج بيانات الخدمات الحالية للمزود
  final List<Map<String, dynamic>> _servicesList = [];

  // متغيرات إدارة الواجهة
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // متغيرات خاصة بالموقع
  double? _locationLatitude;
  double? _locationLongitude;
  String _locationAddress = "";

  // متغيرات إضافة خدمة جديدة
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String _selectedServiceType = 'تخزين';
  final List<String> _serviceTypes = ['تخزين', 'نقل'];
  String _selectedRegion = 'الجزائر';
  final String _currency = 'دينار جزائري';
  final List<String> _regions = [
    'الجزائر',
    'وهران',
    'قسنطينة',
    'عنابة',
    'سطيف',
    'بليدة',
    'باتنة',
    'تلمسان',
    'أخرى',
  ];
  final List<XFile> _selectedImages = [];
  final List<String> _imageUrls = [];

  // متغيرات خاصة بمعلومات المركبة (للنقل)
  String _selectedVehicleType = 'وانيت';
  final List<String> _vehicleTypes = [
    'شاحنة صغيرة',
    'شاحنة متوسطة',
    'شاحنة كبيرة',
    'وانيت',
    'دينا',
    'تريلا',
  ];
  final _vehicleMakeController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehicleCapacityController = TextEditingController();
  final _vehicleDimensionsController = TextEditingController();
  final _vehicleSpecialFeaturesController = TextEditingController();
  final List<XFile> _selectedVehicleImages = [];
  final List<String> _vehicleImageUrls = [];

  // متغيرات للإحصائيات
  int _totalServices = 0;
  int _totalRequests = 0;
  double _totalEarnings = 0;
  double _averageRating = 0;

  @override
  void initState() {
    super.initState();
    _loadProviderServices();
    _loadStatistics();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _vehicleMakeController.dispose();
    _vehicleYearController.dispose();
    _vehiclePlateController.dispose();
    _vehicleCapacityController.dispose();
    _vehicleDimensionsController.dispose();
    _vehicleSpecialFeaturesController.dispose();
    super.dispose();
  }
  // تحميل الإحصائيات
  Future<void> _loadStatistics() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.currentUser != null) {
        final userId = authService.currentUser!.uid;
        
        // استخدام خدمة الإحصائيات لجلب البيانات الحقيقية
        final statisticsService = ProviderStatisticsService();
        final summary = await statisticsService.getStatisticsSummary();
        
        setState(() {
          _totalServices = _servicesList.length;
          _totalRequests = summary['totalRequests'] ?? 0;
          _totalEarnings = summary['totalEarnings'] ?? 0;
          _averageRating = 4.7; // هذا يمكن حسابه من التقييمات لاحقاً
        });
      }
    } catch (e) {
      print('Error loading statistics: $e');
      
      // في حالة الخطأ، استخدم قيم تجريبية
      setState(() {
        _totalServices = _servicesList.length;
        _totalRequests = _servicesList.isNotEmpty ? _servicesList.length * 2 : 10;
        _totalEarnings = _servicesList.isNotEmpty ? _servicesList.length * 1500.0 : 7500.0;
        _averageRating = 4.7;
      });
    }
  }

  // تحميل الخدمات الحالية للمزود
  Future<void> _loadProviderServices() async {
    try {
      setState(() {
        _isLoading = true;
        // تأكد من أن القائمة فارغة قبل البدء
        _servicesList.clear();
      });

      // التحقق من تسجيل الدخول قبل محاولة تحميل الخدمات
      final authService = Provider.of<AuthService>(context, listen: false);

      // محاولة التحقق من تسجيل الدخول إذا لم يكن هناك مستخدم حالي
      if (authService.currentUser == null) {
        print(
          'لا يوجد مستخدم مسجل الدخول، محاولة التحقق من تسجيل الدخول السابق',
        );
        final bool isLoggedIn = await authService.checkPreviousLogin();
        if (!isLoggedIn) {
          print('لم يتم العثور على جلسة تسجيل دخول سابقة');
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // التأكد من وجود مستخدم بعد التحقق من تسجيل الدخول
      if (authService.currentUser != null) {
        // التحقق من وجود معرف المستخدم
        String userId = authService.currentUser!.uid;

        // إذا كان معرف المستخدم فارغًا، استخدم معرفًا مؤقتًا للاختبار
        if (userId.isEmpty) {
          print('تم اكتشاف معرف مستخدم فارغ، استخدام معرف مؤقت للاختبار');
          // استخدم معرف الخدمة الذي تم إنشاؤه مؤخرًا للاختبار
          userId = FirebaseAuth.instance.currentUser?.uid ?? 'test_user_id';
        }

        print('جاري البحث عن خدمات للمستخدم: $userId');
        print('نوع المستخدم: ${authService.currentUser!.role.toString()}');

        // إنشاء قائمة من الاستعلامات المحددة للمستخدم الحالي فقط
        print('البحث عن خدمات المزود باستخدام معرف: $userId');

        // البحث عن جميع الخدمات للاختبار
        print('البحث عن جميع الخدمات للاختبار');

        // البحث في مجموعة الخدمات بدون فلترة للاختبار
        final allServicesSnapshot =
            await FirebaseFirestore.instance
                .collection('services')
                .limit(10)
                .get();

        print(
          'تم العثور على ${allServicesSnapshot.docs.length} خدمة في المجموعة الكاملة',
        );

        // طباعة معرفات الخدمات الموجودة
        for (var doc in allServicesSnapshot.docs) {
          print(
            'خدمة موجودة: ${doc.id}, العنوان: ${doc.data()['title']}, المزود: ${doc.data()['providerId']}',
          );
        }

        // الاستعلامات العادية للبحث عن خدمات المستخدم
        final List<Query> queries = [
          // البحث باستخدام حقل providerId (المستخدم في add_service_screen)
          FirebaseFirestore.instance
              .collection('services')
              .where('providerId', isEqualTo: userId),
          // البحث باستخدام حقول أخرى للتوافق مع البيانات القديمة
          FirebaseFirestore.instance
              .collection('services')
              .where('userId', isEqualTo: userId),
          FirebaseFirestore.instance
              .collection('services')
              .where('provider_id', isEqualTo: userId),
          FirebaseFirestore.instance
              .collection('services')
              .where('uid', isEqualTo: userId),
        ];

        // إنشاء قائمة مؤقتة لتخزين الخدمات
        final List<Map<String, dynamic>> matchingServices = [];

        // تنفيذ كل استعلام وجمع النتائج
        for (var query in queries) {
          final querySnapshot = await query.get();

          if (querySnapshot.docs.isNotEmpty) {
            print('تم العثور على ${querySnapshot.docs.length} خدمة من استعلام');
          }

          for (var doc in querySnapshot.docs) {
            // التحقق من عدم وجود الوثيقة بالفعل في القائمة لتجنب التكرار
            if (!matchingServices.any((service) => service['id'] == doc.id)) {
              final data = doc.data() as Map<String, dynamic>;
              final serviceData = Map<String, dynamic>.from(data);
              serviceData['id'] = doc.id;
              matchingServices.add(serviceData);
              print('تمت إضافة خدمة للقائمة: ${data['title'] ?? 'بدون عنوان'}');
            }
          }
        }

        // البحث في مجموعة services بطريقة مختلفة إذا لم يتم العثور على خدمات
        if (matchingServices.isEmpty) {
          print('لم يتم العثور على خدمات. محاولة بحث أكثر شمولاً...');

          // استعلام جميع الوثائق من مجموعة service_locations التي تنتمي للمستخدم
          final locationSnapshot =
              await FirebaseFirestore.instance
                  .collection('service_locations')
                  .where('providerId', isEqualTo: userId)
                  .get();

          for (var locationDoc in locationSnapshot.docs) {
            final locationData = locationDoc.data();
            final serviceId = locationData['serviceId'];

            // استرجاع بيانات الخدمة باستخدام معرف الخدمة
            if (serviceId != null && serviceId.toString().isNotEmpty) {
              // تأكد من أن معرف الخدمة ليس فارغًا
              final String validServiceId = serviceId.toString().trim();
              if (validServiceId.isEmpty) {
                print('تم تجاوز وثيقة بمعرف فارغ');
                continue;
              }

              final serviceDoc =
                  await FirebaseFirestore.instance
                      .collection('services')
                      .doc(validServiceId)
                      .get();

              if (serviceDoc.exists) {
                final data = serviceDoc.data() as Map<String, dynamic>;
                data['id'] = serviceDoc.id;

                // التحقق من عدم وجود الخدمة بالفعل في القائمة
                if (!matchingServices.any(
                  (service) => service['id'] == serviceDoc.id,
                )) {
                  matchingServices.add(data);
                  print(
                    'تمت إضافة خدمة من مجموعة المواقع: ${data['title'] ?? 'بدون عنوان'}',
                  );
                }
              }
            }
          }

          // البحث في مجموعة الخدمات الخاصة بالمستخدم
          // تأكد من أن معرف المستخدم ليس فارغًا
          if (userId.toString().trim().isEmpty) {
            print('تم تجاوز استعلام خدمات المستخدم بسبب معرف مستخدم فارغ');
          } else {
            print('البحث في مجموعة خدمات المستخدم: users/$userId/services');
            final userServicesSnapshot =
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('services')
                    .get();

            print(
              'تم العثور على ${userServicesSnapshot.docs.length} خدمة في مجموعة خدمات المستخدم',
            );

            for (var serviceDoc in userServicesSnapshot.docs) {
              print(
                'معالجة وثيقة خدمة من مجموعة خدمات المستخدم: ${serviceDoc.id}',
              );
              print('بيانات الوثيقة: ${serviceDoc.data()}');

              final serviceId = serviceDoc.data()['serviceId'];
              if (serviceId != null && serviceId.toString().isNotEmpty) {
                // تأكد من أن معرف الخدمة ليس فارغًا
                final String validServiceId = serviceId.toString().trim();
                if (validServiceId.isEmpty) {
                  print('تم تجاوز وثيقة بمعرف فارغ في خدمات المستخدم');
                  continue;
                }

                print('جاري البحث عن الخدمة باستخدام المعرف: $validServiceId');

                final mainServiceDoc =
                    await FirebaseFirestore.instance
                        .collection('services')
                        .doc(validServiceId)
                        .get();

                if (mainServiceDoc.exists) {
                  print(
                    'تم العثور على الخدمة في مجموعة services: ${mainServiceDoc.id}',
                  );
                  final data = mainServiceDoc.data() as Map<String, dynamic>;
                  data['id'] = mainServiceDoc.id;

                  // طباعة بيانات الخدمة للتشخيص
                  print(
                    'بيانات الخدمة: العنوان=${data['title']}, النوع=${data['type']}, providerId=${data['providerId']}',
                  );

                  if (!matchingServices.any(
                    (service) => service['id'] == mainServiceDoc.id,
                  )) {
                    matchingServices.add(data);
                    print(
                      'تمت إضافة خدمة من مجموعة خدمات المستخدم: ${data['title'] ?? 'بدون عنوان'}',
                    );
                  } else {
                    print('تم تجاهل الخدمة لأنها موجودة بالفعل في القائمة');
                  }
                }
              }
            }
          }
        }

        print(
          'تم العثور على ${matchingServices.length} خدمة تطابق معرف المستخدم',
        );

        // تحديث القائمة المرئية
        setState(() {
          _servicesList.addAll(matchingServices);
          _isLoading = false;
          _totalServices = _servicesList.length;
          print('تم تحميل ${_servicesList.length} خدمة في القائمة المرئية');
        });

        // تحديث الإحصائيات
        _loadStatistics();
      } else {
        print('لا يوجد مستخدم مسجل الدخول حاليًا');
        setState(() {
          _isLoading = false;
        });

        // عرض رسالة للمستخدم
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('الرجاء تسجيل الدخول لعرض خدماتك'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error loading provider services: $e');
      print('Error details: ${e.toString()}');

      setState(() {
        _isLoading = false;
      });

      // عرض رسالة خطأ للمستخدم
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تحميل الخدمات. يرجى المحاولة مرة أخرى'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // إضافة خدمة جديدة - لم يتم تغيير هذه الدالة
  Future<void> _addNewService() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser!.uid;

      // التحقق من صحة السعر
      double price;
      try {
        price = double.parse(_priceController.text.trim());
        if (price < 0) throw FormatException('السعر يجب أن يكون أكبر من صفر');
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('الرجاء إدخال سعر صحيح')));
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // التحقق من وجود صور للخدمة
      if (_selectedImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('الرجاء إضافة صورة واحدة على الأقل للخدمة')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // التحقق من بيانات المركبة في حالة خدمة النقل
      if (_selectedServiceType == 'نقل') {
        if (_selectedVehicleImages.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('الرجاء إضافة صورة واحدة على الأقل للمركبة'),
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // تحميل الصور إلى Firebase Storage مع معالجة الأخطاء
      final List<String> imageUrls = [];
      for (var imageFile in _selectedImages) {
        try {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final imageName = 'service_${timestamp}_${imageUrls.length}.jpg';
          final storageRef = FirebaseStorage.instance.ref().child(
            'services/$userId/$imageName',
          );

          final uploadTask = storageRef.putFile(File(imageFile.path));
          final snapshot = await uploadTask.whenComplete(() => null);
          final imageUrl = await snapshot.ref.getDownloadURL();
          imageUrls.add(imageUrl);
        } catch (e) {
          print('Error uploading image: $e');
          continue; // استمر مع الصور الأخرى إذا فشل تحميل إحداها
        }
      }

      // التحقق من نجاح تحميل الصور
      if (imageUrls.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل الصور، يرجى المحاولة مرة أخرى')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // تحميل صور المركبة إلى Firebase Storage (للنقل)
      final List<String> vehicleImageUrls = [];
      if (_selectedServiceType == 'نقل') {
        for (var imageFile in _selectedVehicleImages) {
          try {
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final imageName =
                'vehicle_${timestamp}_${vehicleImageUrls.length}.jpg';
            final storageRef = FirebaseStorage.instance.ref().child(
              'vehicles/$userId/$imageName',
            );

            final uploadTask = storageRef.putFile(File(imageFile.path));
            final snapshot = await uploadTask.whenComplete(() => null);
            final imageUrl = await snapshot.ref.getDownloadURL();
            vehicleImageUrls.add(imageUrl);
          } catch (e) {
            print('Error uploading vehicle image: $e');
            continue;
          }
        }

        // التحقق من نجاح تحميل صور المركبة
        if (vehicleImageUrls.isEmpty && _selectedVehicleImages.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل تحميل صور المركبة، يرجى المحاولة مرة أخرى'),
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // إنشاء وثيقة الخدمة الجديدة
      final Map<String, dynamic> newService = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': price,
        'currency': _currency,
        'type': _selectedServiceType,
        'region': _selectedRegion,
        'providerId': userId, // تغيير من userId إلى providerId لتوحيد المعرفات
        'imageUrls': imageUrls,
        'rating': 0.0,
        'reviewCount': 0,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // إضافة بيانات الموقع إذا كانت متوفرة
      if (_locationLatitude != null && _locationLongitude != null) {
        newService['location'] = {
          'latitude': _locationLatitude,
          'longitude': _locationLongitude,
          'address': _locationAddress,
          'timestamp': FieldValue.serverTimestamp(),
        };
      }

      // إضافة معلومات المركبة (للنقل)
      if (_selectedServiceType == 'نقل') {
        newService['vehicle'] = {
          'type': _selectedVehicleType,
          'make': _vehicleMakeController.text.trim(),
          'year': _vehicleYearController.text.trim(),
          'plate': _vehiclePlateController.text.trim(),
          'capacity': _vehicleCapacityController.text.trim(),
          'dimensions': _vehicleDimensionsController.text.trim(),
          'specialFeatures': _vehicleSpecialFeaturesController.text.trim(),
          'imageUrls': vehicleImageUrls,
        };
      }

      // إضافة الخدمة إلى Firestore مع معالجة الأخطاء
      try {
        final DocumentReference docRef = await FirebaseFirestore.instance
            .collection('services')
            .add(newService);        // حفظ بيانات الموقع في مجموعة منفصلة للتسهيل في البحث والتصفية مع استخدام الهيكل الصحيح
        if (_locationLatitude != null && _locationLongitude != null) {
          await FirebaseFirestore.instance
              .collection('service_locations')
              .doc(docRef.id)
              .set({
                'serviceId': docRef.id,
                'providerId': userId,
                'type': _selectedServiceType,
                'position': {
                  'latitude': _locationLatitude,
                  'longitude': _locationLongitude,
                  'geopoint': GeoPoint(_locationLatitude ?? 0.0, _locationLongitude ?? 0.0),
                },
                'address': _locationAddress,
                'createdAt': FieldValue.serverTimestamp(),
                'lastUpdate': FieldValue.serverTimestamp(),
              });
        }

        // إعادة تحميل الخدمات
        await _loadProviderServices();

        // إعادة تعيين النموذج
        _resetForm();

        // إغلاق نافذة الإضافة
        Navigator.of(context).pop();

        // عرض رسالة نجاح
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تمت إضافة الخدمة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print('Error adding service to Firestore: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حفظ الخدمة في قاعدة البيانات'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error adding new service: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء إضافة الخدمة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // إعادة تعيين نموذج إضافة الخدمة
  void _resetForm() {
    _titleController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _selectedServiceType = 'تخزين';
    _selectedRegion = 'الجزائر';
    _selectedImages.clear();
    _vehicleMakeController.clear();
    _vehicleYearController.clear();
    _vehiclePlateController.clear();
    _vehicleCapacityController.clear();
    _vehicleDimensionsController.clear();
    _vehicleSpecialFeaturesController.clear();
    _selectedVehicleImages.clear();
  }

  // اختيار صور للخدمة
  Future<void> _pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      print('Error picking images: $e');
    }
  }

  // اختيار صور للمركبة
  Future<void> _pickVehicleImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        setState(() {
          _selectedVehicleImages.addAll(images);
        });
      }
    } catch (e) {
      print('Error picking vehicle images: $e');
    }
  }

  // فتح صفحة الخريطة المناسبة - لم تتغير هذه الدالة
  Future<void> _openMapPage() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;

    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('يجب تسجيل الدخول أولاً')));
      return;
    }

    // إنشاء معرف مؤقت للخدمة قبل حفظها في قاعدة البيانات
    final tempServiceId =
        'temp_${DateTime.now().millisecondsSinceEpoch}_$userId';

    if (_selectedServiceType == 'نقل') {
      // فتح صفحة تتبع السائق لخدمات النقل
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => DriverTrackingMapPage(serviceId: tempServiceId),
        ),
      );

      // التحقق من البيانات المُعادة من صفحة الخريطة
      if (result != null &&
          result.containsKey('latitude') &&
          result.containsKey('longitude')) {
        setState(() {
          _locationLatitude = result['latitude'];
          _locationLongitude = result['longitude'];
          _locationAddress = result['address'] ?? 'العنوان غير متوفر';
        });

        print('تم تحديد موقع النقل: $_locationLatitude, $_locationLongitude');
        print('العنوان: $_locationAddress');

        // عرض رسالة للمستخدم
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تم تحديد موقع النقل بنجاح')));
      }
    } else if (_selectedServiceType == 'تخزين') {
      // فتح صفحة تحديد موقع التخزين
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder:
              (context) => StorageLocationMapPage(
                serviceId: tempServiceId,
                onLocationSelected: (lat, lng, address) {
                  // تخزين بيانات الموقع مؤقتاً
                  setState(() {
                    _locationLatitude = lat;
                    _locationLongitude = lng;
                    _locationAddress = address;
                  });
                },
              ),
        ),
      );

      // التحقق من البيانات المُعادة من صفحة الخريطة
      if (_locationLatitude != null && _locationLongitude != null) {
        print('تم تحديد موقع التخزين: $_locationLatitude, $_locationLongitude');
        print('العنوان: $_locationAddress');

        // عرض رسالة للمستخدم
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تم تحديد موقع التخزين بنجاح')));
      }
    }

    // إعادة فتح نافذة تعديل الخدمة إذا كنا في سياق التعديل
    // أو لا نقوم بأي شيء إذا كنا في سياق إضافة خدمة جديدة
    // حيث سيتم التعامل مع هذا في صفحة AddServiceScreen
  }

  // حذف دالة _showAddServiceDialog والاستعاضة عنها بدالة جديدة لفتح صفحة إضافة الخدمة
  void _openAddServiceScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AddServiceScreen(
              onServiceAdded: () {
                // إعادة تحميل الخدمات فور إضافة خدمة جديدة
                print('تمت الإضافة بنجاح، جاري تحديث القائمة...');
                _loadProviderServices();
              },
            ),
      ),
    ).then((_) {
      // إعادة تحميل الخدمات عند العودة من صفحة إضافة الخدمة
      // هذا يضمن تحديث القائمة حتى إذا لم يتم استدعاء onServiceAdded
      print('العودة من صفحة إضافة الخدمة، جاري تحديث القائمة...');
      _loadProviderServices();
    });
  }

  // حذف الخدمة
  Future<void> _deleteService(String serviceId) async {
    try {
      // عرض مربع حوار للتأكيد قبل الحذف
      final bool confirmDelete =
          await showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red),
                      SizedBox(width: 10),
                      Text('تأكيد الحذف'),
                    ],
                  ),
                  content: Text(
                    'هل أنت متأكد من حذف هذه الخدمة؟ لا يمكن التراجع عن هذا الإجراء.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('إلغاء'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: Text('حذف', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
          ) ??
          false;

      if (!confirmDelete) return;

      setState(() {
        _isLoading = true;
      });

      // حذف الخدمة من Firestore
      await FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId)
          .delete();

      // حذف بيانات الموقع إذا وجدت
      await FirebaseFirestore.instance
          .collection('service_locations')
          .doc(serviceId)
          .delete();

      // إعادة تحميل الخدمات
      await _loadProviderServices();

      // عرض رسالة نجاح
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف الخدمة بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error deleting service: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء حذف الخدمة'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // تغيير حالة تفعيل الخدمة
  Future<void> _toggleServiceStatus(
    String serviceId,
    bool currentStatus,
  ) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // تحديث حالة الخدمة في Firestore
      await FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId)
          .update({'isActive': !currentStatus});

      // إعادة تحميل الخدمات
      await _loadProviderServices();

      // عرض رسالة نجاح
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentStatus ? 'تم تعطيل الخدمة بنجاح' : 'تم تفعيل الخدمة بنجاح',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error toggling service status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تغيير حالة الخدمة'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // تحميل بيانات الخدمة للتعديل
  Future<void> _loadServiceForEdit(Map<String, dynamic> service) async {
    final String serviceId = service['id'];
    _resetForm(); // إعادة تعيين النموذج أولاً

    // تعبئة النموذج ببيانات الخدمة الحالية
    setState(() {
      _titleController.text = service['title'] ?? '';
      _descriptionController.text = service['description'] ?? '';
      _priceController.text = service['price']?.toString() ?? '';
      _selectedServiceType = service['type'] ?? 'تخزين';
      _selectedRegion = service['region'] ?? 'الجزائر';

      // استعادة بيانات الموقع إذا وجدت
      if (service.containsKey('location')) {
        final locationData = service['location'];
        _locationLatitude = locationData['latitude'];
        _locationLongitude = locationData['longitude'];
        _locationAddress = locationData['address'] ?? '';
      }

      // استعادة بيانات المركبة إذا كانت خدمة نقل
      if (_selectedServiceType == 'نقل' && service.containsKey('vehicle')) {
        final vehicleData = service['vehicle'];
        _selectedVehicleType = vehicleData['type'] ?? 'وانيت';
        _vehicleMakeController.text = vehicleData['make'] ?? '';
        _vehicleYearController.text = vehicleData['year'] ?? '';
        _vehiclePlateController.text = vehicleData['plate'] ?? '';
        _vehicleCapacityController.text = vehicleData['capacity'] ?? '';
        _vehicleDimensionsController.text = vehicleData['dimensions'] ?? '';
        _vehicleSpecialFeaturesController.text =
            vehicleData['specialFeatures'] ?? '';
      }
    });

    // فتح نافذة التعديل
    _showEditServiceDialog(serviceId);
  }
  // عرض نافذة تعديل الخدمة
  void _showEditServiceDialog(String serviceId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
            title: Row(
              children: [
                Icon(
                  _selectedServiceType == 'تخزين'
                      ? Icons.warehouse
                      : Icons.local_shipping,
                  color:
                      _selectedServiceType == 'تخزين'
                          ? Color(0xFF3498DB)
                          : Color(0xFFE67E22),
                ),
                SizedBox(width: 12),
                Text(
                  'تعديل الخدمة',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9B59B6),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // نوع الخدمة
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.grey.withOpacity(0.1),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'نوع الخدمة',
                            labelStyle: TextStyle(
                              color: Color(0xFF9B59B6),
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.category,
                              color: Color(0xFF9B59B6),
                            ),
                          ),
                          value: _selectedServiceType,
                          items:
                              _serviceTypes
                                  .map(
                                    (type) => DropdownMenuItem(
                                      value: type,
                                      child: Row(
                                        children: [
                                          Icon(
                                            type == 'تخزين'
                                                ? Icons.warehouse
                                                : Icons.local_shipping,
                                            color:
                                                type == 'تخزين'
                                                    ? Color(0xFF3498DB)
                                                    : Color(0xFFE67E22),
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(type),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedServiceType = value;
                              });
                              // أعد بناء الحوار لتحديث العناصر المعتمدة على نوع الخدمة
                              Navigator.of(context).pop();
                              _showEditServiceDialog(serviceId);
                            }
                          },
                          dropdownColor: Colors.white,
                          icon: Icon(
                            Icons.arrow_drop_down_circle,
                            color: Color(0xFF9B59B6),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // نفس العناصر المستخدمة في نافذة إضافة الخدمة
                      // عنوان الخدمة
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.grey.withOpacity(0.1),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'عنوان الخدمة',
                            labelStyle: TextStyle(
                              color: Color(0xFF9B59B6),
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.title,
                              color: Color(0xFF9B59B6),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'الرجاء إدخال عنوان الخدمة';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(height: 16),

                      // وصف الخدمة
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.grey.withOpacity(0.1),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: 'وصف الخدمة',
                            labelStyle: TextStyle(
                              color: Color(0xFF9B59B6),
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.description,
                              color: Color(0xFF9B59B6),
                            ),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'الرجاء إدخال وصف الخدمة';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(height: 16),

                      // السعر والعملة
                      Row(
                        children: [
                          // حقل السعر
                          Expanded(
                            flex: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.grey.withOpacity(0.1),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              child: TextFormField(
                                controller: _priceController,
                                decoration: InputDecoration(
                                  labelText: 'السعر',
                                  labelStyle: TextStyle(
                                    color: Color(0xFF9B59B6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  border: InputBorder.none,
                                  prefixIcon: Icon(
                                    Icons.attach_money,
                                    color: Color(0xFF9B59B6),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'الرجاء إدخال السعر';
                                  }
                                  try {
                                    double.parse(value);
                                  } catch (e) {
                                    return 'الرجاء إدخال قيمة رقمية';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
                          SizedBox(width: 10),

                          // العملة
                          Expanded(
                            flex: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.grey.withOpacity(0.1),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              child: TextFormField(
                                initialValue: _currency,
                                decoration: InputDecoration(
                                  labelText: 'العملة',
                                  labelStyle: TextStyle(
                                    color: Color(0xFF9B59B6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  border: InputBorder.none,
                                ),
                                readOnly: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // المنطقة
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.grey.withOpacity(0.1),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'المنطقة',
                            labelStyle: TextStyle(
                              color: Color(0xFF9B59B6),
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.location_city,
                              color: Color(0xFF9B59B6),
                            ),
                          ),
                          value: _selectedRegion,
                          items:
                              _regions
                                  .map(
                                    (region) => DropdownMenuItem(
                                      value: region,
                                      child: Text(region),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedRegion = value;
                              });
                            }
                          },
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: Color(0xFF9B59B6),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // زر تحديد الموقع على الخريطة
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            colors: [Color(0xFF5DADE2), Color(0xFF3498DB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF3498DB).withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // إغلاق نافذة التعديل مؤقتًا
                            Navigator.of(context).pop();
                            // فتح صفحة الخريطة حسب نوع الخدمة
                            _openMapPage();
                          },
                          icon: Icon(Icons.location_on, color: Colors.white),
                          label: Text(
                            'تحديد الموقع على الخريطة',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            minimumSize: Size(double.infinity, 50),
                          ),
                        ),
                      ),

                      // إضافة باقي الحقول ومعلومات المركبة كما في نافذة إضافة الخدمة
                      // ...

                      // عرض عنوان الموقع الحالي إذا كان موجودًا
                      if (_locationAddress.isNotEmpty) ...[
                        SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'تم تحديد الموقع',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      _locationAddress,
                                      style: TextStyle(fontSize: 12),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],                ),
                ),
              ),
            ),
        actions: [
              // زر الإلغاء
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _resetForm();
                },
                child: Text(
                  'إلغاء',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // زر حفظ التعديلات
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    colors: [Color(0xFF9B59B6), Color(0xFF8E44AD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF9B59B6).withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () => _updateService(serviceId),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child:
                      _isLoading
                          ? CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          )
                          : Text(
                            'حفظ التعديلات',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),
            ],
          ),
    );
  }

  // تحديث الخدمة
  Future<void> _updateService(String serviceId) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Ensure _isLoading is correctly scoped and set within setState
    if (!mounted) return; // Check mounted before async operations
    setState(() {
      _isLoading = true;
    });

    try {
      // التحقق من صحة السعر
      double price;
      try {
        price = double.parse(_priceController.text.trim());
        if (price < 0) throw FormatException('السعر يجب أن يكون أكبر من صفر');
      } catch (e) {
        if (mounted) { // Check mounted before UI operations
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('الرجاء إدخال سعر صحيح')));
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // إنشاء بيانات الخدمة المحدثة
      final Map<String, dynamic> updatedService = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': price,
        'currency': _currency,
        'type': _selectedServiceType,
        'region': _selectedRegion,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // إضافة بيانات الموقع إذا كانت متوفرة
      if (_locationLatitude != null && _locationLongitude != null) {
        updatedService['location'] = {
          'latitude': _locationLatitude,
          'longitude': _locationLongitude,
          'address': _locationAddress,
        };
      }

      // تحديث الخدمة في Firestore
      await FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId)
          .update(updatedService);

      // تحديث بيانات الموقع في مجموعة منفصلة إذا كانت متوفرة
      if (_locationLatitude != null && _locationLongitude != null) {
        final double lat = _locationLatitude!;
        final double lng = _locationLongitude!;
        await FirebaseFirestore.instance
            .collection('service_locations')
            .doc(serviceId)
            .set({
              'serviceId': serviceId,
              'providerId': Provider.of<AuthService>(context, listen: false).currentUser!.uid,
              'type': _selectedServiceType,
              'position': {
                'latitude': lat,
                'longitude': lng,
                'geopoint': GeoPoint(lat, lng),
              },
              'address': _locationAddress,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }

      // إعادة تحميل الخدمات
      await _loadProviderServices();

      if (mounted) { // Check mounted before UI operations
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحديث الخدمة بنجاح'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print('Error updating service: $e');
      if (mounted) { // Check mounted before UI operations
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تحديث الخدمة'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) { // Check mounted before UI operations
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  // بطاقة إحصائية عصرية بتصميم لوجستي
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.9),
              Colors.white.withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with circular background
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            // Value with larger, bolder text
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: const Color(0xFF0A2463),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Title with color matching the icon
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13, 
                color: color.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // شريط تنقل سفلي بتصميم لوجستي عصري
  Widget _buildBottomNavigationBar() {
    // Define our logistics theme colors
    final vibrantOrange = const Color(0xFFFF7F11);
    
    return Container(
      height: 75,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, -3),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Logistics-themed wave decoration at the top of the navbar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: const Size(double.infinity, 15),
              painter: LogisticsWavePainter(
                color: vibrantOrange.withOpacity(0.2),
                amplitude: 4.0,
              ),
            ),
          ),
          // Main navigation bar
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              selectedItemColor: vibrantOrange,
              unselectedItemColor: Colors.grey[400],
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              showUnselectedLabels: true,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 11,
              ),
              items: [
                BottomNavigationBarItem(
                  icon: Icon(_currentIndex == 0 
                    ? Icons.list_alt 
                    : Icons.list_alt_outlined),
                  label: 'خدماتي',
                ),                BottomNavigationBarItem(
                  icon: _buildRequestsTabIcon(),
                  label: 'الطلبات',
                ),
                BottomNavigationBarItem(
                  icon: Icon(_currentIndex == 2 
                    ? Icons.bar_chart 
                    : Icons.bar_chart_outlined),
                  label: 'الإحصائيات',
                ),
                BottomNavigationBarItem(
                  icon: Icon(_currentIndex == 3 
                    ? Icons.person 
                    : Icons.person_outline),
                  label: 'حسابي',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // تبويب حسابي - تصميم عصري محسّن 2025
  Widget _buildProfilePage() {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final nameController = TextEditingController(text: user?.fullName ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final phoneController = TextEditingController(
      text: user?.phoneNumber ?? '',
    );
    final formKeyProfile = GlobalKey<FormState>();
    bool isSaving = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // خلفية مع رمز المستخدم
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // خلفية لوجستية مميزة
                    Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      child: Stack(
                        children: [
                          // زخارف خلفية شحن ولوجستيات
                          Positioned(
                            right: -15,
                            top: 20,
                            child: Icon(
                              Icons.local_shipping_outlined,
                              size: 80,
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          Positioned(
                            left: -5,
                            bottom: 10,
                            child: Icon(
                              Icons.warehouse_outlined,
                              size: 70,
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          // معلومات أساسية
                          Padding(
                            padding: EdgeInsets.only(top: 30, right: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'مرحباً بك',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  user?.fullName ?? 'مزود خدمات',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 5),
                                // استبدال النص برمز
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      user?.role == UserRole.provider
                                          ? Icons.verified_rounded
                                          : Icons.person_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    SizedBox(width: 4),
                                    Icon(
                                      user?.role == UserRole.provider
                                          ? Icons.local_shipping_outlined
                                          : Icons.shopping_bag_outlined,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // صورة المستخدم
                    Positioned(
                      bottom: -50,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF7C3AED).withOpacity(0.3),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                          border: Border.all(color: Colors.white, width: 4),
                        ),                        child: GestureDetector(
                          onTap: () => _pickProfileImage(context),
                          child: CircleAvatar(
                            radius: 55,
                            backgroundColor: Colors.white,
                            backgroundImage: user?.profileImageUrl != null && user!.profileImageUrl.isNotEmpty
                                ? NetworkImage(user.profileImageUrl)
                                : null,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (user?.profileImageUrl == null || user!.profileImageUrl.isEmpty)
                                  Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Color(0xFF7C3AED),
                                  ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Color(0xFF7C3AED),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 65),

                // بطاقات أو أيقونات اختصارات
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildProfileQuickAction(
                        icon: Icons.assignment,
                        label: 'طلباتي',
                        color: Color(0xFF60A5FA),
                        onTap: () {
                          setState(() => _currentIndex = 1);
                        },
                      ),
                      _buildProfileQuickAction(
                        icon: Icons.local_shipping,
                        label: 'خدماتي',
                        color: Color(0xFFF472B6),
                        onTap: () {
                          setState(() => _currentIndex = 0);
                        },
                      ),
                      _buildProfileQuickAction(
                        icon: Icons.bar_chart,
                        label: 'الإحصائيات',
                        color: Color(0xFF34D399),
                        onTap: () {
                          setState(() => _currentIndex = 2);
                        },
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 30),

                // بطاقة المعلومات الشخصية
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Form(
                      key: formKeyProfile,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // عنوان
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Color(0xFF7C3AED).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.person_outline,
                                  color: Color(0xFF7C3AED),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'المعلومات الشخصية',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 25),

                          // حقول البيانات
                          _buildProfileField(
                            controller: nameController,
                            label: 'الاسم الكامل',
                            icon: Icons.person,
                            validator:
                                (v) =>
                                    v == null || v.trim().isEmpty
                                        ? 'الاسم مطلوب'
                                        : null,
                          ),
                          SizedBox(height: 18),
                          _buildProfileField(
                            controller: emailController,
                            label: 'البريد الإلكتروني',
                            icon: Icons.email,
                            keyboardType: TextInputType.emailAddress,
                            validator:
                                (v) =>
                                    v == null || !v.contains('@')
                                        ? 'بريد إلكتروني غير صالح'
                                        : null,
                          ),
                          SizedBox(height: 18),
                          _buildProfileField(
                            controller: phoneController,
                            label: 'رقم الهاتف',
                            icon: Icons.phone,
                            keyboardType: TextInputType.phone,
                            validator:
                                (v) =>
                                    v == null || v.trim().length < 8
                                        ? 'رقم غير صالح'
                                        : null,
                          ),

                          SizedBox(height: 25),

                          // زر الحفظ
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed:
                                  isSaving
                                      ? null
                                      : () async {
                                        if (formKeyProfile.currentState!
                                            .validate()) {
                                          setState(() => isSaving = true);
                                          try {
                                            await authService.updateProfile(
                                              fullName:
                                                  nameController.text.trim(),
                                              email:
                                                  emailController.text.trim(),
                                              phone:
                                                  phoneController.text.trim(),
                                            );
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.check_circle,
                                                        color: Colors.white,
                                                      ),
                                                      SizedBox(width: 10),
                                                      Text(
                                                        'تم تحديث البيانات بنجاح',
                                                      ),
                                                    ],
                                                  ),
                                                  backgroundColor: Colors.green,
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  margin: EdgeInsets.all(10),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.error,
                                                      color: Colors.white,
                                                    ),
                                                    SizedBox(width: 10),
                                                    Text(
                                                      'فشل تحديث البيانات: ${e.toString()}',
                                                    ),
                                                  ],
                                                ),
                                                backgroundColor: Colors.red,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                margin: EdgeInsets.all(10),
                                              ),
                                            );
                                          }
                                          setState(() => isSaving = false);
                                        }
                                      },
                              icon:
                                  isSaving
                                      ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : Icon(Icons.save_rounded),
                              label: Text('حفظ التعديلات'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF7C3AED),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 25),

                // معلومات إضافية
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildSettingsItem(
                        title: 'تغيير كلمة المرور',
                        icon: Icons.lock_outline,
                        iconColor: Color(0xFF60A5FA),
                        onTap: () {
                          // إظهار نافذة لتغيير كلمة المرور
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('ستتوفر هذه الميزة قريباً'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      Divider(height: 1, indent: 70),
                      _buildSettingsItem(
                        title: 'الإشعارات',
                        icon: Icons.notifications_outlined,
                        iconColor: Color(0xFFF472B6),
                        onTap: () {
                          // إظهار نافذة الإشعارات
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('ستتوفر هذه الميزة قريباً'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      Divider(height: 1, indent: 70),
                      _buildSettingsItem(
                        title: 'الدعم الفني',
                        icon: Icons.headset_mic_outlined,
                        iconColor: Color(0xFF34D399),
                        onTap: () {
                          // إظهار نافذة الدعم الفني
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('ستتوفر هذه الميزة قريباً'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 25),

                // زر تسجيل الخروج
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // إظهار مربع حوار لتأكيد تسجيل الخروج
                      _showLogoutConfirmDialog();
                    },
                    icon: Icon(Icons.logout),
                    label: Text('تسجيل الخروج'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),

                SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  // مربع حوار تأكيد تسجيل الخروج
  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
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
                                      builder: (_) => const BiLinkHomePage(),
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
                                  elevation: 0,
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

  // ويدجت عنصر الإعدادات
  Widget _buildSettingsItem({
    required String title,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return material.InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor),
            ),
            SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F2937),
              ),
            ),
            Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  // ويدجت اختصار سريع في الملف الشخصي
  Widget _buildProfileQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.3), width: 1.5),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // حقل ملف شخصي عصري
  Widget _buildProfileField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 16,
        color: Color(0xFF1F2937),
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Color(0xFF7C3AED)),
        labelText: label,
        labelStyle: TextStyle(
          color: Color(0xFF7C3AED).withOpacity(0.7),
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: Color(0xFFF9FAFB),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Color(0xFF7C3AED), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.red, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }

  // اختيار وتحميل صورة الملف الشخصي
  Future<void> _pickProfileImage(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تسجيل الدخول لتحديث الصورة الشخصية'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    
    if (pickedFile != null) {
      // عرض مؤشر التحميل
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          );
        },
      );
      
      try {
        // رفع الصورة إلى Firebase Storage
        final File imageFile = File(pickedFile.path);
        final fileName = path.basename(imageFile.path);
        final destination = 'profile_images/${user.uid}/$fileName';
        final storageRef = FirebaseStorage.instance.ref().child(destination);
        
        // تنفيذ عملية الرفع
        await storageRef.putFile(imageFile);
        
        // الحصول على رابط الصورة
        final imageUrl = await storageRef.getDownloadURL();
        
        // تحديث بيانات المستخدم في Firestore
        await authService.updateProfileImage(imageUrl);
        
        // إغلاق مربع الحوار
        if (context.mounted) {
          Navigator.of(context).pop();
          
          // عرض رسالة نجاح
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث الصورة الشخصية بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        // إغلاق مربع الحوار
        if (context.mounted) {
          Navigator.of(context).pop();
          
          // عرض رسالة خطأ
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('حدث خطأ أثناء تحديث الصورة: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vibrantOrange = const Color(0xFFFF7F11);
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.black, Colors.black.withOpacity(0.85)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [              Icon(Icons.local_shipping_outlined, color: vibrantOrange),
              const SizedBox(width: 8),
              const Text('لوحة الخدمات',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,          centerTitle: true,
          actions: [
            // زر الإشعارات مع عدد الإشعارات غير المقروءة
            StreamBuilder<int>(
              stream: NotificationService().getUnreadNotificationsCount(
                FirebaseAuth.instance.currentUser?.uid ?? '',
              ),
              builder: (context, snapshot) {
                final unreadNotificationsCount = snapshot.data ?? 0;
                
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    if (unreadNotificationsCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: NotificationBadge(count: unreadNotificationsCount),
                      ),
                  ],
                );
              },
            ),
            // زر المحادثات مع إشعار عدد الرسائل غير المقروءة
            StreamBuilder<int>(
              stream: ChatService(
                FirebaseAuth.instance.currentUser?.uid ?? '',
              ).getUnreadMessageCount(),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;

                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.chat_bubble_outline, color: Colors.white),
                        tooltip: 'المحادثات',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatListScreen(),
                            ),
                          );
                        },
                      ),
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
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              // Logistics themed background elements
              Positioned(
                top: -50,
                right: -50,
                child: CustomPaint(
                  size: const Size(150, 150),
                  painter: LogisticsCirclesPainter(color: vibrantOrange.withOpacity(0.1)),
                ),
              ),
              Positioned(
                bottom: 100,
                left: -30,
                child: CustomPaint(
                  size: const Size(100, 100),
                  painter: LogisticsCirclesPainter(color: Colors.teal.withOpacity(0.1)),
                ),
              ),
              
              // Main content
              _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF7F11)))
                : _currentIndex == 0
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [                        // Dashboard header with wave decoration
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.teal.withOpacity(0.2), Colors.black.withOpacity(0.3)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: vibrantOrange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: vibrantOrange.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.dashboard_rounded,
                                      color: vibrantOrange,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'لوحة التحكم',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        'إدارة خدماتك اللوجستية',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              // إحصائيات سريعة
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Row(
                                  children: [
                                    _buildStatCard(
                                      title: 'خدماتي',
                                      value: '$_totalServices',
                                      icon: Icons.list_alt,
                                      color: Colors.teal,
                                    ),
                                    _buildStatCard(
                                      title: 'الطلبات',
                                      value: '$_totalRequests',
                                      icon: Icons.assignment,
                                      color: vibrantOrange,
                                    ),
                                    _buildStatCard(
                                      title: 'الإيرادات',
                                      value: '${_totalEarnings.toStringAsFixed(0)} دج',
                                      icon: Icons.monetization_on,
                                      color: const Color(0xFF34D399),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // عنوان
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: vibrantOrange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.local_shipping_rounded,
                                  color: vibrantOrange,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'خدماتي اللوجستية',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // قائمة الخدمات
                        _buildServicesList(),
                      ],
                    ),
                  )                : _currentIndex == 1
                ? const RequestTabs()
                : _currentIndex == 2
                ? const ProviderStatisticsPage()
                : _buildProfilePage(),
            ],
          ),
        ),
        floatingActionButton:
            _currentIndex == 0
                ? FloatingActionButton.extended(
                    onPressed: _openAddServiceScreen,
                    backgroundColor: vibrantOrange,
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة خدمة'),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  )
                : null,
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  // قائمة الخدمات الحديثة
  Widget _buildServicesList() {
    final vibrantOrange = const Color(0xFFFF7F11);
    
    if (_servicesList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // Empty state with logistics-themed illustration
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: vibrantOrange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: vibrantOrange.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                ),
                Icon(
                  Icons.local_shipping_outlined,
                  size: 50,
                  color: vibrantOrange.withOpacity(0.7),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'لا توجد خدمات لوجستية بعد',
              style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'أضف خدمتك الأولى للبدء',
                style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.9)),
              ),
            ),
          ],
        ),
      );
    }
    
    // Animated list with staggered appearance
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _servicesList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        final service = _servicesList[index];
        // Add a slight delay based on index for staggered animation effect
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: 1.0,
          child: _buildModernServiceCard(service),
        );
      },
    );
  }

  // بطاقة خدمة حديثة بتصميم لوجستي عصري
  Widget _buildModernServiceCard(Map<String, dynamic> service) {
    final vibrantOrange = const Color(0xFFFF7F11);
    
    final String title = service['title'] ?? 'خدمة بدون عنوان';
    final String type = service['type'] ?? 'غير محدد';
    final String region = service['region'] ?? 'غير محدد';
    final double price = (service['price'] as num?)?.toDouble() ?? 0.0;
    final bool isActive = service['isActive'] ?? true;
    // --- التعديل للصور ---
    List<dynamic> imageUrls = service['imageUrls'] ?? [];

    // Debug print for service images
    print(
      'ProviderInterface: Service ${service['id']} has ${imageUrls.length} images: $imageUrls',
    );

    if (type == 'نقل' &&
        (imageUrls.isEmpty ||
            (imageUrls.length == 1 &&
                (imageUrls[0] == null || imageUrls[0].toString().isEmpty)))) {
      // جلب صور المركبة إذا كانت متوفرة
      if (service['vehicle'] != null &&
          service['vehicle'] is Map &&
          (service['vehicle'] as Map).containsKey('imageUrls')) {
        final vehicleImgs = service['vehicle']['imageUrls'];
        if (vehicleImgs is List && vehicleImgs.isNotEmpty) {
          imageUrls = vehicleImgs;
          print(
            'ProviderInterface: Using vehicle images instead: ${imageUrls.length} images: $imageUrls',
          );
        }
      }
    }

    final double rating = (service['rating'] as num?)?.toDouble() ?? 0.0;
    final int reviewCount = (service['reviewCount'] as num?)?.toInt() ?? 0;

    // ألوان تدل على الخدمات اللوجستية
    final Color typeColor =
        type == 'تخزين'
            ? Colors.teal // تيل للتخزين
            : vibrantOrange; // برتقالي للنقل

    final IconData typeIcon =
        type == 'تخزين'
            ? Icons.warehouse_rounded
            : Icons.local_shipping_rounded;

    // Debug: طباعة روابط الصور لهذه الخدمة
    print('صور الخدمة ($title): $imageUrls');

    // مؤشر الصفحة للصور
    int currentImage = 0;
    final PageController pageController = PageController();

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          decoration: BoxDecoration(
            // تدرج لوني جميل بدلا من لون أبيض
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                type == 'تخزين'
                    ? Colors.teal.withOpacity(0.05) // خلفية بلون تيل فاتح جدا للتخزين
                    : vibrantOrange.withOpacity(0.05), // خلفية بلون برتقالي فاتح جدا للنقل
              ],
            ),
            borderRadius: BorderRadius.circular(24), // زوايا أكثر استدارة
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 6),
                spreadRadius: 2,
              ),
            ],
          ),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // سلايدر صور الخدمة بارتفاع أكبر
                Stack(
                  children: [
                    // الصور
                    Container(
                      height: 200, // ارتفاع أكبر للصور
                      width: double.infinity,
                      decoration: BoxDecoration(
                        // ظل خفيف داخلي
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child:
                          imageUrls.isNotEmpty
                              ? PageView.builder(
                                controller: pageController,
                                itemCount: imageUrls.length,
                                onPageChanged: (index) {
                                  setState(() => currentImage = index);
                                },
                                itemBuilder: (context, index) {
                                  return Hero(
                                    tag:
                                        'service_image_${service['id']}_$index',
                                    child: Image.network(
                                      imageUrls[index],
                                      fit: BoxFit.cover,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        return Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                typeColor.withOpacity(0.05),
                                                typeColor.withOpacity(0.15),
                                              ],
                                            ),
                                          ),
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  typeIcon,
                                                  size: 60,
                                                  color: typeColor.withOpacity(
                                                    0.4,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  type == 'تخزين'
                                                      ? 'خدمة تخزين'
                                                      : 'خدمة نقل',
                                                  style: TextStyle(
                                                    color: typeColor
                                                        .withOpacity(0.7),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              )
                              : Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      typeColor.withOpacity(0.05),
                                      typeColor.withOpacity(0.15),
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        typeIcon,
                                        size: 60,
                                        color: typeColor.withOpacity(0.4),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        type == 'تخزين'
                                            ? 'خدمة تخزين'
                                            : 'خدمة نقل',
                                        style: TextStyle(
                                          color: typeColor.withOpacity(0.7),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                    ),

                    // شريط عنوان مع بيانات الخدمة الرئيسية
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(typeIcon, color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    type,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Spacer(),
                            // شارة الحالة
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isActive
                                        ? Colors.green.withOpacity(0.8)
                                        : Colors.red.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isActive
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    isActive ? 'نشط' : 'غير نشط',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // مؤشرات عدد الصور
                    if (imageUrls.length > 1)
                      Positioned(
                        bottom: 10,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            imageUrls.length,
                            (index) => AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              margin: EdgeInsets.symmetric(horizontal: 3),
                              width: currentImage == index ? 18 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color:
                                    currentImage == index
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.5),
                                boxShadow: [
                                  if (currentImage == index)
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 2,
                                      spreadRadius: 0.5,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (imageUrls.length > 1) ...[
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () {
                            if (currentImage > 0) {
                              pageController.previousPage(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              pageController.animateToPage(
                                imageUrls.length - 1,
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
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
                              child: Icon(
                                Icons.arrow_back_ios_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () {
                            if (currentImage < imageUrls.length - 1) {
                              pageController.nextPage(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              pageController.animateToPage(
                                0,
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
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
                              child: Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // بيانات الخدمة
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // عنوان الخدمة
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      SizedBox(height: 12),                      // معلومات الخدمة: السعر والمنطقة والتقييم
                      Row(
                        children: [
                          // السعر بتصميم مميز - يظهر فقط لخدمات التخزين
                          if (type == 'تخزين')
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: typeColor.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.payments_rounded,
                                    size: 16,
                                    color: typeColor,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '${price.toStringAsFixed(0)} دج',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: typeColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Add spacing only if price container is shown
                          if (type == 'تخزين')
                            SizedBox(width: 12),

                          // المنطقة
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Colors.grey[700],
                                ),
                                SizedBox(width: 4),
                                Text(
                                  region,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Spacer(),

                          // التقييم
                          if (rating > 0)
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 18),
                                SizedBox(width: 4),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Text(
                                  '($reviewCount)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),

                      SizedBox(height: 12),

                      // أزرار التحكم بشكل جديد
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildControlButton(
                            icon: Icons.edit_rounded,
                            label: 'تعديل',
                            color: Color(0xFF3B82F6),
                            onTap: () => _loadServiceForEdit(service),
                          ),
                          _buildControlButton(
                            icon:
                                isActive
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                            label: isActive ? 'تعطيل' : 'تفعيل',
                            color: isActive ? Colors.orange : Colors.green,
                            onTap:
                                () => _toggleServiceStatus(
                                  service['id'],
                                  isActive,
                                ),
                          ),
                          _buildControlButton(
                            icon: Icons.delete_rounded,
                            label: 'حذف',
                            color: Colors.red,
                            onTap: () => _deleteService(service['id']),
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
      },
    );
  }

  // زر تحكم بشكل جديد
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return material.InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),          ],
        ),
      ),
    );
  }
  
  // بناء أيقونة تبويب الطلبات مع إظهار إشعار للطلبات الجديدة
  Widget _buildRequestsTabIcon() {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final notificationService = NotificationService();
    
    return StreamBuilder<int>(
      stream: notificationService.getPendingRequestsCount(userId),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              _currentIndex == 1 
                ? Icons.assignment 
                : Icons.assignment_outlined
            ),
            if (count > 0)
              Positioned(
                right: -6,
                top: -3,
                child: NotificationBadge(count: count),
              ),
          ],
        );      },
    );
  }
}
