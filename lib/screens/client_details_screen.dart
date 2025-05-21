import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bilink/services/notification_service.dart';
import 'package:bilink/services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bilink/screens/chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ClientDetailsScreen extends StatefulWidget {
  final String clientId;
  final bool showDestinationDirectly;

  const ClientDetailsScreen({super.key, required this.clientId, this.showDestinationDirectly = false});

  @override
  State<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends State<ClientDetailsScreen> {
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late ChatService _chatService;

  bool _isLoading = true;
  Map<String, dynamic> _clientDetails = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(_auth.currentUser?.uid ?? '');
    _loadClientDetails();
  }

  Future<void> _loadClientDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final clientDetails = await _notificationService.getClientDetails(widget.clientId);

      setState(() {
        _clientDetails = clientDetails;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'فشل في تحميل بيانات العميل: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      String formattedNumber = phoneNumber.trim();
      formattedNumber = formattedNumber.replaceAll(RegExp(r'[\s\-)(]+'), '');
      final url = 'tel:$formattedNumber';
      final uri = Uri.parse(url);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('جاري الاتصال بالرقم $formattedNumber'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );

      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('لا يمكن الاتصال بهذا الرقم، تأكد من وجود تطبيق اتصال على جهازك'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء محاولة الاتصال: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }  Future<void> _sendEmail(String email) async {
    try {
      // إعداد العديد من محاولات الفتح (أكثر من طريقة)
      bool launched = false;
      
      // محاولة 1: استخدام بروتوكول mailto
      final Uri mailtoUri = Uri.parse('mailto:$email');
      try {
        if (await canLaunchUrl(mailtoUri)) {
          launched = await launchUrl(mailtoUri, mode: LaunchMode.platformDefault);
        }
      } catch (e) {
        print('Mailto launch error: $e');
      }
      
      // إذا نجحت المحاولة الأولى، اعرض إشعار وانتهي
      if (launched) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('جاري فتح البريد الإلكتروني مع $email'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      
      // محاولة 2: فتح البريد باستخدام URL مخصص
      final Uri emailAppUri = Uri.parse('mailto:$email?subject=&body=');
      try {
        if (await canLaunchUrl(emailAppUri)) {
          launched = await launchUrl(emailAppUri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        print('Email app URI error: $e');
      }
      
      // إذا نجحت المحاولة الثانية، اعرض إشعار وانتهي
      if (launched) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('جاري فتح البريد الإلكتروني مع $email'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      
      // محاولة 3: استخدام تطبيق Gmail مباشرة
      final Uri gmailUri = Uri.parse('https://mail.google.com/mail/?view=cm&fs=1&to=$email');
      try {
        if (await canLaunchUrl(gmailUri)) {
          launched = await launchUrl(gmailUri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        print('Gmail web URI error: $e');
      }
      
      // إذا نجحت المحاولة الثالثة، اعرض إشعار وانتهي
      if (launched) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('جاري فتح Gmail مع $email'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
        // في حالة فشل كل المحاولات السابقة، اعرض خيار النسخ للحافظة بتصميم جميل
      if (!launched && mounted) {
        await showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 12,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1E3A8A).withOpacity(0.9),
                    const Color(0xFF2563EB).withOpacity(0.7),
                    Colors.white,
                  ],
                  stops: const [0.0, 0.3, 0.9],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.mark_email_unread_rounded,
                          size: 56,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا يمكن فتح تطبيق البريد الإلكتروني',
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  // Content
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          'هل تريد نسخ البريد الإلكتروني إلى الحافظة؟',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[800],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        
                        // Email in card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A8A).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF1E3A8A).withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.email_outlined,
                                size: 24,
                                color: const Color(0xFF1E3A8A),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  email,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'إلغاء',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3A8A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 2,
                                ),
                                onPressed: () {
                                  // نسخ البريد الإلكتروني إلى الحافظة
                                  Clipboard.setData(ClipboardData(text: email));
                                  Navigator.pop(context);
                                  
                                  // عرض إشعار بأن البريد تم نسخه
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم نسخ البريد الإلكتروني إلى الحافظة'),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: Icon(Icons.content_copy, size: 18),
                                label: const Text(
                                  'نسخ البريد',
                                  style: TextStyle(fontSize: 16),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String clientName = _clientDetails['name'] ?? 'معلومات';

    return Scaffold(
      appBar: AppBar(
        title: Text(clientName),
        backgroundColor: const Color(0xFF1E3A8A), // Darker blue theme for logistics
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1E3A8A).withOpacity(0.9),
              const Color(0xFF2563EB).withOpacity(0.7),
              Colors.white,
            ],
            stops: const [0.0, 0.2, 0.5],
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 70,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _loadClientDetails,
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المحاولة'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header with logistics-themed design
                        Container(
                          padding: const EdgeInsets.only(bottom: 30, top: 10),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Decorative elements (logistics icons)
                              Positioned(
                                left: 20,
                                top: 10,
                                child: Opacity(
                                  opacity: 0.2,
                                  child: Icon(
                                    Icons.local_shipping,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 30,
                                bottom: 20,
                                child: Opacity(
                                  opacity: 0.2,
                                  child: Icon(
                                    Icons.inventory,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              
                              // Client avatar
                              Hero(
                                tag: 'client-profile-${widget.clientId}',
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 4,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(60),
                                    child: _clientDetails['profilePicture'] != null &&
                                            _clientDetails['profilePicture'].toString().isNotEmpty
                                        ? Image.network(
                                            _clientDetails['profilePicture'],
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: const Color(0xFF1E3A8A).withOpacity(0.1),
                                                child: const Icon(
                                                  Icons.person,
                                                  size: 70,
                                                  color: Color(0xFF1E3A8A),
                                                ),
                                              );
                                            },
                                          )
                                        : Container(
                                            color: const Color(0xFF1E3A8A).withOpacity(0.1),
                                            child: const Icon(
                                              Icons.person,
                                              size: 70,
                                              color: Color(0xFF1E3A8A),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Content area with cards
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Client name with role badge
                              Text(
                                _clientDetails['name'] ?? 'معلومات',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A8A),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              
                              // Contact Information Card
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 5,
                                shadowColor: Colors.black.withOpacity(0.2),
                                margin: const EdgeInsets.only(bottom: 20),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white,
                                        const Color(0xFF1E3A8A).withOpacity(0.05),
                                      ],
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1E3A8A).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.contact_phone_outlined,
                                              color: Color(0xFF1E3A8A),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'معلومات الاتصال',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E3A8A),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(
                                        height: 30,
                                        thickness: 1.5,
                                        color: Color(0xFFE5E7EB),
                                      ),
                                        // البريد الإلكتروني
                                      InkWell(
                                        onTap: _clientDetails['email'] != null && _clientDetails['email'].isNotEmpty
                                            ? () => _sendEmail(_clientDetails['email'])
                                            : null,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1E3A8A).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Icon(
                                                  Icons.email_outlined,
                                                  color: Color(0xFF1E3A8A),
                                                  size: 24,
                                                ),
                                              ),
                                              const SizedBox(width: 15),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'البريد الإلكتروني',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.grey[700],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      _clientDetails['email'] ?? 'غير متوفر',
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF1E293B),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (_clientDetails['email'] != null && _clientDetails['email'].isNotEmpty)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(
                                                      color: Colors.blue.withOpacity(0.5),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'إرسال بريد',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.blue,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      
                                      const Divider(height: 2),

                                      // رقم الهاتف
                                      InkWell(
                                        onTap: _clientDetails['phone'] != null && _clientDetails['phone'].isNotEmpty
                                            ? () => _makePhoneCall(_clientDetails['phone'])
                                            : null,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1E3A8A).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Icon(
                                                  Icons.phone_outlined,
                                                  color: Color(0xFF1E3A8A),
                                                  size: 24,
                                                ),
                                              ),
                                              const SizedBox(width: 15),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'رقم الهاتف',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.grey[700],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      _clientDetails['phone'] ?? 'غير متوفر',
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF1E293B),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (_clientDetails['phone'] != null && _clientDetails['phone'].isNotEmpty)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(
                                                      color: Colors.green.withOpacity(0.5),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'اتصال',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.green,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),

                                    ],
                                  ),
                                ),
                              ),

                              // Logistics info card (improved)
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 5,
                                shadowColor: Colors.black.withOpacity(0.2),
                                margin: const EdgeInsets.only(bottom: 20),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white,
                                        const Color(0xFF1E3A8A).withOpacity(0.05),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF1E3A8A).withOpacity(0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1E3A8A).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF1E3A8A).withOpacity(0.1),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.local_shipping_outlined,
                                              color: Color(0xFF1E3A8A),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'خدمات اللوجستية',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E3A8A),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(
                                        height: 30,
                                        thickness: 1.5,
                                        color: Color(0xFFE5E7EB),
                                      ),
                                      
                                      // Enhanced logistics service icons with better visual
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            _buildEnhancedLogisticsServiceItem(
                                              icon: Icons.inventory_2_outlined,
                                              label: 'تخزين',
                                              color: const Color(0xFF3B82F6),
                                            ),
                                            _buildEnhancedLogisticsServiceItem(
                                              icon: Icons.local_shipping_outlined,
                                              label: 'شحن',
                                              color: const Color(0xFF10B981),
                                            ),
                                            _buildEnhancedLogisticsServiceItem(
                                              icon: Icons.badge_outlined,
                                              label: 'تتبع',
                                              color: const Color(0xFF8B5CF6),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              // Buttons row with enhanced styling
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  children: [
                                    if (_clientDetails.containsKey('phone') &&
                                        _clientDetails['phone'] != null &&
                                        _clientDetails['phone'].isNotEmpty)
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF10B981),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            elevation: 3,
                                            shadowColor: const Color(0xFF10B981).withOpacity(0.5),
                                          ),
                                          onPressed: () => _makePhoneCall(_clientDetails['phone']),
                                          icon: const Icon(Icons.call_outlined, size: 22),
                                          label: const Text(
                                            'اتصال',
                                            style: TextStyle(
                                              fontSize: 16, 
                                              fontWeight: FontWeight.bold
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (_clientDetails.containsKey('phone') &&
                                        _clientDetails['phone'] != null &&
                                        _clientDetails['phone'].isNotEmpty)
                                      const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF1E3A8A),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          elevation: 3,
                                          shadowColor: const Color(0xFF1E3A8A).withOpacity(0.5),
                                        ),
                                        onPressed: () => _startChat(),
                                        icon: const Icon(Icons.chat_outlined, size: 22),
                                        label: const Text(
                                          'محادثة',
                                          style: TextStyle(
                                            fontSize: 16, 
                                            fontWeight: FontWeight.bold
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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

  // New enhanced logistics service item builder
  Widget _buildEnhancedLogisticsServiceItem({
    required IconData icon, 
    required String label,
    required Color color
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: color,
            size: 32,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _startChat() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يجب تسجيل الدخول لبدء محادثة'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    try {
      final chatId = await _chatService.createOrGetChat(
        userId1: currentUser.uid,
        userId2: widget.clientId,
        userName1: currentUser.displayName ?? 'مستخدم',
        userName2: _clientDetails['name'] ?? 'عميل',
        userImage1: currentUser.photoURL ?? '',
        userImage2: _clientDetails['profilePicture'] ?? '',
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              otherUserId: widget.clientId,
              otherUserName: _clientDetails['name'] ?? 'عميل',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في بدء المحادثة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}