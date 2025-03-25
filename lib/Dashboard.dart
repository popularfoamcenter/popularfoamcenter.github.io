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
  double _totalStockValue = 0;
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
  List<Map<String, dynamic>> _lowStockItems = [];
  Map<String, int> _stockHistory = {
    'totalSalesItems': 0,
    'salesReturnItems': 0,
    'totalPurchaseItems': 0,
    'purchaseReturnItems': 0,
  };
  List<Invoice> _recentSalesInvoices = [];
  List<Invoice> _recentPurchaseInvoices = [];
  String _stockHistoryPeriod = '7 Days'; // Default period for stock history

  int get totalInventory => _totalInventory;
  double get totalStockValue => _totalStockValue;
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
  List<Map<String, dynamic>> get lowStockItems => _lowStockItems;
  Map<String, int> get stockHistory => _stockHistory;
  List<Invoice> get recentSalesInvoices => _recentSalesInvoices;
  List<Invoice> get recentPurchaseInvoices => _recentPurchaseInvoices;
  String get stockHistoryPeriod => _stockHistoryPeriod;

  void setStockHistoryPeriod(String period) {
    _stockHistoryPeriod = period;
    _fetchStockHistory(); // Re-fetch stock history for the new period
    notifyListeners();
  }

  Future<void> fetchData() async {
    try {
      await _fetchInventoryAndCategoryData();
      await _fetchTransactionData();
      await _fetchLowStockItems();
      await _fetchStockHistory();
      await _fetchRecentInvoices();
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
    double totalValue = 0;

    Map<String, Map<String, double>> qualityDiscounts = {};
    for (var qualityDoc in qualitiesSnapshot.docs) {
      qualityDiscounts[qualityDoc.id] = {
        'covered_discount': (qualityDoc['covered_discount'] as num?)?.toDouble() ?? 0.0,
        'uncovered_discount': (qualityDoc['uncovered_discount'] as num?)?.toDouble() ?? 0.0,
      };
    }

    for (var doc in itemsSnapshot.docs) {
      final data = doc.data();
      int quantity = (data['stockQuantity'] as num?)?.toInt() ?? 0;
      double salePrice = (data['salePrice'] as num?)?.toDouble() ?? 0.0;
      String qualityId = data['qualityId'] as String? ?? '';
      String covered = data['covered'] as String? ?? '-';

      totalInventory += quantity;

      double discountPercentage = 0.0;
      if (qualityDiscounts.containsKey(qualityId)) {
        discountPercentage = covered == 'Yes'
            ? qualityDiscounts[qualityId]!['covered_discount']!
            : qualityDiscounts[qualityId]!['uncovered_discount']!;
      }

      double discountedPrice = salePrice * (1 - discountPercentage / 100);
      totalValue += quantity * discountedPrice;
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

  Future<void> _fetchLowStockItems() async {
    final itemsSnapshot = await FirebaseFirestore.instance
        .collection('items')
        .where('stockQuantity', isLessThan: 10)
        .get();

    _lowStockItems = itemsSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'itemName': data['itemName']?.toString() ?? 'Unknown Item',
        'stockQuantity': (data['stockQuantity'] as num?)?.toInt() ?? 0,
      };
    }).toList();
  }

  Future<void> _fetchStockHistory() async {
    final now = DateTime.now();
    int days;
    switch (_stockHistoryPeriod) {
      case '7 Days':
        days = 7;
        break;
      case '15 Days':
        days = 15;
        break;
      case '30 Days':
        days = 30;
        break;
      default:
        days = 7;
    }
    final periodStart = now.subtract(Duration(days: days));

    // Fetch sales invoices
    final salesInvoicesSnapshot = await FirebaseFirestore.instance
        .collection('invoices')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(periodStart))
        .get();

    // Fetch purchase invoices
    final purchaseInvoicesSnapshot = await FirebaseFirestore.instance
        .collection('purchaseinvoices')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(periodStart))
        .get();

    int totalSalesItems = 0;
    int salesReturnItems = 0;
    int totalPurchaseItems = 0;
    int purchaseReturnItems = 0;

    // Process sales invoices
    for (var doc in salesInvoicesSnapshot.docs) {
      final data = doc.data();
      final type = data['type'] as String? ?? 'Sale';
      final items = (data['items'] as List<dynamic>?)?.map((item) => CartItem.fromMap(item)).toList() ?? [];

      int itemCount = items.fold(0, (sum, item) => sum + item.qty.toInt());

      if (type == 'Sale') {
        totalSalesItems += itemCount;
      } else if (type == 'Return') {
        salesReturnItems += itemCount;
      }
    }

    // Process purchase invoices
    for (var doc in purchaseInvoicesSnapshot.docs) {
      final data = doc.data();
      final items = (data['items'] as List<dynamic>?)?.map((item) {
        return CartItem(
          quality: item['quality'] ?? '',
          itemName: item['name'] ?? '',
          covered: item['isCovered'] == true ? 'Yes' : 'No',
          qty: (item['quantity'] as num?)?.toDouble() ?? 0.0,
          originalQty: (item['quantity'] as num?)?.toDouble() ?? 0.0,
          price: item['price']?.toString() ?? '0',
          discount: item['discount']?.toString() ?? '0',
          total: (item['total'] as num?)?.toString() ?? '0',
        );
      }).toList() ?? [];

      int itemCount = items.fold(0, (sum, item) => sum + item.qty.toInt());

      totalPurchaseItems += itemCount;
      // Assuming purchase returns are not tracked in this dataset; set to 0 for now
      purchaseReturnItems = 0; // Update this if purchase returns are available
    }

    _stockHistory = {
      'totalSalesItems': totalSalesItems,
      'salesReturnItems': salesReturnItems,
      'totalPurchaseItems': totalPurchaseItems,
      'purchaseReturnItems': purchaseReturnItems,
    };

    notifyListeners();
  }

  Future<void> _fetchRecentInvoices() async {
    // Fetch recent sales invoices
    final salesInvoicesSnapshot = await FirebaseFirestore.instance
        .collection('invoices')
        .orderBy('timestamp', descending: true)
        .limit(5)
        .get();

    _recentSalesInvoices = salesInvoicesSnapshot.docs.map((doc) {
      return Invoice.fromMap(doc.id, doc.data());
    }).toList();

    // Fetch recent purchase invoices
    final purchaseInvoicesSnapshot = await FirebaseFirestore.instance
        .collection('purchaseinvoices')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .get();

    _recentPurchaseInvoices = purchaseInvoicesSnapshot.docs.map((doc) {
      final data = doc.data();
      // Handle invoice date parsing for purchase invoices
      DateTime invoiceDate;
      try {
        if (data['createdAt'] is Timestamp) {
          invoiceDate = (data['createdAt'] as Timestamp).toDate();
        } else if (data['createdAt'] is String) {
          invoiceDate = DateFormat('dd-MM-yyyy').parse(data['createdAt']);
        } else {
          invoiceDate = DateTime.now();
        }
      } catch (e) {
        print('Error parsing createdAt: $e');
        invoiceDate = DateTime.now();
      }

      return Invoice(
        id: doc.id,
        invoiceNumber: int.tryParse(data['invoiceId']?.toString() ?? '0') ?? 0,
        customer: {'name': data['company']?.toString() ?? 'Unknown'},
        type: 'Purchase',
        items: (data['items'] as List<dynamic>?)?.map((item) {
          return CartItem(
            quality: item['quality']?.toString() ?? '',
            itemName: item['name']?.toString() ?? '',
            covered: item['isCovered'] == true ? 'Yes' : 'No',
            qty: (item['quantity'] as num?)?.toDouble() ?? 0.0,
            originalQty: (item['quantity'] as num?)?.toDouble() ?? 0.0,
            price: item['price']?.toString() ?? '0',
            discount: item['discount']?.toString() ?? '0',
            total: (item['total'] as num?)?.toString() ?? '0',
          );
        }).toList() ?? [],
        subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
        globalDiscount: 0, // Purchase invoices may not have global discount
        total: (data['total'] as num?)?.toDouble() ?? 0.0,
        givenAmount: (data['total'] as num?)?.toDouble() ?? 0.0,
        returnAmount: 0.0,
        balanceDue: 0.0,
        timestamp: Timestamp.fromDate(invoiceDate),
      );
    }).toList();

    notifyListeners();
  }
}

