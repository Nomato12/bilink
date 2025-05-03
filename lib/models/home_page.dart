import 'package:flutter/material.dart';
import '../auth/login_page.dart';
import '../auth/signup_page.dart';

class BiLinkHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Get screen size to adapt layout
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF6B3B), // البرتقالي
              Color(0xFFFF5775), // الوردي
              Color(0xFF9B59B6), // البنفسجي
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    screenSize.height - MediaQuery.of(context).padding.vertical,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 40),

                    // شعار وعنوان التطبيق
                    _buildHeader(),

                    SizedBox(height: screenSize.height > 700 ? 60 : 40),

                    // القيمة الرئيسية
                    _buildValueProposition(),

                    SizedBox(height: screenSize.height > 700 ? 70 : 50),

                    // فئات المستخدمين
                    _buildUserCategories(screenSize),

                    SizedBox(height: screenSize.height > 700 ? 80 : 60),

                    // أزرار التسجيل والدخول
                    _buildAuthButtons(context),

                    SizedBox(height: 40),
                  ],
                ),
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
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Icon(Icons.link_rounded, size: 60, color: Colors.white),
        ),
        SizedBox(height: 16),
        Text(
          'BiLink',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          'حلول لوجستية ذكية',
          style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.9)),
        ),
      ],
    );
  }

  Widget _buildValueProposition() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'منصة تربط الشركات بمساحات التخزين',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'والنقل المتاحة',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUserCategories(Size screenSize) {
    final cardWidth = screenSize.width < 360 ? 130.0 : 150.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCategoryCard(
          icon: Icons.business,
          title: 'للشركات',
          description: 'أجد خدمات لوجستية\nلأعمالك',
          gradientColors: [Color(0xFFFF6B3B), Color(0xFFFF5775)],
          width: cardWidth,
        ),
        SizedBox(width: 15),
        _buildCategoryCard(
          icon: Icons.local_shipping,
          title: 'لمقدمي الخدمات',
          description: 'قدم خدمات التخزين\nوالنقل',
          gradientColors: [Color(0xFFFF5775), Color(0xFF9B59B6)],
          width: cardWidth,
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: Colors.white),
            ),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.9),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildButton(
          text: 'إنشاء حساب',
          backgroundColor: Colors.white,
          textColor: Color(0xFF9B59B6),
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (context) => SignupPage()));
          },
        ),
        SizedBox(height: 16),
        _buildButton(
          text: 'تسجيل الدخول',
          backgroundColor: Colors.transparent,
          textColor: Colors.white,
          borderColor: Colors.white,
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (context) => LoginPage()));
          },
        ),
      ],
    );
  }

  Widget _buildButton({
    required String text,
    required Color backgroundColor,
    required Color textColor,
    Color? borderColor,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        minimumSize: Size(double.infinity, 55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side:
              borderColor != null
                  ? BorderSide(color: borderColor, width: 2)
                  : BorderSide.none,
        ),
        elevation: 0,
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
