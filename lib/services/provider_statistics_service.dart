// Service to handle provider statistics
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bilink/models/provider_statistics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ProviderStatisticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Get current provider ID
  String? get _providerId => _auth.currentUser?.uid;
  
  // Register earnings when a service request is accepted or completed
  Future<bool> registerServiceEarnings(String requestId, String status) async {
    if (_providerId == null) return false;
    
    try {
      // First check if the request exists
      DocumentSnapshot? requestDoc;
      
      // Try looking in both collections (for compatibility)
      requestDoc = await _firestore.collection('serviceRequests').doc(requestId).get();
      if (!requestDoc.exists) {
        requestDoc = await _firestore.collection('service_requests').doc(requestId).get();
      }
      
      // If request still not found, return
      if (requestDoc == null || !requestDoc.exists) {
        print('Request $requestId not found in any collection');
        return false;
      }
      
      // Only process requests that are accepted or completed
      if (status != 'accepted' && status != 'completed') {
        print('Request status $status is not applicable for earnings calculation');
        return false;
      }
      
      // Process the request data
      final requestData = requestDoc.data() as Map<String, dynamic>?;
      if (requestData == null) return false;
      
      // Check if this provider is the owner of the service
      final String serviceProviderId = requestData['providerId'] ?? '';
      if (serviceProviderId != _providerId) {
        print('This request does not belong to the current provider');
        return false;
      }
      
      // Get service ID
      final String serviceId = requestData['serviceId'] ?? '';
      if (serviceId.isEmpty) {
        print('Service ID is empty in request $requestId');
        return false;
      }
      
      // Get service details
      DocumentSnapshot serviceDoc = await _firestore.collection('services').doc(serviceId).get();
      if (!serviceDoc.exists) {
        print('Service $serviceId not found');
        return false;
      }
      
      final serviceData = serviceDoc.data() as Map<String, dynamic>?;
      if (serviceData == null) return false;
      
      final String serviceType = serviceData['type'] ?? requestData['serviceType'] ?? 'تخزين';
      final String serviceName = serviceData['title'] ?? requestData['serviceName'] ?? 'خدمة';
        // Calculate price based on service type
      double totalPrice = 0.0;
      String durationType = '';
      
      if (serviceType == 'نقل') {
        // For transport service, get price from request
        totalPrice = (requestData['price'] != null) 
            ? (requestData['price'] is num ? (requestData['price'] as num).toDouble() : 0.0) 
            : 0.0;
      } else if (serviceType == 'تخزين') {
        // For storage service, first try to get price from request
        totalPrice = (requestData['price'] != null) 
            ? (requestData['price'] is num ? (requestData['price'] as num).toDouble() : 0.0) 
            : 0.0;
            
        // If price is not in request, get it from service data
        if (totalPrice <= 0) {
          totalPrice = (serviceData['price'] != null) 
              ? (serviceData['price'] is num ? (serviceData['price'] as num).toDouble() : 0.0) 
              : 0.0;
          
          // Add price to request document for future reference
          if (totalPrice > 0) {
            try {
              await _firestore.collection(requestDoc.reference.parent.id).doc(requestId).update({
                'price': totalPrice
              });
              print('Updated price in request document: $totalPrice');
            } catch (e) {
              print('Error updating price in request: $e');
            }
          }
        }
        
        // Get storage duration type (daily, monthly, yearly)
        durationType = serviceData['storageDurationType'] ?? requestData['durationType'] ?? 'شهري';
      }
      
      // Last resort: try to get price directly from the request
      if (totalPrice <= 0) {
        totalPrice = (requestData['price'] != null) 
            ? (requestData['price'] is num ? (requestData['price'] as num).toDouble() : 0.0) 
            : 0.0;
      }
      
      if (totalPrice <= 0) {
        print('Could not determine price for request $requestId with service type $serviceType');
        
        // For debugging:
        print('Request data: ${requestData.toString()}');
        print('Service data: ${serviceData.toString()}');
        return false;
      }
      
      // Create statistics entry
      final statistic = ProviderStatistics(
        id: requestId,
        date: (requestData['completedAt'] ?? requestData['responseDate'] ?? requestData['updatedAt'] ?? requestData['createdAt'] ?? Timestamp.now()).toDate(),
        requestId: requestId,
        serviceId: serviceId, 
        serviceName: serviceName,
        serviceType: serviceType,
        totalAmount: totalPrice,
        status: status,
        durationType: durationType,
      );
      
      // Save to database
      final docRef = _firestore.collection('provider_statistics').doc(requestId);
      
      // Check if this request already has statistics recorded
      final existingDoc = await docRef.get();
      if (existingDoc.exists) {
        // Update existing record
        await docRef.update({
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('Updated statistics for request $requestId');
      } else {
        // Create new record
        final data = statistic.toMap();
        data['providerId'] = _providerId;
        data['createdAt'] = FieldValue.serverTimestamp();
        data['updatedAt'] = FieldValue.serverTimestamp();
        
        await docRef.set(data);
        print('Created new statistics entry for request $requestId with amount $totalPrice');
      }
      
      // Clear cache to ensure fresh data on next load
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('provider_statistics_${_providerId}');
      await prefs.remove('provider_statistics_updated_${_providerId}');
      
      return true;
    } catch (e) {
      print('Error registering earnings for request $requestId: $e');
      return false;
    }
  }
  
  // Get all statistics for the current provider
  Future<List<ProviderStatistics>> getProviderStatistics() async {
    if (_providerId == null) return [];
    
    try {
      // Load from cache first for better performance
      final cachedStats = await _loadFromCache();
      if (cachedStats.isNotEmpty) {
        return cachedStats;
      }
      
      // First check the provider_statistics collection directly
      final snapshot = await _firestore
          .collection('provider_statistics')
          .where('providerId', isEqualTo: _providerId)
          .get();
          
      if (snapshot.docs.isNotEmpty) {
        final stats = snapshot.docs
            .map((doc) => ProviderStatistics.fromMap(doc.data(), doc.id))
            .toList();
            
        // Cache the results
        await _saveToCache(stats);
        return stats;
      }
      
      // If no direct statistics found, calculate them from service requests
      return await _calculateStatisticsFromRequests();
    } catch (e) {
      print('Error getting provider statistics: $e');
      return [];
    }
  }
  
  // Calculate statistics from service requests
  Future<List<ProviderStatistics>> _calculateStatisticsFromRequests() async {
    if (_providerId == null) return [];
    
    try {
      // Get completed service requests for this provider
      final requestsSnapshot = await _firestore
          .collection('service_requests')
          .where('providerId', isEqualTo: _providerId)
          .get();
          
      final List<ProviderStatistics> statistics = [];
      
      for (var doc in requestsSnapshot.docs) {
        final data = doc.data();
        
        // Only include accepted or completed requests
        if (data['status'] == 'accepted' || data['status'] == 'completed') {
          // Get service details to include service name and type
          String? serviceId = data['serviceId'];
          Map<String, dynamic> serviceData = {};
          
          if (serviceId != null) {
            final serviceDoc = await _firestore
                .collection('services')
                .doc(serviceId)
                .get();
                
            if (serviceDoc.exists) {
              serviceData = serviceDoc.data() ?? {};
            }
          }
          
          // Create a statistics entry
          statistics.add(ProviderStatistics(
            id: doc.id,
            date: (data['completedAt'] ?? data['createdAt'] ?? Timestamp.now()).toDate(),
            requestId: doc.id,
            serviceId: serviceId ?? '',
            serviceName: serviceData['title'] ?? data['serviceName'] ?? 'خدمة',
            serviceType: serviceData['type'] ?? data['serviceType'] ?? 'تخزين',
            totalAmount: (data['price'] ?? 0).toDouble(),
            status: data['status'] ?? 'completed',
            durationType: serviceData['storageDurationType'] ?? data['durationType'] ?? '',
          ));
        }
      }
      
      // Save these calculated statistics
      await _saveStatistics(statistics);
      
      // Cache the results
      await _saveToCache(statistics);
      
      return statistics;
    } catch (e) {
      print('Error calculating statistics from requests: $e');
      return [];
    }
  }
  
  // Save statistics to Firestore
  Future<void> _saveStatistics(List<ProviderStatistics> statistics) async {
    if (_providerId == null || statistics.isEmpty) return;
    
    final batch = _firestore.batch();
    
    for (var stat in statistics) {
      final docRef = _firestore.collection('provider_statistics').doc();
      final data = stat.toMap();
      data['providerId'] = _providerId;
      batch.set(docRef, data);
    }
    
    await batch.commit();
  }
  
  // Cache statistics locally
  Future<void> _saveToCache(List<ProviderStatistics> statistics) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> jsonList = 
          statistics.map((stat) => {
            ...stat.toMap(),
            'id': stat.id,
            'date': stat.date.toIso8601String(),
          }).toList();
          
      await prefs.setString('provider_statistics_${_providerId}', jsonEncode(jsonList));
      await prefs.setString('provider_statistics_updated_${_providerId}', DateTime.now().toIso8601String());
    } catch (e) {
      print('Error caching statistics: $e');
    }
  }
  
  // Load statistics from cache
  Future<List<ProviderStatistics>> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonData = prefs.getString('provider_statistics_${_providerId}');
      final String? lastUpdated = prefs.getString('provider_statistics_updated_${_providerId}');
      
      // If cache is more than 60 minutes old, don't use it
      if (lastUpdated != null) {
        final lastUpdateTime = DateTime.parse(lastUpdated);
        if (DateTime.now().difference(lastUpdateTime).inMinutes > 60) {
          return [];
        }
      }
      
      if (jsonData == null) return [];
      
      final List<dynamic> jsonList = jsonDecode(jsonData);
      return jsonList.map((json) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(json);
        // Convert the date string back to DateTime
        map['date'] = DateTime.parse(map['date']);
        return ProviderStatistics.fromMap(map, map['id']);
      }).toList();
    } catch (e) {
      print('Error loading statistics from cache: $e');
      return [];
    }
  }
  
  // Get daily statistics for current month
  Future<Map<DateTime, double>> getDailyStatsForCurrentMonth() async {
    final statistics = await getProviderStatistics();
    final now = DateTime.now();
    final Map<DateTime, double> result = {};
    
    for (var stat in statistics) {
      if (stat.date.year == now.year && stat.date.month == now.month) {
        final day = DateTime(now.year, now.month, stat.date.day);
        result[day] = (result[day] ?? 0) + stat.providerAmount;
      }
    }
    
    return result;
  }
  
  // Get monthly statistics for current year
  Future<Map<int, double>> getMonthlyStatsForCurrentYear() async {
    final statistics = await getProviderStatistics();
    final now = DateTime.now();
    final Map<int, double> result = {};
    
    for (var stat in statistics) {
      if (stat.date.year == now.year) {
        result[stat.date.month] = (result[stat.date.month] ?? 0) + stat.providerAmount;
      }
    }
    
    return result;
  }
  
  // Get total statistics summary
  Future<Map<String, dynamic>> getStatisticsSummary() async {
    final statistics = await getProviderStatistics();
    final statsManager = ProviderStatisticsManager(statistics);
    
    return {
      'totalEarnings': statsManager.getTotalEarnings(),
      'totalRequests': statsManager.getTotalRequests(),
      'completedRequests': statsManager.getCompletedRequests(),
      'transportEarnings': statsManager.getTransportEarnings(),
      'storageEarnings': statsManager.getStorageEarnings(),
      'serviceTypeStats': statsManager.getStatsByServiceType(),
      'storageDurationStats': statsManager.getStatsByStorageDurationType(),
    };
  }
}
