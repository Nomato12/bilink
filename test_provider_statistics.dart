// Script to verify provider statistics tracking works correctly
import 'package:bilink/services/provider_statistics_service.dart';

void main() async {
  // Test service request ID - replace with a real ID from your database
  const String requestId = 'YOUR_REQUEST_ID_HERE'; 
  
  // Test updating statistics for an accepted request
  await testStatisticsUpdate(requestId, 'accepted');
  
  // Test updating statistics for a completed request
  await testStatisticsUpdate(requestId, 'completed');
}

Future<void> testStatisticsUpdate(String requestId, String status) async {
  print('Testing statistics update for request $requestId with status $status');
  
  final providerStatisticsService = ProviderStatisticsService();
  
  try {
    final bool result = await providerStatisticsService.registerServiceEarnings(
      requestId,
      status,
    );
    
    if (result) {
      print('✅ Successfully registered earnings for request $requestId with status $status');
    } else {
      print('❌ Failed to register earnings for request $requestId with status $status');
    }
  } catch (e) {
    print('🔥 Error registering earnings: $e');
  }
}
