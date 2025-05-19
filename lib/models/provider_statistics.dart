// Provider statistics model to manage and process provider income data
import 'package:intl/intl.dart';

class ProviderStatistics {
  final String id;
  final DateTime date;
  final String requestId;
  final String serviceId;
  final String serviceName;
  final String serviceType; // 'نقل' or 'تخزين'
  final double totalAmount;
  final double providerAmount; // 80% of totalAmount
  final double appFee; // 20% of totalAmount
  final String status; // 'completed', 'ongoing', 'cancelled'
  final String durationType; // For storage: 'يومي', 'شهري', 'سنوي'

  ProviderStatistics({
    required this.id,
    required this.date,
    required this.requestId,
    required this.serviceId,
    required this.serviceName,
    required this.serviceType,
    required this.totalAmount,
    required this.status,
    this.durationType = '',
  }) : 
    providerAmount = totalAmount * 0.8, // Provider gets 80%
    appFee = totalAmount * 0.2; // App takes 20%
  
  // Factory constructor from Firestore document
  factory ProviderStatistics.fromMap(Map<String, dynamic> map, String id) {
    return ProviderStatistics(
      id: id,
      date: map['date'] != null 
          ? (map['date'] as DateTime) 
          : DateTime.now(),
      requestId: map['requestId'] ?? '',
      serviceId: map['serviceId'] ?? '',
      serviceName: map['serviceName'] ?? 'خدمة',
      serviceType: map['serviceType'] ?? 'تخزين',
      totalAmount: (map['amount'] ?? 0).toDouble(),
      status: map['status'] ?? 'completed',
      durationType: map['durationType'] ?? '',
    );
  }
  
  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'requestId': requestId,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'serviceType': serviceType,
      'amount': totalAmount,
      'providerAmount': providerAmount,
      'appFee': appFee,
      'status': status,
      'durationType': durationType,
    };
  }
  
  // Helper methods for date formatting
  String get formattedDate => DateFormat('yyyy-MM-dd').format(date);
  String get formattedDateTime => DateFormat('yyyy-MM-dd HH:mm').format(date);
  
  // Get month name
  String get monthName => DateFormat('MMMM', 'ar').format(date);
  
  // Get day name
  String get dayName => DateFormat('EEEE', 'ar').format(date);
}

// Class to manage statistics calculations
class ProviderStatisticsManager {
  List<ProviderStatistics> statistics = [];
  
  ProviderStatisticsManager(this.statistics);
  
  // Calculate total earnings
  double getTotalEarnings() {
    return statistics
        .where((stat) => stat.status == 'completed')
        .fold(0, (sum, stat) => sum + stat.providerAmount);
  }
  
  // Get total requests count
  int getTotalRequests() {
    return statistics.length;
  }
  
  // Get completed requests count
  int getCompletedRequests() {
    return statistics.where((stat) => stat.status == 'completed').length;
  }
  
  // Get earnings for specific date
  double getEarningsForDate(DateTime date) {
    return statistics
        .where((stat) => 
            stat.status == 'completed' && 
            stat.date.year == date.year &&
            stat.date.month == date.month &&
            stat.date.day == date.day)
        .fold(0, (sum, stat) => sum + stat.providerAmount);
  }
  
  // Get earnings for specific month
  double getEarningsForMonth(int year, int month) {
    return statistics
        .where((stat) => 
            stat.status == 'completed' &&
            stat.date.year == year &&
            stat.date.month == month)
        .fold(0, (sum, stat) => sum + stat.providerAmount);
  }
  
  // Get earnings for transport services
  double getTransportEarnings() {
    return statistics
        .where((stat) => stat.status == 'completed' && stat.serviceType == 'نقل')
        .fold(0, (sum, stat) => sum + stat.providerAmount);
  }
  
  // Get earnings for storage services
  double getStorageEarnings() {
    return statistics
        .where((stat) => stat.status == 'completed' && stat.serviceType == 'تخزين')
        .fold(0, (sum, stat) => sum + stat.providerAmount);
  }
  
  // Get daily statistics for a month
  Map<int, double> getDailyStatsForMonth(int year, int month) {
    final Map<int, double> dailyStats = {};
    
    for (var stat in statistics.where((s) => 
        s.status == 'completed' && 
        s.date.year == year && 
        s.date.month == month)) {
      final day = stat.date.day;
      dailyStats[day] = (dailyStats[day] ?? 0) + stat.providerAmount;
    }
    
    return dailyStats;
  }
  
  // Get monthly statistics for a year
  Map<int, double> getMonthlyStatsForYear(int year) {
    final Map<int, double> monthlyStats = {};
    
    for (var stat in statistics.where((s) => 
        s.status == 'completed' && 
        s.date.year == year)) {
      final month = stat.date.month;
      monthlyStats[month] = (monthlyStats[month] ?? 0) + stat.providerAmount;
    }
    
    return monthlyStats;
  }
  
  // Get yearly statistics
  Map<int, double> getYearlyStats() {
    final Map<int, double> yearlyStats = {};
    
    for (var stat in statistics.where((s) => s.status == 'completed')) {
      final year = stat.date.year;
      yearlyStats[year] = (yearlyStats[year] ?? 0) + stat.providerAmount;
    }
    
    return yearlyStats;
  }
  
  // Get stats by service type
  Map<String, double> getStatsByServiceType() {
    final Map<String, double> typeStats = {'نقل': 0, 'تخزين': 0};
    
    for (var stat in statistics.where((s) => s.status == 'completed')) {
      typeStats[stat.serviceType] = (typeStats[stat.serviceType] ?? 0) + stat.providerAmount;
    }
    
    return typeStats;
  }
  
  // Get storage stats by duration type
  Map<String, double> getStatsByStorageDurationType() {
    final Map<String, double> durationStats = {'يومي': 0, 'شهري': 0, 'سنوي': 0};
    
    for (var stat in statistics.where((s) => 
        s.status == 'completed' && 
        s.serviceType == 'تخزين')) {
      durationStats[stat.durationType] = (durationStats[stat.durationType] ?? 0) + stat.providerAmount;
    }
    
    return durationStats;
  }
}
