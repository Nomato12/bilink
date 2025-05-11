import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';

class LocationSynchronizer {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Función para sincronizar y corregir datos de ubicación en todos los servicios de transporte
  Future<void> synchronizeTransportLocations() async {
    try {
      print("LocationSynchronizer: Comenzando sincronización de datos de ubicación");
      
      // Obtener todos los servicios de transporte
      final querySnapshot = await _firestore
          .collection('services')
          .where('type', isEqualTo: 'نقل')
          .get();
      
      print("LocationSynchronizer: Encontrados ${querySnapshot.docs.length} servicios para sincronizar");
      
      int updatedCount = 0;
      int errorCount = 0;
      
      // Procesar cada servicio y verificar/corregir su información de ubicación
      for (var doc in querySnapshot.docs) {
        final serviceId = doc.id;
        final serviceData = doc.data();
        
        try {
          // Extraer la información de ubicación de cualquier formato disponible
          final locationData = extractLocationData(serviceData);
          
          if (locationData != null) {
            // Actualizar el documento principal del servicio
            await _firestore.collection('services').doc(serviceId).update({
              'location': locationData,
              'lastLocationUpdate': FieldValue.serverTimestamp(),
            });
            
            // Asegurar que existe un registro en la colección service_locations
            await _firestore.collection('service_locations').doc(serviceId).set({
              'serviceId': serviceId,
              'providerId': serviceData['providerId'],
              'type': serviceData['type'],
              'latitude': locationData['latitude'],
              'longitude': locationData['longitude'],
              'address': locationData['address'] ?? 'العنوان غير متوفر',
              'lastUpdate': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            
            updatedCount++;
          } else {
            print("LocationSynchronizer: No se pudo extraer ubicación para servicio $serviceId");
            errorCount++;
          }
        } catch (e) {
          print("LocationSynchronizer: Error procesando servicio $serviceId: $e");
          errorCount++;
        }
      }
      
      print("LocationSynchronizer: Sincronización completada. Actualizados: $updatedCount, Errores: $errorCount");
    } catch (e) {
      print("LocationSynchronizer: Error general: $e");
    }
  }
  
  // Extraer datos de ubicación de cualquier formato disponible
  Map<String, dynamic>? extractLocationData(Map<String, dynamic> serviceData) {
    // Buscar en el campo location primero
    if (serviceData.containsKey('location') && serviceData['location'] != null) {
      final location = serviceData['location'];
      
      // Si ya es un mapa con latitud y longitud, usarlo directamente
      if (location is Map && 
          location.containsKey('latitude') && 
          location.containsKey('longitude')) {
        
        final lat = location['latitude'];
        final lng = location['longitude'];
        
        if (lat is num && lng is num) {
          return {
            'latitude': lat.toDouble(),
            'longitude': lng.toDouble(),
            'address': location['address'] ?? 'العنوان غير متوفر',
            'timestamp': location['timestamp'] ?? FieldValue.serverTimestamp(),
          };
        }
      }
      
      // Si es un GeoPoint
      if (location is GeoPoint) {
        return {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'address': 'العنوان غير متوفر',
          'timestamp': FieldValue.serverTimestamp(),
        };
      }
    }
    
    // Buscar en el campo vehicle
    if (serviceData.containsKey('vehicle') && 
        serviceData['vehicle'] != null && 
        serviceData['vehicle'] is Map) {
      
      final vehicle = serviceData['vehicle'];
      
      // Verificar si vehicle tiene location
      if (vehicle.containsKey('location') && vehicle['location'] != null) {
        final location = vehicle['location'];
        
        if (location is Map && 
            location.containsKey('latitude') && 
            location.containsKey('longitude')) {
          
          final lat = location['latitude'];
          final lng = location['longitude'];
          
          if (lat is num && lng is num) {
            return {
              'latitude': lat.toDouble(),
              'longitude': lng.toDouble(),
              'address': location['address'] ?? 'العنوان غير متوفر',
              'timestamp': FieldValue.serverTimestamp(),
            };
          }
        } else if (location is GeoPoint) {
          return {
            'latitude': location.latitude,
            'longitude': location.longitude,
            'address': 'العنوان غير متوفر',
            'timestamp': FieldValue.serverTimestamp(),
          };
        }
      }
      
      // Verificar si vehicle tiene campos de ubicación directos
      if (vehicle.containsKey('latitude') && 
          vehicle.containsKey('longitude')) {
        
        final lat = vehicle['latitude'];
        final lng = vehicle['longitude'];
        
        if (lat is num && lng is num) {
          return {
            'latitude': lat.toDouble(),
            'longitude': lng.toDouble(),
            'address': vehicle['address'] ?? 'العنوان غير متوفر',
            'timestamp': FieldValue.serverTimestamp(),
          };
        }
      }
    }
    
    // Crear ubicación por defecto para Argel si no hay datos
    return {
      'latitude': 36.7538 + (serviceData['id'].hashCode % 100) / 10000,
      'longitude': 3.0588 + (serviceData['id'].hashCode % 50) / 10000,
      'address': 'موقع افتراضي - الجزائر',
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
  
  // Función para verificar si una ubicación es válida
  bool isValidLocation(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return false;
    }
    
    // Verificar que las coordenadas estén dentro de rangos geográficos válidos
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return false;
    }
    
    // Verificar que no sean valores cero o muy cercanos a cero (a veces indica error)
    if (latitude.abs() < 0.001 && longitude.abs() < 0.001) {
      return false;
    }
    
    return true;
  }
  // Obtener LatLng desde un mapa de datos
  LatLng? getLatLngFromData(Map<String, dynamic>? locationData) {
    if (locationData == null) {
      return null;
    }
    
    if (locationData.containsKey('latitude') && 
        locationData.containsKey('longitude')) {
      
      final lat = locationData['latitude'];
      final lng = locationData['longitude'];
      
      if (lat is num && lng is num && isValidLocation(lat.toDouble(), lng.toDouble())) {
        return LatLng(lat.toDouble(), lng.toDouble());
      }
    }
    
    return null;
  }
  
  // Función para forzar la sincronización periódica
  Timer startPeriodicSync(Duration interval) {
    return Timer.periodic(interval, (timer) {
      synchronizeTransportLocations();
    });
  }
}
