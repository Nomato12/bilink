import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:bilink/services/auth_service.dart';
import 'package:bilink/models/user_model.dart';

class AccountProfileScreen extends StatefulWidget {
  const AccountProfileScreen({super.key});

  @override
  State<AccountProfileScreen> createState() => _AccountProfileScreenState();
}

class _AccountProfileScreenState extends State<AccountProfileScreen> {
  final Color _primaryColor = const Color(0xFF1A237E);
  final Color _accentColor = const Color(0xFF4A148C);
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  
  Future<void> _uploadProfileImage(File imageFile, String userId) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      // إنشاء مرجع في Firebase Storage
      final fileName = path.basename(imageFile.path);
      final destination = 'profile_images/$userId/$fileName';
      final storageRef = FirebaseStorage.instance.ref().child(destination);
      
      // رفع الصورة مع تتبع التقدم
      final uploadTask = storageRef.putFile(imageFile);
      
      // متابعة تقدم الرفع
      uploadTask.snapshotEvents.listen((event) {
        setState(() {
          _uploadProgress = event.bytesTransferred.toDouble() / 
                            event.totalBytes.toDouble();
        });
      });
      
      // انتظار اكتمال الرفع
      await uploadTask;
      
      // الحصول على رابط الصورة
      final imageUrl = await storageRef.getDownloadURL();
      
      // تحديث معلومات المستخدم
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.updateProfileImage(imageUrl);

      // عرض رسالة نجاح
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث الصورة الشخصية بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // عرض رسالة خطأ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تحديث الصورة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }
  
  Future<void> _pickImage() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تسجيل الدخول أولاً'),
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
      final imageFile = File(pickedFile.path);
      await _uploadProfileImage(imageFile, user.uid);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _primaryColor,
        centerTitle: true,
        title: const Text(
          'الملف الشخصي',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Consumer<AuthService>(
          builder: (context, authService, _) {
            final user = authService.currentUser;
            
            if (user == null) {
              return const Center(
                child: Text('يرجى تسجيل الدخول لعرض معلومات الحساب'),
              );
            }
            
            return SingleChildScrollView(
              child: Column(
                children: [
                  // قسم الصورة الشخصية
                  Container(
                    height: 250,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [_primaryColor, _accentColor],
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(40),
                        bottomRight: Radius.circular(40),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // الصورة الشخصية
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [                                  // الصورة الشخصية
                                  Hero(
                                    tag: 'profile-image-${user.uid}',
                                    child: CircleAvatar(
                                      radius: 65,
                                      backgroundColor: Colors.white.withOpacity(0.2),
                                      backgroundImage: user.profileImageUrl.isNotEmpty
                                          ? CachedNetworkImageProvider(user.profileImageUrl)
                                          : const AssetImage('assets/images/Design sans titre.png') as ImageProvider,
                                      child: user.profileImageUrl.isEmpty
                                          ? Icon(
                                              Icons.person,
                                              size: 60,
                                              color: Colors.white.withOpacity(0.8),
                                            )
                                          : null,
                                    ),
                                  ),
                                  
                                  // إظهار دائرة التقدم عند رفع الصورة
                                  if (_isUploading)
                                    CircularProgressIndicator(
                                      value: _uploadProgress,
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                ],
                              ),
                            ),
                            
                            // زر تغيير الصورة
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: _pickImage,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.camera_alt,
                                    color: _primaryColor,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 15),
                        
                        // اسم المستخدم
                        Text(
                          user.fullName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 5),
                        
                        // دور المستخدم
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getUserRoleText(user.role),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // قسم تفاصيل معلومات المستخدم
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // عنوان القسم
                            const Text(
                              'معلومات الحساب',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(),
                            
                            // الاسم الكامل
                            _buildInfoRow(
                              icon: Icons.person,
                              title: 'الاسم الكامل',
                              value: user.fullName,
                            ),
                            
                            // البريد الإلكتروني
                            _buildInfoRow(
                              icon: Icons.email,
                              title: 'البريد الإلكتروني',
                              value: user.email,
                            ),
                            
                            // رقم الهاتف
                            _buildInfoRow(
                              icon: Icons.phone,
                              title: 'رقم الهاتف',
                              value: user.phoneNumber.isNotEmpty 
                                  ? user.phoneNumber 
                                  : 'غير متوفر',
                            ),
                            
                            // تاريخ الانضمام
                            _buildInfoRow(
                              icon: Icons.calendar_today,
                              title: 'تاريخ الانضمام',
                              value: _formatDate(user.createdAt),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // قسم الأزرار والإجراءات
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'إجراءات الحساب',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(),
                            
                            // زر تعديل معلومات الحساب
                            _buildActionButton(
                              icon: Icons.edit,
                              title: 'تعديل معلومات الحساب',
                              onTap: () {
                                // تنفيذ إجراء تعديل معلومات الحساب
                              },
                            ),
                            
                            // زر تغيير كلمة المرور
                            _buildActionButton(
                              icon: Icons.lock,
                              title: 'تغيير كلمة المرور',
                              onTap: () {
                                // تنفيذ إجراء تغيير كلمة المرور
                              },
                            ),
                            
                            // زر تسجيل الخروج
                            _buildActionButton(
                              icon: Icons.logout,
                              title: 'تسجيل الخروج',
                              color: Colors.redAccent,
                              onTap: () async {
                                // تأكيد تسجيل الخروج
                                final confirmed = await _showLogoutConfirmation();
                                if (confirmed == true) {
                                  // تنفيذ تسجيل الخروج
                                  final authService = Provider.of<AuthService>(
                                    context, 
                                    listen: false,
                                  );
                                  await authService.logout();
                                  if (mounted) {
                                    Navigator.of(context).pop();
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
  
  // بناء صف المعلومات
  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: _primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // بناء زر الإجراء
  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (color ?? _primaryColor).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color ?? _primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 15),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: color ?? Colors.black87,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
    // تنسيق التاريخ
  String _formatDate(DateTime? date) {
    if (date == null) return 'غير متوفر';
    
    return '${date.day}/${date.month}/${date.year}';
  }
    // تحويل دور المستخدم إلى نص مفهوم
  String _getUserRoleText(UserRole role) {
    switch (role) {
      case UserRole.client:
        return 'عميل';
      case UserRole.provider:
        return 'مزود خدمة';
      case UserRole.admin:
        return 'مدير النظام';
    }
  }
  
  // عرض تأكيد تسجيل الخروج
  Future<bool?> _showLogoutConfirmation() {
    return showDialog<bool>(
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
                padding: const EdgeInsets.symmetric(vertical: 20),
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: const Column(
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    const SizedBox(height: 25),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
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
