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
              Color(0xFFFF6B3B), // برتقالي داكن
              Color(0xFFFF5775), // وردي
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 30),

                  // App logo and title
                  _buildHeader(),

                  const SizedBox(height: 30),

                  // Main value proposition
                  _buildValueProposition(),

                  const SizedBox(height: 30),

                  // Service illustrations
                  _buildServiceIllustration(screenSize),

                  const SizedBox(height: 35),

                  // User categories
                  _buildUserCategories(screenSize),

                  const SizedBox(height: 35),

                  // Authentication slider
                  _buildAuthenticationSlider(context),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Logo with glowing effect
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.2),
                Colors.white.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.link_rounded, size: 60, color: Colors.white),
          ),
        ),
        const SizedBox(height: 15),
        // App name with modern typography
        Text(
          'BiLink',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.2,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.2),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Tagline with elegant styling
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'رابط ذكي لخدمات النقل والتخزين',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildValueProposition() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
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
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'نربط بين',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            'الشركات ومزودي خدمات النقل والتخزين',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'بطريقة مبتكرة وفعالة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'ابدأ الآن',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF6B3B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceIllustration(Size screenSize) {
    // Make service items responsive
    final bool isSmallScreen = screenSize.width < 360;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child:
          isSmallScreen
              ? Column(
                children: [
                  _buildServiceIndicator(
                    icon: Icons.warehouse_rounded,
                    title: 'تخزين',
                    description: 'إدارة المخزون',
                  ),
                  const SizedBox(height: 15),
                  _buildServiceIndicator(
                    icon: Icons.sync_alt_rounded,
                    title: 'ربط',
                    description: 'تواصل آمن',
                    isCenter: true,
                  ),
                  const SizedBox(height: 15),
                  _buildServiceIndicator(
                    icon: Icons.local_shipping_rounded,
                    title: 'نقل',
                    description: 'توصيل سريع',
                  ),
                ],
              )
              : Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildServiceIndicator(
                    icon: Icons.warehouse_rounded,
                    title: 'تخزين',
                    description: 'إدارة المخزون',
                  ),
                  _buildConnectionLine(),
                  _buildServiceIndicator(
                    icon: Icons.sync_alt_rounded,
                    title: 'ربط',
                    description: 'تواصل آمن',
                    isCenter: true,
                  ),
                  _buildConnectionLine(),
                  _buildServiceIndicator(
                    icon: Icons.local_shipping_rounded,
                    title: 'نقل',
                    description: 'توصيل سريع',
                  ),
                ],
              ),
    );
  }

  Widget _buildServiceIndicator({
    required IconData icon,
    required String title,
    required String description,
    bool isCenter = false,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: isCenter ? Colors.white : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              size: 30,
              color: isCenter ? const Color(0xFFFF6B3B) : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
        ),
      ],
    );
  }

  Widget _buildConnectionLine() {
    return Container(
      width: 30,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildUserCategories(Size screenSize) {
    final bool isSmallScreen = screenSize.width < 360;

    // Adapt layout based on screen size
    return isSmallScreen
        ? Column(
          children: [
            _buildCategoryCard(
              icon: Icons.business_center_rounded,
              title: 'للشركات',
              description: 'احصل على خدمات\nلوجستية متكاملة',
              gradientColors: const [Color(0xFF00C9FF), Color(0xFF92FE9D)],
              width: screenSize.width - 40,
            ),
            const SizedBox(height: 15),
            _buildCategoryCard(
              icon: Icons.local_shipping_rounded,
              title: 'لمقدمي الخدمات',
              description: 'قدم خدمات متميزة\nوانمي أعمالك',
              gradientColors: const [Color(0xFFFF8489), Color(0xFFD76AD9)],
              width: screenSize.width - 40,
            ),
          ],
        )
        : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCategoryCard(
              icon: Icons.business_center_rounded,
              title: 'للشركات',
              description: 'احصل على خدمات\nلوجستية متكاملة',
              gradientColors: const [Color(0xFF00C9FF), Color(0xFF92FE9D)],
              width: (screenSize.width - 55) / 2,
            ),
            const SizedBox(width: 15),
            _buildCategoryCard(
              icon: Icons.local_shipping_rounded,
              title: 'لمقدمي الخدمات',
              description: 'قدم خدمات متميزة\nوانمي أعمالك',
              gradientColors: const [Color(0xFFFF8489), Color(0xFFD76AD9)],
              width: (screenSize.width - 55) / 2,
            ),
          ],
        );
  }

  Widget _buildCategoryCard({
    required IconData icon,
    required String title,
    required String description,
    required List<Color> gradientColors,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
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
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 30, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.9),
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticationSlider(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 220, // Increased height to prevent overflow
          child: PageView(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
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
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (context) => LoginPage()));
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
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
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 15),
          Text(
            description,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const Spacer(),
          ElevatedButton(
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
