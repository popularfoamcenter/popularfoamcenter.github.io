import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'reports_landing.dart'; // Assuming StockValuationReportPage is here

// Dashboard ViewModel for State Management
class DashboardViewModel extends ChangeNotifier {
  int _totalInventory = 0;
  int _totalStockValue = 0;
  int _totalQualities = 0;
  int _totalCompanies = 0;
  int _totalVehicles = 0;
  Map<String, int> _transactionsToday = {'Sale': 0, 'Return': 0, 'Order Booking': 0};
  Map<String, int> _transactionsWeek = {'Sale': 0, 'Return': 0, 'Order Booking': 0};
  Map<String, int> _transactionsMonth = {'Sale': 0, 'Return': 0, 'Order Booking': 0};
  Map<String, int> _transactionsYear = {'Sale': 0, 'Return': 0, 'Order Booking': 0};
  int _profitToday = 0;
  int _profitMonth = 0;
  int _profitYear = 0;
  List<HourlyTransaction> _busyHoursData = [];

  int get totalInventory => _totalInventory;
  int get totalStockValue => _totalStockValue;
  int get totalQualities => _totalQualities;
  int get totalCompanies => _totalCompanies;
  int get totalVehicles => _totalVehicles;
  Map<String, int> get transactionsToday => _transactionsToday;
  Map<String, int> get transactionsWeek => _transactionsWeek;
  Map<String, int> get transactionsMonth => _transactionsMonth;
  Map<String, int> get transactionsYear => _transactionsYear;
  int get profitToday => _profitToday;
  int get profitMonth => _profitMonth;
  int get profitYear => _profitYear;
  List<HourlyTransaction> get busyHoursData => _busyHoursData;

  Future<void> fetchData() async {
    try {
      await _fetchInventoryAndCategoryData();
      await _fetchTransactionData();
      notifyListeners();
    } catch (e) {
      print('Error fetching data: $e');
    }
  }

  Future<void> _fetchInventoryAndCategoryData() async {
    final itemsSnapshot = await FirebaseFirestore.instance.collection('items').get();
    final qualitiesSnapshot = await FirebaseFirestore.instance.collection('qualities').get();
    final companiesSnapshot = await FirebaseFirestore.instance.collection('companies').get();
    final vehiclesSnapshot = await FirebaseFirestore.instance.collection('vehicles').get();

    int totalInventory = 0;
    int totalValue = 0;
    for (var doc in itemsSnapshot.docs) {
      final data = doc.data();
      int quantity = (data['stockQuantity'] as num?)?.toInt() ?? 0;
      int salePrice = (data['salePrice'] as num?)?.toInt() ?? 0;
      totalInventory += quantity;
      totalValue += quantity * salePrice;
    }
    _totalInventory = totalInventory;
    _totalStockValue = totalValue;
    _totalQualities = qualitiesSnapshot.size;
    _totalCompanies = companiesSnapshot.size;
    _totalVehicles = vehiclesSnapshot.size;
  }

  Future<void> _fetchTransactionData() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);

    final invoicesSnapshot = await FirebaseFirestore.instance.collection('invoices').get();

    Map<int, int> hourlyCounts = {};
    _transactionsToday.clear();
    _transactionsWeek.clear();
    _transactionsMonth.clear();
    _transactionsYear.clear();
    _profitToday = 0;
    _profitMonth = 0;
    _profitYear = 0;

    for (var doc in invoicesSnapshot.docs) {
      final data = doc.data();
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      final type = data['type'] as String? ?? 'Sale';
      final total = (data['total'] as num?)?.toInt() ?? 0;

      if (timestamp.isAfter(todayStart)) {
        _transactionsToday[type] = (_transactionsToday[type] ?? 0) + 1;
        _profitToday += type == 'Sale' ? total : (type == 'Return' ? -total : 0);
        final hour = timestamp.hour;
        hourlyCounts[hour] = (hourlyCounts[hour] ?? 0) + 1;
      }
      if (timestamp.isAfter(weekStart)) {
        _transactionsWeek[type] = (_transactionsWeek[type] ?? 0) + 1;
      }
      if (timestamp.isAfter(monthStart)) {
        _transactionsMonth[type] = (_transactionsMonth[type] ?? 0) + 1;
        _profitMonth += type == 'Sale' ? total : (type == 'Return' ? -total : 0);
      }
      if (timestamp.isAfter(yearStart)) {
        _transactionsYear[type] = (_transactionsYear[type] ?? 0) + 1;
        _profitYear += type == 'Sale' ? total : (type == 'Return' ? -total : 0);
      }
    }

    _busyHoursData = hourlyCounts.entries
        .map((e) => HourlyTransaction(e.key, e.value))
        .toList()
      ..sort((a, b) => a.hour.compareTo(b.hour));
  }
}

