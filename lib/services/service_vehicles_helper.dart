
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

/// A helper class for calculating prices for transport services based on vehicle type and distance.
class ServiceVehiclesHelper {
  /// Base prices for different vehicle types (in Algerian Dinar per km)
  static final Map<String, double> basePricesPerKm = {
    'شاحنة صغيرة': 80.0,
    'شاحنة متوسطة': 100.0,
    'شاحنة كبيرة': 120.0,
    'مركبة خفيفة': 60.0,
    'دراجة نارية': 50.0,
    'وانيت': 70.0,
    'دينا': 90.0,
    'تريلا': 130.0,
    // Default price per km if vehicle type is not matched
    'default': 70.0,
  };

  /// Minimum prices for each vehicle type regardless of distance
  static final Map<String, double> minimumPrices = {
    'شاحنة صغيرة': 500.0,
    'شاحنة متوسطة': 700.0,
    'شاحنة كبيرة': 1000.0,
    'مركبة خفيفة': 300.0,
    'دراجة نارية': 200.0,
    'وانيت': 500.0,
    'دينا': 800.0,
    'تريلا': 1200.0,
    // Default minimum price
    'default': 400.0,
  };

  /// Calculate the price for a transport service based on vehicle type and distance
  static double calculatePrice({
    required String vehicleType,
    required double distanceInKm,
    double? basePriceAdjustment,
  }) {
    // Get the base price per km for this vehicle type or use default
    final basePricePerKm = basePricesPerKm[vehicleType] ?? basePricesPerKm['default']!;
    
    // Apply custom price adjustment if provided
    final effectiveBasePricePerKm = basePricePerKm * (basePriceAdjustment ?? 1.0);
    
    // Calculate the price based on distance
    double calculatedPrice = effectiveBasePricePerKm * distanceInKm;
    
    // Ensure the price meets the minimum price for this vehicle type
    final minPrice = minimumPrices[vehicleType] ?? minimumPrices['default']!;
    if (calculatedPrice < minPrice) {
      calculatedPrice = minPrice;
    }
    
    // Round to the nearest 10 dinars for a cleaner price
    int roundedPrice = (calculatedPrice / 10).round() * 10;
    
    return roundedPrice.toDouble();
  }

  /// Calculate the price for a transport service based on origin and destination points
  static double calculatePriceFromCoordinates({
    required String vehicleType,
    required LatLng originLocation,
    required LatLng destinationLocation,
    double? routeDistance,
    double? basePriceAdjustment,
  }) {
    // If route distance is provided (from actual route calculation), use it
    if (routeDistance != null && routeDistance > 0) {
      return calculatePrice(
        vehicleType: vehicleType, 
        distanceInKm: routeDistance,
        basePriceAdjustment: basePriceAdjustment,
      );
    }
    
    // Otherwise calculate the direct distance between points
    final directDistance = calculateDistance(
      originLocation.latitude,
      originLocation.longitude,
      destinationLocation.latitude,
      destinationLocation.longitude,
    );
    
    // Add 20% to the direct distance to account for actual road distance
    final estimatedRouteDistance = directDistance * 1.2;
    
    return calculatePrice(
      vehicleType: vehicleType, 
      distanceInKm: estimatedRouteDistance,
      basePriceAdjustment: basePriceAdjustment,
    );
  }

  /// Format price as a string with currency
  static String formatPrice(double price) {
    return '${price.toInt()} دج';
  }

  /// Calculate the direct distance between two points (in kilometers)
  static double calculateDistance(
    double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);
    
    double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  /// Convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Calculate estimated arrival time based on distance (returns minutes)
  static int calculateArrivalTime(double distanceInKm) {
    // Assume average speed of 40 km/hour
    double timeInHours = distanceInKm / 40;
    return (timeInHours * 60).round() + 5; // Add 5 minutes preparation time
  }

  /// Get database record with price data to be stored with transport request
  static Map<String, dynamic> getPriceDataForRequest({
    required String vehicleType,
    required double distance,
    required double price,
    required String distanceText,
    String? durationText,
  }) {
    return {
      'vehicleType': vehicleType,
      'distance': distance,
      'price': price,
      'distanceText': distanceText,
      'durationText': durationText ?? '${calculateArrivalTime(distance).toString()} دقيقة',
      'calculatedAt': FieldValue.serverTimestamp(),
    };
  }
  
  /// Get default vehicle image URL based on vehicle type
  static String getDefaultVehicleImage(String vehicleType) {
    final lowerType = vehicleType.toLowerCase();
    
    if (lowerType.contains('صغيرة') || lowerType == 'وانيت') {
      return 'https://firebasestorage.googleapis.com/v0/b/bilink-b0381.appspot.com/o/vehicles%2Fsmall_truck.png?alt=media';
    } else if (lowerType.contains('متوسطة') || lowerType == 'دينا') {
      return 'https://firebasestorage.googleapis.com/v0/b/bilink-b0381.appspot.com/o/vehicles%2Fmedium_truck.png?alt=media';
    } else if (lowerType.contains('كبيرة') || lowerType == 'تريلا') {
      return 'https://firebasestorage.googleapis.com/v0/b/bilink-b0381.appspot.com/o/vehicles%2Flarge_truck.png?alt=media';
    } else if (lowerType.contains('دراجة') || lowerType.contains('نارية')) {
      return 'https://firebasestorage.googleapis.com/v0/b/bilink-b0381.appspot.com/o/vehicles%2Fmotorcycle.png?alt=media';
    } else if (lowerType.contains('خفيفة') || lowerType.contains('سيارة')) {
      return 'https://firebasestorage.googleapis.com/v0/b/bilink-b0381.appspot.com/o/vehicles%2Fcar.png?alt=media';
    }
    
    // Default image
    return 'https://firebasestorage.googleapis.com/v0/b/bilink-b0381.appspot.com/o/vehicles%2Fgeneric_vehicle.png?alt=media';
  }
  
  /// Check if a vehicle type matches the required type
  /// This handles different naming conventions and partial matches
  static bool isMatchingVehicleType(String vehicleType, String requiredType) {
    if (requiredType.isEmpty) return true;
    
    final lowerVehicleType = vehicleType.toLowerCase();
    final lowerRequiredType = requiredType.toLowerCase();
    
    // Direct match
    if (lowerVehicleType == lowerRequiredType) return true;
    
    // Partial matches based on keywords
    if (lowerRequiredType.contains('صغيرة') && 
        (lowerVehicleType.contains('صغيرة') || lowerVehicleType == 'وانيت')) {
      return true;
    }
    
    if (lowerRequiredType.contains('متوسطة') && 
        (lowerVehicleType.contains('متوسطة') || lowerVehicleType == 'دينا')) {
      return true;
    }
    
    if (lowerRequiredType.contains('كبيرة') && 
        (lowerVehicleType.contains('كبيرة') || lowerVehicleType == 'تريلا')) {
      return true;
    }
    
    if (lowerRequiredType.contains('خفيفة') && 
        (lowerVehicleType.contains('خفيفة') || lowerVehicleType.contains('سيارة'))) {
      return true;
    }
    
    if ((lowerRequiredType.contains('دراجة') || lowerRequiredType.contains('نارية')) && 
        (lowerVehicleType.contains('دراجة') || lowerVehicleType.contains('نارية'))) {
      return true;
    }
    
    return false;
  }
}