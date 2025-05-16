import 'package:flutter/material.dart';
import 'package:bilink/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  runApp(const VerifyStorageNotificationsApp());
}

class VerifyStorageNotificationsApp extends StatelessWidget {
  const VerifyStorageNotificationsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Storage Notifications Verification',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const VerifyStorageNotificationsScreen(),
    );
  }
}

class VerifyStorageNotificationsScreen extends StatefulWidget {
  const VerifyStorageNotificationsScreen({super.key});

  @override
  State<VerifyStorageNotificationsScreen> createState() => _VerifyStorageNotificationsScreenState();
}

class _VerifyStorageNotificationsScreenState extends State<VerifyStorageNotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  
  String _statusText = 'Ready to verify storage service notifications';
  bool _isLoading = false;
  String _logText = '';
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage Notifications Verification'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _statusText,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        if (_isLoading)
                          const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _createTestStorageRequest,
                      child: const Text('Create Test Storage Request'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _verifyProviderNotifications,
                      child: const Text('Verify Provider Notifications'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Logs:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(_logText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _log(String message) {
    final timestamp = DateTime.now().toString().split('.').first;
    setState(() {
      _logText = '$_logText\n[$timestamp] $message';
    });
    print(message);
  }
  
  Future<void> _createTestStorageRequest() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _statusText = 'Creating test storage service request...';
    });
    
    try {
      // Check if user is logged in
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        _log('❌ Error: No user logged in. Please login first.');
        setState(() {
          _statusText = 'Error: No user logged in';
          _isLoading = false;
        });
        return;
      }
      
      // Find a storage service
      _log('🔍 Looking for a storage service...');
      final storageServiceQuery = await _firestore
          .collection('services')
          .where('type', isEqualTo: 'تخزين')
          .limit(1)
          .get();
          
      if (storageServiceQuery.docs.isEmpty) {
        _log('❌ Error: No storage services found');
        setState(() {
          _statusText = 'Error: No storage services found';
          _isLoading = false;
        });
        return;
      }
      
      final serviceDoc = storageServiceQuery.docs.first;
      final serviceData = serviceDoc.data();
      final serviceId = serviceDoc.id;
      final providerId = serviceData['providerId'] ?? serviceData['userId'];
      final serviceName = serviceData['title'] ?? 'Test Storage Service';
      
      _log('✅ Found storage service: $serviceName (ID: $serviceId)');
      _log('👤 Provider ID: $providerId');
      
      // Create the test request
      _log('📝 Creating service request...');
      final requestId = await _notificationService.sendServiceRequest(
        serviceId: serviceId,
        providerId: providerId,
        serviceName: serviceName,
        details: 'This is a test storage service request created at ${DateTime.now()}',
        requestDate: DateTime.now().add(const Duration(days: 1)),
      );
      
      _log('✅ Service request created with ID: $requestId');
      setState(() {
        _statusText = 'Test request created successfully';
        _isLoading = false;
      });
    } catch (e) {
      _log('❌ Error creating test request: $e');
      setState(() {
        _statusText = 'Error: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _verifyProviderNotifications() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _statusText = 'Verifying provider notifications...';
    });
    
    try {
      // Check if user is logged in
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        _log('❌ Error: No user logged in. Please login first.');
        setState(() {
          _statusText = 'Error: No user logged in';
          _isLoading = false;
        });
        return;
      }
      
      // Check for storage providers
      _log('🔍 Looking for storage service providers...');
      final storageServiceQuery = await _firestore
          .collection('services')
          .where('type', isEqualTo: 'تخزين')
          .get();
          
      if (storageServiceQuery.docs.isEmpty) {
        _log('❌ Error: No storage services found');
        setState(() {
          _statusText = 'Error: No storage services found';
          _isLoading = false;
        });
        return;
      }
      
      // Get unique provider IDs
      final providerIds = <String>{};
      for (final doc in storageServiceQuery.docs) {
        final providerId = doc.data()['providerId'] ?? doc.data()['userId'];
        if (providerId != null) {
          providerIds.add(providerId);
        }
      }
      
      _log('👥 Found ${providerIds.length} storage service providers');
      
      // Check notifications for each provider
      int totalPendingRequests = 0;
      for (final providerId in providerIds) {
        _log('🔎 Checking provider: $providerId');
        
        // Check pending requests
        final pendingRequests = await _firestore
            .collection('service_requests')
            .where('providerId', isEqualTo: providerId)
            .where('status', isEqualTo: 'pending')
            .where('serviceType', isEqualTo: 'تخزين')
            .get();
            
        _log('📊 Found ${pendingRequests.docs.length} pending storage requests for provider $providerId');
        totalPendingRequests += pendingRequests.docs.length;
        
        // Check notifications
        final notifications = await _firestore
            .collection('notifications')
            .where('userId', isEqualTo: providerId)
            .where('type', isEqualTo: 'service_request')
            .orderBy('createdAt', descending: true)
            .limit(10)
            .get();
            
        _log('🔔 Found ${notifications.docs.length} service request notifications for provider $providerId');
        
        // Log the last few notifications for this provider
        for (int i = 0; i < notifications.docs.length && i < 3; i++) {
          final notificationData = notifications.docs[i].data();
          final serviceType = notificationData['data']?['serviceType'] ?? 'Unknown';
          final title = notificationData['title'] ?? 'No title';
          final body = notificationData['body'] ?? 'No body';
          final createdAt = notificationData['createdAt'] as Timestamp?;
          final createdAtStr = createdAt != null 
              ? createdAt.toDate().toString() 
              : 'Unknown date';
          
          _log('   - Notification[$i]: $title ($serviceType) - $body - Created: $createdAtStr');
        }
      }
      
      if (totalPendingRequests > 0) {
        _log('✅ Verification complete: Found $totalPendingRequests pending storage service requests');
        setState(() {
          _statusText = 'Verification successful: $totalPendingRequests pending requests found';
          _isLoading = false;
        });
      } else {
        _log('⚠️ Verification concern: No pending storage service requests found');
        setState(() {
          _statusText = 'Warning: No pending storage requests found';
          _isLoading = false;
        });
      }
    } catch (e) {
      _log('❌ Error verifying notifications: $e');
      setState(() {
        _statusText = 'Error: $e';
        _isLoading = false;
      });
    }
  }
}
