import 'package:intl/intl.dart';

class ProviderStatistics {
  final String id;
  final DateTime date;
  final String requestId;
  final String serviceId;
  final String serviceName;
  final String serviceType; // 'نقل' أو 'تخزين'
  final double totalAmount;
  final double providerAmount; // 80% من totalAmount
  final double appFee; // 20% من totalAmount
  final String status; // 'completed', 'ongoing', 'cancelled'
  final String durationType; // 'يومي', 'شهري', 'سنوي' أو فارغ

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
  })  : providerAmount = totalAmount * 0.8,
        appFee = totalAmount * 0.2;

  // دالة تصحيحية للتحويل من Map مهما كان نوع البيانات
  factory ProviderStatistics.fromMap(Map<String, dynamic> map, String id) {
    // إصلاح التاريخ من أي نوع
    DateTime date;
    if (map['date'] is DateTime) {
      date = map['date'];
    } else if (map['date'] is String) {
      date = DateTime.tryParse(map['date']) ?? DateTime.now();
    } else if (map['date'] != null && map['date'].toString().contains('Timestamp')) {
      // Firestore Timestamp
      date = (map['date'] as dynamic).toDate();
    } else {
      date = DateTime.now();
    }

    // إصلاح المبلغ مهما كان نوعه
    double totalAmount = 0.0;
    var amountVal = map['amount'];
    if (amountVal is int) {
      totalAmount = amountVal.toDouble();
    } else if (amountVal is double) {
      totalAmount = amountVal;
    } else if (amountVal is String) {
      totalAmount = double.tryParse(amountVal) ?? 0.0;
    }

    return ProviderStatistics(
      id: id,
      date: date,
      requestId: map['requestId'] ?? '',
      serviceId: map['serviceId'] ?? '',
      serviceName: map['serviceName'] ?? 'خدمة',
      serviceType: map['serviceType'] ?? 'تخزين',
      totalAmount: totalAmount,
      status: map['status'] ?? 'completed',
      durationType: map['durationType'] ?? '',
    );
  }

  // تحويل إلى Map للفاييرستور
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

  // أدوات تنسيق التاريخ
  String get formattedDate => DateFormat('yyyy-MM-dd').format(date);
  String get formattedDateTime => DateFormat('yyyy-MM-dd HH:mm').format(date);

  String get monthName => DateFormat('MMMM', 'ar').format(date);

  String get dayName => DateFormat('EEEE', 'ar').format(date);
}

// مدير العمليات الإحصائية
class ProviderStatisticsManager {
  List<ProviderStatistics> statistics = [];

  ProviderStatisticsManager(this.statistics);

  // مجموع الأرباح
  double getTotalEarnings() {
    return statistics
        .where((stat) => stat.status == 'completed')
        .fold(0.0, (sum, stat) => sum + stat.providerAmount);
  }

  // عدد كل الطلبات
  int getTotalRequests() {
    return statistics.length;
  }

  // عدد الطلبات المكتملة
  int getCompletedRequests() {
    return statistics.where((stat) => stat.status == 'completed').length;
  }

  // أرباح ليوم محدد
  double getEarningsForDate(DateTime date) {
    return statistics
        .where((stat) =>
            stat.status == 'completed' &&
            stat.date.year == date.year &&
            stat.date.month == date.month &&
            stat.date.day == date.day)
        .fold(0.0, (sum, stat) => sum + stat.providerAmount);
  }

  // أرباح لشهر محدد
  double getEarningsForMonth(int year, int month) {
    return statistics
        .where((stat) =>
            stat.status == 'completed' &&
            stat.date.year == year &&
            stat.date.month == month)
        .fold(0.0, (sum, stat) => sum + stat.providerAmount);
  }

  // أرباح النقل
  double getTransportEarnings() {
    return statistics
        .where((stat) => stat.status == 'completed' && stat.serviceType == 'نقل')
        .fold(0.0, (sum, stat) => sum + stat.providerAmount);
  }

  // أرباح التخزين
  double getStorageEarnings() {
    return statistics
        .where((stat) => stat.status == 'completed' && stat.serviceType == 'تخزين')
        .fold(0.0, (sum, stat) => sum + stat.providerAmount);
  }

  // إحصاءات يومية لشهر
  Map<int, double> getDailyStatsForMonth(int year, int month) {
    final Map<int, double> dailyStats = {};

    for (var stat in statistics.where((s) =>
        s.status == 'completed' &&
        s.date.year == year &&
        s.date.month == month)) {
      final day = stat.date.day;
      dailyStats[day] = (dailyStats[day] ?? 0.0) + stat.providerAmount;
    }

    return dailyStats;
  }

  // إحصاءات شهرية لسنة
  Map<int, double> getMonthlyStatsForYear(int year) {
    final Map<int, double> monthlyStats = {};

    for (var stat in statistics.where((s) =>
        s.status == 'completed' && s.date.year == year)) {
      final month = stat.date.month;
      monthlyStats[month] = (monthlyStats[month] ?? 0.0) + stat.providerAmount;
    }

    return monthlyStats;
  }

  // إحصاءات سنوية
  Map<int, double> getYearlyStats() {
    final Map<int, double> yearlyStats = {};

    for (var stat in statistics.where((s) => s.status == 'completed')) {
      final year = stat.date.year;
      yearlyStats[year] = (yearlyStats[year] ?? 0.0) + stat.providerAmount;
    }

    return yearlyStats;
  }

  // إحصاءات حسب نوع الخدمة
  Map<String, double> getStatsByServiceType() {
    final Map<String, double> typeStats = {'نقل': 0.0, 'تخزين': 0.0};

    for (var stat in statistics.where((s) => s.status == 'completed')) {
      typeStats[stat.serviceType] = (typeStats[stat.serviceType] ?? 0.0) + stat.providerAmount;
    }

    return typeStats;
  }

  // إحصاءات التخزين حسب المدة
  Map<String, double> getStatsByStorageDurationType() {
    final Map<String, double> durationStats = {'يومي': 0.0, 'شهري': 0.0, 'سنوي': 0.0};

    for (var stat in statistics.where((s) =>
        s.status == 'completed' && s.serviceType == 'تخزين')) {
      durationStats[stat.durationType] = (durationStats[stat.durationType] ?? 0.0) + stat.providerAmount;
    }

    return durationStats;
  }
}
