// Script para reparar los precios y las estadísticas
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:bilink/firebase_options.dart';
import 'dart:math' as math;

void main() async {
  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('Iniciando reparación de estadísticas...');
  
  // Reparar precios y estadísticas
  await repairAllStatistics();
  
  print('¡Reparación completada! Las estadísticas deberían funcionar correctamente ahora.');
}

/// Este método repara las estadísticas del proveedor:
/// 1. Primero corrige los precios en todas las solicitudes
/// 2. Luego regenera las estadísticas en base a esas solicitudes
Future<void> repairAllStatistics() async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  print('\n========== REPARANDO ESTADÍSTICAS ==========');
  
  // 1. Obtener todas las solicitudes de servicios
  print('Obteniendo solicitudes de servicios...');
  final requestsSnapshot = await firestore.collection('service_requests').get();
  print('Encontradas ${requestsSnapshot.docs.length} solicitudes.');
  
  // 2. Corregir precios en las solicitudes
  print('\nCorrigiendo precios en solicitudes...');
  int fixedPrices = 0;
  
  for (final doc in requestsSnapshot.docs) {
    final requestData = doc.data();
    final requestId = doc.id;
    final serviceId = requestData['serviceId'] ?? '';
    final serviceType = requestData['serviceType'] ?? 'تخزين';
    
    // Solo nos interesan solicitudes aceptadas o completadas
    if (requestData['status'] != 'accepted' && requestData['status'] != 'completed') {
      continue;
    }
    
    // Verificar el precio actual
    dynamic currentPrice = requestData['price'];
    double numericPrice = 0.0;
    bool needsFix = false;
    
    // Convertir el precio a numérico si es posible
    if (currentPrice == null) {
      needsFix = true;
    } else if (currentPrice is String) {
      try {
        numericPrice = double.parse(currentPrice);
        needsFix = true; // Necesitamos convertirlo de string a número
      } catch (e) {
        needsFix = true;
        numericPrice = 0.0;
      }
    } else if (currentPrice is num) {
      numericPrice = currentPrice.toDouble();
      if (numericPrice <= 0) {
        needsFix = true;
      }
    } else {
      needsFix = true;
    }
    
    // Si necesitamos arreglar el precio
    if (needsFix) {
      if (numericPrice <= 0 && serviceId.isNotEmpty) {
        // Intentar obtener precio del servicio
        try {
          final serviceDoc = await firestore.collection('services').doc(serviceId).get();
          if (serviceDoc.exists) {
            final serviceData = serviceDoc.data() as Map<String, dynamic>;
            final servicePrice = serviceData['price'];
            
            if (servicePrice != null) {
              if (servicePrice is num) {
                numericPrice = servicePrice.toDouble();
              } else if (servicePrice is String) {
                try {
                  numericPrice = double.parse(servicePrice);
                } catch (e) {
                  // Mantener precio en 0
                }
              }
            }
          }
        } catch (e) {
          print('Error al obtener servicio $serviceId: $e');
        }
      }
      
      // Si aún no tenemos un precio válido
      if (numericPrice <= 0) {
        // Para transporte, estimar por distancia
        if (serviceType == 'نقل' && requestData['distanceText'] != null) {
          String distanceText = requestData['distanceText'];
          RegExp regex = RegExp(r'(\d+(\.\d+)?)');
          var match = regex.firstMatch(distanceText);
          if (match != null) {
            double distance = double.parse(match.group(1)!);
            numericPrice = math.max(500.0, distance * 50);
          } else {
            numericPrice = 500.0;
          }
        } else {
          // Valor predeterminado según tipo de servicio
          numericPrice = serviceType == 'نقل' ? 500.0 : 300.0;
        }
      }
      
      // Actualizar el precio en la solicitud
      try {
        await firestore.collection('service_requests').doc(requestId).update({
          'price': numericPrice
        });
        fixedPrices++;
        print('✓ Precio corregido para $requestId: $numericPrice');
      } catch (e) {
        print('✗ Error al actualizar precio para $requestId: $e');
      }
    }
  }
  
  print('Corregidos $fixedPrices precios de solicitudes.');
  
  // 3. Regenerar las estadísticas
  print('\nRegenerando estadísticas del proveedor...');
  
  // Primero eliminar estadísticas existentes
  try {
    final statsSnapshot = await firestore.collection('provider_statistics').get();
    print('Eliminando ${statsSnapshot.docs.length} registros de estadísticas antiguas...');
    
    for (final doc in statsSnapshot.docs) {
      await doc.reference.delete();
    }
    
    print('Estadísticas antiguas eliminadas.');
  } catch (e) {
    print('Error al eliminar estadísticas antiguas: $e');
  }
  
  // Regenerar estadísticas para solicitudes aceptadas/completadas
  int generatedStats = 0;
  
  for (final doc in requestsSnapshot.docs) {
    final requestData = doc.data();
    final requestId = doc.id;
    final status = requestData['status'];
    
    // Solo procesar solicitudes aceptadas/completadas
    if (status != 'accepted' && status != 'completed') {
      continue;
    }
    
    final providerId = requestData['providerId'] ?? '';
    if (providerId.isEmpty) continue;
    
    final serviceId = requestData['serviceId'] ?? '';
    final serviceName = requestData['serviceName'] ?? 'خدمة';
    final serviceType = requestData['serviceType'] ?? 'تخزين';
    final durationType = requestData['durationType'] ?? 'شهري';
    
    // Asegurarnos de tener un precio válido
    dynamic price = requestData['price'];
    double numericPrice = 0.0;
    
    if (price != null) {
      if (price is num) {
        numericPrice = price.toDouble();
      } else if (price is String) {
        try {
          numericPrice = double.parse(price);
        } catch (e) {
          numericPrice = 0.0;
        }
      }
    }
    
    if (numericPrice <= 0) {
      numericPrice = serviceType == 'نقل' ? 500.0 : 300.0;
    }
    
    // Calcular comisiones
    double providerAmount = numericPrice * 0.8;
    double appFee = numericPrice * 0.2;
    
    // Fecha de la solicitud
    DateTime date = DateTime.now();
    if (requestData['completedAt'] != null) {
      date = (requestData['completedAt'] as Timestamp).toDate();
    } else if (requestData['responseDate'] != null) {
      date = (requestData['responseDate'] as Timestamp).toDate();
    } else if (requestData['updatedAt'] != null) {
      date = (requestData['updatedAt'] as Timestamp).toDate();
    } else if (requestData['createdAt'] != null) {
      date = (requestData['createdAt'] as Timestamp).toDate();
    }
    
    // Crear el registro de estadísticas
    try {
      await firestore.collection('provider_statistics').doc(requestId).set({
        'providerId': providerId,
        'requestId': requestId,
        'serviceId': serviceId,
        'serviceName': serviceName,
        'serviceType': serviceType,
        'status': status,
        'amount': numericPrice,
        'providerAmount': providerAmount,
        'appFee': appFee,
        'date': date,
        'durationType': durationType,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      generatedStats++;
      print('✓ Estadística generada para $requestId: $numericPrice');
    } catch (e) {
      print('✗ Error al generar estadística para $requestId: $e');
    }
  }
  
  print('\nResultados finales:');
  print('- Precios corregidos: $fixedPrices');
  print('- Estadísticas regeneradas: $generatedStats');
}
