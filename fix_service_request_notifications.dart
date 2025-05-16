import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bilink/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const NotificationFixApp());
}

class NotificationFixApp extends StatelessWidget {
  const NotificationFixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fix Service Request Notifications',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const ServiceRequestFixScreen(),
    );
  }
}

class ServiceRequestFixScreen extends StatefulWidget {
  const ServiceRequestFixScreen({super.key});

  @override
  State<ServiceRequestFixScreen> createState() => _ServiceRequestFixScreenState();
}

class _ServiceRequestFixScreenState extends State<ServiceRequestFixScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  List<Map<String, dynamic>> _requestsToFix = [];
  String _statusMessage = "";
  String _logMessage = "";
  int _totalRequests = 0;
  int _fixedRequests = 0;
  
  @override
  void initState() {
    super.initState();
    _checkServiceRequests();
  }
  
  void _logStatus(String message) {
    setState(() {
      _logMessage = "$_logMessage\n$message";
    });
    print(message);
  }
  
  Future<void> _checkServiceRequests() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _statusMessage = "فحص طلبات الخدمة...";
      _requestsToFix = [];
      _totalRequests = 0;
      _fixedRequests = 0;
      _logMessage = "";
    });
    
    try {
      // Get current user ID
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        _logStatus("⚠️ لم يتم تسجيل الدخول. يرجى تسجيل الدخول أولاً.");
        setState(() {
          _statusMessage = "لم يتم تسجيل الدخول";
          _isLoading = false;
        });
        return;
      }
      
      _logStatus("📊 فحص طلبات الخدمة للمستخدم: $userId");
      
      // Check for accepted requests
      final snapshot = await _firestore
          .collection('service_requests')
          .where('status', isEqualTo: 'accepted')
          .get();
      
      _logStatus("🔍 تم العثور على ${snapshot.docs.length} طلب مقبول");
      _totalRequests = snapshot.docs.length;
      
      if (snapshot.docs.isEmpty) {
        _logStatus("ℹ️ لا توجد طلبات مقبولة للتحقق منها");
        setState(() {
          _statusMessage = "لا توجد طلبات للإصلاح";
          _isLoading = false;
        });
        return;
      }
      
      // Check each request for missing fields
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final Map<String, dynamic> issueDetails = {};
        
        // Check for clientId
        final clientId = data['clientId'] as String?;
        if (clientId == null || clientId.isEmpty) {
          issueDetails['clientId'] = 'مفقود';
        }
        
        // Check for isClientNotified field
        if (!data.containsKey('isClientNotified')) {
          issueDetails['isClientNotified'] = 'مفقود (يجب إضافته)';
        } else if (data['isClientNotified'] == null) {
          issueDetails['isClientNotified'] = 'قيمة فارغة (يجب تعيينها إلى false)';
        }
        
        // Check for responseDate field
        if (!data.containsKey('responseDate')) {
          issueDetails['responseDate'] = 'مفقود (يجب إضافته)';
        } else if (data['responseDate'] == null) {
          issueDetails['responseDate'] = 'قيمة فارغة (يجب تعيينها إلى الوقت الحالي)';
        }
        
        // If there are issues, add to the list
        if (issueDetails.isNotEmpty) {
          _requestsToFix.add({
            'id': doc.id,
            'data': data,
            'issues': issueDetails,
          });
        }
      }
      
      _logStatus("🔧 تم العثور على ${_requestsToFix.length} طلب بحاجة للإصلاح");
      
      setState(() {
        _statusMessage = "تم العثور على ${_requestsToFix.length} طلب بحاجة للإصلاح";
        _isLoading = false;
      });
      
    } catch (e) {
      _logStatus("❌ خطأ أثناء فحص الطلبات: $e");
      setState(() {
        _statusMessage = "خطأ: $e";
        _isLoading = false;
      });
    }
  }
  
  Future<void> _fixServiceRequests() async {
    if (_isLoading || _requestsToFix.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _statusMessage = "جاري إصلاح الطلبات...";
      _fixedRequests = 0;
    });
    
    try {
      final batch = _firestore.batch();
      
      for (final request in _requestsToFix) {
        final docRef = _firestore.collection('service_requests').doc(request['id']);
        final issues = request['issues'] as Map<String, dynamic>;
        final updates = <String, dynamic>{};
        
        // Fix isClientNotified field
        if (issues.containsKey('isClientNotified')) {
          updates['isClientNotified'] = false;
          _logStatus("✓ تعيين isClientNotified = false للطلب ${request['id']}");
        }
        
        // Fix responseDate field
        if (issues.containsKey('responseDate')) {
          updates['responseDate'] = FieldValue.serverTimestamp();
          _logStatus("✓ تعيين responseDate للطلب ${request['id']}");
        }
        
        // Add updates to batch
        if (updates.isNotEmpty) {
          batch.update(docRef, updates);
          _fixedRequests++;
        }
      }
      
      // Commit all updates
      await batch.commit();
      
      _logStatus("✅ تم إصلاح $_fixedRequests طلب بنجاح");
      setState(() {
        _statusMessage = "تم إصلاح $_fixedRequests طلب بنجاح";
        _isLoading = false;
        _requestsToFix = []; // Clear the list after fixing
      });
      
      // Refresh the list
      await _checkServiceRequests();
      
    } catch (e) {
      _logStatus("❌ خطأ أثناء إصلاح الطلبات: $e");
      setState(() {
        _statusMessage = "خطأ أثناء الإصلاح: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إصلاح إشعارات طلبات الخدمة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _checkServiceRequests,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'حالة الإصلاح',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Divider(),
                      Text('إجمالي الطلبات المقبولة: $_totalRequests'),
                      Text('طلبات تحتاج للإصلاح: ${_requestsToFix.length}'),
                      Text('تم إصلاح: $_fixedRequests'),
                      const SizedBox(height: 8),
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _statusMessage.contains('خطأ')
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Fix Button
              if (_requestsToFix.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _fixServiceRequests,
                  icon: const Icon(Icons.build),
                  label: Text('إصلاح ${_requestsToFix.length} طلب'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Requests To Fix List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _requestsToFix.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 64,
                                  color: Colors.green,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _totalRequests > 0
                                      ? 'جميع الطلبات سليمة!'
                                      : 'لا توجد طلبات للتحقق منها',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _requestsToFix.length,
                            itemBuilder: (context, index) {
                              final request = _requestsToFix[index];
                              final issues = request['issues'] as Map<String, dynamic>;
                              final data = request['data'] as Map<String, dynamic>;
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ExpansionTile(
                                  title: Text('طلب رقم: ${request['id']}'),
                                  subtitle: Text(
                                    'عدد المشاكل: ${issues.length}',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('تفاصيل الطلب:'),
                                          Text('الخدمة: ${data['serviceName'] ?? 'غير معروف'}'),
                                          Text('العميل: ${data['clientName'] ?? 'غير معروف'}'),
                                          Text('الحالة: ${data['status'] ?? 'غير معروف'}'),
                                          const Divider(),
                                          Text(
                                            'المشاكل التي تحتاج للإصلاح:',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          ...issues.entries.map((entry) => Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              '• ${entry.key}: ${entry.value}',
                                              style: TextStyle(color: Colors.red[700]),
                                            ),
                                          )),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
              
              // Log Output
              if (_logMessage.isNotEmpty)
                Card(
                  margin: const EdgeInsets.only(top: 16),
                  color: Colors.grey[100],
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'سجل العمليات:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 150,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              _logMessage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
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
    );
  }
}
