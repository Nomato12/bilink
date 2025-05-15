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
    _requestSubscription?.cancel();
    
    // Listen to any client requests that were recently approved
    _requestSubscription = FirebaseFirestore.instance
        .collection('service_requests')
        .where('clientId', isEqualTo: userId)
        .where('status', isEqualTo: 'accepted')
        .orderBy('responseDate', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
          // Check if widget is still mounted before proceeding
          if (!mounted) return;
          
          if (snapshot.docs.isEmpty) return;
          
          final latestDoc = snapshot.docs.first;
          final data = latestDoc.data();
          
          // Check if this is a recent approval (last 10 minutes)
          final responseDate = data['responseDate'] as Timestamp?;
          if (responseDate == null) return;
          
          final responseDateTime = responseDate.toDate();
          final now = DateTime.now();
          final difference = now.difference(responseDateTime);
          
          // Only show alert for requests accepted in the last 10 minutes
          if (difference.inMinutes <= 10) {
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
      // Mark notification as read
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
    final responseDate = _latestApprovedRequest!['responseDate'] as Timestamp?;
    final formattedDate = responseDate != null 
        ? DateFormat.yMd('ar').add_jm().format(responseDate.toDate())
        : '';
        
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
                              color: Colors.green.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              color: Colors.green,
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
