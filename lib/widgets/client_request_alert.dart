import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bilink/services/notification_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class ClientRequestAlert extends StatefulWidget {
  const ClientRequestAlert({super.key});

  @override
  State<ClientRequestAlert> createState() => _ClientRequestAlertState();
}

class _ClientRequestAlertState extends State<ClientRequestAlert> with SingleTickerProviderStateMixin {
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;
  
  bool _isVisible = false;
  Map<String, dynamic>? _latestApprovedRequest;
  StreamSubscription<QuerySnapshot>? _requestSubscription;

  @override
  void initState() {
    super.initState();
    
    // Setup animations
    _animationController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 800),
    );
    
    _slideAnimation = Tween<double>(begin: 100, end: 0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Check for new approved requests when component loads
    _checkForRecentApprovedRequests();
  }

  @override
  void dispose() {
    // Cancel subscription to prevent updates after widget is disposed
    _requestSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkForRecentApprovedRequests() async {
    // Only proceed if user is logged in
    if (_auth.currentUser == null) return;
    
    final userId = _auth.currentUser!.uid;
    
    // Cancel any existing subscription first
    _requestSubscription?.cancel();      // Listen to any client requests that were recently approved
    _requestSubscription = FirebaseFirestore.instance
        .collection('service_requests')
        .where('clientId', isEqualTo: userId)
        .where('status', isEqualTo: 'accepted')
        .where('isClientNotified', isEqualTo: false) // Only show alerts for unnotified requests
        .orderBy('responseDate', descending: true)
        .limit(3) // Increased limit to show more recent requests if there are multiple
        .snapshots()
        .listen((snapshot) {
          // Check if widget is still mounted before proceeding
          if (!mounted) return;
          
          if (snapshot.docs.isEmpty) return;
          
          final latestDoc = snapshot.docs.first;
          final data = latestDoc.data();
          
          // Check if this is a recent approval (last 30 minutes)
          final responseDate = data['responseDate'] as Timestamp?;
          if (responseDate == null) return;
          
          final responseDateTime = responseDate.toDate();
          final now = DateTime.now();
          final difference = now.difference(responseDateTime);
          
          // Only show alert for requests accepted in the last 30 minutes
          if (difference.inMinutes <= 30) {
            // Don't show the same alert multiple times
            if (_latestApprovedRequest != null && 
                _latestApprovedRequest!['id'] == latestDoc.id) {
              return;
            }
            
            // Check if widget is still mounted before updating state
            if (!mounted) return;
            
            // Update state and show alert
            setState(() {
              _latestApprovedRequest = {
                'id': latestDoc.id,
                ...data,
              };
              _isVisible = true;
            });
            
            // Start animation
            _animationController.forward();
            
            // Auto-hide after 6 seconds
            Future.delayed(const Duration(seconds: 6), () {
              if (mounted) {
                _dismissAlert();
              }
            });
          }
        });
  }
    void _dismissAlert() {
    // Mark the request as notified when alert is dismissed
    if (_latestApprovedRequest != null) {
      // Update the service_request document
      FirebaseFirestore.instance
          .collection('service_requests')
          .doc(_latestApprovedRequest!['id'])
          .update({'isClientNotified': true})
          .then((_) {
            print('تم تحديث حالة الإشعار للطلب: ${_latestApprovedRequest!['id']}');
          })
          .catchError((error) {
            print('خطأ في تحديث حالة الإشعار: $error');
          });
    }
    
    _animationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isVisible = false;
        });
      }
    });
  }
    void _viewRequestDetails() {
    // Navigate to the request details or mark as read
    if (_latestApprovedRequest != null) {
      // Mark notification as read in notifications collection
      FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .where('data.requestId', isEqualTo: _latestApprovedRequest!['id'])
          .where('type', isEqualTo: 'request_update')
          .get()
          .then((snapshot) {
            // Check if widget is still mounted before proceeding
            if (!mounted) return;
            
            for (var doc in snapshot.docs) {
              _notificationService.markNotificationAsRead(doc.id);
            }
          });
        // Also mark the request as notified in service_requests collection
      FirebaseFirestore.instance
          .collection('service_requests')
          .doc(_latestApprovedRequest!['id'])
          .update({
            'isClientNotified': true,
            'notifiedAt': FieldValue.serverTimestamp()
          })
          .then((_) {
            print('تم تحديث حالة الإشعار للطلب: ${_latestApprovedRequest!['id']}');
          })
          .catchError((error) {
            print('خطأ في تحديث حالة الإشعار: $error');
          });
      
      // Hide alert after navigating
      _dismissAlert();
      
      // You can add navigation to a details screen here if needed
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible || _latestApprovedRequest == null) {
      return const SizedBox.shrink();
    }
    
    final serviceName = _latestApprovedRequest!['serviceName'] ?? 'خدمة';
    final serviceType = _latestApprovedRequest!['serviceType'] ?? 'تخزين';
    final responseDate = _latestApprovedRequest!['responseDate'] as Timestamp?;
    final formattedDate = responseDate != null 
        ? DateFormat.yMd('ar').add_jm().format(responseDate.toDate())
        : '';
    
    // Count other unread request notifications to show in badge
    final userId = _auth.currentUser?.uid ?? '';
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Positioned(
          top: _slideAnimation.value + 60,
          left: 0,
          right: 0,
          child: Center(
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: Border.all(
                    color: serviceType == 'نقل'
                        ? Colors.orange.withOpacity(0.3)
                        : Colors.green.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _viewRequestDetails,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: serviceType == 'نقل'
                                ? Colors.orange.withOpacity(0.2)
                                : Colors.green.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              serviceType == 'نقل'
                                ? Icons.local_shipping_outlined
                                : Icons.check_circle,
                              color: serviceType == 'نقل'
                                ? Colors.orange.shade700
                                : Colors.green,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'تمت الموافقة على طلبك!',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'تم قبول طلبك للخدمة: $serviceName',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          formattedDate,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    // Count badge for multiple requests
                                    StreamBuilder<QuerySnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('service_requests')
                                          .where('clientId', isEqualTo: userId)
                                          .where('status', isEqualTo: 'accepted')
                                          .where('isClientNotified', isEqualTo: false)
                                          .snapshots(),
                                      builder: (context, snapshot) {
                                        int count = 0;
                                        if (snapshot.hasData) {
                                          count = snapshot.data!.docs.length;
                                        }
                                        
                                        if (count <= 1) {
                                          return const SizedBox.shrink();
                                        }
                                        
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '+${count - 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                            onPressed: _dismissAlert,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
