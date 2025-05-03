import 'package:bilink/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'login_page.dart';
import 'phone_verification_page.dart';
import '../models/user_model.dart';
import 'dart:async';

enum UserType { client, provider }

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage>
    with SingleTickerProviderStateMixin {
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

  // Animation controllers
  late AnimationController _animationController;
  late List<Animation<double>> _formFieldAnimations;
  bool _animationsInitialized = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );
  }

  void _initializeAnimations() {
    if (_animationsInitialized) return;

    // Count how many form fields we need animations for
    int totalFields = 4; // Basic fields (name, email, phone, password)

    if (_selectedUserType == UserType.client) {
      totalFields += 2; // Company name, business type
    } else {
      totalFields += 2; // Service type, coverage area
    }

    // Create staggered animations for each field
    _formFieldAnimations = List.generate(
      totalFields,
      (index) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            (index * 0.1), // Start time, staggered for each field
            (index * 0.1) + 0.5, // End time, allowing overlap
            curve: Curves.easeOutQuart,
          ),
        ),
      ),
    );

    _animationsInitialized = true;
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    // Initialize animations when the build method is first called
    _initializeAnimations();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6B3B), Color(0xFFFF5775), Color(0xFF9B59B6)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    children: [
                      SizedBox(height: 30),

                      // Header with back button
                      _buildHeader(),

                      SizedBox(height: 30),

                      // إظهار رسالة خطأ إذا وجدت
                      if (authService.errorMessage != null)
                        Container(
                          padding: EdgeInsets.all(12),
                          margin: EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.white),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authService.errorMessage!,
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // User type selection
                      _buildUserTypeSelection(),

                      SizedBox(height: 30),

                      // Registration form
                      Form(key: _formKey, child: _buildRegistrationForm()),

                      SizedBox(height: 20),

                      // Terms and conditions
                      _buildTermsAcceptance(),

                      SizedBox(height: 30),

                      // Register button
                      _buildRegisterButton(authService),

                      SizedBox(height: 20),

                      // Login link
                      _buildLoginLink(),

                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.arrow_forward, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        SizedBox(width: 12),
        Text(
          'إنشاء حساب جديد',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildUserTypeSelection() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildUserTypeButton(
              'شركة',
              UserType.client,
              Icons.business,
            ),
          ),
          SizedBox(width: 1),
          Expanded(
            child: _buildUserTypeButton(
              'مقدم خدمة',
              UserType.provider,
              Icons.local_shipping,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTypeButton(String label, UserType type, IconData icon) {
    bool isSelected = _selectedUserType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedUserType = type),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Color(0xFF9B59B6) : Colors.white,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Color(0xFF9B59B6) : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // اسم الشركة - يظهر فقط إذا كان المستخدم "شركة"
          if (_selectedUserType == UserType.client)
            Column(
              children: [
                _buildTextField(
                  controller: _companyNameController,
                  label: 'اسم الشركة',
                  icon: Icons.business_outlined,
                  hint: 'أدخل اسم الشركة',
                  validator: (value) {
                    if (_selectedUserType == UserType.client &&
                        (value == null || value.isEmpty)) {
                      return 'الرجاء إدخال اسم الشركة';
                    }
                    return null;
                  },
                  animationIndex: 0,
                ),
                SizedBox(height: 16),
              ],
            ),

          // الاسم الكامل
          _buildTextField(
            controller: _fullNameController,
            label: 'الاسم الكامل',
            icon: Icons.person_outline,
            hint: 'أدخل الاسم الكامل',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'الرجاء إدخال الاسم الكامل';
              }
              return null;
            },
            animationIndex: 1,
          ),

          SizedBox(height: 16),

          // البريد الإلكتروني
          _buildTextField(
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
            animationIndex: 2,
          ),

          SizedBox(height: 16),

          // رقم الهاتف
          _buildTextField(
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
            animationIndex: 3,
          ),

          SizedBox(height: 16),

          // حقول إضافية حسب نوع المستخدم
          if (_selectedUserType == UserType.client)
            Column(
              children: [
                _buildTextField(
                  controller: _businessTypeController,
                  label: 'نوع النشاط التجاري',
                  icon: Icons.category_outlined,
                  hint: 'مثال: تجارة، صناعة، خدمات',
                  validator: (value) {
                    if (_selectedUserType == UserType.client &&
                        (value == null || value.isEmpty)) {
                      return 'الرجاء إدخال نوع النشاط التجاري';
                    }
                    return null;
                  },
                  animationIndex: 4,
                ),
                SizedBox(height: 16),
              ],
            )
          else
            Column(
              children: [
                _buildTextField(
                  controller: _serviceTypeController,
                  label: 'نوع الخدمات اللوجستية',
                  icon: Icons.local_shipping_outlined,
                  hint: 'مثال: نقل بضائع، تخزين، توصيل',
                  validator: (value) {
                    if (_selectedUserType == UserType.provider &&
                        (value == null || value.isEmpty)) {
                      return 'الرجاء إدخال نوع الخدمات اللوجستية';
                    }
                    return null;
                  },
                  animationIndex: 4,
                ),
                SizedBox(height: 16),
                _buildTextField(
                  controller: _coverageAreaController,
                  label: 'منطقة التغطية',
                  icon: Icons.location_on_outlined,
                  hint: 'المناطق التي تقدم فيها خدماتك',
                  validator: (value) {
                    if (_selectedUserType == UserType.provider &&
                        (value == null || value.isEmpty)) {
                      return 'الرجاء إدخال منطقة التغطية';
                    }
                    return null;
                  },
                  animationIndex: 5,
                ),
                SizedBox(height: 16),
              ],
            ),

          // كلمة المرور
          _buildTextField(
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
              ),
              onPressed:
                  () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            animationIndex: 6,
          ),

          SizedBox(height: 16),

          // تأكيد كلمة المرور
          _buildTextField(
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
              ),
              onPressed:
                  () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
            ),
            animationIndex: 7,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    int? animationIndex,
  }) {
    // If animation index is provided, wrap with animated builder
    Widget formField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            fontWeight: FontWeight.w500,
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
            fillColor: Colors.white.withOpacity(0.2),
            prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.7)),
            suffixIcon: suffixIcon,
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red, width: 1),
            ),
            errorStyle: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );

    // If animation is provided, wrap with animation
    if (animationIndex != null &&
        animationIndex < _formFieldAnimations.length) {
      return AnimatedBuilder(
        animation: _formFieldAnimations[animationIndex],
        builder: (context, child) {
          return Opacity(
            opacity: _formFieldAnimations[animationIndex].value,
            child: Transform.translate(
              offset: Offset(
                0.0,
                30 * (1 - _formFieldAnimations[animationIndex].value),
              ),
              child: child,
            ),
          );
        },
        child: formField,
      );
    }

    return formField;
  }

  Widget _buildTermsAcceptance() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => setState(() => _acceptTerms = !_acceptTerms),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
            child:
                _acceptTerms
                    ? Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Wrap(
            children: [
              Text(
                'أوافق على ',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to terms and conditions
                  _showTermsAndConditions();
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'الشروط والأحكام',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton(AuthService authService) {
    return ElevatedButton(
      onPressed:
          authService.isLoading || !_acceptTerms
              ? null
              : () => _handleRegister(authService),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF9B59B6),
        minimumSize: Size(double.infinity, 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 0,
        disabledBackgroundColor: Colors.white.withOpacity(0.5),
      ),
      child:
          authService.isLoading
              ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Color(0xFF9B59B6),
                  strokeWidth: 2,
                ),
              )
              : Text(
                'إنشاء حساب',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'لديك حساب بالفعل؟ ',
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
        ),
        TextButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => LoginPage()),
            );
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
          ),
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
    );
  }

  Future<void> _handleRegister(AuthService authService) async {
    if (_formKey.currentState!.validate()) {
      if (!_acceptTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('يجب قبول الشروط والأحكام'),
            backgroundColor: Colors.red,
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
        // التحويل إلى صفحة التحقق من الهاتف
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => PhoneVerificationPage(
                  phoneNumber: _phoneController.text.trim(),
                ),
          ),
        );
      }
    }
  }

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
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('موافق'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _businessTypeController.dispose();
    _serviceTypeController.dispose();
    _coverageAreaController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}
