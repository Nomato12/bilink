import 'dart:io';

void main() async {
  // Define the file path
  final filePath = 'd:\\bilink\\lib\\screens\\directions_map_tracking.dart';
  
  // Read the file content
  final fileContent = await File(filePath).readAsString();
  
  // Find and replace the _stopTracking method
  final oldStopTrackingMethod = RegExp(
    r'void _stopTracking\(\) {[\s\S]*?_isTracking = false;[\s\S]*?}\s*\)'
  );
  
  final newStopTrackingMethod = '''
  void _stopTracking() {
    if (_navigationUpdateTimer != null) {
      _navigationUpdateTimer!.cancel();
      _navigationUpdateTimer = null;
    }
    
    if (_positionStreamSubscription != null) {
      _positionStreamSubscription!.cancel();
      _positionStreamSubscription = null;
    }
    
    if (mounted) {
      setState(() {
        _isTracking = false;
      });
    }
  }''';
  
  // Replace all setState calls in the timer with mounted checks
  String updatedContent = fileContent.replaceAllMapped(
    RegExp(r'setState\(\(\) {(?:[^{}]|{[^{}]*})*?}\);'),
    (match) {
      final stateSetContent = match.group(0)!;
      if (stateSetContent.contains('mounted')) {
        return stateSetContent;
      }
      return 'if (mounted) {\n      ${stateSetContent}\n    }';
    }
  );
  
  // Replace the _stopTracking method
  updatedContent = updatedContent.replaceAll(
    RegExp(r'void _stopTracking\(\) {[\s\S]*?setState\(\(\) {[\s\S]*?_isTracking = false;[\s\S]*?}\);[\s\S]*?}'),
    newStopTrackingMethod
  );
  
  // Add mounted checks to _updateCurrentLocationMarker
  updatedContent = updatedContent.replaceAll(
    RegExp(r'void _updateCurrentLocationMarker\(LatLng position\)[^{]*{'),
    'void _updateCurrentLocationMarker(LatLng position) {\n    if (!mounted) return;\n'
  );
  
  // Write the updated content back to the file
  await File(filePath).writeAsString(updatedContent);
  
  print('Successfully fixed _lifecycleState assertion error in ${filePath}');
}
