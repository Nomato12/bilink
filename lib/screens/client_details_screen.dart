import 'package:flutter/material.dart';
import 'package:bilink/services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ClientDetailsScreen extends StatefulWidget {
  final String clientId;
  
  const ClientDetailsScreen({
    super.key, 
    required this.clientId
  });

  @override
  State<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends State<ClientDetailsScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = true;
  Map<String, dynamic> _clientDetails = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
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
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن الاتصال بهذا الرقم'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri emailUri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن فتح تطبيق البريد الإلكتروني'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('معلومات العميل'),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 60,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loadClientDetails,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Card
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                // Profile Picture
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: const Color(0xFFE9D5FF),
                                  backgroundImage: _clientDetails['profilePicture'] != null && 
                                      _clientDetails['profilePicture'].isNotEmpty
                                      ? NetworkImage(_clientDetails['profilePicture'])
                                      : null,
                                  child: _clientDetails['profilePicture'] == null || 
                                        _clientDetails['profilePicture'].isEmpty
                                      ? const Icon(
                                          Icons.person,
                                          size: 60,
                                          color: Color(0xFF8B5CF6),
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                // Name
                                Text(
                                  _clientDetails['name'] ?? 'عميل',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Contact Information
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'معلومات الاتصال',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF8B5CF6),
                                  ),
                                ),
                                const Divider(),
                                const SizedBox(height: 8),
                                _buildContactTile(
                                  icon: Icons.email,
                                  title: 'البريد الإلكتروني',
                                  value: _clientDetails['email'] ?? 'غير متوفر',
                                  onTap: _clientDetails['email'] != null && 
                                         _clientDetails['email'].isNotEmpty
                                      ? () => _sendEmail(_clientDetails['email'])
                                      : null,
                                ),
                                _buildContactTile(
                                  icon: Icons.phone,
                                  title: 'رقم الهاتف',
                                  value: _clientDetails['phone'] ?? 'غير متوفر',
                                  onTap: _clientDetails['phone'] != null && 
                                         _clientDetails['phone'].isNotEmpty
                                      ? () => _makePhoneCall(_clientDetails['phone'])
                                      : null,
                                ),
                                _buildContactTile(
                                  icon: Icons.location_on,
                                  title: 'العنوان',
                                  value: _clientDetails['address'] ?? 'غير متوفر',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Call to Action
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _clientDetails['phone'] != null && 
                                       _clientDetails['phone'].isNotEmpty
                                ? () => _makePhoneCall(_clientDetails['phone'])
                                : null,
                            icon: const Icon(Icons.phone),
                            label: const Text(
                              'الاتصال بالعميل',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildContactTile({
    required IconData icon, 
    required String title, 
    required String value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: const Color(0xFF8B5CF6),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: onTap != null ? FontWeight.bold : FontWeight.normal,
                      color: onTap != null ? const Color(0xFF8B5CF6) : null,
                      decoration: onTap != null ? TextDecoration.underline : null,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) 
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Color(0xFF8B5CF6),
              ),
          ],
        ),
      ),
    );
  }
}