class HourlyTransaction {
  final int hour;
  final int count;

  HourlyTransaction(this.hour, this.count);
}

class CartItem {
  final String quality;
  final String itemName;
  final String? covered;
  double qty;
  final double originalQty;
  String price;
  String discount;
  String total;

  CartItem({
    required this.quality,
    required this.itemName,
    this.covered,
    required this.qty,
    required this.originalQty,
    required this.price,
    required this.discount,
    required this.total,
  });

  Map<String, dynamic> toMap() => {
    'quality': quality,
    'item': itemName,
    'covered': covered,
    'qty': qty,
    'originalQty': originalQty,
    'price': price,
    'discount': discount,
    'total': total,
  };

  factory CartItem.fromMap(Map<String, dynamic> map) => CartItem(
    quality: map['quality'] ?? '',
    itemName: map['item'] ?? '',
    covered: map['covered'],
    qty: (map['qty'] is num ? map['qty'].toDouble() : double.tryParse(map['qty'].toString())) ?? 0.0,
    originalQty: (map['originalQty'] is num
        ? map['originalQty'].toDouble()
        : double.tryParse(map['originalQty']?.toString() ?? '0')) ??
        (map['qty'] is num ? map['qty'].toDouble() : double.tryParse(map['qty'].toString())) ??
        0.0,
    price: map['price'] ?? '0',
    discount: map['discount'] ?? '0',
    total: map['total'] ?? '0',
  );
}