class HourlyTransaction {
  final int hour;
  final int count;

  HourlyTransaction(this.hour, this.count);
}

// Main Dashboard Widget
class Dashboard extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback toggleDarkMode;

  const Dashboard({required this.isDarkMode, required this.toggleDarkMode, super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DashboardViewModel()..fetchData(),
      child: Theme(
        data: isDarkMode ? _darkTheme() : _lightTheme(),
        child: Scaffold(
          backgroundColor: isDarkMode ? const Color(0xFF1A1A2F) : const Color(0xFFF8F9FA),
          body: Consumer<DashboardViewModel>(
            builder: (context, viewModel, child) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DashboardHeader(isDarkMode: isDarkMode, onRefresh: viewModel.fetchData),
                  const SizedBox(height: 24),
                  MainMetricsGrid(viewModel: viewModel, isDarkMode: isDarkMode, toggleDarkMode: toggleDarkMode)
                      .animate()
                      .fadeIn(duration: const Duration(milliseconds: 600), delay: const Duration(milliseconds: 200)),
                  const SizedBox(height: 24),
                  TransactionSummary(viewModel: viewModel)
                      .animate()
                      .fadeIn(duration: const Duration(milliseconds: 600), delay: const Duration(milliseconds: 400)),
                  const SizedBox(height: 24),
                  BusyHoursGraph(viewModel: viewModel)
                      .animate()
                      .fadeIn(duration: const Duration(milliseconds: 600), delay: const Duration(milliseconds: 600)),
                  const SizedBox(height: 24),
                  CategoryGrid(viewModel: viewModel)
                      .animate()
                      .fadeIn(duration: const Duration(milliseconds: 600), delay: const Duration(milliseconds: 800)),
                  const SizedBox(height: 24),
                  ProfitMetrics(viewModel: viewModel)
                      .animate()
                      .fadeIn(duration: const Duration(milliseconds: 600), delay: const Duration(milliseconds: 1000)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  ThemeData _lightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      cardColor: Colors.white,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: Color(0xFF1A1A2F), fontWeight: FontWeight.w800, fontFamily: 'Poppins'),
        bodyMedium: TextStyle(color: Color(0xFF6C757D), fontFamily: 'Inter'),
        titleLarge: TextStyle(color: Color(0xFF1A1A2F), fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
      ),
      shadowColor: Colors.grey.withOpacity(0.15),
    );
  }

  ThemeData _darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF1A1A2F),
      cardColor: const Color(0xFF252541),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontFamily: 'Poppins'),
        bodyMedium: TextStyle(color: Color(0xFFB0B0C0), fontFamily: 'Inter'),
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
      ),
      shadowColor: Colors.black.withOpacity(0.3),
    );
  }
}

// Dashboard Header
class DashboardHeader extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onRefresh;

  const DashboardHeader({required this.isDarkMode, required this.onRefresh, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Dashboard", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 28)),
            Text("Real-time insights", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16)),
          ],
        ),
        IconButton(
          icon: Icon(Icons.refresh, color: Theme.of(context).textTheme.bodyMedium?.color),
          onPressed: onRefresh,
        ),
      ],
    ).animate().slideY(begin: -0.2, end: 0, duration: const Duration(milliseconds: 500));
  }
}

// Main Metrics Grid
class MainMetricsGrid extends StatelessWidget {
  final DashboardViewModel viewModel;
  final bool isDarkMode;
  final VoidCallback toggleDarkMode;

  const MainMetricsGrid({
    required this.viewModel,
    required this.isDarkMode,
    required this.toggleDarkMode,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
      childAspectRatio: 2.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        MetricCard(
          title: "Total Inventory",
          value: viewModel.totalInventory,
          icon: Icons.inventory_rounded,
          gradient: const [Color(0xFF6B48FF), Color(0xFF8A72FF)],
        ),
        MetricCard(
          title: "Stock Value",
          value: viewModel.totalStockValue,
          icon: Icons.attach_money_rounded,
          gradient: const [Color(0xFF00C4B4), Color(0xFF26A69A)],
          isCurrency: true,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StockValuationReportPage(
                  isDarkMode: isDarkMode,
                  toggleDarkMode: toggleDarkMode,
                ),
              ),
            );
          },
        ),
        MetricCard(
          title: "Sales Today",
          value: viewModel.transactionsToday['Sale'] ?? 0,
          icon: Icons.shopping_cart,
          gradient: const [Color(0xFFFF6B6B), Color(0xFFFF8A80)],
        ),
        MetricCard(
          title: "Today's Sale Values",
          value: viewModel.profitToday,
          icon: Icons.trending_up,
          gradient: const [Color(0xFFFFCA28), Color(0xFFFFB300)],
          isCurrency: true,
        ),
      ],
    );
  }
}

