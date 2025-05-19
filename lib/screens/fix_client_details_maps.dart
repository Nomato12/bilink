// تعديل لإزالة الخرائط من معلومات العميل في صفحة provider_interface.dart

import 'dart:io';

void main() async {
  final filePath = 'd:/bilink/lib/screens/client_details_screen.dart';
  final backupPath = 'd:/bilink/lib/screens/client_details_screen.dart.bak';
  
  try {
    // إنشاء نسخة احتياطية من الملف الأصلي
    final originalFile = File(filePath);
    if (await originalFile.exists()) {
      await originalFile.copy(backupPath);
      print('تم إنشاء نسخة احتياطية: $backupPath');
    }
    
    // قراءة محتوى الملف
    String content = await originalFile.readAsString();
    
    // القسم الأول: حذف خريطة ملف التفاصيل الشخصي للعميل
    content = _removeFirstMapSection(content);
    
    // القسم الثاني: حذف خريطة قسم طلبات النقل
    content = _removeSecondMapSection(content);
    
    // حفظ التعديلات على الملف
    await originalFile.writeAsString(content);
    
    print('تم حذف أقسام الخرائط من ملف معلومات العميل بنجاح!');
  } catch (e) {
    print('حدث خطأ أثناء تحديث الملف: $e');
  }
}

String _removeFirstMapSection(String content) {
  // علامة بداية القسم
  final startMarker = r"""                                if (_destinationLocation != null) ...[
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      children: [                                        ElevatedButton.icon(""";
  
  // علامة نهاية القسم - تنتهي قبل تبديل إلى else
  final endMarker = r"""                                ],
                                    ),
                                  ),
                                ] else ...[""";

  // العثور على موقع بداية ونهاية القسم
  final startIndex = content.indexOf(startMarker);
  final endIndex = content.indexOf(endMarker);
  
  if (startIndex != -1 && endIndex != -1) {
    // إنشاء القسم الجديد بدون الخريطة
    final prefix = content.substring(0, startIndex);
    final suffix = content.substring(endIndex);
    
    // نص التعليق الذي سيظهر بدلاً من الخريطة
    const replacementText = """
                                // تم إزالة أزرار الملاحة وأدوات الخريطة
                                } else { // نهاية if (_destinationLocation != null)
                                  // تم إزالة أزرار الملاحة وأدوات الخريطة
""";
    
    return prefix + replacementText + suffix;
  }
  
  return content;
}

String _removeSecondMapSection(String content) {
  // العثور على قسم الخريطة الثانية في صفحة طلبات النقل
  final secondMapStartMarker = r"""                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (_markers.any((m) => m.markerId.value == 'origin'))""";
  
  // نهاية قسم الخريطة الثانية
  final secondMapEndMarker = r"""                                  Container(
                                    height: 250,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(16),
                                      ),
                                    ),
                                    child: GoogleMap(
                                      initialCameraPosition: _initialCameraPosition!,
                                      markers: _markers,
                                      polylines: _polylines,
                                      myLocationEnabled: false,
                                      myLocationButtonEnabled: false,
                                      zoomControlsEnabled: true,
                                      mapToolbarEnabled: true,
                                      onMapCreated: (controller) {
                                        _mapController = controller;
                                      },
                                    ),
                                  ),""";

  // العثور على موقع بداية ونهاية القسم الثاني
  final startIndex = content.indexOf(secondMapStartMarker);
  
  if (startIndex != -1) {
    final endIndex = content.indexOf(secondMapEndMarker);
    
    if (endIndex != -1) {
      final endPosition = endIndex + secondMapEndMarker.length;
      
      final prefix = content.substring(0, startIndex);
      final suffix = content.substring(endPosition);
      
      return "$prefix                                  // تم إزالة قسم خريطة المسار\n$suffix";
    }
  }
  
  return content;
}
