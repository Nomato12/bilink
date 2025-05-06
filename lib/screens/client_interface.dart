import 'package:flutter/material.dart';

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  _ClientHomePageState createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("واجهة العملاء"),
        backgroundColor: Color(0xFF9B59B6),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // عنوان الواجهة
            Text(
              "3. واجهة العملاء",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9B59B6),
              ),
            ),
            SizedBox(height: 24),

            // تصفح الخدمات المتاحة
            Text(
              "تصفح الخدمات المتاحة:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            // قسم التخزين
            _buildServiceCategory(
              title: "التخزين",
              details: "حسب المساحة، الموقع، السعر",
              icon: Icons.warehouse,
              color: Colors.blue,
            ),
            SizedBox(height: 16),

            // قسم النقل
            _buildServiceCategory(
              title: "النقل",
              details: "حسب نوع البضائع، المسافة",
              icon: Icons.local_shipping,
              color: Colors.red,
            ),

            SizedBox(height: 32),
            Divider(),
            SizedBox(height: 32),

            // فلترة البحث
            Text(
              "فلترة البحث حسب:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            // خيارات الفلترة
            Wrap(
              spacing: 12.0,
              runSpacing: 12.0,
              children: [
                _buildFilterChip(label: "المنطقة", icon: Icons.location_on),
                _buildFilterChip(label: "السعر", icon: Icons.monetization_on),
                _buildFilterChip(label: "التقييمات", icon: Icons.star),
              ],
            ),

            SizedBox(height: 32),
            Divider(),
            SizedBox(height: 32),

            // عرض تفاصيل الخدمة
            Text(
              "عرض تفاصيل الخدمة والمقدم",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            // مثال لبطاقة عرض خدمة
            _buildServiceCard(),
          ],
        ),
      ),
    );
  }

  // بناء بطاقة فئة الخدمة
  Widget _buildServiceCategory({
    required String title,
    required String details,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(details, style: TextStyle(color: Colors.grey[700])),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16),
        ],
      ),
    );
  }

  // بناء رقاقة فلترة
  Widget _buildFilterChip({required String label, required IconData icon}) {
    return Chip(
      avatar: Icon(icon, size: 16, color: Color(0xFF9B59B6)),
      label: Text(label),
      backgroundColor: Color(0xFF9B59B6).withOpacity(0.1),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  // بناء بطاقة عرض خدمة
  Widget _buildServiceCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
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
            child: Container(
              height: 160,
              color: Colors.grey[300],
              width: double.infinity,
              child: Center(
                child: Icon(Icons.warehouse, size: 60, color: Colors.grey[400]),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Chip(
                      label: Text("تخزين"),
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      labelStyle: TextStyle(color: Colors.blue),
                    ),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 18),
                        SizedBox(width: 4),
                        Text(
                          "4.8",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  "مستودع حديث للإيجار",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.grey, size: 16),
                    SizedBox(width: 4),
                    Text(
                      "الرياض، السعودية",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.aspect_ratio, color: Colors.grey, size: 16),
                    SizedBox(width: 4),
                    Text(
                      "500 متر مربع",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "1,200 ريال / الشهر",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9B59B6),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF9B59B6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text("عرض التفاصيل"),
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
}
