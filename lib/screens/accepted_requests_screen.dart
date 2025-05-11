import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bilink/services/notification_service.dart';
import 'package:bilink/widgets/service_request_card.dart';

class AcceptedRequestsScreen extends StatefulWidget {
  const AcceptedRequestsScreen({super.key});

  @override
  State<AcceptedRequestsScreen> createState() => _AcceptedRequestsScreenState();
}

class _AcceptedRequestsScreenState extends State<AcceptedRequestsScreen> {
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  void _checkAuthState() {
    if (_auth.currentUser == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'يجب تسجيل الدخول لعرض الطلبات المقبولة';
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('الطلبات المقبولة'),
          backgroundColor: const Color(0xFF8B5CF6),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text(
            _errorMessage!,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    final providerId = _auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلبات المقبولة'),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<DocumentSnapshot>>(
        stream: _notificationService.getProviderAcceptedRequests(providerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'حدث خطأ: ${snapshot.error}',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            );
          }

          final requests = snapshot.data;

          if (requests == null || requests.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد طلبات مقبولة',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 12, bottom: 80),
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
            ),
          );
        },
      ),
    );
  }
}
