# Provider Statistics Integration Documentation

This document describes the integration of the Provider Statistics system with service requests in the Bilink app.

## Overview

The Provider Statistics system tracks earnings from both transport and storage services. It:

1. Calculates provider earnings (80% of total price) and platform fees (20%)
2. Tracks earnings over time (daily, monthly, yearly)
3. Provides visualizations for data analysis
4. Persists statistics data to the Firestore database

## Integration Points

### 1. Service Request Card (Transport Services)

The `service_request_card.dart` file handles requests for both transport and storage services. When a request's status is updated to "accepted" or "completed", the provider statistics are updated automatically:

```dart
// Update statistics if request is accepted or completed
if (newStatus == 'accepted' || newStatus == 'completed') {
  try {
    final providerStatisticsService = ProviderStatisticsService();
    final bool statsUpdated = await providerStatisticsService.registerServiceEarnings(
      requestId,
      newStatus,
    );
    
    if (statsUpdated) {
      print('تم تحديث الإحصائيات بنجاح للطلب $requestId');
    } else {
      print('فشل تحديث الإحصائيات للطلب $requestId');
    }
  } catch (e) {
    print('خطأ في تحديث الإحصائيات: $e');
  }
}
```

### 2. Price Calculation

#### Transport Services:
For transport services, the price is calculated in `nearby_vehicles_map.dart`:

```dart
double price = basePrice + (routeDistanceKm * 20);
int roundedPrice = (price / 10).round() * 10;
```

This price is stored directly in the service request document and retrieved by the statistics service.

#### Storage Services:
For storage services, the price is stored in the service document itself, and the statistics service retrieves it from there.

## Data Flow

1. When a client makes a request, the price is calculated and stored in the request document
2. When a provider accepts or completes the request, the `ProviderStatisticsService` is triggered
3. The service retrieves the price from the request or service document
4. The statistics data is stored in a dedicated `provider_statistics` collection

## Testing

You can test the statistics integration using the provided test script:

```
dart test_provider_statistics.dart
```

Be sure to replace the test request ID with a real request ID from your database.

## Statistics Service API

The `ProviderStatisticsService` provides the following methods:

- `registerServiceEarnings(String requestId, String status)`: Records earnings for a service request
- `getDailyStatistics(DateTime date)`: Gets statistics for a specific day
- `getMonthlyStatistics(int year, int month)`: Gets statistics for a specific month
- `getYearlyStatistics(int year)`: Gets statistics for a specific year
- `getServiceTypeBreakdown()`: Gets earnings breakdown by service type

## Provider Statistics Model

The `ProviderStatistics` model handles calculations for:

- Provider earnings (80% of total price)
- Platform fees (20% of total price) 
- Grouping statistics by date and service type