// Reusable Metric Card
class MetricCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final List<Color> gradient;
  final bool isCurrency;
  final VoidCallback? onTap;

  const MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    this.isCurrency = false,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Icon(icon, size: 28, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 8),
                  AnimatedCount(
                    count: value,
                    isCurrency: isCurrency,
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 20),
          ],
        ),
      ),
    ).animate().scale(duration: const Duration(milliseconds: 500), curve: Curves.easeOutExpo);
  }
}

// Animated Count Widget
class AnimatedCount extends StatelessWidget {
  final int count;
  final bool isCurrency;
  final TextStyle style;

  const AnimatedCount({required this.count, this.isCurrency = false, required this.style, super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: IntTween(begin: 0, end: count),
      duration: const Duration(seconds: 2),
      builder: (context, value, child) => Text(
        isCurrency ? NumberFormat.decimalPattern().format(value) : value.toString(),
        style: style,
      ),
    );
  }
}

// Transaction Summary
class TransactionSummary extends StatelessWidget {
  final DashboardViewModel viewModel;

  const TransactionSummary({required this.viewModel, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Transaction Summary", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Theme.of(context).shadowColor, blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              _buildSummaryHeader(context),
              const SizedBox(height: 8),
              Divider(color: Theme.of(context).shadowColor.withOpacity(0.2)),
              const SizedBox(height: 8),
              _buildSummaryRow(context, "Today", viewModel.transactionsToday),
              _buildSummaryRow(context, "This Week", viewModel.transactionsWeek),
              _buildSummaryRow(context, "This Month", viewModel.transactionsMonth),
              _buildSummaryRow(context, "This Year", viewModel.transactionsYear),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryHeader(BuildContext context) {
    return Row(
      children: [
        _buildHeaderCell(context, "Period", Icons.calendar_today),
        _buildHeaderCell(context, "Sales", Icons.shopping_cart),
        _buildHeaderCell(context, "Returns", Icons.reply),
        _buildHeaderCell(context, "Orders", Icons.bookmark),
        _buildHeaderCell(context, "Total", Icons.summarize),
      ],
    );
  }

  Widget _buildHeaderCell(BuildContext context, String title, IconData icon) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Theme.of(context).textTheme.bodyMedium?.color),
            const SizedBox(width: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String period, Map<String, int> transactions) {
    final total = (transactions['Sale'] ?? 0) + (transactions['Return'] ?? 0) + (transactions['Order Booking'] ?? 0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          _buildDataCell(context, period, Colors.blue.withOpacity(0.1)),
          _buildDataCell(context, "${transactions['Sale'] ?? 0}", Colors.green.withOpacity(0.1)),
          _buildDataCell(context, "${transactions['Return'] ?? 0}", Colors.orange.withOpacity(0.1)),
          _buildDataCell(context, "${transactions['Order Booking'] ?? 0}", Colors.purple.withOpacity(0.1)),
          _buildDataCell(context, "$total", Colors.grey.withOpacity(0.1)),
        ],
      ),
    );
  }

  Widget _buildDataCell(BuildContext context, String value, Color backgroundColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// Busy Hours Graph
class BusyHoursGraph extends StatelessWidget {
  final DashboardViewModel viewModel;

  const BusyHoursGraph({required this.viewModel, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Busy Hours (Today)", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20)),
        const SizedBox(height: 16),
        Container(
          height: 250,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Theme.of(context).shadowColor, blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (viewModel.busyHoursData.isNotEmpty
                  ? viewModel.busyHoursData.map((e) => e.count).reduce((a, b) => a > b ? a : b) * 1.2
                  : 10)
                  .toDouble(),
              barGroups: viewModel.busyHoursData.map((data) {
                return BarChartGroupData(
                  x: data.hour,
                  barRods: [
                    BarChartRodData(
                      toY: data.count.toDouble(),
                      gradient: LinearGradient(
                        colors: [const Color(0xFF6B48FF), const Color(0xFF8A72FF)],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      width: 20,
                      borderRadius: BorderRadius.circular(8),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: (viewModel.busyHoursData.isNotEmpty
                            ? viewModel.busyHoursData.map((e) => e.count).reduce((a, b) => a > b ? a : b) * 1.2
                            : 10)
                            .toDouble(),
                        color: Colors.grey.withOpacity(0.1),
                      ),
                    ),
                  ],
                  showingTooltipIndicators: data.count > 0 ? [0] : [],
                );
              }).toList(),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) => Text(
                      "${value.toInt()}:00",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                    ),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Theme.of(context).shadowColor.withOpacity(0.2),
                  strokeWidth: 1,
                ),
              ),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => Colors.black.withOpacity(0.8),
                  tooltipPadding: const EdgeInsets.all(8),
                  tooltipMargin: 8,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${group.x}:00\n${rod.toY.toInt()} transactions',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Category Grid
class CategoryGrid extends StatelessWidget {
  final DashboardViewModel viewModel;

  const CategoryGrid({required this.viewModel, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Categories", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20)),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 600 ? 2 : 1;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              childAspectRatio: 1.5,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                CategoryItem(
                  title: "Qualities",
                  value: viewModel.totalQualities,
                  icon: Icons.auto_awesome_mosaic_rounded,
                  color: const Color(0xFFFF6B6B),
                ),
                CategoryItem(
                  title: "Companies",
                  value: viewModel.totalCompanies,
                  icon: Icons.business_rounded,
                  color: const Color(0xFF00C4B4),
                ),
                CategoryItem(
                  title: "Vehicles",
                  value: viewModel.totalVehicles,
                  icon: Icons.local_shipping_rounded,
                  color: const Color(0xFFFFCA28),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class CategoryItem extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;

  const CategoryItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Theme.of(context).shadowColor, blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, size: 24, color: color),
          ),
          const Spacer(),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          AnimatedCount(
            count: value,
            style: Theme.of(context).textTheme.headlineMedium!.copyWith(fontSize: 28),
          ),
        ],
      ),
    ).animate().scale(duration: const Duration(milliseconds: 500), curve: Curves.easeOutExpo);
  }
}