class Invoice {
  final String? id;
  final int invoiceNumber;
  final Map<String, dynamic> customer;
  final String type;
  final List<CartItem> items;
  final double subtotal;
  final int globalDiscount;
  final double total;
  final double givenAmount;
  final double returnAmount;
  final double balanceDue;
  final dynamic timestamp;

  Invoice({
    this.id,
    required this.invoiceNumber,
    required this.customer,
    required this.type,
    required this.items,
    required this.subtotal,
    required this.globalDiscount,
    required this.total,
    required this.givenAmount,
    required this.returnAmount,
    required this.balanceDue,
    this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'invoiceNumber': invoiceNumber,
    'customer': customer,
    'type': type,
    'items': items.map((item) => item.toMap()).toList(),
    'subtotal': subtotal,
    'globalDiscount': globalDiscount,
    'total': total,
    'givenAmount': givenAmount,
    'returnAmount': returnAmount,
    'balanceDue': balanceDue,
    'timestamp': timestamp,
  };

  factory Invoice.fromMap(String id, Map<String, dynamic> map) {
    return Invoice(
      id: id,
      invoiceNumber: map['invoiceNumber'] ?? 0,
      customer: Map<String, dynamic>.from(map['customer'] ?? {}),
      type: map['type'] ?? 'Sale',
      items: (map['items'] as List<dynamic>?)
          ?.map((item) => CartItem.fromMap(item))
          .toList() ??
          [],
      subtotal: (map['subtotal'] is num ? map['subtotal'].toDouble() : 0.0),
      globalDiscount: map['globalDiscount'] ?? 0,
      total: (map['total'] is num ? map['total'].toDouble() : 0.0),
      givenAmount: (map['givenAmount'] is num ? map['givenAmount'].toDouble() : 0.0),
      returnAmount: (map['returnAmount'] is num ? map['returnAmount'].toDouble() : 0.0),
      balanceDue: (map['balanceDue'] is num ? map['balanceDue'].toDouble() : 0.0),
      timestamp: map['timestamp'] is Timestamp
          ? map['timestamp'] as Timestamp
          : (map['timestamp'] != null
          ? Timestamp.fromDate(
          DateTime.fromMillisecondsSinceEpoch(map['timestamp'].millisecondsSinceEpoch))
          : null),
    );
  }
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
                  MainMetricsRow(viewModel: viewModel, isDarkMode: isDarkMode, toggleDarkMode: toggleDarkMode)
                      .animate()
                      .fadeIn(duration: const Duration(milliseconds: 600), delay: const Duration(milliseconds: 200)),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TransactionSummary(viewModel: viewModel)
                            .animate()
                            .fadeIn(duration: const Duration(milliseconds: 600), delay: const Duration(milliseconds: 400)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: BusyHoursGraph(viewModel: viewModel)
                            .animate()
                            .fadeIn(duration: const Duration(milliseconds: 600), delay: const Duration(milliseconds: 600)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ProfitMetrics(viewModel: viewModel)
                            .animate()
                            .fadeIn(duration: const Duration(milliseconds: 600), delay: const Duration(milliseconds: 800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: RecentInvoices(viewModel: viewModel)
                            .animate()
                            .fadeIn(duration: const Duration(milliseconds: 600), delay: const Duration(milliseconds: 1000)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: StockHistory(viewModel: viewModel)
                            .animate()
                            .fadeIn(duration: const Duration(milliseconds: 600), delay: const Duration(milliseconds: 1200)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: CategoryGrid(viewModel: viewModel)
                                .animate()
                                .fadeIn(duration: const Duration(milliseconds: 600), delay: const Duration(milliseconds: 1400)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: StockAlert(viewModel: viewModel)
                                .animate()
                                .fadeIn(duration: const Duration(milliseconds: 600), delay: const Duration(milliseconds: 1600)),
                          ),
                        ],
                      );
                    },
                  ),
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
            Text("Dashboard Overview", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 28)),
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

// Main Metrics Row
class MainMetricsRow extends StatelessWidget {
  final DashboardViewModel viewModel;
  final bool isDarkMode;
  final VoidCallback toggleDarkMode;

  const MainMetricsRow({
    required this.viewModel,
    required this.isDarkMode,
    required this.toggleDarkMode,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              MetricCard(
                title: "Total Inventory",
                value: viewModel.totalInventory,
                icon: Icons.inventory_rounded,
                gradient: const [Color(0xFF6B48FF), Color(0xFF8A72FF)],
                width: constraints.maxWidth / 4,
              ),
              const SizedBox(width: 16),
              MetricCard(
                title: "Stock Value (Discounted)",
                value: viewModel.totalStockValue.toInt(),
                icon: Icons.attach_money_rounded,
                gradient: const [Color(0xFF00C4B4), Color(0xFF26A69A)],
                isCurrency: true,
                width: constraints.maxWidth / 4,
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
              const SizedBox(width: 16),
              MetricCard(
                title: "Sales Today",
                value: viewModel.transactionsToday['Sale'] ?? 0,
                icon: Icons.shopping_cart,
                gradient: const [Color(0xFFFF6B6B), Color(0xFFFF8A80)],
                width: constraints.maxWidth / 4,
              ),
              const SizedBox(width: 16),
              MetricCard(
                title: "Today's Sale Values",
                value: viewModel.profitToday,
                icon: Icons.trending_up,
                gradient: const [Color(0xFFFFCA28), Color(0xFFFFB300)],
                isCurrency: true,
                width: constraints.maxWidth / 4,
              ),
            ],
          ),
        );
      },
    );
  }
}

