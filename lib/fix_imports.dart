// This is a utility file to fix the math import in the transport_service_map_updated.dart file
import 'dart:io';

void main() async {
  final file = File('d:/bilink/lib/screens/transport_service_map_updated.dart');
  String content = await file.readAsString();
  
  // Add the import if it doesn't exist
  if (!content.contains("import 'dart:math' as math;")) {
    content = content.replaceFirst(
      "import 'dart:async';",
      "import 'dart:async';\nimport 'dart:math' as math;"
    );
    
    // Remove the local math class definition if it exists
    final mathClassPattern = RegExp(r"class math \{[\s\S]*?static double max\([^\)]*\) => [^\;]*;\s*\}");
    content = content.replaceAll(mathClassPattern, '');
    
    await file.writeAsString(content);
    print('Successfully added math import and removed local math class');
  } else {
    print('math import already exists');
  }
  
  // Add flutter_polyline_points import if it doesn't exist
  if (!content.contains("import 'package:flutter_polyline_points/flutter_polyline_points.dart';")) {
    content = content.replaceFirst(
      "import 'package:cached_network_image/cached_network_image.dart';",
      "import 'package:cached_network_image/cached_network_image.dart';\nimport 'package:flutter_polyline_points/flutter_polyline_points.dart';"
    );
    
    await file.writeAsString(content);
    print('Successfully added flutter_polyline_points import');
  } else {
    print('flutter_polyline_points import already exists');
  }
}
