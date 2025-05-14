// Script to fix duplicate client location sections in ClientDetailsScreen

import 'dart:io';

void main() async {
  final filePath = 'lib/screens/client_details_screen.dart';
  
  try {
    final file = File(filePath);
    if (!await file.exists()) {
      print('❌ File not found: $filePath');
      return;
    }

    String content = await file.readAsString();
    
    // Find all occurrences of client location section markers
    final List<int> sectionMarkers = [];
    int index = 0;
    
    while ((index = content.indexOf('// إضافة قسم لموقع العميل إذا كان متاحاً', index)) != -1) {
      sectionMarkers.add(index);
      index++;
    }
    
    if (sectionMarkers.length <= 1) {
      print('✅ No duplicate client location sections found - everything looks good!');
      return;
    }
    
    print('📍 Found ${sectionMarkers.length} client location sections at indices: $sectionMarkers');
    
    // Keep only the first section and remove others
    for (int i = sectionMarkers.length - 1; i > 0; i--) {
      final sectionStart = sectionMarkers[i];
      
      // Find where this section starts and ends
      final sectionOpenBrace = content.indexOf('[', sectionStart);
      if (sectionOpenBrace == -1) continue;
      
      // Find the matching closing brace - this is complex with nested content
      int braceCount = 1;
      int pos = sectionOpenBrace + 1;
      int sectionEnd = -1;
      
      while (pos < content.length && braceCount > 0) {
        if (content[pos] == '[') {
          braceCount++;
        } else if (content[pos] == ']') braceCount--;
        
        if (braceCount == 0) {
          sectionEnd = pos + 1;
          
          // Get a few more characters if there's a comma or spacing
          if (pos + 1 < content.length && content[pos + 1] == ',') {
            sectionEnd = pos + 2;
          }
          
          // Also include any subsequent SizedBox if there is one
          final nextSizedBox = content.indexOf('const SizedBox(height:', sectionEnd);
          if (nextSizedBox != -1 && nextSizedBox - sectionEnd < 10) {
            final endOfSizedBox = content.indexOf('),', nextSizedBox);
            if (endOfSizedBox != -1) {
              sectionEnd = endOfSizedBox + 2;
            }
          }
          
          break;
        }
        pos++;
      }
      
      if (sectionEnd != -1) {
        print('🔍 Removing duplicate section from index $sectionStart to $sectionEnd');
        content = content.substring(0, sectionStart) + content.substring(sectionEnd);
      }
    }
    
    // Fix the condition for displaying client location
    final restrictiveCondition = 'if (_initialCameraPosition != null && _markers.isNotEmpty && !_hasTransportRequestData)';
    final betterCondition = 'if (_initialCameraPosition != null && _markers.isNotEmpty)';
    
    if (content.contains(restrictiveCondition)) {
      content = content.replaceAll(restrictiveCondition, betterCondition);
      print('✅ Fixed client location display condition');
    }
    
    // Write the updated content back to the file
    await file.writeAsString(content);
    print('✅ Successfully removed duplicate client location sections');
    
  } catch (e) {
    print('❌ Error fixing duplicate sections: $e');
  }
}