// Metric Card
class MetricCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final List<Color> gradient;
  final bool isCurrency;
  final VoidCallback? onTap;
  final double? width;

  const MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    this.isCurrency = false,
    this.onTap,
    this.width,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width ?? 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: gradient[0].withOpacity(0.2),
                  child: Icon(icon, size: 24, color: gradient[0]),
                ),
                if (onTap != null) ...[
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            AnimatedCount(
              count: value,
              isCurrency: isCurrency,
              style: Theme.of(context).textTheme.headlineMedium!.copyWith(fontSize: 24),
            ),
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
        isCurrency ? "\$${NumberFormat.decimalPattern().format(value)}" : value.toString(),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Payments", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20)),
            DropdownButton<String>(
              value: "15 Days",
              items: ["7 Days", "15 Days", "30 Days"]
                  .map((period) => DropdownMenuItem(
                value: period,
                child: Text(period, style: Theme.of(context).textTheme.bodyMedium),
              ))
                  .toList(),
              onChanged: (value) {
                // Implement filtering logic if needed
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Theme.of(context).shadowColor, blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    FlSpot(1, 1000),
                    FlSpot(2, 2000),
                    FlSpot(3, 1500),
                    FlSpot(4, 3000),
                    FlSpot(5, 2500),
                    FlSpot(6, 4000),
                    FlSpot(7, 3500),
                    FlSpot(8, 2000),
                    FlSpot(9, 3000),
                    FlSpot(10, 2500),
                    FlSpot(11, 4000),
                    FlSpot(12, 3500),
                    FlSpot(13, 5000),
                    FlSpot(14, 4500),
                    FlSpot(15, 6000),
                  ],
                  isCurved: true,
                  color: Colors.red,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                ),
                LineChartBarData(
                  spots: [
                    FlSpot(1, 2000),
                    FlSpot(2, 1500),
                    FlSpot(3, 2500),
                    FlSpot(4, 2000),
                    FlSpot(5, 3000),
                    FlSpot(6, 2500),
                    FlSpot(7, 4000),
                    FlSpot(8, 3500),
                    FlSpot(9, 2000),
                    FlSpot(10, 3000),
                    FlSpot(11, 2500),
                    FlSpot(12, 4000),
                    FlSpot(13, 3500),
                    FlSpot(14, 5000),
                    FlSpot(15, 7000),
                  ],
                  isCurved: true,
                  color: Colors.blue,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                ),
              ],
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => Text(
                      '${(value / 1000).toInt()}k',
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
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildLegendItem(context, "Payment Sent", Colors.red),
            const SizedBox(width: 16),
            _buildLegendItem(context, "Payment Received", Colors.blue),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(BuildContext context, String title, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
        ),
      ],
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
          height: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Theme.of(context).shadowColor, blurRadius: 8, offset: const Offset(0, 2))],
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
                      color: Colors.purpleAccent,
                      width: 10,
                      borderRadius: BorderRadius.circular(4),
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

