import 'package:flutter/material.dart';
import '../auth/login_page.dart';
import '../auth/signup_page.dart';

class BiLinkHomePage extends StatefulWidget {
  const BiLinkHomePage({super.key});

  @override
  _BiLinkHomePageState createState() => _BiLinkHomePageState();
}

class _BiLinkHomePageState extends State<BiLinkHomePage> {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // إضافة استدعاء التأخير لضمان تهيئة كافة الويدجت قبل التحديث
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          // تأكد من تحديث الواجهة بعد تحميلها بشكل كامل
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size to adapt layout
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF7C3AED), // أرجواني داكن عصري
              Color(0xFF5B21B6), // أرجواني متوسط
            ],
          ),
        ),
        child: Stack(
          children: [
            // خلفية زخرفية - دوائر شفافة
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            // حاوية المحتوى الرئيسي
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.none, // إضافة هذا السطر لمنع قص المحتوى
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize:
                        MainAxisSize.min, // تحديد الحجم على الحد الأدنى
                    children: [
                      const SizedBox(height: 20),

                      // شعار التطبيق والعنوان
                      _buildAnimatedHeader(),

                      const SizedBox(height: 20), // تقليل المسافة قليلاً
                      // العرض القيمي المطور
                      _buildEnhancedValueProposition(),

                      const SizedBox(height: 20), // تقليل المسافة قليلاً
                      // توضيح الخدمات بتصميم محسن
                      _buildEnhancedServiceIllustration(screenSize),

                      const SizedBox(height: 25), // تقليل المسافة قليلاً
                      // فئات المستخدمين بتصميم محسن
                      _buildEnhancedUserCategories(screenSize),

                      const SizedBox(height: 25), // تقليل المسافة قليلاً
                      // شريحة تسجيل الدخول/إنشاء حساب بتصميم محسن
                      _buildAuthenticationSlider(context),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedHeader() {
    return Column(
      children: [
        // شعار مع تأثيرات متحركة
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0xFFa78bfa).withOpacity(0.5),
                blurRadius: 25,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/Design sans titre.png',
            fit: BoxFit.contain,
          ),
        ),
        // اسم التطبيق بتصميم عصري وطباعة حديثة
        ShaderMask(
          shaderCallback:
              (bounds) => LinearGradient(
                colors: [Colors.white, Color(0xFFddd6fe)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ).createShader(bounds),
          child: Text(
            'BiLink',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
              color: Colors.white,
              letterSpacing: 1.2,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // وصف مختصر بتصميم أنيق
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: const Text(
            'رابط ذكي لخدمات النقل والتخزين',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedValueProposition() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFc4b5fd).withOpacity(0.3),
            Color(0xFFd8b4fe).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // أيقونة مع تأثير متوهج
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFF8b5cf6).withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF8b5cf6).withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.route_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),

          // عنوان مع تأثير نص متوهج
          ShaderMask(
            shaderCallback:
                (bounds) => LinearGradient(
                  colors: [Colors.white, Color(0xFFe9d5ff)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(bounds),
            child: const Text(
              'نربط الشركات بخدمات النقل والتخزين',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),

          // وصف مفصل
          const Text(
            'منصة متكاملة تجمع احتياجات الشركات مع مقدمي خدمات النقل والتخزين بطريقة آمنة وسهلة وفعالة',
            style: TextStyle(fontSize: 16, color: Colors.white, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // زر "ابدأ الآن" أكثر بروزاً
          Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFa78bfa), Color(0xFF8b5cf6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF8b5cf6).withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                // توجيه المستخدم إلى صفحة إنشاء حساب جديد
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SignupPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'ابدأ الآن',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedServiceIllustration(Size screenSize) {
    // التكيف مع حجم الشاشة
    final bool isSmallScreen = screenSize.width < 400;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF8b5cf6).withOpacity(0.15),
            Color(0xFFc084fc).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
      ),
      child: Column(
        children: [
          // عنوان القسم مع تأثير متوهج
          ShaderMask(
            shaderCallback:
                (bounds) => LinearGradient(
                  colors: [Colors.white, Color(0xFFddd6fe)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(bounds),
            child: const Text(
              'خدماتنا الرئيسية',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // خدمات مطورة - تصميم أكثر عصرية بتناسق متساوٍ
          isSmallScreen
              ? Column(
                children: [
                  _buildEnhancedServiceItem(
                    icon: Icons.warehouse_rounded,
                    title: 'خدمات التخزين',
                    description: 'حلول تخزين متكاملة وآمنة لجميع احتياجاتك',
                    color: Color(0xFF60a5fa),
                  ),
                  const SizedBox(height: 16),
                  _buildEnhancedServiceItem(
                    icon: Icons.sync_alt_rounded,
                    title: 'خدمات الربط',
                    description: 'ربط سلس بين الشركات ومقدمي الخدمات',
                    color: Color(0xFFc084fc),
                    isPrimary: true,
                  ),
                  const SizedBox(height: 16),
                  _buildEnhancedServiceItem(
                    icon: Icons.local_shipping_rounded,
                    title: 'خدمات النقل',
                    description: 'نقل سريع وآمن لجميع أنواع البضائع',
                    color: Color(0xFFf472b6),
                  ),
                ],
              )
              // استخدام IntrinsicHeight لضمان توافق الارتفاع في الصف
              : Column(
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 1, // نفس النسبة للعناصر
                          child: _buildEnhancedServiceItem(
                            icon: Icons.warehouse_rounded,
                            title: 'خدمات التخزين',
                            description: 'حلول تخزين متكاملة وآمنة',
                            color: Color(0xFF60a5fa),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1, // نفس النسبة للعناصر
                          child: _buildEnhancedServiceItem(
                            icon: Icons.local_shipping_rounded,
                            title: 'خدمات النقل',
                            description: 'نقل سريع وآمن للبضائع',
                            color: Color(0xFFf472b6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildEnhancedServiceItem(
                    icon: Icons.sync_alt_rounded,
                    title: 'خدمات الربط',
                    description:
                        'منصة ذكية لربط الشركات بمقدمي الخدمات بكفاءة عالية وتكلفة مناسبة',
                    color: Color(0xFFc084fc),
                    isPrimary: true,
                  ),
                ],
              ),
        ],
      ),
    );
  }

  Widget _buildEnhancedServiceItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    bool isPrimary = false,
  }) {
    // إزالة الارتفاع الثابت واستخدام ConstrainedBox بدلاً منه
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: isPrimary ? 110.0 : 90.0),
      child: Container(
        // إزالة معلمة الارتفاع الثابت
        padding: EdgeInsets.all(isPrimary ? 18 : 14),
        decoration: BoxDecoration(
          color:
              isPrimary
                  ? color.withOpacity(0.2)
                  : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isPrimary
                    ? color.withOpacity(0.3)
                    : Colors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow:
              isPrimary
                  ? [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ]
                  : [],
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start, // تغيير محاذاة الصف لتجنب التجاوز
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isPrimary ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isPrimary ? 14 : 13,
                      color: Colors.white.withOpacity(0.8),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedUserCategories(Size screenSize) {
    final bool isSmallScreen = screenSize.width < 400;

    return Column(
      children: [
        // عنوان القسم بتصميم جذاب
        ShaderMask(
          shaderCallback:
              (bounds) => LinearGradient(
                colors: [Colors.white, Color(0xFFddd6fe)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ).createShader(bounds),
          child: Text(
            'اختر ما يناسبك',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),

        // بطاقات فئات المستخدمين - تحسين تناسق الحجم
        isSmallScreen
            ? Column(
              children: [
                _buildEnhancedCategoryCard(
                  icon: Icons.business_center_rounded,
                  title: 'للشركات',
                  description:
                      'احصل على خدمات لوجستية متكاملة تلبي احتياجات شركتك مع أفضل مقدمي الخدمات',
                  gradientColors: [Color(0xFF4f46e5), Color(0xFF6366f1)],
                  width: screenSize.width - 48,
                  onExplorePressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      ),
                ),
                const SizedBox(height: 16),
                _buildEnhancedCategoryCard(
                  icon: Icons.local_shipping_rounded,
                  title: 'لمقدمي الخدمات',
                  description:
                      'قدم خدماتك المتميزة للشركات وانمي أعمالك مع منصة متكاملة تدعم نجاحك',
                  gradientColors: [Color(0xFFec4899), Color(0xFFf472b6)],
                  width: screenSize.width - 48,
                  onExplorePressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      ),
                ),
              ],
            )
            : Row(
              children: [
                Expanded(
                  flex: 1, // نفس النسبة للعناصر (متساوية)
                  child: _buildEnhancedCategoryCard(
                    icon: Icons.business_center_rounded,
                    title: 'للشركات',
                    description: 'احصل على خدمات لوجستية متكاملة بأفضل الأسعار',
                    gradientColors: [Color(0xFF4f46e5), Color(0xFF6366f1)],
                    width: double.infinity,
                    onExplorePressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1, // نفس النسبة للعناصر (متساوية)
                  child: _buildEnhancedCategoryCard(
                    icon: Icons.local_shipping_rounded,
                    title: 'لمقدمي الخدمات',
                    description: 'قدم خدماتك المتميزة للشركات وانمي أعمالك',
                    gradientColors: [Color(0xFFec4899), Color(0xFFf472b6)],
                    width: double.infinity,
                    onExplorePressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        ),
                  ),
                ),
              ],
            ),
      ],
    );
  }

  Widget _buildEnhancedCategoryCard({
    required IconData icon,
    required String title,
    required String description,
    required List<Color> gradientColors,
    required double width,
    required VoidCallback onExplorePressed,
  }) {
    // Get screen size for responsive adjustments
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 400;

    // Use constraints instead of fixed height to avoid overflow
    return Container(
      width: width,
      // Remove fixed height to let content determine size
      padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Column(
          mainAxisSize:
              MainAxisSize.min, // Ensure column doesn't expand beyond content
          children: [
            // القسم العلوي (الأيقونة والعنوان)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(icon, size: 32, color: Colors.white),
            ),

            const SizedBox(height: 16),

            // عنوان مع تأثير متوهج
            ShaderMask(
              shaderCallback:
                  (bounds) => LinearGradient(
                    colors: [Colors.white, Colors.white70],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 12),

            // القسم الأوسط (الوصف)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.95),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                maxLines: isSmallScreen ? 3 : 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 16),

            // القسم السفلي (الزر)
            Container(
              width: double.infinity,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextButton(
                onPressed: onExplorePressed,
                style: TextButton.styleFrom(
                  foregroundColor: gradientColors[0],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'اكتشف المزيد',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: gradientColors[0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthenticationSlider(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min, // تحديد الحجم على الحد الأدنى
      children: [
        SizedBox(
          height:
              200, // تقليل الارتفاع للمناسبة مع ConstrainedBox في _buildAuthCard
          child: PageView(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            physics:
                const BouncingScrollPhysics(), // تغيير طريقة التمرير لمنع المشاكل
            children: [
              _buildAuthCard(
                title: 'إنشاء حساب',
                description:
                    'انضم إلينا واستفد من خدماتنا المتكاملة للشحن والتخزين',
                buttonText: 'إنشاء حساب جديد',
                gradientColors: const [Color(0xFF00C9FF), Color(0xFF92FE9D)],
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SignupPage()),
                  );
                },
              ),
              _buildAuthCard(
                title: 'تسجيل الدخول',
                description:
                    'مرحبا بعودتك، سجل دخولك للوصول لحسابك وإدارة خدماتك',
                buttonText: 'تسجيل الدخول',
                gradientColors: const [Color(0xFFFF8489), Color(0xFFD76AD9)],
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildPageIndicator(),
      ],
    );
  }

  Widget _buildAuthCard({
    required String title,
    required String description,
    required String buttonText,
    required List<Color> gradientColors,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ), // تقليل الهامش أكثر
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      // استخدام ConstrainedBox لتحديد حد أقصى للارتفاع
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 60,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    title == 'إنشاء حساب'
                        ? Icons.person_add_rounded
                        : Icons.login_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            // استخدام Spacer مع flex قليل لتقليل المساحة
            const Spacer(flex: 1),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: gradientColors[0],
                  elevation: 4,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        2,
        (index) => Container(
          width: index == _currentPage ? 24 : 12,
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color:
                index == _currentPage
                    ? Colors.white
                    : Colors.white.withOpacity(0.3),
            boxShadow:
                index == _currentPage
                    ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                    : [],
          ),
        ),
      ),
    );
  }
}
