import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bilink/services/notification_service.dart';
import 'package:bilink/widgets/service_request_card.dart' show ServiceRequestCard;
import 'package:bilink/widgets/transport_request_card.dart' show TransportRequestCard;

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
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String providerId = _auth.currentUser?.uid ?? '';
    if (providerId.isEmpty) {
      return const Center(
        child: Text(
          'يرجى تسجيل الدخول لعرض الطلبات',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return Column(
      children: [
        // Tab Bar
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFF8B5CF6),
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              color: const Color(0xFF8B5CF6),
            ),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'قيد الانتظار',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              Tab(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'المقبولة',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Pending Requests Tab
              StreamBuilder<List<DocumentSnapshot>>(
                stream: _notificationService.getProviderPendingRequests(providerId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'حدث خطأ: ${snapshot.error}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  }                  final requests = snapshot.data;
                  if (requests == null || requests.isEmpty) {
                    return _buildEmptyState('لا توجد طلبات قيد الانتظار', Icons.hourglass_empty);
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() {});
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final requestDoc = requests[index];
                        final requestData = {
                          ...requestDoc.data() as Map<String, dynamic>,
                          'id': requestDoc.id,
                        };
                        
                        // Use TransportRequestCard for transport service requests
                        final String serviceType = requestData['serviceType'] ?? '';
                        if (serviceType == 'نقل') {
                          return TransportRequestCard(
                            requestData: requestData,
                            onRequestUpdated: () {
                              setState(() {});
                            },
                          );
                        }
                        
                        // Use regular ServiceRequestCard for all other request types
                        return ServiceRequestCard(
                          requestData: requestData,
                          onRequestUpdated: () {
                            setState(() {});
                          },
                        );
                      },
                    ),
                  );
                },
              ),

              // Accepted Requests Tab
              StreamBuilder<List<DocumentSnapshot>>(
                stream: _notificationService.getProviderAcceptedRequests(providerId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'حدث خطأ: ${snapshot.error}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  }                  final requests = snapshot.data;
                  if (requests == null || requests.isEmpty) {
                    return _buildEmptyState('لا توجد طلبات مقبولة', Icons.check_circle_outline);
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() {});
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final requestDoc = requests[index];
                        final requestData = {
                          ...requestDoc.data() as Map<String, dynamic>,
                          'id': requestDoc.id,
                        };
                        
                        // Use TransportRequestCard for transport service requests
                        final String serviceType = requestData['serviceType'] ?? '';
                        if (serviceType == 'نقل') {
                          return TransportRequestCard(
                            requestData: requestData,
                            onRequestUpdated: () {
                              setState(() {});
                            },
                          );
                        }
                        
                        // Use regular ServiceRequestCard for all other request types
                        return ServiceRequestCard(
                          requestData: requestData,
                          onRequestUpdated: () {
                            setState(() {});
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
