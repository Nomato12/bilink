import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:bilink/services/notification_service.dart';
import 'package:bilink/services/auth_service.dart';
import 'package:bilink/widgets/service_request_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late NotificationService _notificationService;
  late String _userId;
  late TabController _tabController;
  final bool _isLoading = true;
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService();
    final authService = Provider.of<AuthService>(context, listen: false);
    _userId = authService.currentUser?.uid ?? '';
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _activeTabIndex = _tabController.index;
        });
      }
    });
    
    if (_userId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
      });
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF0B3D91),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          tabs: const [
            Tab(text: 'الإشعارات'),
            Tab(text: 'طلبات الخدمة'),
          ],
        ),
      ),
      body: _userId.isEmpty
          ? const Center(child: Text('يرجى تسجيل الدخول لعرض الإشعارات'))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildNotificationsTab(),
                _buildServiceRequestsTab(),
              ],
            ),
    );
  }
  
  Widget _buildNotificationsTab() {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _notificationService.getUserNotifications(_userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
              child: Text('حدث خطأ: ${snapshot.error}'));
        }

        final notifications = snapshot.data ?? [];

        if (notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد إشعارات',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        // Mark notifications as read when viewed
        for (var notification in notifications) {
          if (notification.get('read') == false) {
            _notificationService.markNotificationAsRead(notification.id);
          }
        }

        return ListView.builder(
          itemCount: notifications.length,
          padding: const EdgeInsets.all(8),
          itemBuilder: (context, index) {
            final notification = notifications[index];
            final data = notification.data() as Map<String, dynamic>;
            final type = data['type'] as String;
            final title = data['title'] as String;
            final body = data['body'] as String;
            final isRead = data['read'] as bool;
            final createdAt = data['createdAt'] as Timestamp?;
            
            final timestamp = createdAt != null 
                ? DateFormat('yyyy/MM/dd hh:mm a').format(createdAt.toDate())
                : '';
                
            // Determine icon based on notification type
            IconData notificationIcon;
            Color iconColor;
            
            if (type == 'service_request') {
              notificationIcon = Icons.assignment;
              iconColor = Colors.orange;
            } else if (type == 'request_update' && data['data']['status'] == 'accepted') {
              notificationIcon = Icons.check_circle;
              iconColor = Colors.green;
            } else if (type == 'request_update' && data['data']['status'] == 'rejected') {
              notificationIcon = Icons.cancel;
              iconColor = Colors.red;
            } else {
              notificationIcon = Icons.notifications;
              iconColor = Colors.blue;
            }

            return Card(
              margin: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              elevation: isRead ? 1 : 3,
              color: isRead ? Colors.white : const Color(0xFFF5F8FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isRead ? Colors.grey[300]! : const Color(0xFF0B3D91).withOpacity(0.3),
                  width: isRead ? 1 : 2,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: iconColor.withOpacity(0.2),
                  child: Icon(
                    notificationIcon,
                    color: iconColor,
                  ),
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(body),
                    const SizedBox(height: 4),
                    Text(
                      timestamp,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  // If this is a service request notification, switch to the requests tab
                  if (type == 'service_request') {
                    _tabController.animateTo(1);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildServiceRequestsTab() {
    final authService = Provider.of<AuthService>(context);
    final isProvider = authService.currentUser?.role == 'provider';
    
    if (!isProvider) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'هذه الميزة متاحة فقط لمزودي الخدمات',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _notificationService.getProviderPendingRequests(_userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
              child: Text('حدث خطأ: ${snapshot.error}'));
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد طلبات خدمة حالياً',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: requests.length,
          padding: const EdgeInsets.all(8),
          itemBuilder: (context, index) {
            final request = requests[index];
            final requestData = request.data() as Map<String, dynamic>;
            requestData['id'] = request.id; // Add document ID for reference
            
            return ServiceRequestCard(
              requestData: requestData,
              onRequestUpdated: () {
                // Refresh the tab when a request is updated
                setState(() {});
              },
            );
          },
        );
      },
    );
  }
}
