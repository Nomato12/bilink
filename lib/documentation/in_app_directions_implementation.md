# In-App Directions Implementation for BiLink

This guide explains how to implement in-app directions in the BiLink application, replacing the behavior of opening Google Maps when a user taps "Get Directions" on a service details screen.

## Components

1. **DirectionsHelper** - A utility service for calculating routes and directions
2. **DirectionsMapScreen** - A screen that displays the map with directions
3. **ServiceDetailsScreen** - Updated to use the in-app directions instead of launching Google Maps

## Implementation Steps

### 1. Fix the Math Calculations

The distance calculation in the `directions_helper.dart` file has been updated to use proper math functions:

```dart
static double _calculateDistance(LatLng start, LatLng end) {
  const double earthRadius = 6371; // بالكيلومترات
  final double lat1 = start.latitude * (math.pi / 180);
  final double lng1 = start.longitude * (math.pi / 180);
  final double lat2 = end.latitude * (math.pi / 180);
  final double lng2 = end.longitude * (math.pi / 180);
  final double dLat = lat2 - lat1;
  final double dLng = lng2 - lng1;
  
  final double a = 
      math.sin(dLat/2) * math.sin(dLat/2) +
      math.sin(dLng/2) * math.sin(dLng/2) * math.cos(lat1) * math.cos(lat2);
  final double c = 2 * math.asin(math.sqrt(a));
  
  return earthRadius * c;
}
```

### 2. Update the Service Details Screen

In `service_details_screen.dart`, locate the `_launchMapsUrl` method and replace it with:

```dart
Future<void> _launchMapsUrl(double latitude, double longitude) async {
  // بدلا من فتح Google Maps، سننتقل إلى خريطة التطبيق مع تحديد الوجهة
  final Map<String, dynamic>? locationData = _serviceData?.containsKey('location') 
      ? _serviceData!['location'] as Map<String, dynamic>? 
      : null;
      
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => DirectionsMapScreen(
        destinationLocation: LatLng(latitude, longitude),
        destinationName: locationData?['name'] ?? _serviceData?['title'] ?? '',
      ),
    ),
  );
}
```

Also update the import at the top of the file:

```dart
import 'package:bilink/screens/directions_map_screen_simple.dart'; // إضافة استيراد شاشة خريطة الاتجاهات البسيطة
```

### 3. How It Works

1. When a user taps "Get Directions" on the service details screen, the app will open an in-app map view
2. The map will:
   - Show the user's current location
   - Show the destination location
   - Draw a direct route between the two points
   - Calculate approximate distance and travel time
   - Display a panel with step-by-step directions
   - Provide a button to open Google Maps for full navigation if needed

### 4. Notes on Implementation

- **Simple Route Visualization**: The current implementation draws a direct route between the two points. For more advanced routing (with proper roads and turns), you would need to use the Google Directions API with an API key.
- **Additional Features**: Consider enhancing the directions panel with more detailed information and navigation instructions.
- **Testing**: Test thoroughly on different device sizes and with different locations to ensure smooth user experience.

### 5. Future Enhancements

1. Add more detailed route visualization (turns, waypoints)
2. Implement alternative routes
3. Add voice guidance for navigation
4. Enhance the directions panel UI with more intuitive design
