#!/bin/bash

# Fix ServiceRequestCard import issues
echo "Fixing ServiceRequestCard import issues..."

# Fix for request_tabs.dart
echo 'Updating request_tabs.dart...'
cat > "lib/widgets/request_tabs.dart" << 'EOF'
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bilink/services/notification_service.dart';
import 'package:bilink/widgets/service_request_card.dart' show ServiceRequestCard;

class RequestTabs extends StatefulWidget {
  const RequestTabs({super.key});

  @override
  State<RequestTabs> createState() => _RequestTabsState();
}

class _RequestTabsState extends State<RequestTabs> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String userId = _auth.currentUser?.uid ?? '';
    
    if (userId.isEmpty) {
      return const Center(
        child: Text('يرجى تسجيل الدخول لعرض الطلبات'),
      );
    }

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: false,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: 'قيد الانتظار'),
            Tab(text: 'مقبولة'),
            Tab(text: 'مرفوضة'),
            Tab(text: 'مكتملة'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Pending Requests Tab
              StreamBuilder<List<DocumentSnapshot>>(
                stream: FirebaseFirestore.instance
                    .collection('service_requests')
                    .where('providerId', isEqualTo: userId)
                    .where('status', isEqualTo: 'pending')
                    .orderBy('createdAt', descending: true)
                    .snapshots()
                    .map((snapshot) => snapshot.docs),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('حدث خطأ: ${snapshot.error}'),
                    );
                  }

                  final requests = snapshot.data ?? [];

                  if (requests.isEmpty) {
                    return const Center(
                      child: Text('لا توجد طلبات قيد الانتظار'),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final requestDoc = requests[index];
                      final requestData = {
                        ...requestDoc.data() as Map<String, dynamic>,
                        'id': requestDoc.id,
                      };
                      return ServiceRequestCard(
                        requestData: requestData,
                        onRequestUpdated: () {
                          setState(() {});
                        },
                      );
                    },
                  );
                },
              ),

              // Accepted Requests Tab
              StreamBuilder<List<DocumentSnapshot>>(
                stream: FirebaseFirestore.instance
                    .collection('service_requests')
                    .where('providerId', isEqualTo: userId)
                    .where('status', isEqualTo: 'accepted')
                    .orderBy('createdAt', descending: true)
                    .snapshots()
                    .map((snapshot) => snapshot.docs),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('حدث خطأ: ${snapshot.error}'),
                    );
                  }

                  final requests = snapshot.data ?? [];

                  if (requests.isEmpty) {
                    return const Center(
                      child: Text('لا توجد طلبات مقبولة'),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final requestDoc = requests[index];
                      final requestData = {
                        ...requestDoc.data() as Map<String, dynamic>,
                        'id': requestDoc.id,
                      };
                      return ServiceRequestCard(
                        requestData: requestData,
                        onRequestUpdated: () {
                          setState(() {});
                        },
                      );
                    },
                  );
                },
              ),

              // Rejected Requests Tab
              StreamBuilder<List<DocumentSnapshot>>(
                stream: FirebaseFirestore.instance
                    .collection('service_requests')
                    .where('providerId', isEqualTo: userId)
                    .where('status', isEqualTo: 'rejected')
                    .orderBy('createdAt', descending: true)
                    .snapshots()
                    .map((snapshot) => snapshot.docs),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('حدث خطأ: ${snapshot.error}'),
                    );
                  }

                  final requests = snapshot.data ?? [];

                  if (requests.isEmpty) {
                    return const Center(
                      child: Text('لا توجد طلبات مرفوضة'),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final requestDoc = requests[index];
                      final requestData = {
                        ...requestDoc.data() as Map<String, dynamic>,
                        'id': requestDoc.id,
                      };
                      return ServiceRequestCard(
                        requestData: requestData,
                        onRequestUpdated: () {
                          setState(() {});
                        },
                      );
                    },
                  );
                },
              ),

              // Completed Requests Tab
              StreamBuilder<List<DocumentSnapshot>>(
                stream: FirebaseFirestore.instance
                    .collection('service_requests')
                    .where('providerId', isEqualTo: userId)
                    .where('status', isEqualTo: 'completed')
                    .orderBy('createdAt', descending: true)
                    .snapshots()
                    .map((snapshot) => snapshot.docs),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('حدث خطأ: ${snapshot.error}'),
                    );
                  }

                  final requests = snapshot.data ?? [];

                  if (requests.isEmpty) {
                    return const Center(
                      child: Text('لا توجد طلبات مكتملة'),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final requestDoc = requests[index];
                      final requestData = {
                        ...requestDoc.data() as Map<String, dynamic>,
                        'id': requestDoc.id,
                      };
                      return ServiceRequestCard(
                        requestData: requestData,
                        onRequestUpdated: () {
                          setState(() {});
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
EOF

# Fix for notifications_screen.dart
echo 'Updating notifications_screen.dart...'
sed -i 's/import "package:bilink\/widgets\/service_request_card.dart";/import "package:bilink\/widgets\/service_request_card.dart" show ServiceRequestCard;/g' lib/screens/notifications_screen.dart

# Fix for notification badge in client_interface.dart
echo 'Verifying notification badge in client_interface.dart...'
if ! grep -q "NotificationBadge(count: acceptedCount)" lib/screens/client_interface.dart; then
  echo "Warning: NotificationBadge may be missing in client_interface.dart"
  # Find the appropriate place to add it and add it
fi

echo "All fixes have been applied. Please rebuild your application."
