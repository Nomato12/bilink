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
      
      // Calculate price based on service type - with better type handling
      double totalPrice = 0.0;
      String durationType = '';
      
      // First try to get price from request document
      dynamic requestPrice = requestData['price'];
      if (requestPrice != null) {
        if (requestPrice is num) {
          totalPrice = requestPrice.toDouble();
        } else if (requestPrice is String) {
          try {
            totalPrice = double.parse(requestPrice);
            
            // Also update the price in the request document to be numeric
            try {
              await _firestore.collection(requestDoc.reference.parent.id).doc(requestId).update({
                'price': totalPrice
              });
              print('Updated price format in request to numeric: $totalPrice');
            } catch (e) {
              print('Error updating price format in request: $e');
            }
          } catch (e) {
            print('Invalid price format in request: $requestPrice');
          }
        }
      }
      
      // If still no valid price and it's a storage service, try to get from service
      if (totalPrice <= 0 && serviceType == 'تخزين') {
        dynamic servicePrice = serviceData['price'];
        if (servicePrice != null) {
          if (servicePrice is num) {
            totalPrice = servicePrice.toDouble();
          } else if (servicePrice is String) {
            try {
              totalPrice = double.parse(servicePrice);
            } catch (e) {
              print('Invalid price format in service: $servicePrice');
            }
          }
        }
        
        // Update price in request if we found a valid one
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
        
        // Get duration type for storage
        if (serviceType == 'تخزين') {
          String? rawDurationType = serviceData['storageDurationType'] ?? requestData['durationType'];
          if (rawDurationType == 'يومي' || rawDurationType == 'شهري' || rawDurationType == 'سنوي') {
            durationType = rawDurationType ?? 'شهري';
          } else {
            durationType = 'شهري';
          }
        } else {
          durationType = '';
        }
      }
      
      // For transport services, ensure we have a defined price
      if (serviceType == 'نقل' && totalPrice <= 0) {
        // Try to estimate price based on distance if available
        if (requestData['distanceText'] != null) {
          String distanceText = requestData['distanceText'];
          // Extract numeric value from something like "15.2 كم"
          RegExp regex = RegExp(r'(\d+(\.\d+)?)');
          var match = regex.firstMatch(distanceText);
          if (match != null) {
            double distance = double.parse(match.group(1)!);
            // Estimate 50 per kilometer as base rate
            totalPrice = distance * 50; 
            print('Estimated price from distance ($distance km): $totalPrice');
          }
        }
        // If we still don't have a price, use a default value
        if (totalPrice <= 0) {
          totalPrice = 500.0; // default value for transport
          print('Using default price for transport: $totalPrice');
        }
        
        // Update the price in the request document
        try {
          await _firestore.collection(requestDoc.reference.parent.id).doc(requestId).update({
            'price': totalPrice
          });
          print('Updated transport request price to: $totalPrice');
        } catch (e) {
          print('Error updating transport request price: $e');
        }
      }
      
      // If we still don't have a price, use a default value
      if (totalPrice <= 0) {
        totalPrice = serviceType == 'نقل' ? 500.0 : 300.0;
        print('Using default price for $serviceType service: $totalPrice');
        
        // Update the price in the request
        try {
          await _firestore.collection(requestDoc.reference.parent.id).doc(requestId).update({
            'price': totalPrice
          });
          print('Updated request with default price: $totalPrice');
        } catch (e) {
          print('Error updating default price: $e');
        }
      }
      
      // Check if statistics already exist for this request
      final existingStatDoc = await _firestore.collection('provider_statistics').doc(requestId).get();
      
      // Create or update statistics entry
      final statistic = ProviderStatistics(
        id: requestId,
        date: (requestData['completedAt'] ?? requestData['responseDate'] ?? 
               requestData['updatedAt'] ?? requestData['createdAt'] ?? 
               Timestamp.now()).toDate(),
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
      
      if (existingStatDoc.exists) {
        // Update existing record
        await docRef.update({
          'status': status,
          'amount': totalPrice, // Ensure price is updated
          'providerAmount': totalPrice * 0.8, // Update provider amount
          'appFee': totalPrice * 0.2, // Update app fee
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('Updated statistics for request $requestId with price $totalPrice');
      } else {
        // Create new record
        final data = statistic.toMap();
        data['providerId'] = _providerId;
        data['amount'] = totalPrice; // Ensure price is in amount field
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
    
    // Asegurar que todos los valores sean numéricos y estén definidos
    double totalEarnings = statsManager.getTotalEarnings();
    int totalRequests = statsManager.getTotalRequests();
    int completedRequests = statsManager.getCompletedRequests();
    double transportEarnings = statsManager.getTransportEarnings();
    double storageEarnings = statsManager.getStorageEarnings();
    Map<String, double> serviceTypeStats = statsManager.getStatsByServiceType();
    Map<String, double> storageDurationStats = statsManager.getStatsByStorageDurationType();
    
    // Verificar que todas las claves necesarias existan en serviceTypeStats
    if (!serviceTypeStats.containsKey('نقل')) {
      serviceTypeStats['نقل'] = 0.0;
    }
    if (!serviceTypeStats.containsKey('تخزين')) {
      serviceTypeStats['تخزين'] = 0.0;
    }
    
    // Verificar que todas las claves necesarias existan en storageDurationStats
    if (!storageDurationStats.containsKey('يومي')) {
      storageDurationStats['يومي'] = 0.0;
    }
    if (!storageDurationStats.containsKey('شهري')) {
      storageDurationStats['شهري'] = 0.0;
    }
    if (!storageDurationStats.containsKey('سنوي')) {
      storageDurationStats['سنوي'] = 0.0;
    }
    
    print('Summary - Total Earnings: $totalEarnings, Total Requests: $totalRequests, Completed: $completedRequests');
    print('Transport Earnings: $transportEarnings, Storage Earnings: $storageEarnings');
    
    return {
      'totalEarnings': totalEarnings,
      'totalRequests': totalRequests,
      'completedRequests': completedRequests,
      'transportEarnings': transportEarnings,
      'storageEarnings': storageEarnings,
      'serviceTypeStats': serviceTypeStats,
      'storageDurationStats': storageDurationStats,
    };
  }
}
