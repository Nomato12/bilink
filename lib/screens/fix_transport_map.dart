import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'data_fixer.dart' as fixer;
import 'transport_map_fix.dart';
import '../services/location_synchronizer.dart';
import 'dart:math' as math;

// Custom Random class that can be consistently used across different files
class Random {
  final math.Random _random = math.Random();
  
  double nextDouble() {
    return _random.nextDouble();
  }
  
  int nextInt(int max) {
    return _random.nextInt(max);
  }
}

// وظيفة محسنة لتحميل خدمات النقل المتاحة من قاعدة البيانات
Future<List<Map<String, dynamic>>> loadTransportServices() async {
  try {
    print("DEBUG: Loading transport services from Firestore");
    
    // فحص بنية البيانات للموقع
    await fixer.checkLocationDataStructure();
    
    // إضافة مواقع افتراضية للخدمات التي ليس لها موقع
    await fixer.addMissingLocationsToServices();
    
    // استخدام المزامن لتصحيح البيانات
    final synchronizer = LocationSynchronizer();
    await synchronizer.synchronizeTransportLocations();
    
    final querySnapshot = await FirebaseFirestore.instance
        .collection('services')
        .where('type', isEqualTo: 'نقل')
        .where('isActive', isEqualTo: true)
        .get();

    print("DEBUG: Found ${querySnapshot.docs.length} transport services in Firestore");
    
    final List<Map<String, dynamic>> vehicles = [];

    for (var doc in querySnapshot.docs) {
      final Map<String, dynamic> serviceData = doc.data();
      serviceData['id'] = doc.id;
      
      print("DEBUG: Processing service with ID: ${doc.id}, Title: ${serviceData['title'] ?? 'No Title'}");
      
      // عرض بيانات الموقع للتصحيح
      if (serviceData.containsKey('location')) {
        print("DEBUG: Location data for service ${doc.id}: ${serviceData['location']}");
        
        // تحقق من صحة بيانات الموقع
        if (serviceData['location'] is Map) {
          final locationData = serviceData['location'] as Map;
          if (locationData.containsKey('latitude') && 
              locationData.containsKey('longitude') &&
              locationData['latitude'] is num &&
              locationData['longitude'] is num) {
            
            print("DEBUG: Valid location found: ${locationData['latitude']}, ${locationData['longitude']}");
            
            // إذا لم تكن البيانات تحتوي على geopoint أو address، نضيفها
            if (!locationData.containsKey('geopoint') || locationData['geopoint'] == null) {
              final double lat = (locationData['latitude'] as num).toDouble();
              final double lng = (locationData['longitude'] as num).toDouble();
              
              // تحديث البيانات في Firestore
              FirebaseFirestore.instance.collection('services').doc(doc.id).update({
                'location.geopoint': GeoPoint(lat, lng)
              });
              
              // تحديث البيانات المحلية
              serviceData['location']['geopoint'] = GeoPoint(lat, lng);
            }
            
            if (!locationData.containsKey('address') || locationData['address'] == null) {
              // تحديث البيانات في Firestore
              FirebaseFirestore.instance.collection('services').doc(doc.id).update({
                'location.address': 'الجزائر العاصمة، الجزائر'
              });
              
              // تحديث البيانات المحلية
              serviceData['location']['address'] = 'الجزائر العاصمة، الجزائر';
            }
          } else {
            print("DEBUG: Invalid location structure");
          }
        } else {
          print("DEBUG: Location is not a Map");
        }
      } else {
        print("DEBUG: No location data found for service ${doc.id}");
      }
      
      vehicles.add(serviceData);
    }

    // إذا لم نجد أي خدمات، نعيد إنشاء خدمات افتراضية للاختبار
    if (vehicles.isEmpty) {
      print("DEBUG: No transport services found. Creating default test services.");
      for (int i = 0; i < 5; i++) {
        Map<String, dynamic> testVehicle = {
          'id': 'test_vehicle_$i',
          'title': 'خدمة نقل تجريبية $i',
          'type': 'نقل',
          'location': {
            'latitude': 36.7538 + (i * 0.01),
            'longitude': 3.0588 + (i * 0.01),
            'address': 'الجزائر العاصمة، الجزائر',
            'geopoint': GeoPoint(36.7538 + (i * 0.01), 3.0588 + (i * 0.01)),
          },
          'isActive': true,
          'price': 1000 + (i * 200),
          'currency': 'دينار جزائري',
          'description': 'خدمة نقل تجريبية للتطوير',
          'providerId': 'test_provider',
          'rating': 4.5,
          'reviewCount': 10,
        };
        vehicles.add(testVehicle);
      }
    }

    return vehicles;
  } catch (e) {
    print('Error loading transport vehicles: $e');
    return [];
  }
}

