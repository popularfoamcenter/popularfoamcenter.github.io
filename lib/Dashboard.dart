import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class Dashboard extends StatefulWidget {
  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with SingleTickerProviderStateMixin {
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
  List<_HourlyTransaction> _busyHoursData = [];
  bool _isLoading = true;

  late AnimationController _controller;
  late Animation<int> _inventoryAnimation;
  late Animation<int> _stockValueAnimation;
  late Animation<int> _salesTodayAnimation;
  late Animation<int> _profitTodayAnimation;
  late Animation<int> _qualitiesAnimation;
  late Animation<int> _companiesAnimation;
  late Animation<int> _vehiclesAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _initializeAnimations();
    _fetchData();
  }

  void _initializeAnimations() {
    _inventoryAnimation = IntTween(begin: 0, end: 0).animate(_controller);
    _stockValueAnimation = IntTween(begin: 0, end: 0).animate(_controller);
    _salesTodayAnimation = IntTween(begin: 0, end: 0).animate(_controller);
    _profitTodayAnimation = IntTween(begin: 0, end: 0).animate(_controller);
    _qualitiesAnimation = IntTween(begin: 0, end: 0).animate(_controller);
    _companiesAnimation = IntTween(begin: 0, end: 0).animate(_controller);
    _vehiclesAnimation = IntTween(begin: 0, end: 0).animate(_controller);
  }

  Future<void> _fetchData() async {
    try {
      await _fetchInventoryAndCategoryData();
      await _fetchTransactionData();
      setState(() {
        _updateAnimations();
        _controller
          ..reset()
          ..forward();
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching data: $e');
      setState(() => _isLoading = false);
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
      final data = doc.data() as Map<String, dynamic>;
      int quantity = (data['stockQuantity'] ?? 0) as int;
      int salePrice = (data['salePrice'] ?? 0) as int;
      totalInventory += quantity;
      totalValue += quantity * salePrice;
    }
    setState(() {
      _totalInventory = totalInventory;
      _totalStockValue = totalValue;
      _totalQualities = qualitiesSnapshot.size;
      _totalCompanies = companiesSnapshot.size;
      _totalVehicles = vehiclesSnapshot.size;
    });
  }

  Future<void> _fetchTransactionData() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);

    final invoicesSnapshot = await FirebaseFirestore.instance.collection('invoices').get();

    Map<int, int> hourlyCounts = {};
    for (var doc in invoicesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      final type = data['type'] as String;
      final total = (data['total'] as int?) ?? 0;

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
        .map((e) => _HourlyTransaction(e.key, e.value))
        .toList()
      ..sort((a, b) => a.hour.compareTo(b.hour));
  }

  void _updateAnimations() {
    _inventoryAnimation = IntTween(begin: 0, end: _totalInventory).animate(_controller);
    _stockValueAnimation = IntTween(begin: 0, end: _totalStockValue).animate(_controller);
    _salesTodayAnimation = IntTween(begin: 0, end: _transactionsToday['Sale'] ?? 0).animate(_controller);
    _profitTodayAnimation = IntTween(begin: 0, end: _profitToday).animate(_controller);
    _qualitiesAnimation = IntTween(begin: 0, end: _totalQualities).animate(_controller);
    _companiesAnimation = IntTween(begin: 0, end: _totalCompanies).animate(_controller);
    _vehiclesAnimation = IntTween(begin: 0, end: _totalVehicles).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: 24),
        child: Column(
          children: [
            _buildDashboardHeader(context),
            const SizedBox(height: 32),
            _buildMainMetricsGrid(context),
            const SizedBox(height: 32),
            _buildTransactionSummary(context),
            const SizedBox(height: 32),
            _buildBusyHoursGraph(context),
            const SizedBox(height: 32),
            _buildCategoryGrid(context),
            const SizedBox(height: 32),
            _buildProfitMetrics(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardHeader(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Dashboard",
          style: TextStyle(
            fontSize: screenWidth < 600 ? 24 : 28,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1A2F),
          ),
        ),
        Text(
          "Real-time business analytics",
          style: TextStyle(fontSize: screenWidth < 600 ? 14 : 16, color: const Color(0xFF6C757D)),
        ),
      ],
    );
  }

  Widget _buildMainMetricsGrid(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
        childAspectRatio: 3,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      children: [
        _buildMetricCard(
          context,
          title: "Total Inventory",
          animation: _inventoryAnimation,
          icon: Icons.inventory_rounded,
          gradient: const [Color(0xFF4E54C8), Color(0xFF8F94FB)],
        ),
        _buildMetricCard(
          context,
          title: "Stock Value",
          animation: _stockValueAnimation,
          icon: Icons.attach_money_rounded,
          gradient: const [Color(0xFF11998E), Color(0xFF38EF7D)],
          isCurrency: true,
        ),
        _buildMetricCard(
          context,
          title: "Sales Today",
          animation: _salesTodayAnimation,
          icon: Icons.shopping_cart,
          gradient: const [Color(0xFFFF6B6B), Color(0xFFFFA6A6)],
        ),
        _buildMetricCard(
          context,
          title: "Sales Value",
          animation: _profitTodayAnimation,
          icon: Icons.trending_up,
          gradient: const [Color(0xFF4ECDC4), Color(0xFF7EE8E2)],
          isCurrency: true,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      BuildContext context, {
        required String title,
        required Animation<int> animation,
        required IconData icon,
        required List<Color> gradient,
        bool isCurrency = false,
      }) {
    final screenWidth = MediaQuery.of(context).size.width;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: gradient),
          boxShadow: [
            BoxShadow(color: gradient.last.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8)),
          ],
        ),
        padding: EdgeInsets.all(screenWidth < 600 ? 16 : 24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: Icon(icon, size: screenWidth < 600 ? 24 : 32, color: Colors.white),
            ),
            SizedBox(width: screenWidth < 600 ? 12 : 20),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: screenWidth < 600 ? 14 : 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isCurrency ? '${animation.value}/-' : animation.value.toString(),
                    style: TextStyle(color: Colors.white, fontSize: screenWidth < 600 ? 24 : 32, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionSummary(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Transaction Summary",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A2F),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSummaryHeader(),
              const SizedBox(height: 8),
              Divider(color: Colors.grey.withOpacity(0.2)),
              const SizedBox(height: 8),
              _buildSummaryRow("Today", _transactionsToday),
              _buildSummaryRow("This Week", _transactionsWeek),
              _buildSummaryRow("This Month", _transactionsMonth),
              _buildSummaryRow("This Year", _transactionsYear),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryHeader() {
    return Row(
      children: [
        _buildHeaderCell("Period", Icons.calendar_today),
        _buildHeaderCell("Sales", Icons.shopping_cart),
        _buildHeaderCell("Returns", Icons.reply),
        _buildHeaderCell("Orders", Icons.bookmark),
        _buildHeaderCell("Total", Icons.summarize),
      ],
    );
  }

  Widget _buildHeaderCell(String title, IconData icon) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF6C757D)),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: const Color(0xFF1A1A2F),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String period, Map<String, int> transactions) {
    final total = (transactions['Sale'] ?? 0) + (transactions['Return'] ?? 0) + (transactions['Order Booking'] ?? 0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          _buildDataCell(period, Colors.blue.withOpacity(0.1)),
          _buildDataCell("${transactions['Sale'] ?? 0}", Colors.green.withOpacity(0.1)),
          _buildDataCell("${transactions['Return'] ?? 0}", Colors.orange.withOpacity(0.1)),
          _buildDataCell("${transactions['Order Booking'] ?? 0}", Colors.purple.withOpacity(0.1)),
          _buildDataCell("$total", Colors.grey.withOpacity(0.1)),
        ],
      ),
    );
  }

  Widget _buildDataCell(String value, Color backgroundColor) {
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
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A2F),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildBusyHoursGraph(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Busy Hours (Today)",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A2F)),
        ),
        const SizedBox(height: 16),
        Container(
          height: 250,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (_busyHoursData.isNotEmpty ? _busyHoursData.map((e) => e.count).reduce((a, b) => a > b ? a : b) * 1.2 : 10).toDouble(),
              barGroups: _busyHoursData.map((data) {
                return BarChartGroupData(
                  x: data.hour,
                  barRods: [
                    BarChartRodData(
                      toY: data.count.toDouble(),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4E54C8), Color(0xFF8F94FB)],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      width: 20,
                      borderRadius: BorderRadius.circular(8),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: (_busyHoursData.map((e) => e.count).reduce((a, b) => a > b ? a : b) * 1.2).toDouble(),
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
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6C757D)),
                    ),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6C757D)),
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
                  color: Colors.grey.withOpacity(0.2),
                  strokeWidth: 1,
                ),
              ),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => Colors.black.withOpacity(0.8),
                  tooltipPadding: const EdgeInsets.all(8),
                  tooltipMargin: 8,
                  tooltipBorder: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
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

  Widget _buildCategoryGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Categories",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A2F)),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 600 ? 2 : 1;
            return GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 1.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              children: [
                _buildCategoryItem(
                  context,
                  title: "Qualities",
                  animation: _qualitiesAnimation,
                  icon: Icons.auto_awesome_mosaic_rounded,
                  color: const Color(0xFFFF6B6B),
                ),
                _buildCategoryItem(
                  context,
                  title: "Companies",
                  animation: _companiesAnimation,
                  icon: Icons.business_rounded,
                  color: const Color(0xFF4ECDC4),
                ),
                _buildCategoryItem(
                  context,
                  title: "Vehicles",
                  animation: _vehiclesAnimation,
                  icon: Icons.local_shipping_rounded,
                  color: const Color(0xFFFF9F43),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryItem(
      BuildContext context, {
        required String title,
        required Animation<int> animation,
        required IconData icon,
        required Color color,
      }) {
    final screenWidth = MediaQuery.of(context).size.width;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0x11000000), blurRadius: 16, offset: Offset(0, 8)),
          ],
        ),
        padding: EdgeInsets.all(screenWidth < 600 ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: screenWidth < 600 ? 24 : 28, color: color),
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                color: const Color(0xFF6C757D),
                fontSize: screenWidth < 600 ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              animation.value.toString(),
              style: TextStyle(
                color: const Color(0xFF1A1A2F),
                fontSize: screenWidth < 600 ? 24 : 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitMetrics(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Profit Overview",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A2F)),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 1,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2,
          children: [
            _buildProfitCard("Today", _profitToday, Colors.green),
            _buildProfitCard("This Month", _profitMonth, Colors.blue),
            _buildProfitCard("This Year", _profitYear, Colors.purple),
          ],
        ),
      ],
    );
  }

  Widget _buildProfitCard(String period, int profit, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(period, style: TextStyle(fontSize: 16, color: const Color(0xFF6C757D))),
          const SizedBox(height: 8),
          Text(
            '$profit/-',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

class _HourlyTransaction {
  final int hour;
  final int count;

  _HourlyTransaction(this.hour, this.count);
}