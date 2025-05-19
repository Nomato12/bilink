// Script for debugging provider statistics issues
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:bilink/services/provider_statistics_service.dart';
import 'package:bilink/firebase_options.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('Starting provider statistics debugging script...');
  
  // Test both transport and storage requests
  await debugStorageRequestStatistics();
  await debugTransportRequestStatistics();
  
  print('Debugging complete!');
}

Future<void> debugStorageRequestStatistics() async {
  print('\n========== DEBUG STORAGE REQUEST STATISTICS ==========');
  
  // 1. Find a recent storage service request
  print('Searching for a recent storage service request...');
  final storageRequests = await FirebaseFirestore.instance
      .collection('service_requests')
      .where('serviceType', isEqualTo: 'تخزين')
      .orderBy('createdAt', descending: true)
      .limit(5)
      .get();
  
  if (storageRequests.docs.isEmpty) {
    print('No storage service requests found!');
    return;
  }
  
  print('Found ${storageRequests.docs.length} storage requests.');
  
  for (final requestDoc in storageRequests.docs) {
    final requestId = requestDoc.id;
    final requestData = requestDoc.data();
    
    print('\nAnalyzing storage request: $requestId');
    print('Status: ${requestData['status']}');
    print('Price in request: ${requestData['price']}');
    
    // Get the associated service
    final String serviceId = requestData['serviceId'] ?? '';
    if (serviceId.isEmpty) {
      print('⚠️ Service ID is missing!');
      continue;
    }
    
    final serviceDoc = await FirebaseFirestore.instance
        .collection('services')
        .doc(serviceId)
        .get();
    
    if (!serviceDoc.exists) {
      print('⚠️ Service document not found!');
      continue;
    }
    
    final serviceData = serviceDoc.data() as Map<String, dynamic>;
    print('Service price: ${serviceData['price']}');
    print('Service duration type: ${serviceData['storageDurationType']}');
    
    // Test updating statistics
    final providerStatisticsService = ProviderStatisticsService();
    final bool statsUpdated = await providerStatisticsService.registerServiceEarnings(
      requestId,
      requestData['status'] ?? 'completed', // Use existing status or completed
    );
    
    print('Statistics update result: ${statsUpdated ? '✓ SUCCESS' : '❌ FAILED'}');
    
    // Check if statistics record exists
    final statsDoc = await FirebaseFirestore.instance
        .collection('provider_statistics')
        .doc(requestId)
        .get();
    
    if (statsDoc.exists) {
      final statsData = statsDoc.data() as Map<String, dynamic>;
      print('Statistics record exists: ✓');
      print('  Total amount: ${statsData['totalAmount']}');
      print('  Provider amount: ${statsData['providerAmount']}');
      print('  App fee: ${statsData['appFee']}');
    } else {
      print('Statistics record does not exist: ❌');
    }
  }
}

Future<void> debugTransportRequestStatistics() async {
  print('\n========== DEBUG TRANSPORT REQUEST STATISTICS ==========');
  
  // 1. Find a recent transport service request
  print('Searching for a recent transport service request...');
  final transportRequests = await FirebaseFirestore.instance
      .collection('service_requests')
      .where('serviceType', isEqualTo: 'نقل')
      .orderBy('createdAt', descending: true)
      .limit(5)
      .get();
  
  if (transportRequests.docs.isEmpty) {
    print('No transport service requests found!');
    return;
  }
  
  print('Found ${transportRequests.docs.length} transport requests.');
  
  for (final requestDoc in transportRequests.docs) {
    final requestId = requestDoc.id;
    final requestData = requestDoc.data();
    
    print('\nAnalyzing transport request: $requestId');
    print('Status: ${requestData['status']}');
    print('Price in request: ${requestData['price']}');
    
    // Test updating statistics
    final providerStatisticsService = ProviderStatisticsService();
    final bool statsUpdated = await providerStatisticsService.registerServiceEarnings(
      requestId,
      requestData['status'] ?? 'completed', // Use existing status or completed
    );
    
    print('Statistics update result: ${statsUpdated ? '✓ SUCCESS' : '❌ FAILED'}');
    
    // Check if statistics record exists
    final statsDoc = await FirebaseFirestore.instance
        .collection('provider_statistics')
        .doc(requestId)
        .get();
    
    if (statsDoc.exists) {
      final statsData = statsDoc.data() as Map<String, dynamic>;
      print('Statistics record exists: ✓');
      print('  Total amount: ${statsData['totalAmount']}');
      print('  Provider amount: ${statsData['providerAmount']}');
      print('  App fee: ${statsData['appFee']}');
    } else {
      print('Statistics record does not exist: ❌');
    }
  }
}
