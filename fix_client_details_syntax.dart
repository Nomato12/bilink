// Fix syntax errors in client_details_screen.dart

import 'dart:io';

void main() async {
  final filePath = 'lib/screens/client_details_screen.dart';
  
  try {
    final file = File(filePath);
    if (!await file.exists()) {
      print('❌ File not found: $filePath');
      return;
    }
    
    var content = await file.readAsString();
    
    // Fix 1: Change the client location section syntax using spread operator
    content = fixClientLocationSection(content);
    
    // Fix 2: Fix indentation issues
    content = fixIndentation(content);
    
    // Write the fixed content back to the file
    await file.writeAsString(content);
    
    print('✅ Fixed syntax errors in $filePath');
  } catch (e) {
    print('❌ Error fixing syntax errors: $e');
  }
}

String fixClientLocationSection(String content) {
  // Find and fix the first problematic section (client location)
  final locSectionStart = content.indexOf('// إضافة قسم لموقع العميل إذا كان متاحاً');
  
  if (locSectionStart == -1) {
    print('⚠️ Client location section not found');
    return content;
  }
  
  final locIfStart = content.indexOf('if (_initialCameraPosition != null', locSectionStart);
  if (locIfStart == -1) {
    print('⚠️ Client location condition not found');
    return content;
  }
  
  // Find where the client location section ends
  final nextSectionStart = content.indexOf('// إضافة قسم للخريطة عندما تكون بيانات النقل متاحة', locIfStart);
  if (nextSectionStart == -1) {
    print('⚠️ Next section marker not found');
    return content;
  }
  
  // Extract the problematic code section
  final problemSection = content.substring(locSectionStart, nextSectionStart);
  
  // Fix the problematic section
  String fixedSection = '${content.substring(locSectionStart, locIfStart)}if (_initialCameraPosition != null && _markers.isNotEmpty && !_hasTransportRequestData) ...[${content.substring(content.indexOf('{', locIfStart) + 1, nextSectionStart)
          .replaceFirst('const SizedBox(height: 16),', 'const SizedBox(height: 16),\n                      ],')}';
  
  // Replace the problematic section with the fixed one
  return content.substring(0, locSectionStart) + fixedSection + content.substring(nextSectionStart);
}

String fixIndentation(String content) {
  // Make sure indentation is consistent throughout the file
  var lines = content.split('\n');
  var fixedLines = <String>[];
  
  bool inIf = false;
  int indentLevel = 0;
  
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    
    // Detect special patterns that might cause issues
    if (line.contains('if (') && line.contains(') ...[')) {
      inIf = true;
      indentLevel++;
    } else if (line.trim() == '],') {
      inIf = false;
      indentLevel--;
      // Make sure this closing bracket is properly indented
      line = ' ' * 22 + '],';
    }
    
    // Fix any lines with obviously wrong indentation
    if (line.trim().startsWith('if (_hasTransportRequestData)') && !line.contains('...')) {
      line = line.replaceFirst('if (_hasTransportRequestData)', 'if (_hasTransportRequestData) ...');
    }
    
    // Add corrected line
    fixedLines.add(line);
  }
  
  return fixedLines.join('\n');
}