// Profit Metrics
class ProfitMetrics extends StatelessWidget {
  final DashboardViewModel viewModel;

  const ProfitMetrics({required this.viewModel, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Profit Distribution", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20)),
        const SizedBox(height: 16),
        Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Theme.of(context).shadowColor, blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Expanded(
                child: PieChart(
                  PieChartData(
                    sections: _getPieChartSections(context),
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                    startDegreeOffset: 270,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem(context, "Today", Colors.green, viewModel.profitToday),
                    const SizedBox(height: 8),
                    _buildLegendItem(context, "This Month", Colors.blue, viewModel.profitMonth),
                    const SizedBox(height: 8),
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
        title: "${((viewModel.profitToday / total) * 100).toStringAsFixed(0)}%",
        radius: 50,
        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: Colors.blue,
        value: viewModel.profitMonth.toDouble(),
        title: "${((viewModel.profitMonth / total) * 100).toStringAsFixed(0)}%",
        radius: 50,
        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: Colors.purple,
        value: viewModel.profitYear.toDouble(),
        title: "${((viewModel.profitYear / total) * 100).toStringAsFixed(0)}%",
        radius: 50,
        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    ];
  }

  Widget _buildLegendItem(BuildContext context, String title, Color color, int value) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
        ),
      ],
    );
  }
}

// Recent Invoices (Updated)
class RecentInvoices extends StatefulWidget {
  final DashboardViewModel viewModel;

  const RecentInvoices({required this.viewModel, super.key});

  @override
  _RecentInvoicesState createState() => _RecentInvoicesState();
}

class _RecentInvoicesState extends State<RecentInvoices> {
  String _selectedInvoiceType = "Sales Invoice";

