import 'package:bilink/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bilink/auth/login_page.dart';
import 'package:bilink/auth/phone_verification_page.dart';
import 'package:bilink/models/user_model.dart';
import 'dart:async';
import 'dart:math';

enum UserType { client, provider }

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> with TickerProviderStateMixin {
  // Controllers للحقول
  final _companyNameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _serviceTypeController = TextEditingController();
  final _coverageAreaController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  UserType _selectedUserType = UserType.client;

  // Controller للمؤشر المتحرك في اختيار نوع المستخدم
  late final AnimationController _tabAnimationController;
  late final Animation<double> _tabAnimation;

  // Controllers للرسوم المتحركة
  late AnimationController _headerAnimationController;
  late AnimationController _formAnimationController;
  late AnimationController _buttonAnimationController;

  // تعريف الرسوم المتحركة
  late Animation<double> _headerScaleAnimation;
  late Animation<double> _headerFadeAnimation;
  late Animation<double> _formSlideAnimation;
  late Animation<double> _buttonScaleAnimation;

  // متغيرات للرسوم المتحركة للخلفية
  final List<Map<String, dynamic>> _backgroundElements = [];
  final Random _random = Random();

  // Controller الرسوم المتحركة للخلفية
  late AnimationController _bgAnimationController;

  // متغير للتحقق من بدء الرسوم المتحركة
  bool _animationsInitialized = false;
  late List<Animation<double>> _formFieldAnimations;
  int _animationFieldCount = 0;

  @override
  void initState() {
    super.initState();

    // إنشاء عناصر زخرفية للخلفية
    _createBackgroundElements();

    // تهيئة controller للمؤشر المتحرك في اختيار نوع المستخدم
    _tabAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _tabAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _tabAnimationController, curve: Curves.easeInOut),
    );

    // تهيئة controller للرسوم المتحركة للترويسة
    _headerAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _headerScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.8,
          end: 1.1,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.1,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
    ]).animate(_headerAnimationController);

    _headerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _headerAnimationController,
        curve: Interval(0.0, 0.7, curve: Curves.easeIn),
      ),
    );

    // تهيئة controller للرسوم المتحركة للنموذج
    _formAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );

    _formSlideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _formAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    // تهيئة controller للرسوم المتحركة للزر
    _buttonAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );

    _buttonScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.1,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
    ]).animate(_buttonAnimationController);

    // تهيئة controller للرسوم المتحركة للخلفية
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 20),
    )..repeat();

    // بدء الرسوم المتحركة بتسلسل
    _startAnimationSequence();
  }

  void _createBackgroundElements() {
    // إنشاء عناصر زخرفية متنوعة للخلفية
    for (int i = 0; i < 15; i++) {
      _backgroundElements.add({
        'x': _random.nextDouble(),
        'y': _random.nextDouble(),
        'size': _random.nextDouble() * 50 + 20, // 20-70
        'opacity': _random.nextDouble() * 0.07 + 0.01, // 0.01-0.08
        'speed': _random.nextDouble() * 0.001 + 0.0005, // 0.0005-0.0015
        'shape': _random.nextInt(3), // 0: دائرة، 1: مربع، 2: مثلث
        'angle': _random.nextDouble() * 2 * pi,
      });
    }
  }

  void _initializeFormFieldAnimations() {
    if (_animationsInitialized) return;

    // حساب عدد الحقول بناءً على نوع المستخدم
    _animationFieldCount = _selectedUserType == UserType.client ? 7 : 8;

    // إنشاء رسوم متحركة متتالية لكل حقل
    _formFieldAnimations = List.generate(
      _animationFieldCount,
      (index) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _formAnimationController,
          curve: Interval(
            (index * 0.1).clamp(
              0.0,
              0.9,
            ), // وقت البدء، مع التأكد من أنه لا يتجاوز 0.9
            min(
              (index * 0.1) + 0.5,
              1.0,
            ), // وقت الانتهاء، مع التأكد من أنه لا يتجاوز 1.0
            curve: Curves.easeOutQuart,
          ),
        ),
      ),
    );

    _animationsInitialized = true;
  }

  Future<void> _startAnimationSequence() async {
    // بدء الرسوم المتحركة للخلفية فوراً
    _bgAnimationController.forward();

    // بدء الرسوم المتحركة للترويسة
    await Future.delayed(Duration(milliseconds: 200));
    _headerAnimationController.forward();

    // بدء الرسوم المتحركة للنموذج
    await Future.delayed(Duration(milliseconds: 400));
    _initializeFormFieldAnimations();
    _formAnimationController.forward();

    // بدء الرسوم المتحركة للزر
    await Future.delayed(Duration(milliseconds: 800));
    _buttonAnimationController.forward();
  }

  // بناء العناصر الزخرفية للخلفية
  List<Widget> _buildBackgroundElements(Size screenSize) {
    return _backgroundElements.map((element) {
      // حساب الموضع المتحرك بناءً على الزمن
      final double offsetX =
          sin(_bgAnimationController.value * 2 * pi + element['angle']) * 0.05;
      final double offsetY =
          cos(_bgAnimationController.value * 2 * pi + element['angle']) * 0.05;
      final double x = (element['x'] + offsetX) % 1.0;
      final double y = (element['y'] + offsetY) % 1.0;

      // اختيار الشكل المناسب
      Widget shape;
      final double size = element['size'];

      switch (element['shape']) {
        case 0: // دائرة
          shape = Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(element['opacity']),
            ),
          );
          break;
        case 1: // مربع
          shape = Transform.rotate(
            angle: element['angle'] + _bgAnimationController.value * pi,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.2),
                color: Colors.white.withOpacity(element['opacity']),
              ),
            ),
          );
          break;
        case 2: // مثلث بسيط
        default:
          shape = Transform.rotate(
            angle: element['angle'] + _bgAnimationController.value * pi,
            child: CustomPaint(
              size: Size(size, size),
              painter: TrianglePainter(
                color: Colors.white.withOpacity(element['opacity']),
              ),
            ),
          );
          break;
      }

      return Positioned(
        left: x * screenSize.width,
        top: y * screenSize.height,
        child: shape,
      );
    }).toList();
  }

  // ترويسة محسنة
  Widget _buildEnhancedHeader() {
    return Transform.scale(
      scale: _headerScaleAnimation.value,
      child: Opacity(
        opacity: _headerFadeAnimation.value,
        child: Row(
          children: [
            // زر العودة
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_forward, color: Colors.white, size: 24),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            SizedBox(width: 16),
            // عنوان الصفحة
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback:
                      (bounds) => LinearGradient(
                        colors: [Colors.white, Color(0xFFddd6fe)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(bounds),
                  child: Text(
                    'إنشاء حساب جديد',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'انضم إلى BiLink واستمتع بخدماتنا',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // اختيار نوع المستخدم محسن
  Widget _buildEnhancedUserTypeSelection() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Stack(
        children: [
          // مؤشر متحرك - تم تعديل قيمة العرض لتفادي المشاكل
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: _selectedUserType == UserType.client ? 0 : null,
            right: _selectedUserType == UserType.provider ? 0 : null,
            top: 5,
            bottom: 5,
            width: MediaQuery.of(context).size.width * 0.42,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF8B5CF6).withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),

          // أزرار اختيار نوع المستخدم
          Row(
            children: [
              Expanded(
                child: _buildEnhancedUserTypeButton(
                  'شركة',
                  UserType.client,
                  Icons.business_rounded,
                ),
              ),
              Expanded(
                child: _buildEnhancedUserTypeButton(
                  'مقدم خدمة',
                  UserType.provider,
                  Icons.local_shipping_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // زر اختيار نوع المستخدم محسن
  Widget _buildEnhancedUserTypeButton(
    String label,
    UserType type,
    IconData icon,
  ) {
    final isSelected = _selectedUserType == type;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            if (_selectedUserType != type) {
              _selectedUserType = type;

              // إعادة تهيئة الرسوم المتحركة للحقول عند تغيير نوع المستخدم
              _animationsInitialized = false;
              _initializeFormFieldAnimations();
              _formAnimationController.reset();
              _formAnimationController.forward();
            }
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 60,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // رسالة خطأ محسنة
  Widget _buildErrorMessage(String message) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFef4444).withOpacity(0.2),
            Color(0xFFef4444).withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFef4444).withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFFef4444).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, color: Colors.white, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // نموذج التسجيل المحسن
  Widget _buildEnhancedRegistrationForm() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // عنوان القسم
          Container(
            margin: EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFF8B5CF6).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person_add_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'المعلومات الشخصية',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // اسم الشركة - يظهر فقط للشركات
          if (_selectedUserType == UserType.client)
            _buildEnhancedTextField(
              controller: _companyNameController,
              label: 'اسم الشركة',
              icon: Icons.business_outlined,
              hint: 'أدخل اسم الشركة',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'الرجاء إدخال اسم الشركة';
                }
                return null;
              },
              animationIndex: 0,
            ),

          // الاسم الكامل
          _buildEnhancedTextField(
            controller: _fullNameController,
            label: 'الاسم الكامل',
            icon: Icons.person_outlined,
            hint: 'أدخل الاسم الكامل',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'الرجاء إدخال الاسم الكامل';
              }
              return null;
            },
            animationIndex: _selectedUserType == UserType.client ? 1 : 0,
          ),

          // البريد الإلكتروني
          _buildEnhancedTextField(
            controller: _emailController,
            label: 'البريد الإلكتروني',
            icon: Icons.email_outlined,
            hint: 'example@email.com',
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'الرجاء إدخال البريد الإلكتروني';
              }
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value)) {
                return 'الرجاء إدخال بريد إلكتروني صالح';
              }
              return null;
            },
            animationIndex: _selectedUserType == UserType.client ? 2 : 1,
          ),

          // رقم الهاتف
          _buildEnhancedTextField(
            controller: _phoneController,
            label: 'رقم الهاتف',
            icon: Icons.phone_outlined,
            hint: '+213XXXXXXXXX',
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'الرجاء إدخال رقم الهاتف';
              }
              if (!value.startsWith('+')) {
                return 'يجب أن يبدأ رقم الهاتف بـ + ورمز الدولة';
              }
              return null;
            },
            animationIndex: _selectedUserType == UserType.client ? 3 : 2,
          ),

          // حقول خاصة بنوع المستخدم
          if (_selectedUserType == UserType.client) ...[
            _buildEnhancedTextField(
              controller: _businessTypeController,
              label: 'نوع النشاط التجاري',
              icon: Icons.category_outlined,
              hint: 'مثال: تجارة، صناعة، خدمات',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'الرجاء إدخال نوع النشاط التجاري';
                }
                return null;
              },
              animationIndex: 4,
            ),
          ] else ...[
            _buildEnhancedTextField(
              controller: _serviceTypeController,
              label: 'نوع الخدمات اللوجستية',
              icon: Icons.local_shipping_outlined,
              hint: 'مثال: نقل بضائع، تخزين، توصيل',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'الرجاء إدخال نوع الخدمات اللوجستية';
                }
                return null;
              },
              animationIndex: 3,
            ),
            _buildEnhancedTextField(
              controller: _coverageAreaController,
              label: 'منطقة التغطية',
              icon: Icons.location_on_outlined,
              hint: 'المناطق التي تقدم فيها خدماتك',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'الرجاء إدخال منطقة التغطية';
                }
                return null;
              },
              animationIndex: 4,
            ),
          ],

          // عنوان قسم كلمة المرور
          Container(
            margin: EdgeInsets.only(top: 15, bottom: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFF8B5CF6).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.lock_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'معلومات الأمان',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // كلمة المرور
          _buildEnhancedTextField(
            controller: _passwordController,
            label: 'كلمة المرور',
            icon: Icons.lock_outline,
            hint: '••••••••',
            obscureText: _obscurePassword,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'الرجاء إدخال كلمة المرور';
              }
              if (value.length < 6) {
                return 'يجب أن تكون كلمة المرور 6 أحرف على الأقل';
              }
              return null;
            },
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.white.withOpacity(0.7),
                size: 22,
              ),
              onPressed:
                  () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            animationIndex: _selectedUserType == UserType.client ? 5 : 5,
          ),

          // تأكيد كلمة المرور
          _buildEnhancedTextField(
            controller: _confirmPasswordController,
            label: 'تأكيد كلمة المرور',
            icon: Icons.lock_outline,
            hint: '••••••••',
            obscureText: _obscureConfirmPassword,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'الرجاء تأكيد كلمة المرور';
              }
              if (value != _passwordController.text) {
                return 'كلمات المرور غير متطابقة';
              }
              return null;
            },
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: Colors.white.withOpacity(0.7),
                size: 22,
              ),
              onPressed:
                  () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
            ),
            animationIndex: _selectedUserType == UserType.client ? 6 : 6,
          ),
        ],
      ),
    );
  }

  // حقل نص محسن
  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    required int animationIndex,
  }) {
    // بناء حقل النموذج
    final Widget formField = Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            validator: validator,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              contentPadding: EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              prefixIcon: Container(
                margin: EdgeInsets.only(right: 12),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              prefixIconConstraints: BoxConstraints(minWidth: 60, minHeight: 0),
              suffixIcon: suffixIcon,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Color(0xFFef4444).withOpacity(0.5),
                  width: 1,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Color(0xFFef4444).withOpacity(0.7),
                  width: 1.5,
                ),
              ),
              errorStyle: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );

    // إذا كان الرسم المتحرك مفعل وكان مؤشر الرسم المتحرك ضمن النطاق
    if (_animationsInitialized &&
        animationIndex < _formFieldAnimations.length) {
      return AnimatedBuilder(
        animation: _formFieldAnimations[animationIndex],
        builder: (context, child) {
          // Asegurar que el valor de la animación esté en el rango [0.0, 1.0]
          final animValue = _formFieldAnimations[animationIndex].value.clamp(
            0.0,
            1.0,
          );
          return Transform.translate(
            offset: Offset(0, 30 * (1 - animValue)),
            child: Opacity(opacity: animValue, child: child),
          );
        },
        child: formField,
      );
    }

    return formField;
  }

  // قبول الشروط والأحكام المحسن
  Widget _buildEnhancedTermsAcceptance() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => setState(() => _acceptTerms = !_acceptTerms),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _acceptTerms ? Color(0xFF8B5CF6) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _acceptTerms ? Color(0xFF8B5CF6) : Colors.white,
                  width: 2,
                ),
                boxShadow:
                    _acceptTerms
                        ? [
                          BoxShadow(
                            color: Color(0xFF8B5CF6).withOpacity(0.3),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ]
                        : [],
              ),
              child:
                  _acceptTerms
                      ? Center(
                        child: Icon(Icons.check, color: Colors.white, size: 16),
                      )
                      : null,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Text(
                  'أوافق على ',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                GestureDetector(
                  onTap: _showTermsAndConditions,
                  child: Text(
                    'الشروط والأحكام',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // زر التسجيل المحسن
  Widget _buildEnhancedRegisterButton(AuthService authService) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                _acceptTerms && !authService.isLoading
                    ? Color(0xFF8B5CF6).withOpacity(0.4)
                    : Colors.transparent,
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
        gradient: LinearGradient(
          colors:
              _acceptTerms && !authService.isLoading
                  ? [Color(0xFF8B5CF6), Color(0xFFA78BFA)]
                  : [
                    Colors.grey.withOpacity(0.3),
                    Colors.grey.withOpacity(0.2),
                  ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap:
              authService.isLoading || !_acceptTerms
                  ? null
                  : () => _handleRegister(authService),
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child:
                authService.isLoading
                    ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_add_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'إنشاء حساب',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }

  // رابط تسجيل الدخول المحسن
  Widget _buildEnhancedLoginLink() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'لديك حساب بالفعل؟ ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => LoginPage(),
                  transitionDuration: Duration(milliseconds: 500),
                  transitionsBuilder: (_, animation, __, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
              );
            },
            child: Text(
              'سجل دخول',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // عرض الشروط والأحكام
  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('الشروط والأحكام'),
            content: SingleChildScrollView(
              child: Text(
                'شروط استخدام تطبيق BiLink:\n\n'
                '1. المقدمة\n'
                'أهلا بك في BiLink، منصة متخصصة في ربط الشركات بمقدمي الخدمات اللوجستية. باستخدامك للتطبيق، فإنك توافق على الالتزام بهذه الشروط والأحكام.\n\n'
                '2. الحسابات\n'
                'يجب أن تكون المعلومات المقدمة عند إنشاء الحساب دقيقة وكاملة. أنت مسؤول عن الحفاظ على سرية كلمة المرور الخاصة بك.\n\n'
                '3. الخدمات\n'
                'يوفر التطبيق منصة للتواصل بين الشركات ومقدمي الخدمات اللوجستية. نحن لا نتحمل مسؤولية أي اتفاقيات تتم بين المستخدمين.\n\n'
                '4. المحتوى\n'
                'أنت مسؤول عن جميع المحتويات التي تنشرها على التطبيق، ويجب أن تكون دقيقة وقانونية.\n\n'
                '5. الخصوصية\n'
                'نحترم خصوصيتك ونلتزم بحماية بياناتك الشخصية وفقًا لسياسة الخصوصية الخاصة بنا.\n\n'
                '6. التعديلات\n'
                'نحتفظ بالحق في تعديل هذه الشروط في أي وقت. سيتم إعلامك بالتغييرات الهامة.\n\n'
                '7. إنهاء الخدمة\n'
                'نحتفظ بالحق في تعليق أو إنهاء حسابك في حالة انتهاك هذه الشروط.\n\n'
                '8. القانون المطبق\n'
                'تخضع هذه الشروط للقوانين المعمول بها وسيتم تسوية أي نزاعات وفقًا لهذه القوانين.\n\n',
                textAlign: TextAlign.right,
                style: TextStyle(height: 1.5),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'موافق',
                  style: TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Colors.white,
          ),
    );
  }

  // معالجة عملية التسجيل
  Future<void> _handleRegister(AuthService authService) async {
    if (_formKey.currentState!.validate()) {
      if (!_acceptTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text('يجب قبول الشروط والأحكام للمتابعة')),
              ],
            ),
            backgroundColor: Color(0xFFef4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.all(10),
          ),
        );
        return;
      }

      // تحضير البيانات الإضافية حسب نوع المستخدم
      Map<String, dynamic> additionalData = {};

      if (_selectedUserType == UserType.client) {
        additionalData = {'businessType': _businessTypeController.text.trim()};
      } else {
        additionalData = {
          'serviceType': _serviceTypeController.text.trim(),
          'coverageArea': _coverageAreaController.text.trim(),
        };
      }

      final success = await authService.registerWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        role:
            _selectedUserType == UserType.client
                ? UserRole.client
                : UserRole.provider,
        companyName:
            _selectedUserType == UserType.client
                ? _companyNameController.text.trim()
                : null,
        additionalData: additionalData,
      );

      if (success && mounted) {
        // إظهار رسالة نجاح
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text('تم إنشاء الحساب بنجاح'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.all(10),
          ),
        );

        // التحويل إلى صفحة التحقق من الهاتف
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder:
                (_, __, ___) => PhoneVerificationPage(
                  phoneNumber: _phoneController.text.trim(),
                ),
            transitionDuration: Duration(milliseconds: 500),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final screenSize = MediaQuery.of(context).size;

    // حساب موضع مؤشر اختيار نوع المستخدم
    final double tabIndicatorPosition =
        _selectedUserType == UserType.client ? 0.0 : 1.0;

    // تحديث موضع المؤشر عند تغيير نوع المستخدم
    // Solo actualizar cuando sea necesario para evitar llamadas innecesarias
    if (_tabAnimationController.status != AnimationStatus.forward &&
        _tabAnimationController.status != AnimationStatus.reverse) {
      if ((_selectedUserType == UserType.client && _tabAnimation.value == 1) ||
          (_selectedUserType == UserType.provider &&
              _tabAnimation.value == 0)) {
        _tabAnimationController.animateTo(tabIndicatorPosition);
      }
    }

    // تهيئة الرسوم المتحركة للحقول عند الحاجة
    if (!_animationsInitialized) {
      _initializeFormFieldAnimations();
    }

    return Scaffold(
      body: RepaintBoundary(
        // Add repaint boundary to optimize rendering
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _headerAnimationController,
            _formAnimationController,
            _buttonAnimationController,
            _bgAnimationController,
            _tabAnimationController,
          ]),
          builder: (context, _) {
            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF7C3AED), // أرجواني داكن عصري
                    Color(0xFF5B21B6), // أرجواني متوسط
                    Color(0xFF4C1D95), // أرجواني غامق
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  // العناصر الزخرفية المتحركة في الخلفية
                  // Limitar número de elementos decorativos para mejorar rendimiento
                  if (_backgroundElements.length > 10)
                    ..._buildBackgroundElements(screenSize).take(10)
                  else
                    ..._buildBackgroundElements(screenSize),

                  // المحتوى الرئيسي
                  SafeArea(
                    child: SingleChildScrollView(
                      physics: BouncingScrollPhysics(),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          children: [
                            SizedBox(height: 20),

                            // ترويسة مع زر العودة
                            _buildEnhancedHeader(),

                            SizedBox(height: 25),

                            // رسالة خطأ إذا وجدت
                            if (authService.errorMessage != null)
                              _buildErrorMessage(authService.errorMessage!),

                            SizedBox(height: 10),

                            // اختيار نوع المستخدم
                            _buildEnhancedUserTypeSelection(),

                            SizedBox(height: 25),

                            // نموذج التسجيل
                            Transform.translate(
                              offset: Offset(
                                0,
                                _formSlideAnimation.value.clamp(0.0, 50.0),
                              ),
                              child: Opacity(
                                opacity: (1 - _formSlideAnimation.value / 50)
                                    .clamp(0.0, 1.0),
                                child: Form(
                                  key: _formKey,
                                  child: _buildEnhancedRegistrationForm(),
                                ),
                              ),
                            ),

                            SizedBox(height: 20),

                            // قبول الشروط والأحكام
                            Transform.translate(
                              offset: Offset(
                                0,
                                (_formSlideAnimation.value / 2).clamp(
                                  0.0,
                                  25.0,
                                ),
                              ),
                              child: Opacity(
                                opacity: (1 - _formSlideAnimation.value / 100)
                                    .clamp(0.0, 1.0),
                                child: _buildEnhancedTermsAcceptance(),
                              ),
                            ),

                            SizedBox(height: 30),

                            // زر التسجيل
                            Transform.scale(
                              scale: _buttonScaleAnimation.value.clamp(
                                0.0,
                                1.0,
                              ),
                              child: _buildEnhancedRegisterButton(authService),
                            ),

                            SizedBox(height: 15),

                            // رابط تسجيل الدخول
                            Opacity(
                              opacity: _buttonScaleAnimation.value.clamp(
                                0.0,
                                1.0,
                              ),
                              child: _buildEnhancedLoginLink(),
                            ),

                            SizedBox(height: 40),
                          ],
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
    );
  }

  @override
  void dispose() {
    // التخلص من controllers لتجنب تسرب الذاكرة
    _companyNameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _businessTypeController.dispose();
    _serviceTypeController.dispose();
    _coverageAreaController.dispose();

    _tabAnimationController.dispose();
    _headerAnimationController.dispose();
    _formAnimationController.dispose();
    _buttonAnimationController.dispose();
    _bgAnimationController.dispose();

    super.dispose();
  }
}

// فئة لرسم المثلثات
class TrianglePainter extends CustomPainter {
  final Color color;

  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
