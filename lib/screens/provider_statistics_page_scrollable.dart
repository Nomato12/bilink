// Provider statistics page with scrollable content
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:bilink/services/provider_statistics_service.dart';
import 'dart:math' as math;
import 'package:bilink/models/provider_statistics.dart';

class ProviderStatisticsPage extends StatefulWidget {
  const ProviderStatisticsPage({Key? key}) : super(key: key);

  @override
  _ProviderStatisticsPageState createState() => _ProviderStatisticsPageState();
}

// Helper class for SliverPersistentHeader
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.black,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

class _ProviderStatisticsPageState extends State<ProviderStatisticsPage> with SingleTickerProviderStateMixin {
  final ProviderStatisticsService _statisticsService = ProviderStatisticsService();
  late TabController _tabController;
  
  List<ProviderStatistics> _statistics = [];
  bool _isLoading = true;
  Map<String, dynamic> _summary = {};
  
  // View period states
  String _selectedPeriod = 'شهري';
  final List<String> _periods = ['يومي', 'شهري', 'سنوي'];
  
  // Current period
  DateTime _currentDate = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedPeriod = _periods[_tabController.index];
        });
      }
    });
    
    // Initialize date formatting for Arabic
    initializeDateFormatting('ar', null).then((_) {
      _loadStatistics();
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });
      try {
      final stats = await _statisticsService.getProviderStatistics();
      final summary = await _statisticsService.getStatisticsSummary();
      
      print('Loaded ${stats.length} statistics entries');
      print('Completed transactions: ${stats.where((s) => s.status == 'completed').length}');
      
      setState(() {
        _statistics = stats;
        _summary = summary;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading statistics: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Navigate to previous period
  void _previousPeriod() {
    setState(() {
      if (_selectedPeriod == 'يومي') {
        _currentDate = _currentDate.subtract(const Duration(days: 1));
      } else if (_selectedPeriod == 'شهري') {
        _currentDate = DateTime(
          _currentDate.year, 
          _currentDate.month - 1, 
          _currentDate.day,
        );
      } else {
        _currentDate = DateTime(
          _currentDate.year - 1, 
          _currentDate.month, 
          _currentDate.day,
        );
      }
    });
  }
  
  // Navigate to next period
  void _nextPeriod() {
    final now = DateTime.now();
    
    // Don't allow navigating beyond current date
    if ((_selectedPeriod == 'يومي' && 
         _currentDate.year == now.year && 
         _currentDate.month == now.month && 
         _currentDate.day == now.day) ||
        (_selectedPeriod == 'شهري' && 
         _currentDate.year == now.year && 
         _currentDate.month == now.month) ||
        (_selectedPeriod == 'سنوي' && 
         _currentDate.year == now.year)) {
      return;
    }
    
    setState(() {
      if (_selectedPeriod == 'يومي') {
        _currentDate = _currentDate.add(const Duration(days: 1));
      } else if (_selectedPeriod == 'شهري') {
        _currentDate = DateTime(
          _currentDate.year, 
          _currentDate.month + 1, 
          _currentDate.day,
        );
      } else {
        _currentDate = DateTime(
          _currentDate.year + 1, 
          _currentDate.month, 
          _currentDate.day,
        );
      }
    });
  }
  
  // Reset to current period
  void _resetToToday() {
    setState(() {
      _currentDate = DateTime.now();
    });
  }
  
  // Format current period for display
  String _formatCurrentPeriod() {
    if (_selectedPeriod == 'يومي') {
      return DateFormat('yyyy/MM/dd', 'ar').format(_currentDate);
    } else if (_selectedPeriod == 'شهري') {
      return DateFormat('yyyy MMMM', 'ar').format(_currentDate);
    } else {
      return DateFormat('yyyy', 'ar').format(_currentDate);
    }
  }
  
  // Calculate statistics for the selected period
  Map<String, dynamic> _getStatsForPeriod() {
    final statsManager = ProviderStatisticsManager(_statistics);
    final result = {
      'totalEarnings': 0.0,
      'totalRequests': 0,
      'chartData': <int, double>{},
    };
    
    if (_selectedPeriod == 'يومي') {
      result['totalEarnings'] = statsManager.getEarningsForDate(_currentDate);
      result['totalRequests'] = _statistics.where((s) => 
        s.date.year == _currentDate.year && 
        s.date.month == _currentDate.month && 
        s.date.day == _currentDate.day).length;
      
      // Hourly data for the day
      final Map<int, double> hourlyData = {};
      for (var stat in _statistics.where((s) => 
        s.date.year == _currentDate.year && 
        s.date.month == _currentDate.month && 
        s.date.day == _currentDate.day)) {
        final hour = stat.date.hour;
        hourlyData[hour] = (hourlyData[hour] ?? 0) + stat.providerAmount;
      }
      result['chartData'] = hourlyData;
      
    } else if (_selectedPeriod == 'شهري') {
      result['totalEarnings'] = statsManager.getEarningsForMonth(_currentDate.year, _currentDate.month);
      result['totalRequests'] = _statistics.where((s) => 
        s.date.year == _currentDate.year && 
        s.date.month == _currentDate.month).length;
      
      // Daily data for the month
      result['chartData'] = statsManager.getDailyStatsForMonth(_currentDate.year, _currentDate.month);
    } else {
      // Yearly view
      final yearStats = statsManager.getMonthlyStatsForYear(_currentDate.year);
      // Calculate total manually to avoid type issues
      double yearlyTotal = 0.0;
      yearStats.values.forEach((value) => yearlyTotal += value);
      result['totalEarnings'] = yearlyTotal;
      result['totalRequests'] = _statistics.where((s) => s.date.year == _currentDate.year).length;
      result['chartData'] = yearStats;
    }
    
    return result;
  }
  
  @override  Widget build(BuildContext context) {
    final vibrantOrange = const Color(0xFFFF7F11);
    final tealColor = Colors.teal;
    final purpleColor = const Color(0xFF9B59B6);
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF7F11)))
          : SafeArea(
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    // Header
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.teal.withOpacity(0.3), Colors.black.withOpacity(0.4)],
                          ),
                          borderRadius: BorderRadius.circular(0),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: purpleColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.bar_chart_rounded,
                                    color: purpleColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'الإحصائيات والأرباح',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'تتبع أدائك ومداخيلك',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Summary Statistics Cards
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ملخص الأداء',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatCard(
                                  title: 'إجمالي الأرباح',
                                  value: '${(_summary['totalEarnings'] ?? 0.0).toStringAsFixed(0)} دج',
                                  icon: Icons.monetization_on_rounded,
                                  color: Colors.green,
                                ),
                                _buildStatCard(
                                  title: 'الطلبات المكتملة',
                                  value: '${_summary['completedRequests'] ?? 0}',
                                  icon: Icons.check_circle_outline_rounded,
                                  color: vibrantOrange,
                                ),
                                _buildStatCard(
                                  title: 'حصة التطبيق',
                                  value: '${((_summary['totalEarnings'] ?? 0.0) * 0.2).toStringAsFixed(0)} دج',
                                  icon: Icons.account_balance_rounded,
                                  color: purpleColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildStatCard(
                                  title: 'أرباح النقل',
                                  value: '${(_summary['transportEarnings'] ?? 0.0).toStringAsFixed(0)} دج',
                                  icon: Icons.local_shipping_rounded,
                                  color: tealColor,
                                  width: 150,
                                ),
                                const SizedBox(width: 15),
                                _buildStatCard(
                                  title: 'أرباح التخزين',
                                  value: '${(_summary['storageEarnings'] ?? 0.0).toStringAsFixed(0)} دج',
                                  icon: Icons.warehouse_rounded,
                                  color: Colors.amber,
                                  width: 150,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Tabs
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverAppBarDelegate(
                        TabBar(
                          controller: _tabController,
                          labelColor: vibrantOrange,
                          unselectedLabelColor: Colors.white.withOpacity(0.6),
                          indicatorColor: vibrantOrange,
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                          tabs: [
                            const Tab(text: 'يومي'),
                            const Tab(text: 'شهري'),
                            const Tab(text: 'سنوي'),
                          ],
                        ),
                      ),
                    ),
                    
                    // Period Navigation
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: _previousPeriod,
                              icon: const Icon(Icons.chevron_left, color: Colors.white),
                            ),
                            GestureDetector(
                              onTap: _resetToToday,
                              child: Text(
                                _formatCurrentPeriod(),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _nextPeriod,
                              icon: Icon(
                                Icons.chevron_right, 
                                color: _currentDate.isBefore(DateTime.now()) 
                                    ? Colors.white 
                                    : Colors.white.withOpacity(0.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPeriodStatisticsView('يومي'),
                    _buildPeriodStatisticsView('شهري'),
                    _buildPeriodStatisticsView('سنوي'),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: vibrantOrange,
        onPressed: _loadStatistics,
        child: const Icon(Icons.refresh),
      ),
    );
  }
  
  // Build statistics card
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    double width = 100,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.07),
            Colors.white.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon with circular background
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          // Value with larger, bolder text
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          // Title with color matching the icon
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  // Build period statistics view based on selected period
  Widget _buildPeriodStatisticsView(String period) {
    final periodStats = _getStatsForPeriod();
    final totalEarnings = periodStats['totalEarnings'] as double;
    final totalRequests = periodStats['totalRequests'] as int;
    final chartData = periodStats['chartData'] as Map<int, double>;
    
    // Colors
    final vibrantOrange = const Color(0xFFFF7F11);
    final tealColor = Colors.teal.withOpacity(0.8);
    
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Period summary cards
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPeriodSummaryCard(
                    title: 'الأرباح',
                    value: '${totalEarnings.toStringAsFixed(0)} دج',
                    icon: Icons.monetization_on_rounded,
                    color: Colors.green,
                  ),
                  _buildPeriodSummaryCard(
                    title: 'الطلبات',
                    value: '$totalRequests',
                    icon: Icons.receipt_long_rounded,
                    color: vibrantOrange,
                  ),
                  _buildPeriodSummaryCard(
                    title: 'عائد التطبيق',
                    value: '${(totalEarnings * 0.2).toStringAsFixed(0)} دج',
                    icon: Icons.business_center_rounded,
                    color: const Color(0xFF9B59B6),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Chart
            Container(
              height: 220,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تحليل الأرباح',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: chartData.isEmpty 
                      ? Center(
                          child: Text(
                            'لا توجد بيانات في هذه الفترة',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                        )
                      : _buildBarChart(chartData),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Service Type Split
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'توزيع الأرباح حسب نوع الخدمة',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: _buildServiceTypePieChart(),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Storage Duration Split (only if there are storage services)
            if ((_summary['storageEarnings'] ?? 0) > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'توزيع أرباح التخزين حسب المدة',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: _buildStorageDurationPieChart(),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 20),
            
            // Recent Transactions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'آخر المعاملات',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // إصلاح: ترتيب المعاملات حسب الأحدث مع معالجة sort void
                  _statistics.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'لا توجد معاملات حديثة',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: (() {
                          final completed = _statistics
                              .where((stat) => stat.status == 'completed')
                              .toList();
                          completed.sort((a, b) => b.date.compareTo(a.date));
                          return completed
                              .take(5)
                              .map((stat) => _buildTransactionItem(stat))
                              .toList();
                        })(),
                      ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
  
  // Build period summary card
  Widget _buildPeriodSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  // Build bar chart based on period
  Widget _buildBarChart(Map<int, double> data) {
    // If no data, show placeholder
    if (data.isEmpty) {
      return Center(
        child: Text(
          'لا توجد بيانات كافية للعرض',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
      );
    }
    
    final List<BarChartGroupData> barGroups = [];
    final tealGradient = LinearGradient(
      colors: [
        Colors.teal.withOpacity(0.8),
        Colors.teal.withOpacity(0.3),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
    
    // Sort keys for proper display
    final sortedKeys = data.keys.toList()..sort();
    
    // Find max value for scaling
    final maxValue = data.values.isEmpty ? 10.0 : data.values.reduce(math.max);
    // Ensure maxValue is never zero to prevent FlGridData.horizontalInterval assertion error
    final effectiveMaxValue = maxValue > 0 ? maxValue : 10.0;
    
    for (var i = 0; i < sortedKeys.length; i++) {
      final key = sortedKeys[i];
      final value = data[key] ?? 0;
      
      barGroups.add(
        BarChartGroupData(
          x: key,
          barRods: [
            BarChartRodData(
              toY: value,
              gradient: tealGradient,
              width: _selectedPeriod == 'يومي' ? 14 : 10,
              borderRadius: BorderRadius.circular(2),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: effectiveMaxValue * 1.1,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ],
        ),
      );
    }
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.center,
        maxY: effectiveMaxValue * 1.1,
        minY: 0,
        barGroups: barGroups,
        gridData: FlGridData(
          show: true,
          horizontalInterval: effectiveMaxValue / 5,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withOpacity(0.1),
            strokeWidth: 1,
            dashArray: [5, 3],
          ),
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final xValue = value.toInt();
                String text = '';
                
                if (_selectedPeriod == 'يومي') {
                  // For daily view, show hours
                  text = '${xValue}:00';
                } else if (_selectedPeriod == 'شهري') {
                  // For monthly view, show days
                  text = '$xValue';
                } else {
                  // For yearly view, show month abbreviations
                  final months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 
                                  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
                  if (xValue >= 1 && xValue <= months.length) {
                    text = months[xValue - 1].substring(0, 3);
                  }
                }
                
                return Text(
                  text,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10,
                  ),
                );
              },
              interval: _selectedPeriod == 'يومي' ? 4 : 1,
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0) {
                  return const Text('');
                }
                return Text(
                  value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : value.toInt().toString(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 10,
                  ),
                );
              },
              interval: effectiveMaxValue / 5,
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${rod.toY.toStringAsFixed(0)} دج',
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  // Build service type pie chart
  Widget _buildServiceTypePieChart() {
    final Map<String, double> serviceTypeData = _summary['serviceTypeStats'] ?? {};
    final double transportEarnings = serviceTypeData['نقل'] ?? 0;
    final double storageEarnings = serviceTypeData['تخزين'] ?? 0;
    final total = transportEarnings + storageEarnings;
    
    // Calculate percentages
    final transportPercentage = total > 0 ? (transportEarnings / total * 100).toStringAsFixed(1) : '0';
    final storagePercentage = total > 0 ? (storageEarnings / total * 100).toStringAsFixed(1) : '0';
    
    return Row(
      children: [
        // Pie Chart
        SizedBox(
          width: 150,
          height: 150,
          child: total > 0 ? PieChart(
            PieChartData(
              sections: [
                PieChartSectionData(
                  value: transportEarnings,
                  title: '',
                  color: Colors.teal,
                  radius: 60,
                ),
                PieChartSectionData(
                  value: storageEarnings,
                  title: '',
                  color: Colors.amber,
                  radius: 60,
                ),
              ],
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              startDegreeOffset: -90,
            ),
          ) : Center(
            child: Text(
              'لا توجد بيانات',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Legend
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Transport
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'خدمات النقل',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '$transportPercentage% (${transportEarnings.toStringAsFixed(0)} دج)',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Storage
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'خدمات التخزين',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '$storagePercentage% (${storageEarnings.toStringAsFixed(0)} دج)',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Build storage duration type pie chart
  Widget _buildStorageDurationPieChart() {
    final Map<String, double> durationData = _summary['storageDurationStats'] ?? {};
    final double dailyEarnings = durationData['يومي'] ?? 0;
    final double monthlyEarnings = durationData['شهري'] ?? 0;
    final double yearlyEarnings = durationData['سنوي'] ?? 0;
    final total = dailyEarnings + monthlyEarnings + yearlyEarnings;
    
    // Calculate percentages
    final dailyPercentage = total > 0 ? (dailyEarnings / total * 100).toStringAsFixed(1) : '0';
    final monthlyPercentage = total > 0 ? (monthlyEarnings / total * 100).toStringAsFixed(1) : '0';
    final yearlyPercentage = total > 0 ? (yearlyEarnings / total * 100).toStringAsFixed(1) : '0';
    
    // Colors
    final dailyColor = Colors.orange;
    final monthlyColor = Colors.amber;
    final yearlyColor = Colors.deepOrange;
    
    return Row(
      children: [
        // Pie Chart
        SizedBox(
          width: 150,
          height: 150,
          child: total > 0 ? PieChart(
            PieChartData(
              sections: [
                PieChartSectionData(
                  value: dailyEarnings,
                  title: '',
                  color: dailyColor,
                  radius: 60,
                ),
                PieChartSectionData(
                  value: monthlyEarnings,
                  title: '',
                  color: monthlyColor,
                  radius: 60,
                ),
                PieChartSectionData(
                  value: yearlyEarnings,
                  title: '',
                  color: yearlyColor,
                  radius: 60,
                ),
              ],
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              startDegreeOffset: -90,
            ),
          ) : Center(
            child: Text(
              'لا توجد بيانات',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Legend
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Daily
              _buildDurationLegendItem(
                title: 'يومي',
                percentage: dailyPercentage,
                amount: dailyEarnings,
                color: dailyColor,
              ),
              
              // Monthly
              _buildDurationLegendItem(
                title: 'شهري',
                percentage: monthlyPercentage,
                amount: monthlyEarnings,
                color: monthlyColor,
              ),
              
              // Yearly
              _buildDurationLegendItem(
                title: 'سنوي',
                percentage: yearlyPercentage,
                amount: yearlyEarnings,
                color: yearlyColor,
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Build duration legend item
  Widget _buildDurationLegendItem({
    required String title,
    required String percentage,
    required double amount,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
              Text(
                '$percentage% (${amount.toStringAsFixed(0)} دج)',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Build transaction item
  Widget _buildTransactionItem(ProviderStatistics stat) {
    final vibrantOrange = const Color(0xFFFF7F11);
    final serviceTypeColor = stat.serviceType == 'نقل' ? Colors.teal : Colors.amber;
    final serviceTypeIcon = stat.serviceType == 'نقل' 
        ? Icons.local_shipping_rounded 
        : Icons.warehouse_rounded;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          // Service Type Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: serviceTypeColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(serviceTypeIcon, color: serviceTypeColor, size: 16),
          ),
          
          const SizedBox(width: 12),
          
          // Service details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.serviceName,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  stat.formattedDate,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${stat.providerAmount.toStringAsFixed(0)} دج',
                style: TextStyle(
                  color: vibrantOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                '80% من ${stat.totalAmount.toStringAsFixed(0)} دج',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