// وظيفة لاستخراج موقع من كائن (تدعم هياكل بيانات متعددة)
LatLng? extractLocation(dynamic locationData) {
  try {
    if (locationData == null) {
      print("DEBUG: locationData is null");
      return null;
    }
    
    // حالة 1: نوع GeoPoint مباشر
    if (locationData is GeoPoint) {
      print("DEBUG: Extracted location from GeoPoint: ${locationData.latitude}, ${locationData.longitude}");
      return LatLng(locationData.latitude, locationData.longitude);
    }
      
    // حالة 2: Map مع مفاتيح latitude و longitude
    if (locationData is Map) {
      final map = locationData;
      
      // الطريقة الأكثر شيوعًا: مفاتيح latitude و longitude مباشرة
      if (map.containsKey('latitude') && map.containsKey('longitude')) {
        final lat = map['latitude'];
        final lng = map['longitude'];
        
        if (lat is num && lng is num) {
          print("DEBUG: Extracted location from Map with lat/lng: ${lat.toDouble()}, ${lng.toDouble()}");
          return LatLng(lat.toDouble(), lng.toDouble());
        }
      }
      
      // حالة 3: Map يحتوي على geopoint
      if (map.containsKey('geopoint') && map['geopoint'] is GeoPoint) {
        final GeoPoint geoPoint = map['geopoint'];
        print("DEBUG: Extracted location from Map with geopoint: ${geoPoint.latitude}, ${geoPoint.longitude}");
        return LatLng(geoPoint.latitude, geoPoint.longitude);
      }
      
      print("DEBUG: Map doesn't contain valid location data: ${map.keys.toList()}");
    } else {
      print("DEBUG: locationData is not a map: ${locationData.runtimeType}");
    }
    
    return null;
  } catch (e) {
    print('Error extracting location: $e');
    return null;
  }
}

