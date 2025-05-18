import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

// استيراد الخدمات المطلوبة

// استيراد صفحات الخرائط
import 'package:bilink/screens/storage_location_map.dart';
import 'package:bilink/screens/driver_tracking_map.dart';

class AddServiceScreen extends StatefulWidget {
  final Function onServiceAdded;

  const AddServiceScreen({super.key, required this.onServiceAdded});

  @override
  _AddServiceScreenState createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen>
    with SingleTickerProviderStateMixin {
  // متغيرات إدارة الواجهة
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false; // تغيير من final إلى متغير عادي ليمكن تعديله
  late TabController _tabController;
  int _currentStep = 0;
  final int _totalSteps = 3;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _selectedServiceType = _tabController.index == 0 ? 'تخزين' : 'نقل';
        // إعادة تعيين الخطوة الحالية عند تغيير نوع الخدمة
        _currentStep = 0;
      });
    }
  }

  // ألوان التطبيق - تصميم عصري محسّن
  final Color _primaryColor = Color(0xFF0F2B5B);
  final Color _accentColor = Color(0xFF00A78E);
  final Color _transportColor = Color(0xFF2E5BFF);
  final Color _backgroundColor = Color(0xFFFAFAFC);
  final Color _cardColor = Colors.white;
  final Color _errorColor = Color(0xFFE53935);
  final Color _successColor = Color(0xFF4CAF50);
  final Color _warningColor = Color(0xFFFFA000);
  final Color _greyLight = Color(0xFFE0E0E0);
  final Color _greyDark = Color(0xFF757575);

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
    'أدرار',
    'الشلف',
    'الأغواط',
    'أم البواقي',
    'باتنة',
    'بجاية',
    'بسكرة',
    'بشار',
    'البليدة',
    'البويرة',
    'تمنراست',
    'تبسة',
    'تلمسان',
    'تيارت',
    'تيزي وزو',
    'الجزائر',
    'الجلفة',
    'جيجل',
    'سطيف',
    'سعيدة',
    'سكيكدة',
    'سيدي بلعباس',
    'عنابة',
    'قالمة',
    'قسنطينة',
    'المدية',
    'مستغانم',
    'المسيلة',
    'معسكر',
    'ورقلة',
    'وهران',
    'البيض',
    'إليزي',
    'برج بوعريريج',
    'بومرداس',
    'الطارف',
    'تندوف',
    'تيسمسيلت',
    'الوادي',
    'خنشلة',
    'سوق أهراس',
    'تيبازة',
    'ميلة',
    'عين الدفلى',
    'النعامة',
    'عين تموشنت',
    'غرداية',
    'غليزان',
    'تيميمون',
    'برج باجي مختار',
    'أولاد جلال',
    'بني عباس',
    'عين صالح',
    'عين قزام',
    'تقرت',
    'جانت',
    'المغير',
    'المنيعة',
  ];
  final List<File> _selectedImages = [];
  String _storageDurationType = 'شهري';

  // متغيرات خاصة بمعلومات المركبة (للنقل)
  String _selectedVehicleType = 'شاحنة صغيرة';
  final List<String> _vehicleTypes = [
    'شاحنة صغيرة',
    'شاحنة متوسطة',
    'شاحنة كبيرة',
    'مركبة خفيفة',
    'دراجة نارية',
  ];
  final _vehicleMakeController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehicleCapacityController = TextEditingController();
  final _vehicleDimensionsController = TextEditingController();
  final _vehicleSpecialFeaturesController = TextEditingController();
  final List<File> _vehicleImages = [];

  // متغيرات خاصة بصور مكان التخزين (للتخزين)
  final List<File> _storageLocationImages = [];

  @override
  void dispose() {
    _tabController.dispose();
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

  // إعادة تعيين نموذج إضافة الخدمة
  void _resetForm() {
    setState(() {
      _currentStep = 0;
      _titleController.clear();
      _descriptionController.clear();
      _priceController.clear();
      _locationLatitude = null;
      _locationLongitude = null;
      _locationAddress = "";
      _selectedImages.clear();
      _storageLocationImages.clear();
      _vehicleMakeController.clear();
      _vehicleYearController.clear();
      _vehiclePlateController.clear();
      _vehicleCapacityController.clear();
      _vehicleDimensionsController.clear();
      _vehicleSpecialFeaturesController.clear();
      _vehicleImages.clear();
    });
  }

  // التحقق من الخطوة الحالية
  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      // التحقق من معلومات الخدمة الأساسية
      if (_titleController.text.isEmpty ||
          _descriptionController.text.isEmpty ||
          _priceController.text.isEmpty) {
        return false;
      }

      // التحقق من صحة السعر
      try {
        final double price = double.parse(_priceController.text);
        if (price <= 0) {
          return false;
        }
      } catch (e) {
        return false;
      }

      return true;
    } else if (_currentStep == 1) {
      // التحقق من الموقع - للخدمات من نوع "تخزين" فقط
      if (_selectedServiceType == 'تخزين') {
        return _locationLatitude != null &&
            _locationLongitude != null &&
            _locationAddress.isNotEmpty;
      } else {
        // لخدمات النقل، نسمح بالانتقال للخطوة التالية حتى لو لم يتم تحديد الموقع
        // لأن التتبع المباشر سيتم تفعيله لاحقاً
        return true;
      }
    } else if (_currentStep == 2) {
      if (_selectedServiceType == 'تخزين') {
        // التحقق من صور مكان التخزين
        return _selectedImages.isNotEmpty && _storageLocationImages.isNotEmpty;
      } else {
        // التحقق من معلومات المركبة
        final bool hasRequiredInfo =
            _vehicleMakeController.text.isNotEmpty &&
            _vehicleYearController.text.isNotEmpty &&
            _vehiclePlateController.text.isNotEmpty;

        // يجب توفر صورة واحدة على الأقل
        final bool hasImages = _vehicleImages.isNotEmpty;

        return hasRequiredInfo && hasImages;
      }
    }

    return false; // في حالة وجود خطأ أو خطوة غير معروفة
  }

  // الانتقال إلى الخطوة التالية والرجوع للخطوة السابقة
  void _nextStep() {
    if (_validateCurrentStep()) {
      if (_currentStep < _totalSteps - 1) {
        setState(() {
          _currentStep++;
        });
      } else {
        // إذا كانت هذه هي الخطوة الأخيرة، قم بإضافة الخدمة
        _addNewService();
      }
    } else {
      // عرض رسالة خطأ إذا كانت الخطوة الحالية غير مكتملة
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Text('يرجى إكمال جميع المعلومات المطلوبة'),
            ],
          ),
          backgroundColor: _errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: EdgeInsets.all(10),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  // وظائف اختيار الصور
  Future<void> _pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (images.isNotEmpty) {
        setState(() {
          for (var image in images) {
            _selectedImages.add(File(image.path));
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء اختيار الصور: $e'),
          backgroundColor: _errorColor,
        ),
      );
    }
  }

  Future<void> _pickVehicleImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (images.isNotEmpty) {
        setState(() {
          for (var image in images) {
            _vehicleImages.add(File(image.path));
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء اختيار صور المركبة: $e'),
          backgroundColor: _errorColor,
        ),
      );
    }
  }

  Future<void> _pickStorageLocationImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (images.isNotEmpty) {
        setState(() {
          for (var image in images) {
            _storageLocationImages.add(File(image.path));
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء اختيار صور مكان التخزين: $e'),
          backgroundColor: _errorColor,
        ),
      );
    }
  }

  // فتح صفحة الخريطة المناسبة
  Future<void> _openMapPage() async {
    // إنشاء معرّف مؤقت للخدمة
    final tempServiceId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    if (_selectedServiceType == 'تخزين') {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StorageLocationMapPage(
            serviceId: tempServiceId,
            onLocationSelected: (lat, lng, address) {
              // إضافة دالة callback للتعامل مع بيانات الموقع المحددة
              setState(() {
                _locationLatitude = lat;
                _locationLongitude = lng;
                _locationAddress = address;
              });
            },
          ),
        ),
      );
      // التحقق من النتيجة المُعادة مباشرة من صفحة الخريطة
      if (result != null && result is Map<String, dynamic>) {
        setState(() {
          _locationLatitude = result['latitude'];
          _locationLongitude = result['longitude'];
          // تحقق من أن العنوان ليس بقيمة null
          _locationAddress = result['address'] ?? 'موقع محدد';
        });
      }
    } else {
      // خدمة النقل - استخدام نفس منطق خدمة التخزين لتحديد الموقع الفعلي
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DriverTrackingMapPage(
            serviceId: tempServiceId,
            // إضافة دالة callback للتعامل مع بيانات الموقع المحددة
            onLocationSelected: (lat, lng, address) {
              setState(() {
                _locationLatitude = lat;
                _locationLongitude = lng;
                _locationAddress = address;
              });
            },
          ),
        ),
      );
      if (result != null && result is Map<String, dynamic>) {
        setState(() {
          _locationLatitude = result['latitude'];
          _locationLongitude = result['longitude'];
          // تحقق من أن العنوان ليس بقيمة null وليس فارغاً
          if (result['address'] != null && result['address'].toString().isNotEmpty) {
            _locationAddress = result['address'];
          } else {
            // إذا كان العنوان غير محدد، استخدم تنسيق الإحداثيات
            _locationAddress = 'موقع مُحدّد: ${_locationLatitude!.toStringAsFixed(4)}, ${_locationLongitude!.toStringAsFixed(4)}';
          }
        });
      }
    }
  }

  // إضافة خدمة جديدة
  Future<void> _addNewService() async {
    // تحقق من صحة البيانات قبل الإرسال مرة أخرى (كإجراء احترازي)
    if (!_validateCurrentStep()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Text('يرجى إكمال جميع المعلومات المطلوبة قبل إضافة الخدمة'),
            ],
          ),
          backgroundColor: _errorColor,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(10),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // تفعيل مؤشر التحميل لإظهاره للمستخدم أثناء معالجة الإضافة
    setState(() {
      _isLoading = true;
    });

    try {
      // التحقق من وجود مستخدم مسجل الدخول
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.account_circle, color: Colors.white),
                SizedBox(width: 10),
                Text('يرجى تسجيل الدخول أولاً لإضافة خدمة جديدة'),
              ],
            ),
            backgroundColor: _errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.all(10),
            duration: Duration(seconds: 3),
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // إعداد البيانات الأساسية
      final serviceData = {
        'providerId': user.uid,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text),
        'currency': _currency,
        'region': _selectedRegion,
        'type': _selectedServiceType,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'userDisplayName': user.displayName ?? 'مستخدم',
        'userEmail': user.email ?? '',
        'userPhotoURL': user.photoURL ?? '',
        'rating': 0.0,
        'reviewCount': 0,
      };
      
      // إضافة معلومات نوع المدة للتخزين
      if (_selectedServiceType == 'تخزين') {
        serviceData['storageDurationType'] = _storageDurationType;
      }

      // إضافة بيانات الموقع إذا كانت متوفرة - تم تحسين التعامل مع الموقع
      if (_locationLatitude != null && _locationLongitude != null) {
        // التأكد من استخدام قيم غير فارغة لمنشئ GeoPoint
        final double lat = _locationLatitude!;
        final double lng = _locationLongitude!;
        
        // التأكد من أن عنوان الموقع غير فارغ
        final String locationAddr = _locationAddress.isEmpty ? 
            'موقع مُحدّد: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}' : 
            _locationAddress;
            
        serviceData['location'] = {
          'latitude': lat,
          'longitude': lng,
          'address': locationAddr,
          'geopoint': GeoPoint(lat, lng),
        };
      }

      // إضافة بيانات المركبة إذا كانت خدمة نقل
      if (_selectedServiceType == 'نقل') {
        final bool isMotorcycle = _selectedVehicleType == 'دراجة نارية';

        final Map<String, dynamic> vehicleInfo = {
          'type': _selectedVehicleType,
          'make': _vehicleMakeController.text.trim(),
          'year': _vehicleYearController.text.trim(),
          'plate':
              _vehiclePlateController.text
                  .trim(), // تعديل من plateNumber إلى plate
          'specialFeatures': _vehicleSpecialFeaturesController.text.trim(),
        };

        // إضافة معلومات قدرة المركبة فقط إذا لم تكن دراجة نارية
        if (!isMotorcycle) {
          vehicleInfo['capacity'] = _vehicleCapacityController.text.trim();
          vehicleInfo['dimensions'] = _vehicleDimensionsController.text.trim();
        }

        serviceData['vehicle'] =
            vehicleInfo; // تعديل من vehicleInfo إلى vehicle
      }

      // إنشاء مستند جديد في Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('services')
          .add(serviceData);
      final serviceId = docRef.id;

      // إضافة حقل الـ ID في البيانات للرجوع إليه بسهولة
      await docRef.update({'id': serviceId});

      // مصفوفات لتخزين روابط الصور المختلفة
      final List<String> imageUrls = [];
      final List<String> storageLocationImageUrls = [];
      final List<String> vehicleImageUrls = [];

      // رفع الصور العامة
      if (_selectedImages.isNotEmpty) {
        for (var i = 0; i < _selectedImages.length; i++) {
          final image = _selectedImages[i];
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          // إنشاء مسار فريد لكل صورة باستخدام الوقت والـ ID
          final imageRef = FirebaseStorage.instance
              .ref()
              .child('services')
              .child(serviceId)
              .child('general')
              .child('image_${i}_$timestamp.jpg');

          try {
            // رفع الصورة
            await imageRef.putFile(
              image,
              SettableMetadata(contentType: 'image/jpeg'),
            );

            // الحصول على رابط الصورة
            final imageUrl = await imageRef.getDownloadURL();
            imageUrls.add(imageUrl);
            print('تم رفع الصورة بنجاح: $imageUrl');
          } catch (e) {
            print('خطأ في رفع الصورة: $e');
          }
        }

        // تحديث المستند مع روابط الصور - مهم استخدام imageUrls وليس images
        await docRef.update({'imageUrls': imageUrls});
        
        // Print debug information about uploaded images
        print('تم رفع ${imageUrls.length} صورة للخدمة: $imageUrls');
      }

      // رفع صور مكان التخزين إذا كانت خدمة تخزين
      if (_selectedServiceType == 'تخزين' &&
          _storageLocationImages.isNotEmpty) {
        for (var i = 0; i < _storageLocationImages.length; i++) {
          final image = _storageLocationImages[i];
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final imageRef = FirebaseStorage.instance
              .ref()
              .child('services')
              .child(serviceId)
              .child('storageLocation')
              .child('storage_${i}_$timestamp.jpg');

          try {
            await imageRef.putFile(
              image,
              SettableMetadata(contentType: 'image/jpeg'),
            );
            final imageUrl = await imageRef.getDownloadURL();
            storageLocationImageUrls.add(imageUrl);
            print('تم رفع صورة مكان التخزين بنجاح: $imageUrl');
          } catch (e) {
            print('خطأ في رفع صورة مكان التخزين: $e');
          }
        }

        // تحديث المستند مع روابط صور مكان التخزين
        await docRef.update({
          'storageLocationImageUrls': storageLocationImageUrls,
        });
      }

      // رفع صور المركبة إذا كانت خدمة نقل
      if (_selectedServiceType == 'نقل' && _vehicleImages.isNotEmpty) {
        for (var i = 0; i < _vehicleImages.length; i++) {
          final image = _vehicleImages[i];
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final imageRef = FirebaseStorage.instance
              .ref()
              .child('services')
              .child(serviceId)
              .child('vehicle')
              .child('vehicle_${i}_$timestamp.jpg');

          try {
            await imageRef.putFile(
              image,
              SettableMetadata(contentType: 'image/jpeg'),
            );
            final imageUrl = await imageRef.getDownloadURL();
            vehicleImageUrls.add(imageUrl);
            print('تم رفع صورة المركبة بنجاح: $imageUrl');
          } catch (e) {
            print('خطأ في رفع صورة المركبة: $e');
          }
        }

        // تحديث المستند مع روابط صور المركبة - اسم الحقل تم تغييره ليتناسب مع بقية التطبيق
        if (vehicleImageUrls.isNotEmpty) {
          // تحديث بيانات المركبة مع الصور
          await docRef.update({'vehicle.imageUrls': vehicleImageUrls});
        }
      }

      // إضافة الخدمة إلى قائمة خدمات المستخدم
      print('إضافة الخدمة إلى قائمة خدمات المستخدم بمعرف: ${user.uid}');

      // إنشاء بيانات الخدمة للمستخدم
      final Map<String, dynamic> userServiceData = {
        'serviceId': serviceId,
        'createdAt': FieldValue.serverTimestamp(),
        'title': _titleController.text.trim(),
        'serviceType': _selectedServiceType,
        'region': _selectedRegion,
        'isActive': true,
        'providerId': user.uid, // إضافة معرف المزود للتأكد من وجوده في كل مكان
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('services')
          .doc(serviceId)
          .set(userServiceData);

      // Create entry in service_locations collection if location data is available
      if (_locationLatitude != null && _locationLongitude != null) {
        // Make sure we use non-null values for GeoPoint constructor
        final double lat = _locationLatitude!;
        final double lng = _locationLongitude!;
        
        await FirebaseFirestore.instance
          .collection('service_locations')
          .doc(serviceId)
          .set({
            'serviceId': serviceId,
            'providerId': user.uid,
            'type': _selectedServiceType,
            'position': {
              'latitude': lat,
              'longitude': lng,
              'geopoint': GeoPoint(lat, lng),
            },
            'address': _locationAddress,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      }

      // إظهار رسالة نجاح وإغلاق الصفحة
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('تمت إضافة الخدمة بنجاح'),
            ],
          ),
          backgroundColor: _successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: EdgeInsets.all(10),
          duration: Duration(seconds: 3),
        ),
      );

      // استدعاء الدالة الخارجية للإبلاغ عن إضافة الخدمة بنجاح
      widget.onServiceAdded();

      // إعادة تعيين النموذج وعودة للوضع الأصلي
      _resetForm();
    } catch (e) {
      // معالجة الأخطاء بشكل أكثر تفصيلاً
      String errorMessage = 'حدث خطأ أثناء إضافة الخدمة';

      if (e.toString().contains('permission-denied')) {
        errorMessage = 'ليس لديك صلاحية لإضافة خدمة جديدة';
      } else if (e.toString().contains('network')) {
        errorMessage = 'يرجى التحقق من اتصالك بالإنترنت';
      } else if (e.toString().contains('storage')) {
        errorMessage = 'حدث خطأ أثناء رفع الصور، يرجى المحاولة مرة أخرى';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Expanded(child: Text(errorMessage)),
            ],
          ),
          backgroundColor: _errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: EdgeInsets.all(10),
          duration: Duration(seconds: 5),
        ),
      );

      // تسجيل الخطأ للتشخيص
      print('Error adding service: $e');
    } finally {
      // إيقاف مؤشر التحميل بعد الانتهاء سواء بنجاح أو بخطأ
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color serviceColor =
        _selectedServiceType == 'تخزين' ? _accentColor : _transportColor;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: _buildAppBar(serviceColor),
        body: _buildBody(serviceColor),
      ),
    );
  }

  // بناء الـ AppBar المخصص مع التبويبات
  PreferredSizeWidget _buildAppBar(Color serviceColor) {
    return AppBar(
      elevation: 0,
      centerTitle: true,
      title: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'إضافة ',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
            TextSpan(
              text: 'خدمة جديدة',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      backgroundColor: _primaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(70.0),
        child: Container(
          height: 70.0, // تحديد ارتفاع ثابت للحاوية
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: serviceColor,
            indicatorWeight: 3,
            labelColor: serviceColor,
            unselectedLabelColor: _greyDark,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
            indicator: UnderlineTabIndicator(
              borderSide: BorderSide(width: 3.0, color: serviceColor),
              insets: EdgeInsets.symmetric(horizontal: 30.0),
            ),
            tabs: [
              Tab(
                icon: Icon(Icons.warehouse),
                text: 'خدمة تخزين',
                iconMargin: EdgeInsets.only(bottom: 5),
              ),
              Tab(
                icon: Icon(Icons.local_shipping),
                text: 'خدمة نقل',
                iconMargin: EdgeInsets.only(bottom: 5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // بناء الجسم الرئيسي للصفحة
  Widget _buildBody(Color serviceColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF1F0FF), Color(0xFFE8F5FF), Color(0xFFF0FFFF)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // مؤشر الخطوات
                  _buildStepperProgressIndicator(serviceColor),

                  SizedBox(height: 16),

                  // محتوى الخطوة الحالية
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SingleChildScrollView(
                        physics: BouncingScrollPhysics(),
                        child: Container(
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // عنوان الخطوة
                                _buildStepTitle(serviceColor),

                                SizedBox(height: 20),

                                // محتوى الخطوة
                                if (_currentStep == 0)
                                  _buildBasicInfoStep(serviceColor)
                                else if (_currentStep == 1)
                                  _buildLocationStep(serviceColor)
                                else if (_currentStep == 2)
                                  _selectedServiceType == 'تخزين'
                                      ? _buildStorageImagesStep(serviceColor)
                                      : _buildTransportVehicleStep(
                                        serviceColor,
                                      ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // أزرار التنقل بين الخطوات
                  _buildNavigationButtons(serviceColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // مؤشر التقدم عبر الخطوات
  Widget _buildStepperProgressIndicator(Color serviceColor) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: List.generate(
          _totalSteps,
          (index) => Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  // مؤشر الخطوة (دائرة أو رقم)
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: index <= _currentStep ? serviceColor : _greyLight,
                      shape: BoxShape.circle,
                      boxShadow:
                          index <= _currentStep
                              ? [
                                BoxShadow(
                                  color: serviceColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ]
                              : null,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color:
                              index <= _currentStep ? Colors.white : _greyDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 8),

                  // خط التقدم
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: index <= _currentStep ? serviceColor : _greyLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  SizedBox(height: 4),

                  // تسمية الخطوة
                  Text(
                    _getStepName(index),
                    style: TextStyle(
                      fontSize: 10,
                      color: index <= _currentStep ? serviceColor : _greyDark,
                      fontWeight:
                          index == _currentStep
                              ? FontWeight.bold
                              : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // الحصول على اسم الخطوة
  String _getStepName(int stepIndex) {
    switch (stepIndex) {
      case 0:
        return 'المعلومات الأساسية';
      case 1:
        return 'الموقع';
      case 2:
        return _selectedServiceType == 'تخزين' ? 'الصور' : 'المركبة';
      default:
        return '';
    }
  }

  // عنوان الخطوة الحالية
  Widget _buildStepTitle(Color serviceColor) {
    String title = '';
    IconData icon;

    switch (_currentStep) {
      case 0:
        title = 'المعلومات الأساسية للخدمة';
        icon =
            _selectedServiceType == 'تخزين'
                ? Icons.inventory_2
                : Icons.delivery_dining;
        break;
      case 1:
        title = 'تحديد موقع الخدمة';
        icon = Icons.location_on;
        break;
      case 2:
        if (_selectedServiceType == 'تخزين') {
          title = 'صور مكان التخزين';
          icon = Icons.photo_library;
        } else {
          title = 'معلومات وصور المركبة';
          icon = Icons.local_shipping;
        }
        break;
      default:
        title = '';
        icon = Icons.info;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: serviceColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: serviceColor, size: 24),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Divider(color: _greyLight, thickness: 1),
      ],
    );
  }

  // الخطوة الأولى: معلومات الخدمة الأساسية - محسنة
  Widget _buildBasicInfoStep(Color serviceColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // عنوان الخدمة
        _buildSectionTitle('عنوان الخدمة', Icons.title, serviceColor),
        SizedBox(height: 10),
        _buildInputField(
          controller: _titleController,
          label: 'عنوان الخدمة',
          hint: 'اكتب عنوانًا واضحًا ومختصرًا للخدمة',
          prefixIcon: Icons.title,
          color: serviceColor,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال عنوان الخدمة';
            }
            return null;
          },
        ),
        SizedBox(height: 24),

        // وصف الخدمة
        _buildSectionTitle('وصف الخدمة', Icons.description, serviceColor),
        SizedBox(height: 10),
        _buildInputField(
          controller: _descriptionController,
          label: 'وصف الخدمة',
          hint: 'اشرح تفاصيل الخدمة والميزات التي تقدمها',
          prefixIcon: Icons.description,
          color: serviceColor,
          maxLines: 4,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال وصف الخدمة';
            }
            return null;
          },
        ),
        SizedBox(height: 24),

        // السعر
        _buildSectionTitle('السعر', Icons.monetization_on, serviceColor),
        SizedBox(height: 10),
        _buildPriceField(serviceColor),
        SizedBox(height: 24),

        // المنطقة
        _buildSectionTitle('المنطقة', Icons.location_city, serviceColor),
        SizedBox(height: 10),
        _buildDropdownField(
          value: _selectedRegion,
          label: 'المنطقة',
          hint: 'اختر المنطقة التي تقدم فيها الخدمة',
          prefixIcon: Icons.location_city,
          color: serviceColor,
          items:
              _regions.map((region) {
                return DropdownMenuItem(value: region, child: Text(region));
              }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedRegion = value;
              });
            }
          },
        ),
        SizedBox(height: 10),
      ],
    );
  }

  // عنوان القسم المحسن
  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // حقل السعر المحسن
  Widget _buildPriceField(Color serviceColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: _greyLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.monetization_on, color: serviceColor, size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedServiceType == 'تخزين'
                        ? 'أدخل سعر التخزين'
                        : 'أدخل سعر خدمة النقل',
                    style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_selectedServiceType == 'تخزين') ...[
                  SizedBox(width: 8),
                  SizedBox(
                    width: 90,
                    child: DropdownButton<String>(
                      value: _storageDurationType,
                      items: [
                        DropdownMenuItem(value: 'شهري', child: Text('شهري')),
                        DropdownMenuItem(value: 'سنوي', child: Text('سنوي')),
                        DropdownMenuItem(value: 'يومي', child: Text('يومي')),
                      ],
                      onChanged: (val) {
                        setState(() => _storageDurationType = val!);
                      },
                      underline: SizedBox(),
                      isExpanded: true,
                      style: TextStyle(
                        color: serviceColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: _greyLight),
          Row(
            children: [
              // السعر
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _priceController,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    hintText: 'أدخل السعر',
                    hintStyle: TextStyle(
                      color: Colors.grey.withOpacity(0.7),
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'أدخل السعر';
                    }
                    try {
                      final double price = double.parse(value);
                      if (price <= 0) {
                        return 'السعر يجب أن يكون أكبر من صفر';
                      }
                    } catch (e) {
                      return 'يرجى إدخال سعر صحيح';
                    }
                    return null;
                  },
                ),
              ),
              // لا تعرض العملة أبداً
            ],
          ),
        ],
      ),
    );
  }

  // الخطوة الثانية: تحديد الموقع - محسنة
  Widget _buildLocationStep(Color serviceColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // إرشادات تحديد الموقع
        _buildInfoBox(
          _selectedServiceType == 'تخزين'
              ? 'إرشادات تحديد الموقع'
              : 'إرشادات التتبع المباشر',
          _selectedServiceType == 'تخزين'
              ? 'يرجى تحديد موقع مكان التخزين بدقة على الخريطة للسماح للعملاء بالوصول إليه بسهولة.'
              : 'حدد موقع البداية الخاص بك للسماح للعملاء بتتبع مسار الشحنة بداية من هذا الموقع.',
          serviceColor,
          Icons.info_outline,
        ),
        SizedBox(height: 24),

        // زر تحديد الموقع على الخريطة
        _buildLocationButton(serviceColor),
        SizedBox(height: 24),

        // عرض عنوان الموقع إذا تم تحديده
        _locationAddress.isNotEmpty
            ? _buildSelectedLocationCard(serviceColor)
            : _buildNoLocationWarning(serviceColor),
      ],
    );
  }

  // صندوق معلومات
  Widget _buildInfoBox(
    String title,
    String content,
    Color color,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: _primaryColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  // زر تحديد الموقع
  Widget _buildLocationButton(Color serviceColor) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: serviceColor.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
        gradient: LinearGradient(
          colors: [serviceColor, serviceColor.withOpacity(0.8)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openMapPage,
          borderRadius: BorderRadius.circular(15),
          splashColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _selectedServiceType == 'تخزين' ? Icons.map : Icons.gps_fixed,
                color: Colors.white,
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                _selectedServiceType == 'تخزين'
                    ? 'تحديد موقع مكان التخزين'
                    : 'تفعيل التتبع المباشر للشحنة',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // بطاقة الموقع المحدد
  Widget _buildSelectedLocationCard(Color serviceColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: serviceColor.withOpacity(0.3), width: 1),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(8), // Reducido de 10 a 8
                decoration: BoxDecoration(
                  color: serviceColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _selectedServiceType == 'تخزين'
                      ? Icons.check_circle
                      : Icons.gps_fixed,
                  color: serviceColor,
                  size: 18, // Reducido de 20 a 18
                ),
              ),
              SizedBox(width: 8), // Reducido de 12 a 8
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedServiceType == 'تخزين'
                          ? 'تم تحديد الموقع بنجاح'
                          : 'تم تفعيل التتبع المباشر',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14, // Reducido de 16 a 14
                        color: _primaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'يمكنك تغيير الموقع في أي وقت',
                      style: TextStyle(fontSize: 12, color: _greyDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Botón de edición más pequeño y eficiente
              SizedBox(
                width: 32, // Reducido de 40 a 32
                height: 32, // Reducido de 40 a 32
                child: IconButton(
                  onPressed: _openMapPage,
                  icon: Icon(
                    Icons.edit_location_alt,
                    color: serviceColor,
                    size: 16, // Reducido de 20 a 16
                  ),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  tooltip: 'تعديل الموقع',
                  visualDensity:
                      VisualDensity.compact, // Hacer el botón más compacto
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Divider(color: _greyLight),
          SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on, color: serviceColor, size: 18),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  _locationAddress,
                  style: TextStyle(color: _primaryColor, height: 1.4),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          if (_locationLatitude != null && _locationLongitude != null)
            Row(
              children: [
                Icon(Icons.info_outline, color: _greyDark, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الإحداثيات: ${_locationLatitude!.toStringAsFixed(6)}, ${_locationLongitude!.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: _greyDark,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // تحذير عدم تحديد الموقع
  Widget _buildNoLocationWarning(Color serviceColor) {
    return Container(
      decoration: BoxDecoration(
        color: _warningColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _warningColor.withOpacity(0.3), width: 1),
      ),
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: _warningColor,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'لم يتم تحديد الموقع بعد',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _warningColor,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  _selectedServiceType == 'تخزين'
                      ? 'يرجى النقر على زر تحديد الموقع لتحديد مكان التخزين على الخريطة'
                      : 'يرجى النقر على زر تفعيل التتبع المباشر لتحديد نقطة البداية',
                  style: TextStyle(
                    color: _primaryColor.withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // الخطوة الثالثة للتخزين: صور مكان التخزين - محسنة
  Widget _buildStorageImagesStep(Color serviceColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // إرشادات تحميل الصور
        _buildInfoBox(
          'إرشادات تحميل الصور',
          'قم بتحميل صور عالية الجودة وواضحة لمكان التخزين. يفضل إضافة صور من زوايا مختلفة للداخل والخارج لمساعدة العملاء على تقييم المكان بشكل أفضل.',
          serviceColor,
          Icons.info_outline,
        ),
        SizedBox(height: 24),

        // صور عامة للخدمة
        _buildImagesUploadSection(
          'صور عامة للخدمة',
          'أضف صوراً توضح خدمتك بشكل عام (يفضل 3-5 صور)',
          Icons.photo_library,
          serviceColor,
          _selectedImages,
          _pickImages,
          (index) {
            setState(() {
              _selectedImages.removeAt(index);
            });
          },
        ),
        SizedBox(height: 24),

        // صور مكان التخزين
        _buildImagesUploadSection(
          'صور مكان التخزين',
          'أضف صوراً توضح المساحة الداخلية والخارجية لمكان التخزين (يفضل 3-5 صور)',
          Icons.warehouse,
          serviceColor,
          _storageLocationImages,
          _pickStorageLocationImages,
          (index) {
            setState(() {
              _storageLocationImages.removeAt(index);
            });
          },
        ),
        SizedBox(height: 10),
      ],
    );
  }

  // الخطوة الثالثة للنقل: معلومات وصور المركبة - محسنة
  Widget _buildTransportVehicleStep(Color serviceColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // قسم نوع المركبة
        _buildSectionTitle('نوع المركبة', Icons.local_shipping, serviceColor),
        SizedBox(height: 10),
        _buildVehicleTypeSelector(serviceColor),
        SizedBox(height: 24),

        // قسم معلومات المركبة
        _buildSectionTitle('معلومات المركبة', Icons.info, serviceColor),
        SizedBox(height: 10),
        _buildVehicleInfoInputs(serviceColor),
        SizedBox(height: 24),

        // قسم صور المركبة
        _buildImagesUploadSection(
          'صور المركبة',
          'أضف صوراً واضحة للمركبة من جميع الجوانب (يفضل 3-5 صور)',
          Icons.directions_car,
          serviceColor,
          _vehicleImages,
          _pickVehicleImages,
          (index) {
            setState(() {
              _vehicleImages.removeAt(index);
            });
          },
        ),
        SizedBox(height: 10),
      ],
    );
  }

  // اختيار نوع المركبة
  Widget _buildVehicleTypeSelector(Color serviceColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: _greyLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'اختر نوع المركبة المستخدمة في النقل',
              style: TextStyle(
                fontSize: 14,
                color: _primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Divider(height: 1, color: _greyLight),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _vehicleTypes.length,
            itemBuilder: (context, index) {
              final vehicleType = _vehicleTypes[index];
              final isSelected = _selectedVehicleType == vehicleType;

              IconData vehicleIcon;
              switch (index) {
                case 0:
                  vehicleIcon = Icons.local_shipping;
                  break;
                case 1:
                  vehicleIcon = Icons.fire_truck;
                  break;
                case 2:
                  vehicleIcon = Icons.directions_bus;
                  break;
                case 3:
                  vehicleIcon = Icons.airport_shuttle;
                  break;
                case 4:
                  vehicleIcon = Icons.two_wheeler;
                  break;
                default:
                  vehicleIcon = Icons.drive_eta;
              }

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedVehicleType = vehicleType;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? serviceColor : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? serviceColor : _greyLight,
                      width: isSelected ? 0 : 1,
                    ),
                    boxShadow:
                        isSelected
                            ? [
                              BoxShadow(
                                color: serviceColor.withOpacity(0.2),
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ]
                            : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        vehicleIcon,
                        color: isSelected ? Colors.white : serviceColor,
                        size: 28,
                      ),
                      SizedBox(height: 8),
                      Text(
                        vehicleType,
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? Colors.white : _primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // حقول إدخال معلومات المركبة
  Widget _buildVehicleInfoInputs(Color serviceColor) {
    // تحقق مما إذا كان نوع المركبة دراجة نارية
    final bool isMotorcycle = _selectedVehicleType == 'دراجة نارية';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: _greyLight, width: 1),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ماركة المركبة - حقل منفصل في صف كامل
          Text(
            'ماركة المركبة',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          SizedBox(height: 8),
          _buildInputField(
            controller: _vehicleMakeController,
            label: 'ماركة المركبة',
            hint: 'مثال: مرسيدس، إيسوزو، هينو، إلخ',
            prefixIcon: Icons.branding_watermark,
            color: serviceColor,
            validator: (value) {
              if (_selectedServiceType == 'نقل' &&
                  (value == null || value.isEmpty)) {
                return 'الرجاء إدخال ماركة المركبة';
              }
              return null;
            },
          ),
          SizedBox(height: 20),

          // عنوان للقسم الخاص بسنة الصنع ورقم اللوحة
          Text(
            'معلومات هوية المركبة',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          SizedBox(height: 8),

          // سنة الصنع - حقل منفصل
          _buildInputField(
            controller: _vehicleYearController,
            label: 'سنة الصنع',
            hint: 'مثال: 2020',
            prefixIcon: Icons.date_range,
            color: serviceColor,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (_selectedServiceType == 'نقل' &&
                  (value == null || value.isEmpty)) {
                return 'أدخل سنة الصنع';
              }
              return null;
            },
          ),
          SizedBox(height: 16),

          // رقم اللوحة - حقل منفصل
          _buildInputField(
            controller: _vehiclePlateController,
            label: 'رقم اللوحة',
            hint: 'أدخل رقم اللوحة',
            prefixIcon: Icons.confirmation_number,
            color: serviceColor,
            validator: (value) {
              if (_selectedServiceType == 'نقل' &&
                  (value == null || value.isEmpty)) {
                return 'أدخل رقم اللوحة';
              }
              return null;
            },
          ),

          // إظهار قسم معلومات قدرة المركبة فقط إذا لم تكن دراجة نارية
          if (!isMotorcycle) ...[
            SizedBox(height: 20),

            // عنوان للقسم الخاص بالحمولة والأبعاد
            Text(
              'معلومات قدرة المركبة',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            SizedBox(height: 8),

            // الحمولة - حقل منفصل
            _buildInputField(
              controller: _vehicleCapacityController,
              label: 'الحمولة',
              hint: 'مثال: 3 طن',
              prefixIcon: Icons.line_weight,
              color: serviceColor,
            ),
            SizedBox(height: 16),

            // الأبعاد - حقل منفصل
            _buildInputField(
              controller: _vehicleDimensionsController,
              label: 'الأبعاد',
              hint: 'مثال: 4×2×2 متر',
              prefixIcon: Icons.straighten,
              color: serviceColor,
            ),
          ],

          SizedBox(height: 20),

          // عنوان للقسم الخاص بالميزات الخاصة
          Text(
            'ميزات إضافية للمركبة',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          SizedBox(height: 8),

          // ميزات خاصة - حقل منفصل في صف كامل
          _buildInputField(
            controller: _vehicleSpecialFeaturesController,
            label: 'ميزات خاصة',
            hint:
                isMotorcycle
                    ? 'مثال: حقيبة أمتعة، نظام GPS، إلخ'
                    : 'مثال: تبريد، رافعة، نظام تتبع، إلخ',
            prefixIcon: Icons.star,
            color: serviceColor,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // قسم تحميل الصور المحسّن
  Widget _buildImagesUploadSection(
    String title,
    String description,
    IconData icon,
    Color color,
    List<File> images,
    VoidCallback onAddPressed,
    Function(int) onRemove,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: _greyLight, width: 1),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _primaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(fontSize: 12, color: _greyDark),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Divider(height: 1, color: _greyLight),
          SizedBox(height: 16),

          // عرض الصور المختارة
          if (images.isNotEmpty) ...[
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: EdgeInsets.only(left: 10),
                    child: Stack(
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(images[index], fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: 5,
                          right: 5,
                          child: GestureDetector(
                            onTap: () => onRemove(index),
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _errorColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 5,
                          left: 5,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${index + 1}/${images.length}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
          ],

          // زر إضافة الصور
          InkWell(
            onTap: onAddPressed,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 1,
                  style: BorderStyle.solid,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.05),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_photo_alternate,
                      color: color,
                      size: 24,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    images.isEmpty
                        ? 'إضافة صور جديدة'
                        : 'إضافة المزيد من الصور',
                    style: TextStyle(color: color, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          if (images.isEmpty) ...[
            SizedBox(height: 10),
            Center(
              child: Text(
                'لم يتم اختيار أي صور بعد',
                style: TextStyle(
                  fontSize: 12,
                  color: _greyDark,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // أزرار التنقل بين الخطوات
  Widget _buildNavigationButtons(Color serviceColor) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // إذا كانت المساحة صغيرة جداً استخدم Wrap بدلاً من Row
          if (constraints.maxWidth < 350) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_currentStep > 0)
                  SizedBox(
                    width: double.infinity,
                    child: _buildNavigationButton(
                      onPressed: _previousStep,
                      label: 'السابق',
                      icon: Icons.arrow_back,
                      color: Colors.white,
                      backgroundColor: _greyDark,
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: _buildNavigationButton(
                    onPressed:
                        _currentStep < _totalSteps - 1
                            ? _nextStep
                            : _addNewService,
                    label:
                        _currentStep < _totalSteps - 1
                            ? 'التالي'
                            : 'إضافة الخدمة',
                    icon:
                        _currentStep < _totalSteps - 1
                            ? Icons.arrow_forward
                            : Icons.check,
                    color: Colors.white,
                    backgroundColor: serviceColor,
                    isLoading: _isLoading,
                  ),
                ),
              ],
            );
          }
          // الوضع الطبيعي: استخدم Row مع Expanded
          return Row(
            children: [
              if (_currentStep > 0) ...[
                Expanded(
                  flex: 2,
                  child: _buildNavigationButton(
                    onPressed: _previousStep,
                    label: 'السابق',
                    icon: Icons.arrow_back,
                    color: Colors.white,
                    backgroundColor: _greyDark,
                  ),
                ),
                SizedBox(width: 8),
              ],
              Expanded(
                flex: 3,
                child: _buildNavigationButton(
                  onPressed:
                      _currentStep < _totalSteps - 1
                          ? _nextStep
                          : _addNewService,
                  label:
                      _currentStep < _totalSteps - 1
                          ? 'التالي'
                          : 'إضافة الخدمة',
                  icon:
                      _currentStep < _totalSteps - 1
                          ? Icons.arrow_forward
                          : Icons.check,
                  color: Colors.white,
                  backgroundColor: serviceColor,
                  isLoading: _isLoading,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // زر التنقل المحسّن
  Widget _buildNavigationButton({
    required VoidCallback onPressed,
    required String label,
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    bool isLoading = false,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(15),
          splashColor: color.withOpacity(0.1),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child:
                isLoading
                    ? Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          strokeWidth: 2,
                        ),
                      ),
                    )
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(icon, color: color),
                      ],
                    ),
          ),
        ),
      ),
    );
  }

  // إنشاء حقل إدخال نص موحد ومحسّن
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    required Color color,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: TextStyle(color: _primaryColor),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.all(16),
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: _greyDark.withOpacity(0.6), fontSize: 14),
          labelStyle: TextStyle(color: color, fontWeight: FontWeight.w500),
          prefixIcon: Icon(prefixIcon, color: color, size: 20),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: _greyLight, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: color, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: _errorColor, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: _errorColor, width: 2),
          ),
          errorStyle: TextStyle(color: _errorColor),
        ),
        validator: validator,
      ),
    );
  }

  // إنشاء حقل قائمة منسدلة موحد ومحسّن
  Widget _buildDropdownField<T>({
    required T value,
    required String label,
    required String hint,
    required IconData prefixIcon,
    required Color color,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        dropdownColor: Colors.white,
        isExpanded: true, // إضافة هذه الخاصية لمنع تجاوز الحدود
        style: TextStyle(
          color: _primaryColor,
          fontSize: 15,
        ), // تقليل حجم الخط لمنع الإزدحام
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 16,
          ), // تقليل الهوامش الأفقية
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: _greyDark.withOpacity(0.6), fontSize: 14),
          labelStyle: TextStyle(color: color, fontWeight: FontWeight.w500),
          prefixIcon: Icon(
            prefixIcon,
            color: color,
            size: 18,
          ), // تقليل حجم الأيقونة
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: _greyLight, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: color, width: 2),
          ),
        ),
        icon: Icon(
          Icons.keyboard_arrow_down,
          color: color,
          size: 20,
        ), // تقليل حجم أيقونة السهم
      ),
    );
  }
}