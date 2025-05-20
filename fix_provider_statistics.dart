// Script para corregir las estadísticas de proveedores
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:bilink/firebase_options.dart';
import 'package:bilink/services/provider_statistics_service.dart';

/// Este script:
/// 1. Verifica que todos los documentos de solicitud tengan un precio válido
/// 2. Actualiza las estadísticas para todas las solicitudes aceptadas/completadas
/// 3. Regenera los cálculos de estadísticas para asegurar su precisión

void main() async {
  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('Iniciando script de corrección de estadísticas...');
  
  // Obtener todas las solicitudes aceptadas y completadas
  await fixAllServiceRequestPrices();
  
  // Regenerar estadísticas para todas las solicitudes aceptadas/completadas
  await regenerateAllStatistics();
  
  print('¡Corrección completada! Las estadísticas deberían mostrarse correctamente ahora.');
}

Future<void> fixAllServiceRequestPrices() async {
  print('\n========== CORRIGIENDO PRECIOS EN SOLICITUDES ==========');
  
  // 1. Obtener todas las solicitudes
  final requestsSnapshot = await FirebaseFirestore.instance
      .collection('service_requests')
      .get();
  
  print('Encontradas ${requestsSnapshot.docs.length} solicitudes para revisar.');
  
  int fixedCount = 0;
  
  for (final doc in requestsSnapshot.docs) {
    final requestData = doc.data();
    final String requestId = doc.id;
    String status = requestData['status'] ?? 'pending';
    
    // Solo nos interesan solicitudes aceptadas o completadas
    if (status != 'accepted' && status != 'completed') {
      continue;
    }
    
    // Verificar si hay precio en la solicitud
    dynamic priceValue = requestData['price'];
    bool needsFixing = false;
    
    // Convertir el precio a un valor numérico si no lo es
    if (priceValue == null) {
      needsFixing = true;
    } else if (priceValue is String) {
      try {
        priceValue = double.parse(priceValue);
        needsFixing = true;
      } catch (e) {
        needsFixing = true;
        priceValue = 0.0;
      }
    } else if (priceValue is! num) {
      needsFixing = true;
      priceValue = 0.0;
    }
    
    // Si no hay precio o es inválido, intentar obtenerlo del servicio
    if (needsFixing || (priceValue is num && priceValue <= 0)) {
      final String serviceId = requestData['serviceId'] ?? '';
      if (serviceId.isNotEmpty) {
        try {
          final serviceDoc = await FirebaseFirestore.instance
              .collection('services')
              .doc(serviceId)
              .get();
              
          if (serviceDoc.exists) {
            final serviceData = serviceDoc.data() as Map<String, dynamic>;
            final servicePrice = serviceData['price'];
            
            if (servicePrice != null && servicePrice is num && servicePrice > 0) {
              priceValue = servicePrice;
              
              // Actualizar el documento de solicitud con el precio correcto
              await FirebaseFirestore.instance
                  .collection('service_requests')
                  .doc(requestId)
                  .update({'price': priceValue});
              
              fixedCount++;
              print('✓ Corregido precio para solicitud $requestId: $priceValue');
            }
          }
        } catch (e) {
          print('Error al obtener servicio para solicitud $requestId: $e');
        }
      }
    }
  }
  
  print('Se corrigieron $fixedCount precios de solicitudes.');
}

Future<void> regenerateAllStatistics() async {
  print('\n========== REGENERANDO ESTADÍSTICAS ==========');
  
  // 1. Obtener todas las solicitudes aceptadas/completadas
  final requestsSnapshot = await FirebaseFirestore.instance
      .collection('service_requests')
      .where('status', whereIn: ['accepted', 'completed'])
      .get();
  
  print('Encontradas ${requestsSnapshot.docs.length} solicitudes aceptadas/completadas.');
  
  int successCount = 0;
  int failCount = 0;
  
  // 2. Limpiar estadísticas existentes
  print('Limpiando estadísticas existentes...');
  try {
    final statsSnapshot = await FirebaseFirestore.instance
        .collection('provider_statistics')
        .get();
    
    // Eliminar estadísticas existentes en lotes para mejor rendimiento
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in statsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    
    print('Se eliminaron ${statsSnapshot.docs.length} registros de estadísticas existentes.');
  } catch (e) {
    print('Error al limpiar estadísticas existentes: $e');
  }
  
  // 3. Regenerar estadísticas para cada solicitud
  final providerStatisticsService = ProviderStatisticsService();
  
  for (final doc in requestsSnapshot.docs) {
    final requestId = doc.id;
    final requestData = doc.data();
    final status = requestData['status'];
    
    print('Procesando solicitud $requestId con estado $status');
    
    try {
      final result = await providerStatisticsService.registerServiceEarnings(
        requestId,
        status,
      );
      
      if (result) {
        successCount++;
        print('✓ Estadística registrada para solicitud $requestId');
      } else {
        failCount++;
        print('✗ No se pudo registrar estadística para solicitud $requestId');
      }
    } catch (e) {
      failCount++;
      print('✗ Error al registrar estadística para solicitud $requestId: $e');
    }
  }
  
  print('\nResultados de regeneración de estadísticas:');
  print('- Éxitos: $successCount');
  print('- Fallos: $failCount');
}
