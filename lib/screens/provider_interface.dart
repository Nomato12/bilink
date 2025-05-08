import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'driver_tracking_map.dart';
import 'storage_location_map.dart';
import 'add_service_screen.dart'; // Corrected import path
import '../models/home_page.dart';

class ServiceProviderHomePage extends StatefulWidget {
  const ServiceProviderHomePage({super.key});

  @override
  _ServiceProviderHomePageState createState() =>
      _ServiceProviderHomePageState();
}

class _ServiceProviderHomePageState extends State<ServiceProviderHomePage> {
  int _currentIndex = 0;

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
  final List<File> _selectedImages = [];

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
  final List<File> _vehicleImages = [];

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

        // هنا يمكن إضافة استعلامات لجلب الإحصائيات من Firebase
        // هذه قيم تجريبية فقط
        setState(() {
          _totalServices = _servicesList.length;
          _totalRequests = 12;
          _totalEarnings = 8500;
          _averageRating = 4.7;
        });
      }
    } catch (e) {
      print('Error loading statistics: $e');
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

      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.currentUser != null) {
        final userId = authService.currentUser!.uid;

        print('جاري البحث عن خدمات للمستخدم: $userId');
        print('نوع المستخدم: ${authService.currentUser!.role.toString()}');

        // استعلام مباشر للخدمات التي تتطابق مع معرف المستخدم
        final userServicesSnapshot =
            await FirebaseFirestore.instance
                .collection('services')
                .where('userId', isEqualTo: userId)
                .get();

        print(
          'تم العثور على ${userServicesSnapshot.docs.length} خدمة من استعلام userId المباشر',
        );

        // إنشاء قائمة مؤقتة لتخزين الخدمات المطابقة
        List<Map<String, dynamic>> matchingServices = [];

        // إضافة الخدمات من الاستعلام المباشر
        for (var doc in userServicesSnapshot.docs) {
          final data = doc.data();
          // إضافة معرف المستند إلى البيانات
          final serviceData = Map<String, dynamic>.from(data);
          serviceData['id'] = doc.id;
          matchingServices.add(serviceData);
          print(
            'تمت إضافة خدمة للقائمة من الاستعلام المباشر: ${data['title']}',
          );
        }

        // استعلام إضافي للتأكد من عدم فقدان أي خدمات (قد تكون مخزنة بطريقة مختلفة)
        if (matchingServices.isEmpty) {
          print(
            'لم يتم العثور على خدمات في الاستعلام المباشر، جاري البحث في كل الخدمات',
          );

          // جلب جميع الخدمات
          final allServicesSnapshot =
              await FirebaseFirestore.instance.collection('services').get();

          print(
            'إجمالي الخدمات في قاعدة البيانات: ${allServicesSnapshot.docs.length}',
          );

          for (var doc in allServicesSnapshot.docs) {
            final data = doc.data();
            // طباعة بيانات كل خدمة للتشخيص
            print(
              'خدمة: ${doc.id} - userId: ${data['userId']}, providerId: ${data['providerId']}',
            );

            // تحقق منطقي من التطابق (تحويل المتغيرات إلى نصوص للمقارنة الآمنة)
            final docUserId = data['userId']?.toString() ?? '';
            final docProviderId = data['providerId']?.toString() ?? '';
            final docUid = data['uid']?.toString() ?? '';
            final docuserId = data['user_id']?.toString() ?? '';
            final docproviderId = data['provider_id']?.toString() ?? '';

            print('مقارنة: "$docUserId" مع "$userId"');

            if (docUserId == userId ||
                docProviderId == userId ||
                docUid == userId ||
                docuserId == userId ||
                docproviderId == userId) {
              // إضافة معرف المستند إلى البيانات
              final serviceData = Map<String, dynamic>.from(data);
              serviceData['id'] = doc.id;
              matchingServices.add(serviceData);
              print(
                'تمت إضافة خدمة للقائمة من البحث الشامل: ${data['title'] ?? doc.id}',
              );
            }
          }
        }

        print(
          'تم العثور على ${matchingServices.length} خدمة تطابق معرف المستخدم',
        );

        // تحديث القائمة المرئية مرة واحدة بعد الانتهاء من البحث
        setState(() {
          _servicesList.addAll(matchingServices);
          _isLoading = false;
          _totalServices = _servicesList.length;
          print('تم تحميل ${_servicesList.length} خدمة في القائمة المرئية');
        });

        // تحديث الإحصائيات بعد تحميل الخدمات
        _loadStatistics();
      } else {
        print('لا يوجد مستخدم مسجل الدخول حاليًا');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading provider services: $e');
      print('Error details: ${e.toString()}');

      setState(() {
        _isLoading = false;
      });
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
        if (_vehicleImages.isEmpty) {
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

          final uploadTask = storageRef.putFile(imageFile);
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
        for (var imageFile in _vehicleImages) {
          try {
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final imageName =
                'vehicle_${timestamp}_${vehicleImageUrls.length}.jpg';
            final storageRef = FirebaseStorage.instance.ref().child(
              'vehicles/$userId/$imageName',
            );

            final uploadTask = storageRef.putFile(imageFile);
            final snapshot = await uploadTask.whenComplete(() => null);
            final imageUrl = await snapshot.ref.getDownloadURL();
            vehicleImageUrls.add(imageUrl);
          } catch (e) {
            print('Error uploading vehicle image: $e');
            continue;
          }
        }

        // التحقق من نجاح تحميل صور المركبة
        if (vehicleImageUrls.isEmpty && _vehicleImages.isNotEmpty) {
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
        'userId':
            userId, // تغيير من providerId إلى userId لتتوافق مع add_service_screen.dart
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
        DocumentReference docRef = await FirebaseFirestore.instance
            .collection('services')
            .add(newService);

        // حفظ بيانات الموقع في مجموعة منفصلة للتسهيل في البحث والتصفية
        if (_locationLatitude != null && _locationLongitude != null) {
          await FirebaseFirestore.instance
              .collection('service_locations')
              .doc(docRef.id)
              .set({
                'serviceId': docRef.id,
                'providerId': userId,
                'type': _selectedServiceType,
                'latitude': _locationLatitude,
                'longitude': _locationLongitude,
                'address': _locationAddress,
                'createdAt': FieldValue.serverTimestamp(),
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
    _vehicleImages.clear();
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
          _selectedImages.addAll(
            images.map((xFile) => File(xFile.path)).toList(),
          );
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
          _vehicleImages.addAll(
            images.map((xFile) => File(xFile.path)).toList(),
          );
        });
      }
    } catch (e) {
      print('Error picking vehicle images: $e');
    }
  }

  // فتح صفحة الخريطة المناسبة - لم تتغير هذه الدالة
  void _openMapPage() async {
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
      bool confirmDelete =
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
      builder:
          (context) => AlertDialog(
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
                    ],
                  ),
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

    try {
      setState(() {
        _isLoading = true;
      });

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

      // هنا يمكن إضافة معلومات المركبة إذا كانت خدمة نقل
      // ...

      // تحديث الخدمة في Firestore
      await FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId)
          .update(updatedService);

      // تحديث بيانات الموقع في مجموعة منفصلة إذا كانت متوفرة
      if (_locationLatitude != null && _locationLongitude != null) {
        await FirebaseFirestore.instance
            .collection('service_locations')
            .doc(serviceId)
            .set({
              'serviceId': serviceId,
              'providerId':
                  Provider.of<AuthService>(
                    context,
                    listen: false,
                  ).currentUser!.uid,
              'type': _selectedServiceType,
              'latitude': _locationLatitude,
              'longitude': _locationLongitude,
              'address': _locationAddress,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }

      // إعادة تحميل الخدمات
      await _loadProviderServices();

      // إغلاق نافذة التعديل
      Navigator.of(context).pop();

      // عرض رسالة نجاح
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث الخدمة بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error updating service: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تحديث الخدمة'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('مزود الخدمة'),
        backgroundColor: Color(0xFF9B59B6),
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _currentIndex == 0
              ? _buildServicesPage()
              : _currentIndex == 1
              ? _buildRequestsPage()
              : _currentIndex == 2
              ? _buildAnalyticsPage()
              : _currentIndex == 3
              ? _buildProfilePage()
              : Container(),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton:
          _currentIndex == 0
              ? FloatingActionButton(
                onPressed: _openAddServiceScreen,
                backgroundColor: Color(0xFF9B59B6), // تغيير استدعاء الدالة هنا
                child: Icon(Icons.add),
              )
              : null,
    );
  }

  Widget _buildServicesPage() {
    return Container(
      padding: EdgeInsets.all(16),
      child:
          _servicesList.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 80, color: Colors.grey[400]),
                    SizedBox(height: 20),
                    Text(
                      'لا توجد خدمات مضافة بعد',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: _servicesList.length,
                itemBuilder: (context, index) {
                  final service = _servicesList[index];
                  return _buildServiceCard(service);
                },
              ),
    );
  }

  // بطاقة إحصائية
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 160,
      margin: EdgeInsets.symmetric(horizontal: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Spacer(),
              SizedBox(
                height: 25,
                width: 40,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    color: color.withOpacity(0.1),
                    child: CustomPaint(painter: MiniChartPainter(color: color)),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          Text(title, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
          SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // رسم مخطط صغير
  Widget _buildServiceCard(Map<String, dynamic> service) {
    final String title = service['title'] ?? 'خدمة بدون عنوان';
    final String type = service['type'] ?? 'غير محدد';
    final String region = service['region'] ?? 'غير محدد';
    final double price = service['price'] ?? 0.0;
    final bool isActive = service['isActive'] ?? true;
    final List<dynamic> imageUrls = service['imageUrls'] ?? [];
    final double rating = service['rating'] ?? 0.0;
    final int reviewCount = service['reviewCount'] ?? 0;
    final String currency = service['currency'] ?? 'دينار جزائري';

    // بيانات المركبة إذا كانت خدمة نقل
    Map<String, dynamic>? vehicleData;
    if (type == 'نقل') {
      vehicleData = service['vehicle'];
    }

    // بيانات الموقع
    Map<String, dynamic>? locationData;
    if (service.containsKey('location')) {
      locationData = service['location'];
    }

    // طباعة عناوين الصور للتشخيص
    print('عناوين الصور للخدمة $title:');
    for (var url in imageUrls) {
      print('URL: $url');
    }

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
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
          // شريط الحالة في الأعلى
          Container(
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 15),
            decoration: BoxDecoration(
              color: isActive ? Colors.green : Colors.red,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isActive ? Icons.check_circle : Icons.cancel,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 6),
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
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        type,
                        style: TextStyle(
                          color:
                              type == 'تخزين'
                                  ? Color(0xFF3498DB)
                                  : Color(0xFFE67E22),
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

          // صورة الخدمة
          Stack(
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(5),
                    bottomRight: Radius.circular(5),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(5),
                    bottomRight: Radius.circular(5),
                  ),
                  child:
                      imageUrls.isNotEmpty
                          ? _buildServiceImage(imageUrls.first, type)
                          : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  type == 'تخزين'
                                      ? Icons.warehouse
                                      : Icons.local_shipping,
                                  size: 60,
                                  color: Colors.grey[400],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'لا توجد صورة',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                ),
              ),

              // شريط التقييم
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.star, color: Color(0xFFF1C40F), size: 18),
                          SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            '($reviewCount)',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            region,
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 10),

                // السعر
                Container(
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Color(0xFF9B59B6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Color(0xFF9B59B6).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${price.toStringAsFixed(0)} $currency',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9B59B6),
                      fontSize: 16,
                    ),
                  ),
                ),
                SizedBox(height: 15),

                // معلومات إضافية حسب نوع الخدمة
                if (type == 'تخزين') ...[
                  // معلومات خدمة التخزين
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFF3498DB).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warehouse, color: Color(0xFF3498DB)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'خدمة تخزين',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3498DB),
                                ),
                              ),
                              if (locationData != null) ...[
                                SizedBox(height: 4),
                                Text(
                                  locationData['address'] ?? 'غير محدد',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (type == 'نقل' && vehicleData != null) ...[
                  // معلومات خدمة النقل
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFE67E22).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.local_shipping, color: Color(0xFFE67E22)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'المركبة: ${vehicleData['make'] ?? ''} ${vehicleData['type'] ?? ''}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFE67E22),
                                    ),
                                  ),
                                  Text(
                                    vehicleData['year'] ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.scale,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'الحمولة: ${vehicleData['capacity'] ?? 'غير محدد'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Icon(
                                    Icons.straighten,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'الأبعاد: ${vehicleData['dimensions'] ?? 'غير محدد'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                      overflow: TextOverflow.ellipsis,
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
                ],
                SizedBox(height: 15),

                // أزرار التحكم
                Row(
                  children: [
                    // زر التعديل
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _loadServiceForEdit(service);
                        },
                        icon: Icon(Icons.edit, size: 18),
                        label: Text('تعديل'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3498DB),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),

                    // زر التفعيل/التعطيل
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _toggleServiceStatus(service['id'], isActive);
                        },
                        icon: Icon(
                          isActive ? Icons.cancel : Icons.check_circle,
                          size: 18,
                        ),
                        label: Text(isActive ? 'تعطيل' : 'تفعيل'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isActive ? Colors.grey : Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),

                    // زر الحذف
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        onPressed: () {
                          _deleteService(service['id']);
                        },
                        icon: Icon(Icons.delete, color: Colors.white),
                        padding: EdgeInsets.all(8),
                        constraints: BoxConstraints(),
                        splashRadius: 24,
                        tooltip: 'حذف الخدمة',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // دالة مساعدة لعرض صور الخدمة
  Widget _buildServiceImage(String imageUrl, String serviceType) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return Container(
          color: Colors.grey[300],
          height: 180,
          width: double.infinity,
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9B59B6)),
              value:
                  loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('خطأ في تحميل الصورة: $error');
        print('العنوان: $imageUrl');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                serviceType == 'تخزين' ? Icons.warehouse : Icons.local_shipping,
                size: 60,
                color: Colors.grey[400],
              ),
              SizedBox(height: 8),
              Text(
                'فشل تحميل الصورة',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
              SizedBox(height: 4),
              IconButton(
                icon: Icon(Icons.refresh, color: Color(0xFF9B59B6)),
                onPressed: () {
                  // إعادة تحميل الصفحة
                  setState(() {});
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestsPage() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Color(0xFF9B59B6).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment,
                size: 70,
                color: Color(0xFF9B59B6).withOpacity(0.7),
              ),
            ),
            SizedBox(height: 20),
            Text(
              "صفحة الطلبات",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            SizedBox(height: 15),
            Text(
              "هنا ستظهر طلبات العملاء الخاصة بك",
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                // تحديث الطلبات
              },
              icon: Icon(Icons.refresh),
              label: Text("تحديث الطلبات"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF9B59B6),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsPage() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "التحليلات والإحصائيات",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF9B59B6),
            ),
          ),
          SizedBox(height: 20),

          // بطاقة الإيرادات
          _buildAnalyticsCard(
            title: "الإيرادات",
            value: "${_totalEarnings.toStringAsFixed(0)} دج",
            icon: Icons.monetization_on,
            color: Color(0xFF2ECC71),
            content: SizedBox(
              height: 160,
              child: CustomPaint(painter: ChartPainter(), child: Container()),
            ),
          ),
          SizedBox(height: 16),

          // بطاقة التقييمات
          _buildAnalyticsCard(
            title: "تقييمات العملاء",
            value: "${_averageRating.toStringAsFixed(1)} / 5.0",
            icon: Icons.star,
            color: Color(0xFFF1C40F),
            content: Container(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildRatingBar(5, 0.7, 0.7),
                  _buildRatingBar(4, 0.2, 0.2),
                  _buildRatingBar(3, 0.05, 0.05),
                  _buildRatingBar(2, 0.03, 0.03),
                  _buildRatingBar(1, 0.02, 0.02),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // بطاقة الطلبات
          _buildAnalyticsCard(
            title: "نشاط الطلبات",
            value: "$_totalRequests طلب",
            icon: Icons.assignment,
            color: Color(0xFF3498DB),
            content: Container(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn("جاري التنفيذ", "5", Colors.orange),
                  _buildStatColumn("مكتملة", "7", Colors.green),
                  _buildStatColumn("ملغاة", "0", Colors.red),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // بطاقة تحليلات
  Widget _buildAnalyticsCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Widget content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
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
          // العنوان والقيمة
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color),
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                Spacer(),
                PopupMenuButton(
                  icon: Icon(Icons.more_vert, color: Colors.grey),
                  itemBuilder:
                      (context) => [
                        PopupMenuItem(
                          value: 'print',
                          child: Row(
                            children: [
                              Icon(Icons.print, color: color),
                              SizedBox(width: 8),
                              Text('طباعة التقرير'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'download',
                          child: Row(
                            children: [
                              Icon(Icons.download, color: color),
                              SizedBox(width: 8),
                              Text('تصدير كملف Excel'),
                            ],
                          ),
                        ),
                      ],
                ),
              ],
            ),
          ),

          // خط فاصل
          Divider(color: Colors.grey.withOpacity(0.2), height: 1),

          // المحتوى
          content,

          // زر عرض التفاصيل
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(15),
                bottomRight: Radius.circular(15),
              ),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "عرض التفاصيل",
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 16, color: color),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // شريط تقييم
  Widget _buildRatingBar(int stars, double percentage, double value) {
    return Column(
      children: [
        Text(
          '$stars',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        Container(
          width: 30,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(15),
          ),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                height: 100 * value,
                width: 30,
                decoration: BoxDecoration(
                  color: Color(0xFFF1C40F),
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Text(
          '${(percentage * 100).toInt()}%',
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
      ],
    );
  }

  // عمود إحصائيات
  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildProfilePage() {
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // معلومات الملف الشخصي
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
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
                  // الصورة الشخصية
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Color(0xFF9B59B6), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Color(0xFF9B59B6).withOpacity(0.1),
                      child: Icon(
                        Icons.person,
                        size: 60,
                        color: Color(0xFF9B59B6),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // الاسم والبريد الإلكتروني
                  Text(
                    "اسم المستخدم",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "user@example.com",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 20),

                  // زر تعديل الملف الشخصي
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // تعديل الملف الشخصي
                          },
                          icon: Icon(Icons.edit),
                          label: Text("تعديل الملف الشخصي"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF9B59B6),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      // إضافة زر تسجيل الخروج بجانب زر التعديل
                      ElevatedButton.icon(
                        onPressed: _logout,
                        icon: Icon(Icons.logout),
                        label: Text("تسجيل الخروج"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // قائمة الإعدادات
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
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
                  _buildSettingsItem(
                    icon: Icons.payment,
                    title: "طرق الدفع",
                    subtitle: "إدارة طرق الدفع المقبولة",
                    iconColor: Color(0xFF2ECC71),
                  ),
                  Divider(height: 1),
                  _buildSettingsItem(
                    icon: Icons.notifications,
                    title: "الإشعارات",
                    subtitle: "إدارة إعدادات الإشعارات",
                    iconColor: Color(0xFFE74C3C),
                  ),
                  Divider(height: 1),
                  _buildSettingsItem(
                    icon: Icons.language,
                    title: "اللغة",
                    subtitle: "تغيير لغة التطبيق",
                    iconColor: Color(0xFF3498DB),
                  ),
                  Divider(height: 1),
                  _buildSettingsItem(
                    icon: Icons.security,
                    title: "الأمان",
                    subtitle: "إدارة إعدادات الأمان",
                    iconColor: Color(0xFFF1C40F),
                  ),
                  Divider(height: 1),
                  _buildSettingsItem(
                    icon: Icons.help,
                    title: "المساعدة والدعم",
                    subtitle: "تواصل مع فريق الدعم",
                    iconColor: Color(0xFF9B59B6),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // زر تسجيل الخروج
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.logout, color: Colors.red),
                ),
                title: Text(
                  "تسجيل الخروج",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  _logout();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // عنصر في قائمة الإعدادات
  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: () {
        // فتح صفحة الإعدادات المحددة
      },
    );
  }

  // وظيفة تسجيل الخروج
  Future<void> _logout() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // إظهار حوار تأكيد تسجيل الخروج
      bool confirmLogout =
          await showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 10),
                      Text('تأكيد تسجيل الخروج'),
                    ],
                  ),
                  content: Text(
                    'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟',
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
                      child: Text(
                        'تسجيل الخروج',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
          ) ??
          false;

      if (!confirmLogout) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // تنفيذ تسجيل الخروج
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.logout();

      // إضافة طباعة للتأكد من تنفيذ عملية تسجيل الخروج
      print('تم تسجيل الخروج بنجاح');

      // الانتقال إلى الصفحة الرئيسية بطريقتين مختلفتين للتأكد من عمل إحداهما
      if (mounted) {
        // الطريقة الأولى
        print('محاولة العودة للصفحة الرئيسية باستخدام pushNamedAndRemoveUntil');
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);

        // في حال لم تعمل الطريقة الأولى، نجرب الطريقة الثانية بعد تأخير قصير
        await Future.delayed(Duration(milliseconds: 100));
        if (mounted) {
          print(
            'محاولة العودة للصفحة الرئيسية باستخدام Navigator.pushAndRemoveUntil',
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => BiLinkHomePage()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      print('Error logging out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تسجيل الخروج: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Color(0xFF9B59B6),
        unselectedItemColor: Colors.grey[400],
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        items: [
          BottomNavigationBarItem(
            icon: _buildNavIcon(
              index: 0,
              icon: Icons.list_alt,
              label: 'خدماتي',
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(
              index: 1,
              icon: Icons.assignment,
              label: 'الطلبات',
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(
              index: 2,
              icon: Icons.bar_chart,
              label: 'التحليلات',
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(index: 3, icon: Icons.person, label: 'حسابي'),
            label: '',
          ),
        ],
      ),
    );
  }

  // أيقونة القائمة السفلية
  Widget _buildNavIcon({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool isSelected = _currentIndex == index;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// رسام للمخطط الصغير
class MiniChartPainter extends CustomPainter {
  final Color color;

  MiniChartPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

    final path = Path();
    final width = size.width;
    final height = size.height;

    // رسم خط المخطط
    path.moveTo(0, height * 0.7);
    path.lineTo(width * 0.2, height * 0.5);
    path.lineTo(width * 0.4, height * 0.8);
    path.lineTo(width * 0.6, height * 0.3);
    path.lineTo(width * 0.8, height * 0.6);
    path.lineTo(width, height * 0.2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

// رسام لمخطط كبير
class ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // رسم الشبكة
    final gridPaint =
        Paint()
          ..color = Colors.grey.withOpacity(0.2)
          ..strokeWidth = 1;

    // رسم الخطوط الأفقية
    for (int i = 1; i < 5; i++) {
      final y = height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    // رسم الخطوط الرأسية
    for (int i = 1; i < 7; i++) {
      final x = width * i / 7;
      canvas.drawLine(Offset(x, 0), Offset(x, height), gridPaint);
    }

    // رسم المخطط
    final paint =
        Paint()
          ..color = Color(0xFF2ECC71)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

    final fillPaint =
        Paint()
          ..color = Color(0xFF2ECC71).withOpacity(0.2)
          ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    // نقاط البيانات (للتوضيح فقط)
    final points = [
      Offset(0, height * 0.7),
      Offset(width / 6, height * 0.6),
      Offset(width * 2 / 6, height * 0.8),
      Offset(width * 3 / 6, height * 0.4),
      Offset(width * 4 / 6, height * 0.5),
      Offset(width * 5 / 6, height * 0.3),
      Offset(width, height * 0.2),
    ];

    // رسم المسار
    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, height);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
      fillPath.lineTo(points[i].dx, points[i].dy);
    }

    fillPath.lineTo(width, height);
    fillPath.lineTo(0, height);
    fillPath.close();

    // رسم المخطط والتظليل
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // رسم النقاط
    final dotPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

    final dotStrokePaint =
        Paint()
          ..color = Color(0xFF2ECC71)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    for (var point in points) {
      canvas.drawCircle(point, 5, dotStrokePaint);
      canvas.drawCircle(point, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
