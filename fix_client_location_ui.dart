// Script to create a unified fix for the client location display and map in client details

import 'dart:io';

void main() async {
  final filePath = 'lib/screens/client_details_screen.dart';
  
  try {
    // Fix for redundant client location section that was duplicated
    await fixDuplicateLocationSection(filePath);
    print('✅ Fixed duplicate client location section');
    
    // Fix to properly handle the case where there's client location but no transport data
    await fixClientLocationRendering(filePath);
    print('✅ Enhanced client location rendering logic');
    
    print('\n🎉 All client location display fixes applied successfully!');
  } catch (e) {
    print('❌ Error fixing client location UI: $e');
  }
}

Future<void> fixDuplicateLocationSection(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    throw 'File not found: $filePath';
  }
  
  final content = await file.readAsString();
  
  // Find the duplicated client location section
  final firstLocationSection = content.indexOf('// إضافة قسم لموقع العميل إذا كان متاحاً');
  if (firstLocationSection == -1) {
    print('No duplicate client location section found - already fixed');
    return;
  }
  
  final secondLocationSection = content.indexOf('// إضافة قسم لموقع العميل إذا كان متاحاً', firstLocationSection + 10);
  if (secondLocationSection == -1) {
    print('No duplicate client location section found - already fixed');
    return;
  }
  
  // Find the end of the first client location section
  final firstSectionEnd = content.indexOf('const SizedBox(height: 16),', firstLocationSection) + 'const SizedBox(height: 16),'.length;
  if (firstSectionEnd == -1) {
    throw 'Could not find end of first client location section';
  }
  
  // Find the end of the second client location section
  final secondSectionEnd = content.indexOf('const SizedBox(height: 16),', secondLocationSection) + 'const SizedBox(height: 16),'.length;
  if (secondSectionEnd == -1) {
    throw 'Could not find end of second client location section';
  }
  
  // Remove the duplicated section
  final updatedContent = content.substring(0, firstLocationSection) + 
    content.substring(firstSectionEnd, secondLocationSection) + 
    content.substring(secondSectionEnd);
  
  await file.writeAsString(updatedContent);
}

Future<void> fixClientLocationRendering(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    throw 'File not found: $filePath';
  }
  
  final content = await file.readAsString();
  
  // Find the client location section in UI
  final clientLocationSection = content.indexOf('// إضافة قسم لموقع العميل إذا كان متاحاً');
  if (clientLocationSection == -1) {
    throw 'Could not find client location section';
  }
  
  // Find the condition that controls whether to show client location
  final locationCondition = content.indexOf('if (_initialCameraPosition != null && _markers.isNotEmpty && !_hasTransportRequestData)', clientLocationSection);
  if (locationCondition == -1) {
    throw 'Could not find client location condition';
  }
  
  // Define a better condition
  const newCondition = 'if (_initialCameraPosition != null && _markers.isNotEmpty)';
  
  // Replace the condition
  final updatedContent = content.substring(0, locationCondition) + 
    newCondition + 
    content.substring(locationCondition + 'if (_initialCameraPosition != null && _markers.isNotEmpty && !_hasTransportRequestData)'.length);
  
  await file.writeAsString(updatedContent);
}
