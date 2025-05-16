import 'package:flutter/material.dart';
import 'package:bilink/services/service_request_notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() {
  runApp(const NotificationDebugApp());
}

class NotificationDebugApp extends StatelessWidget {
  const NotificationDebugApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notification Debug',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const NotificationDebugScreen(),
    );
  }
}

class NotificationDebugScreen extends StatefulWidget {
  const NotificationDebugScreen({super.key});

  @override
  State<NotificationDebugScreen> createState() => _NotificationDebugScreenState();
}

class _NotificationDebugScreenState extends State<NotificationDebugScreen> {
  final ServiceRequestNotificationService _notificationService = ServiceRequestNotificationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  int _notificationCount = 0;
  List<Map<String, dynamic>> _acceptedRequests = [];
  bool _isLoading = false;
  String _statusMessage = "";
  
  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }
  
  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Loading notifications...";
    });
    
    try {
      // Get the notification count
      final count = await _notificationService.getAcceptedRequestsCount().first;
      
      // Get the list of accepted requests
      final requests = await _notificationService.getAcceptedRequests().first;
      final requestsData = requests.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
      
      setState(() {
        _notificationCount = count;
        _acceptedRequests = List<Map<String, dynamic>>.from(requestsData);
        _statusMessage = "Found $_notificationCount notifications";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Error: $e";
        _isLoading = false;
      });
    }
  }
  
  Future<void> _createTestRequest() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Creating test request...";
    });
    
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _statusMessage = "Error: No user logged in";
          _isLoading = false;
        });
        return;
      }
      
      // Find a service for testing
      final serviceSnap = await _firestore.collection('services').limit(1).get();
      if (serviceSnap.docs.isEmpty) {
        setState(() {
          _statusMessage = "Error: No services found";
          _isLoading = false;
        });
        return;
      }
      
      final serviceData = serviceSnap.docs.first.data();
      final providerId = serviceData['userId'];
      
      // Create the test request
      final requestRef = _firestore.collection('service_requests').doc();
      await requestRef.set({
        'clientId': userId,
        'providerId': providerId,
        'serviceId': serviceSnap.docs.first.id,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'details': 'Test request for notification debugging',
        'clientName': 'Debug Client',
        'serviceName': serviceData['title'] ?? 'Debug Service',
        'serviceType': serviceData['type'] ?? 'تخزين',
        'isClientNotified': false
      });
      
      setState(() {
        _statusMessage = "Test request created with ID: ${requestRef.id}";
      });
      
      // Simulate accepting the request
      await Future.delayed(const Duration(seconds: 2));
      await requestRef.update({
        'status': 'accepted',
        'responseDate': FieldValue.serverTimestamp(),
      });
      
      setState(() {
        _statusMessage = "Test request accepted. Notification should appear.";
        _isLoading = false;
      });
      
      // Reload notifications
      await _loadNotifications();
      
    } catch (e) {
      setState(() {
        _statusMessage = "Error: $e";
        _isLoading = false;
      });
    }
  }
  
  Future<void> _markAllAsNotified() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Marking all as notified...";
    });
    
    try {
      await _notificationService.markAllRequestsAsNotified();
      
      setState(() {
        _statusMessage = "All requests marked as notified";
        _isLoading = false;
      });
      
      // Reload notifications
      await _loadNotifications();
      
    } catch (e) {
      setState(() {
        _statusMessage = "Error: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notification Debug'),
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
                    Text(
                      'Notification Status',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Divider(),
                    Text('Current user: ${_auth.currentUser?.email ?? 'None'}'),
                    SizedBox(height: 8),
                    Text(
                      'Notification count: $_notificationCount',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _notificationCount > 0 ? Colors.green : Colors.grey,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(_statusMessage),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _loadNotifications,
                  child: Text('Refresh'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _createTestRequest,
                  child: Text('Create Test Request'),
                ),
                ElevatedButton(
                  onPressed: _isLoading || _notificationCount == 0 ? null : _markAllAsNotified,
                  child: Text('Mark All As Notified'),
                ),
              ],
            ),
            SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _acceptedRequests.isEmpty
                      ? Center(
                          child: Text(
                            'No accepted requests found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _acceptedRequests.length,
                          itemBuilder: (context, index) {
                            final request = _acceptedRequests[index];
                            return Card(
                              margin: EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(request['serviceName'] ?? 'Unknown Service'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Status: ${request['status']}'),
                                    Text('Notified: ${request['isClientNotified'] == true ? 'Yes' : 'No'}'),
                                    if (request['responseDate'] != null)
                                      Text(
                                        'Response Date: ${(request['responseDate'] as Timestamp).toDate().toString()}',
                                      ),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: Icon(
                                  request['isClientNotified'] == true
                                      ? Icons.notifications_off
                                      : Icons.notifications_active,
                                  color: request['isClientNotified'] == true
                                      ? Colors.grey
                                      : Colors.green,
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
