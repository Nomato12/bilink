import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

// Función para verificar y agregar ubicaciones a los servicios sin ubicación
Future<void> addMissingLocationsToServices() async {
  try {
    print("DEBUG: Checking for services without location...");

    final firestore = FirebaseFirestore.instance;
    final querySnapshot =
        await firestore
            .collection('services')
            .where('type', isEqualTo: 'نقل')
            .get();

    int updatedCount = 0;

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      bool needsLocationUpdate = false;

      // Verificar si no tiene campo location
      if (!data.containsKey('location') || data['location'] == null) {
        needsLocationUpdate = true;
      }
      // Verificar si el campo location no tiene la estructura correcta
      else if (data['location'] is Map) {
        final locationData = data['location'] as Map;
        if (!locationData.containsKey('latitude') ||
            !locationData.containsKey('longitude') ||
            locationData['latitude'] is! num ||
            locationData['longitude'] is! num) {
          needsLocationUpdate = true;
        }
      } else {
        needsLocationUpdate = true;
      }

      if (needsLocationUpdate) {
        print(
          "DEBUG: Service ${doc.id} has invalid or missing location. Adding proper location.",
        );

        // Crear un número semilla único para este documento
        final int seed = doc.id.hashCode;
        final math.Random random = math.Random(seed);

        // Coordenadas de Argel (36.7538, 3.0588) con variación aleatoria pero consistente
        // para que cada servicio tenga siempre la misma ubicación "aleatoria"
        final double randomLat = 36.7538 + (random.nextDouble() * 0.05 - 0.025);
        final double randomLng = 3.0588 + (random.nextDouble() * 0.05 - 0.025);

        // Actualizar con ubicación bien estructurada que incluye GeoPoint para consultas geoespaciales
        await firestore.collection('services').doc(doc.id).update({
          'location': {
            'latitude': randomLat,
            'longitude': randomLng,
            'address': 'الجزائر العاصمة، الجزائر',
            'geopoint': GeoPoint(randomLat, randomLng),
            'timestamp': FieldValue.serverTimestamp(),
          },
        });

        // También crear o actualizar en la colección service_locations para mayor redundancia
        await firestore.collection('service_locations').doc(doc.id).set({
          'serviceId': doc.id,
          'providerId': data['providerId'] ?? data['userId'] ?? '',
          'type': 'نقل',
          'latitude': randomLat,
          'longitude': randomLng,
          'address': 'الجزائر العاصمة، الجزائر',
          'lastUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        updatedCount++;
      }
    }

    print("DEBUG: Updated $updatedCount services with proper location data");
  } catch (e) {
    print("ERROR: Failed to add missing locations: $e");
  }
}

// Función para verificar estructura de datos de ubicación
Future<void> checkLocationDataStructure() async {
  try {
    print("DEBUG: Checking location data structure...");

    final firestore = FirebaseFirestore.instance;
    final querySnapshot =
        await firestore
            .collection('services')
            .where('type', isEqualTo: 'نقل')
            .get();

    int validLocations = 0;
    int invalidLocations = 0;
    int missingLocations = 0;

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      print("DEBUG: ==== Service ${doc.id} ====");

      if (data.containsKey('location') && data['location'] != null) {
        if (data['location'] is Map) {
          final locationData = data['location'] as Map;

          if (locationData.containsKey('latitude') &&
              locationData.containsKey('longitude') &&
              locationData['latitude'] is num &&
              locationData['longitude'] is num) {
            validLocations++;
            print(
              "DEBUG: Valid location found: ${locationData['latitude']}, ${locationData['longitude']}",
            );
          } else {
            invalidLocations++;
            print(
              "DEBUG: Invalid location structure: ${locationData.keys.toList()}",
            );
          }
        } else {
          invalidLocations++;
          print("DEBUG: Location not a map: ${data['location'].runtimeType}");
        }
      } else {
        missingLocations++;
        print("DEBUG: No location field found");
      }
    }

    print("DEBUG: Location check summary:");
    print("DEBUG: - Valid locations: $validLocations");
    print("DEBUG: - Invalid locations: $invalidLocations");
    print("DEBUG: - Missing locations: $missingLocations");
    print("DEBUG: - Total services: ${querySnapshot.docs.length}");
  } catch (e) {
    print("ERROR: Failed to check location data structure: $e");
  }
}