  @override
  Widget build(BuildContext context) {
    List<Invoice> invoices = _selectedInvoiceType == "Sales Invoice"
        ? widget.viewModel.recentSalesInvoices
        : widget.viewModel.recentPurchaseInvoices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Recent Invoice", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20)),
            DropdownButton<String>(
              value: _selectedInvoiceType,
              items: ["Sales Invoice", "Purchase Invoice"]
                  .map((type) => DropdownMenuItem(
                value: type,
                child: Text(type, style: Theme.of(context).textTheme.bodyMedium),
              ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedInvoiceType = value;
                  });
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Theme.of(context).shadowColor, blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: [
              _buildInvoiceHeader(context),
              const Divider(),
              if (invoices.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("No invoices available"),
                )
              else
                ...invoices.map((invoice) => _buildInvoiceRow(context, invoice)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text("Invoice ID", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold))),
        Expanded(child: Text("Customer", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold))),
        Expanded(child: Text("Sales Date", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold))),
        Expanded(child: Text("Paid Amount", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold))),
        Expanded(child: Text("Status", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildInvoiceRow(BuildContext context, Invoice invoice) {
    DateTime date;
    try {
      if (invoice.timestamp is Timestamp) {
        date = (invoice.timestamp as Timestamp).toDate();
      } else if (invoice.timestamp is String) {
        date = DateFormat('dd-MM-yyyy').parse(invoice.timestamp);
      } else {
        date = DateTime.now();
      }
    } catch (e) {
      print('Error parsing invoice date: $e');
      date = DateTime.now();
    }

    final status = invoice.type == 'Purchase' ? "Received" : (invoice.balanceDue > 0 ? "In Progress" : "Delivered");
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(child: Text("#INV${invoice.invoiceNumber}", style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(child: Text(invoice.customer['name'] ?? 'Unknown', style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(child: Text(DateFormat('dd/MM/yyyy').format(date), style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(child: Text("\$${invoice.total.toStringAsFixed(0)}", style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: status == "Delivered" || status == "Received"
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: status == "Delivered" || status == "Received" ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Stock History
class StockHistory extends StatelessWidget {
  final DashboardViewModel viewModel;

  const StockHistory({required this.viewModel, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Stock History", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20)),
            DropdownButton<String>(
              value: viewModel.stockHistoryPeriod,
              items: ["7 Days", "15 Days", "30 Days"]
                  .map((period) => DropdownMenuItem(
                value: period,
                child: Text(period, style: Theme.of(context).textTheme.bodyMedium),
              ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  viewModel.setStockHistoryPeriod(value);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Theme.of(context).shadowColor, blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: [
              _buildStockHistoryItem(context, "Total Sales Items", viewModel.stockHistory['totalSalesItems']!, Colors.blue, "+20%"),
              const Divider(),
              _buildStockHistoryItem(context, "Sales Return Items", viewModel.stockHistory['salesReturnItems']!, Colors.red, "-45%"),
              const Divider(),
              _buildStockHistoryItem(context, "Total Purchase Items", viewModel.stockHistory['totalPurchaseItems']!, Colors.blue, "+20%"),
              const Divider(),
              _buildStockHistoryItem(context, "Purchase Returns Items", viewModel.stockHistory['purchaseReturnItems']!, Colors.red, "-68%"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStockHistoryItem(BuildContext context, String title, int value, Color trendColor, String trend) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          Row(
            children: [
              Text(value.toString(), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 24)),
              const SizedBox(width: 8),
              Text(
                trend,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: trendColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Stock Alert (Updated)
class StockAlert extends StatelessWidget {
  final DashboardViewModel viewModel;

  const StockAlert({required this.viewModel, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Stock Alert", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20)),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            // Calculate the height to match CategoryGrid
            final crossAxisCount = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 600 ? 2 : 1;
            const childAspectRatio = 1.5;
            // Height of one row in CategoryGrid: (width / crossAxisCount) / childAspectRatio + padding
            final categoryItemHeight = (constraints.maxWidth / crossAxisCount) / childAspectRatio;
            // CategoryGrid has 1 row (3 items in a row), plus title (20) and spacing (16)
            final categoryGridHeight = categoryItemHeight + 16 + 20; // 16 for spacing, 20 for title

            return Container(
              height: categoryGridHeight, // Match the height of CategoryGrid
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Theme.of(context).shadowColor, blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Product", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text("QTY", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(),
                      if (viewModel.lowStockItems.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text("No low stock items"),
                        )
                      else
                        ...viewModel.lowStockItems.map((item) => _buildStockAlertItem(context, item)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStockAlertItem(BuildContext context, Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(item['itemName'], style: Theme.of(context).textTheme.bodyMedium)),
          Text(item['stockQuantity'].toString(), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red)),
        ],
      ),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Theme.of(context).shadowColor, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
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