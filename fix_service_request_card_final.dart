// Fix for service_request_card.dart

import 'dart:io';

void main() async {
  final filePath = 'lib/widgets/service_request_card.dart';
  
  try {
    final file = File(filePath);
    final content = await file.readAsString(); 
    
    // Define the modified version of the first _showClientLocationOnMap method
    // that includes the parameter fix and combines functionality of both methods
    final fixedMethod = '''
  // عرض خريطة كاملة الشاشة للموقع
  void _showClientLocationOnMap(BuildContext context, GeoPoint clientLocation, String clientName, {bool showRoute = false}) async {
    try {
      final String address = requestData['clientAddress'] ?? '';
      final String clientId = requestData['clientId'] ?? '';
      
      if (showRoute) {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
        
        // Try to open in Google Maps with directions
        final url = 'https://www.google.com/maps/dir/?api=1&destination=\${clientLocation.latitude},\${clientLocation.longitude}&destination_name=\${Uri.encodeComponent(clientName)}&travelmode=driving';
        final uri = Uri.parse(url);
        
        bool launched = false;
        
        if (await canLaunchUrl(uri)) {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        
        // Try alternative URI format if the first one fails
        if (!launched) {
          final geoUrl = 'geo:0,0?q=\${clientLocation.latitude},\${clientLocation.longitude}(\${Uri.encodeComponent(clientName)})&mode=d';
          final geoUri = Uri.parse(geoUrl);
          
          if (await canLaunchUrl(geoUri)) {
            launched = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
          }
        }
        
        // Close loading dialog
        if (context.mounted) {
          Navigator.pop(context);
          
          // Show message if failed
          if (!launched) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('لم يتم العثور على تطبيق خرائط يدعم الاتجاهات'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        // Just show the map without directions
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RequestLocationMap(
              location: clientLocation,
              title: 'موقع \$clientName',
              address: address, 
              enableNavigation: true,
              clientId: clientId.isNotEmpty ? clientId : null,
              showRouteToCurrent: showRoute,
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if it's open
      if (context.mounted) {
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء محاولة فتح الخريطة: \$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }''';
    
    // Find the first method and replace it with our fixed method
    final firstMethodStart = content.indexOf('  // عرض خريطة كاملة الشاشة للموقع');
    final firstMethodEnd = content.indexOf('  // Show the full-screen map');
    
    if (firstMethodStart != -1 && firstMethodEnd != -1) {
      // Create new content with the fixed method
      final contentBefore = content.substring(0, firstMethodStart);
      final contentAfter = content.substring(firstMethodEnd);
      
      // Combine with the fixed method
      final newContent = '$contentBefore$fixedMethod\n$contentAfter';
      
      // Remove the duplicate method
      final secondMethodStart = newContent.indexOf('  // Function to display client location on a map');
      final secondMethodEnd = newContent.indexOf('  // Show dialog with options for client location');
      
      String finalContent = newContent;
      if (secondMethodStart != -1 && secondMethodEnd != -1) {
        // Remove the second method implementation
        finalContent = newContent.substring(0, secondMethodStart) + 
                         newContent.substring(secondMethodEnd);
      }
      
      // Write the updated content back to the file
      await file.writeAsString(finalContent);
      print('✅ Successfully fixed service_request_card.dart');
    } else {
      print('❌ Could not locate method boundaries');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
