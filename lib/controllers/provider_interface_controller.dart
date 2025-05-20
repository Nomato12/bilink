import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

/// A controller class to manage the provider interface state and service operations
class ProviderInterfaceController extends ChangeNotifier {
  final AuthService authService;
  bool isLoading = false;
  List<Map<String, dynamic>> servicesList = [];
  int totalServices = 0;
  int totalRequests = 0;
  double totalEarnings = 0;
  double averageRating = 0;
  
  ProviderInterfaceController({required this.authService}) {
    loadProviderServices();
    loadStatistics();
  }
  
  /// Load all services for the current provider
  Future<void> loadProviderServices() async {
    try {
      isLoading = true;
      notifyListeners();
      
      // Clear existing services
      servicesList.clear();
      
      if (authService.currentUser == null) {
        print('No logged in user found. Checking previous login...');
        final bool isLoggedIn = await authService.checkPreviousLogin();
        if (!isLoggedIn) {
          print('No previous login session found');
          isLoading = false;
          notifyListeners();
          return;
        }
      }
      
      if (authService.currentUser != null) {
        final String userId = authService.currentUser!.uid;
        
        // Define queries to find services
        final List<Query> queries = [
          FirebaseFirestore.instance
              .collection('services')
              .where('providerId', isEqualTo: userId),
          FirebaseFirestore.instance
              .collection('services')
              .where('userId', isEqualTo: userId),
          FirebaseFirestore.instance
              .collection('services')
              .where('provider_id', isEqualTo: userId),
          FirebaseFirestore.instance
              .collection('services')
              .where('uid', isEqualTo: userId),
        ];
        
        // Temporary list to store services
        final List<Map<String, dynamic>> matchingServices = [];
        
        // Execute each query and collect results
        for (var query in queries) {
          final querySnapshot = await query.get();
          
          if (querySnapshot.docs.isNotEmpty) {
            print('Found ${querySnapshot.docs.length} services from query');
          }
          
          for (var doc in querySnapshot.docs) {
            if (!matchingServices.any((service) => service['id'] == doc.id)) {
              final data = doc.data() as Map<String, dynamic>;
              final serviceData = Map<String, dynamic>.from(data);
              serviceData['id'] = doc.id;
              matchingServices.add(serviceData);
            }
          }
        }
        
        // If no services found, try additional queries
        if (matchingServices.isEmpty) {
          print('No services found. Trying more comprehensive search...');
          
          // Check service locations
          final locationSnapshot = await FirebaseFirestore.instance
              .collection('service_locations')
              .where('providerId', isEqualTo: userId)
              .get();
              
          for (var locationDoc in locationSnapshot.docs) {
            final locationData = locationDoc.data();
            final serviceId = locationData['serviceId'];
            
            if (serviceId != null && serviceId.toString().isNotEmpty) {
              final String validServiceId = serviceId.toString().trim();
              if (validServiceId.isEmpty) {
                continue;
              }
              
              final serviceDoc = await FirebaseFirestore.instance
                  .collection('services')
                  .doc(validServiceId)
                  .get();
                  
              if (serviceDoc.exists) {
                final data = serviceDoc.data() as Map<String, dynamic>;
                data['id'] = serviceDoc.id;
                
                if (!matchingServices.any((service) => service['id'] == serviceDoc.id)) {
                  matchingServices.add(data);
                }
              }
            }
          }
          
          // Check user's services subcollection
          final userServicesSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('services')
              .get();
              
          for (var serviceDoc in userServicesSnapshot.docs) {
            final serviceId = serviceDoc.data()['serviceId'];
            if (serviceId != null && serviceId.toString().isNotEmpty) {
              final String validServiceId = serviceId.toString().trim();
              if (validServiceId.isEmpty) {
                continue;
              }
              
              final mainServiceDoc = await FirebaseFirestore.instance
                  .collection('services')
                  .doc(validServiceId)
                  .get();
                  
              if (mainServiceDoc.exists) {
                final data = mainServiceDoc.data() as Map<String, dynamic>;
                data['id'] = mainServiceDoc.id;
                
                if (!matchingServices.any((service) => service['id'] == mainServiceDoc.id)) {
                  matchingServices.add(data);
                }
              }
            }
          }
        }
        
        // Update the services list
        servicesList.addAll(matchingServices);
        totalServices = servicesList.length;
        
        print('Loaded ${servicesList.length} services');
        
        // Update statistics
        loadStatistics();
      }
    } catch (e) {
      print('Error loading provider services: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
  
  /// Load statistics for the provider dashboard
  Future<void> loadStatistics() async {
    try {
      if (authService.currentUser != null) {
        // In real implementation, fetch actual statistics from a service
        // For now, use simple calculations
        totalServices = servicesList.length;
        totalRequests = totalServices > 0 ? totalServices * 2 : 10;
        totalEarnings = totalServices > 0 ? totalServices * 1500.0 : 7500.0;
        averageRating = 4.7;
        
        notifyListeners();
      }
    } catch (e) {
      print('Error loading statistics: $e');
      // Fallback values
      totalServices = servicesList.length;
      totalRequests = totalServices > 0 ? totalServices * 2 : 10;
      totalEarnings = totalServices > 0 ? totalServices * 1500.0 : 7500.0;
      averageRating = 4.7;
      
      notifyListeners();
    }
  }
  
  /// Toggle the active status of a service
  Future<void> toggleServiceStatus(String serviceId, bool currentStatus) async {
    try {
      isLoading = true;
      notifyListeners();
      
      await FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId)
          .update({'isActive': !currentStatus});
          
      await loadProviderServices();
    } catch (e) {
      print('Error toggling service status: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
  
  /// Delete a service
  Future<void> deleteService(String serviceId) async {
    try {
      isLoading = true;
      notifyListeners();
      
      await FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId)
          .delete();
          
      await FirebaseFirestore.instance
          .collection('service_locations')
          .doc(serviceId)
          .delete();
          
      await loadProviderServices();
    } catch (e) {
      print('Error deleting service: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