// Profit Metrics
class ProfitMetrics extends StatelessWidget {
  final DashboardViewModel viewModel;

  const ProfitMetrics({required this.viewModel, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Sales Overview", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20)),
        const SizedBox(height: 16),
        Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Theme.of(context).shadowColor, blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: PieChart(
                  PieChartData(
                    sections: _getPieChartSections(context),
                    centerSpaceRadius: 60,
                    sectionsSpace: 2,
                    startDegreeOffset: 270,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem(context, "Today", Colors.green, viewModel.profitToday),
                    const SizedBox(height: 16),
                    _buildLegendItem(context, "This Month", Colors.blue, viewModel.profitMonth),
                    const SizedBox(height: 16),
                    _buildLegendItem(context, "This Year", Colors.purple, viewModel.profitYear),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _getPieChartSections(BuildContext context) {
    final total = viewModel.profitToday + viewModel.profitMonth + viewModel.profitYear;
    if (total == 0) {
      return [
        PieChartSectionData(
          color: Colors.grey.withOpacity(0.3),
          value: 1,
          title: "No Data",
          radius: 50,
          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ];
    }

    return [
      PieChartSectionData(
        color: Colors.green,
        value: viewModel.profitToday.toDouble(),
        title: "${((viewModel.profitToday / total) * 100).toStringAsFixed(1)}%",
        radius: 50,
        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        badgeWidget: _buildBadge(Icons.today, Colors.green),
        badgePositionPercentageOffset: 1.2,
      ),
      PieChartSectionData(
        color: Colors.blue,
        value: viewModel.profitMonth.toDouble(),
        title: "${((viewModel.profitMonth / total) * 100).toStringAsFixed(1)}%",
        radius: 50,
        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        badgeWidget: _buildBadge(Icons.calendar_month, Colors.blue),
        badgePositionPercentageOffset: 1.2,
      ),
      PieChartSectionData(
        color: Colors.purple,
        value: viewModel.profitYear.toDouble(),
        title: "${((viewModel.profitYear / total) * 100).toStringAsFixed(1)}%",
        radius: 50,
        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        badgeWidget: _buildBadge(Icons.calendar_today, Colors.purple),
        badgePositionPercentageOffset: 1.2,
      ),
    ];
  }

  Widget _buildLegendItem(BuildContext context, String title, Color color, int value) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
          ),
        ),
        Text(
          NumberFormat.compact().format(value),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: color, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildBadge(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 1))],
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

void main() {
  runApp(
    MaterialApp(
      home: Dashboard(
        isDarkMode: false,
        toggleDarkMode: () {},
      ),
    ),
  );
}