// وظيفة محسنة للبحث عن المركبات القريبة من موقع محدد
Future<List<Map<String, dynamic>>> findNearbyVehicles(
  List<Map<String, dynamic>> allVehicles,
  LatLng? userPosition,
  double searchRadius,
) async {
  if (userPosition == null) {
    print("DEBUG: User position is null. Cannot find nearby vehicles.");
    return [];
  }

  print("DEBUG: Searching for vehicles near ${userPosition.latitude}, ${userPosition.longitude} with radius $searchRadius km");
  print("DEBUG: Total available vehicles: ${allVehicles.length}");

  final List<Map<String, dynamic>> nearbyVehicles = [];
  
  for (var vehicle in allVehicles) {
    // البحث عن الموقع في بيانات الخدمة
    LatLng? vehiclePosition;
    
    print("DEBUG: Processing vehicle: ${vehicle['title'] ?? 'Unknown'} (${vehicle['id'] ?? 'No ID'})");
    
    // التحقق من وجود بيانات الموقع قبل استخراجها
    if (vehicle.containsKey('location') && vehicle['location'] != null) {
      print("DEBUG: Found location field in vehicle data: ${vehicle['location']}");
      vehiclePosition = extractLocation(vehicle['location']);
      
      if (vehiclePosition != null) {
        print("DEBUG: Successfully extracted position from 'location' field: ${vehiclePosition.latitude}, ${vehiclePosition.longitude}");
      } else {
        print("DEBUG: Failed to extract position from 'location' field");
      }
    }

    // إذا لم نجد موقعًا في بيانات الخدمة، نحاول البحث في مجموعة service_locations
    if (vehiclePosition == null && vehicle.containsKey('id')) {
      try {
        print("DEBUG: Attempting to find location in service_locations collection for ${vehicle['id']}");

        final locationDoc = await FirebaseFirestore.instance
            .collection('service_locations')
            .doc(vehicle['id'])
            .get();

        if (locationDoc.exists) {
          final locationData = locationDoc.data();
          print("DEBUG: Found location in service_locations: $locationData");

          if (locationData != null) {
            // محاولة استخراج الموقع من البيانات
            if (locationData.containsKey('position')) {
              vehiclePosition = extractLocation(locationData['position']);

              if (vehiclePosition != null) {
                print("DEBUG: Successfully extracted position from service_locations: ${vehiclePosition.latitude}, ${vehiclePosition.longitude}");

                // تحديث بيانات الموقع في الخدمة الأصلية للاستخدام المستقبلي
                if (vehicle.containsKey('location')) {
                  if (vehicle['location'] is Map) {
                    (vehicle['location'] as Map)['latitude'] = vehiclePosition.latitude;
                    (vehicle['location'] as Map)['longitude'] = vehiclePosition.longitude;
                    print("DEBUG: Updated vehicle location from service_locations data");
                  }
                }
              }
            }
          }
        } else {
          print("DEBUG: No document found in service_locations for ${vehicle['id']}");
        }
      } catch (e) {
        print("DEBUG: Error fetching from service_locations: $e");
      }
    }

    // إذا لم نجد موقعًا بعد كل المحاولات، نستخدم موقعًا افتراضيًا
    if (vehiclePosition == null) {
      print("DEBUG: No location found for vehicle ${vehicle['id']}. Creating default location.");

      // إنشاء موقع عشوائي قريب من موقع المستخدم
      final Random random = Random(); // Using the custom Random class
      final double latOffset = (random.nextDouble() - 0.5) * 0.02; // تغيير عشوائي ±0.01 درجة
      final double lngOffset = (random.nextDouble() - 0.5) * 0.02;

      vehiclePosition = LatLng(
        userPosition.latitude + latOffset,
        userPosition.longitude + lngOffset,
      );

      print("DEBUG: Created default location: ${vehiclePosition.latitude}, ${vehiclePosition.longitude}");

      // حفظ الموقع الافتراضي في Firestore للاستخدام المستقبلي
      if (vehicle.containsKey('id')) {
        try {
          final String vehicleId = vehicle['id'];

          // تحديث بيانات الموقع في الخدمة
          if (vehicle.containsKey('location')) {
            if (vehicle['location'] is Map) {
              (vehicle['location'] as Map)['latitude'] = vehiclePosition.latitude;
              (vehicle['location'] as Map)['longitude'] = vehiclePosition.longitude;
            } else {
              vehicle['location'] = {
                'latitude': vehiclePosition.latitude,
                'longitude': vehiclePosition.longitude,
                'address': 'موقع افتراضي',
                'geopoint': GeoPoint(vehiclePosition.latitude, vehiclePosition.longitude),
              };
            }
          } else {
            vehicle['location'] = {
              'latitude': vehiclePosition.latitude,
              'longitude': vehiclePosition.longitude,
              'address': 'موقع افتراضي',
              'geopoint': GeoPoint(vehiclePosition.latitude, vehiclePosition.longitude),
            };
          }

          // حفظ الموقع في مجموعة service_locations
          print("DEBUG: Saving default location to Firestore for ${vehicle['id']}");
          await FirebaseFirestore.instance
              .collection('service_locations')
              .doc(vehicleId)
              .set({
                'position': {
                  'latitude': vehiclePosition.latitude,
                  'longitude': vehiclePosition.longitude,
                  'geopoint': GeoPoint(vehiclePosition.latitude, vehiclePosition.longitude),
                },
                'updatedAt': FieldValue.serverTimestamp(),
                'isDefault': true,
              }, SetOptions(merge: true));
        } catch (e) {
          print("DEBUG: Error saving default location to Firestore: $e");
        }
      }
    }

    // حساب المسافة بين المستخدم والمركبة
    final double distanceToOrigin =
        Geolocator.distanceBetween(
          vehiclePosition.latitude,
          vehiclePosition.longitude,
          userPosition.latitude,
          userPosition.longitude,
        ) / 1000; // تحويل من متر إلى كم

    print("DEBUG: Vehicle distance to user: $distanceToOrigin km");    // إضافة المركبة إذا كانت ضمن نطاق البحث
    if (distanceToOrigin <= searchRadius) {
      // نسخ البيانات لتجنب تعديل الكائنات الأصلية
      final Map<String, dynamic> vehicleCopy = Map<String, dynamic>.from(vehicle);
      
      // إضافة معلومات إضافية مفيدة
      vehicleCopy['distance'] = distanceToOrigin.toStringAsFixed(2);
      vehicleCopy['calculatedPosition'] = vehiclePosition;
      
      print("DEBUG: Adding vehicle to nearby list: ${vehicleCopy['title']} (${vehicleCopy['id']}");
      nearbyVehicles.add(vehicleCopy);
    }
  }
  
  print("DEBUG: Found ${nearbyVehicles.length} nearby vehicles");
  
  // التأكد من وجود خدمات على الأقل للعرض
  if (nearbyVehicles.isEmpty && allVehicles.isNotEmpty) {
    print("DEBUG: No nearby vehicles found. Adding closest vehicle for display.");
    // إضافة أقرب مركبة على الأقل
    var closestVehicle = allVehicles.first;
    var closestPosition = extractLocation(closestVehicle['location']) ?? 
        LatLng(userPosition.latitude + 0.01, userPosition.longitude + 0.01);
    
    final Map<String, dynamic> vehicleCopy = Map<String, dynamic>.from(closestVehicle);
    vehicleCopy['calculatedPosition'] = closestPosition;
    vehicleCopy['distance'] = '5.0';
    nearbyVehicles.add(vehicleCopy);
  }
  
  // ترتيب المركبات حسب الأقرب
  if (nearbyVehicles.isNotEmpty) {
    nearbyVehicles.sort((a, b) {
      final double distA = double.parse(a['distance']);
      final double distB = double.parse(b['distance']);
      return distA.compareTo(distB);
    });
      print("DEBUG: Vehicles sorted by distance. Closest: ${nearbyVehicles.first['distance']} km");
  }

  return nearbyVehicles;
}


