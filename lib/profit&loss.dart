import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'pointofsale.dart'; // Adjust this import based on your file structure

// Color Scheme
const Color _primaryColor = Color(0xFF0D6EFD);
const Color _textColor = Color(0xFF2D2D2D);
const Color _secondaryTextColor = Color(0xFF4A4A4A);
const Color _backgroundColor = Color(0xFFF8F9FA);
const Color _surfaceColor = Colors.white;

class ProfitAndLossPage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback toggleDarkMode;

  const ProfitAndLossPage({super.key, required this.isDarkMode, required this.toggleDarkMode});

  @override
  _ProfitAndLossPageState createState() => _ProfitAndLossPageState();
}

class _ProfitAndLossPageState extends State<ProfitAndLossPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _horizontalScrollController = ScrollController();
  List<ProfitLossItem> _profitLossItems = [];
  DateTimeRange? _selectedDateRange;
  bool _isLoading = true;
  String? _errorMessage;
  final double _mobileTableWidth = 1600;

  late Color _textColorCache;
  late Color _secondaryTextColorCache;
  late Color _backgroundColorCache;
  late Color _surfaceColorCache;

  @override
  void initState() {
    super.initState();
    _selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
    _updateColorCache();
    _fetchProfitLossData();
  }

  @override
  void didUpdateWidget(ProfitAndLossPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode) {
      _updateColorCache();
    }
  }

  void _updateColorCache() {
    _textColorCache = widget.isDarkMode ? Colors.white : _textColor;
    _secondaryTextColorCache = widget.isDarkMode ? Colors.white70 : _secondaryTextColor;
    _backgroundColorCache = widget.isDarkMode ? const Color(0xFF1A1A2F) : _backgroundColor;
    _surfaceColorCache = widget.isDarkMode ? const Color(0xFF252541) : _surfaceColor;
  }

  Future<void> _fetchProfitLossData() async {
    if (_selectedDateRange == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Date range not selected';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('Fetching item data...');
      final itemSnapshot = await _firestore.collection('items').get();
      final qualitySnapshot = await _firestore.collection('qualities').get();
      final Map<String, PurchaseBatch> purchaseBatches = {};
      final Map<String, Map<String, dynamic>> qualitiesMap = {
        for (var doc in qualitySnapshot.docs) doc.id: doc.data()
      };

      for (var doc in itemSnapshot.docs) {
        final data = doc.data();
        debugPrint('Processing item doc: ${doc.id}');
        final itemName = data['itemName'] as String? ?? '';
        final qualityName = data['qualityName'] as String? ?? '';
        final itemKey = '$itemName-$qualityName';
        final purchasePrice = (data['purchasePrice'] as num?)?.toDouble() ?? 0.0;
        final qualityId = data['qualityId'] as String?;
        final covered = data['covered']?.toString().toLowerCase() == 'yes';
        double discount = 0.0;

        if (qualityId != null && qualitiesMap.containsKey(qualityId)) {
          final qualityData = qualitiesMap[qualityId]!;
          discount = covered ? (qualityData['covered_discount'] as num?)?.toDouble() ?? 0.0 : (qualityData['uncovered_discount'] as num?)?.toDouble() ?? 0.0;
        }
        final purchasePriceAfterDiscount = purchasePrice * (1 - discount / 100);
        final quantity = (data['stockQuantity'] as num?)?.toDouble() ?? (data['openingStock'] as num?)?.toDouble() ?? 0.0;
        final date = (data['dateModified'] as Timestamp?)?.toDate() ?? (data['dateCreated'] as Timestamp?)?.toDate() ?? DateTime.now();

        purchaseBatches[itemKey] = PurchaseBatch(
          purchasePrice: purchasePriceAfterDiscount,
          discount: discount,
          quantity: quantity,
          date: date,
        );
      }

      debugPrint('Fetching sales data...');
      final salesSnapshot = await _firestore
          .collection('invoices')
          .where('type', isEqualTo: 'Sale') // Fixed syntax here
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.end))
          .get();

      final List<ProfitLossItem> profitLossItems = [];

      for (var doc in salesSnapshot.docs) {
        final invoice = doc.data();
        final invoiceId = doc.id;
        final invoiceNumber = invoice['invoiceNumber'] as int? ?? 0;
        debugPrint('Processing invoice doc: $invoiceId, Number: $invoiceNumber');
        final items = (invoice['items'] as List<dynamic>?)?.map((item) => CartItem.fromMap(item)).toList() ?? [];
        final saleDate = (invoice['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

        for (var item in items) {
          final itemKey = '${item.itemName}-${item.quality}';
          final batch = purchaseBatches[itemKey];
          if (batch == null) {
            debugPrint('No purchase batch found for itemKey: $itemKey');
            continue;
          }

          double remainingQty = item.qty;
          double totalCost = 0.0;
          double totalRevenue = double.tryParse(item.total) ?? 0.0;

          if (remainingQty <= batch.quantity) {
            totalCost = batch.purchasePrice * remainingQty;
          } else {
            totalCost = batch.purchasePrice * batch.quantity;
            remainingQty -= batch.quantity;
            if (remainingQty > 0) {
              totalCost += batch.purchasePrice * remainingQty;
            }
          }

          final profit = totalRevenue - totalCost;
          debugPrint('Item: ${item.itemName}, Cost: $totalCost, Revenue: $totalRevenue, Profit: $profit');

          profitLossItems.add(ProfitLossItem(
            itemName: item.itemName,
            quality: item.quality,
            quantitySold: item.qty,
            revenue: totalRevenue,
            cost: totalCost,
            profit: profit,
            saleDate: saleDate,
            invoiceNumber: invoiceNumber,
            invoiceId: invoiceId,
          ));
        }
      }

      setState(() {
        _profitLossItems = profitLossItems;
        _isLoading = false;
      });
    } on FirebaseException catch (e) {
      debugPrint('FirebaseException: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Firebase Error: ${e.message}';
      });
    } catch (e, stackTrace) {
      debugPrint('Unexpected error: $e\nStackTrace: $stackTrace');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unexpected error: $e';
      });
    }
  }

  Future<void> _selectDateRange(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _selectedDateRange!.start : _selectedDateRange!.end,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: widget.isDarkMode ? ThemeData.dark() : ThemeData.light(),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _selectedDateRange = DateTimeRange(start: picked, end: _selectedDateRange!.end);
        } else {
          _selectedDateRange = DateTimeRange(start: _selectedDateRange!.start, end: picked);
        }
        _fetchProfitLossData();
      });
    }
  }

  void _navigateToInvoice(String invoiceId) async {
    try {
      final doc = await _firestore.collection('invoices').doc(invoiceId).get();
      if (doc.exists) {
        final invoice = Invoice.fromMap(doc.id, doc.data()!);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PointOfSalePage(invoice: invoice, isReadOnly: true),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice not found')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading invoice: $e')),
      );
    }
  }

  Widget _buildDateFilterChip(String label, DateTime date, bool isStart) {
    return InputChip(
      label: Text(
        DateFormat('dd-MM-yyyy').format(date),
        style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w500),
      ),
      backgroundColor: _surfaceColorCache,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _primaryColor.withOpacity(0.3)),
      ),
      onPressed: () => _selectDateRange(context, isStart),
    );
  }

  Widget _buildDesktopHeader() {
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(child: _HeaderCell('Invoice #')),
            Expanded(child: _HeaderCell('Quality')),
            Expanded(child: _HeaderCell('Item Name')),
            Expanded(child: _HeaderCell('Qty Sold')),
            Expanded(child: _HeaderCell('Cost')),
            Expanded(child: _HeaderCell('Revenue')),
            Expanded(child: _HeaderCell('Profit')),
            Expanded(child: _HeaderCell('Sale Date')),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _HeaderCell('Invoice #', 150),
            _HeaderCell('Quality', 150),
            _HeaderCell('Item Name', 200),
            _HeaderCell('Qty Sold', 150),
            _HeaderCell('Cost', 200),
            _HeaderCell('Revenue', 200),
            _HeaderCell('Profit', 200),
            _HeaderCell('Sale Date', 200),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopRow(ProfitLossItem item) {
    debugPrint('Building desktop row for item: ${item.itemName}');
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: _surfaceColorCache,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _navigateToInvoice(item.invoiceId),
                child: _DataCell(
                  item.invoiceNumber.toString(),
                  isDarkMode: widget.isDarkMode,
                  color: _primaryColor,
                ),
              ),
            ),
            Expanded(child: _DataCell(item.quality, isDarkMode: widget.isDarkMode)),
            Expanded(child: _DataCell(item.itemName, isDarkMode: widget.isDarkMode)),
            Expanded(child: _DataCell(item.quantitySold.toInt().toString(), isDarkMode: widget.isDarkMode)),
            Expanded(child: _DataCell(item.cost.toInt().toString(), isDarkMode: widget.isDarkMode)),
            Expanded(child: _DataCell(item.revenue.toInt().toString(), isDarkMode: widget.isDarkMode)),
            Expanded(
              child: _DataCell(
                item.profit.toInt().toString(),
                isDarkMode: widget.isDarkMode,
                color: item.profit >= 0 ? Colors.green : Colors.red,
              ),
            ),
            Expanded(child: _DataCell(DateFormat('dd-MM-yyyy').format(item.saleDate), isDarkMode: widget.isDarkMode)),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileRow(ProfitLossItem item) {
    debugPrint('Building mobile row for item: ${item.itemName}');
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: _surfaceColorCache,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _navigateToInvoice(item.invoiceId),
              child: _DataCell(
                item.invoiceNumber.toString(),
                width: 150,
                isDarkMode: widget.isDarkMode,
                color: _primaryColor,
              ),
            ),
            _DataCell(item.quality, width: 150, isDarkMode: widget.isDarkMode),
            _DataCell(item.itemName, width: 200, isDarkMode: widget.isDarkMode),
            _DataCell(item.quantitySold.toInt().toString(), width: 150, isDarkMode: widget.isDarkMode),
            _DataCell(item.cost.toInt().toString(), width: 200, isDarkMode: widget.isDarkMode),
            _DataCell(item.revenue.toInt().toString(), width: 200, isDarkMode: widget.isDarkMode),
            _DataCell(
              item.profit.toInt().toString(),
              width: 200,
              isDarkMode: widget.isDarkMode,
              color: item.profit >= 0 ? Colors.green : Colors.red,
            ),
            _DataCell(DateFormat('dd-MM-yyyy').format(item.saleDate), width: 200, isDarkMode: widget.isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16)));
    }
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: _primaryColor));
    }
    if (_profitLossItems.isEmpty) {
      return Center(child: Text('No data available', style: TextStyle(color: _textColorCache)));
    }

    return Column(
      children: [
        _buildDesktopHeader(),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 16),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: _profitLossItems.length,
            itemBuilder: (context, index) => _buildDesktopRow(_profitLossItems[index]),
          ),
        ),
        _buildTotalProfit(),
      ],
    );
  }

  Widget _buildMobileLayout() {
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16)));
    }
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: _primaryColor));
    }
    if (_profitLossItems.isEmpty) {
      return Center(child: Text('No data available', style: TextStyle(color: _textColorCache)));
    }

    return Scrollbar(
      controller: _horizontalScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalScrollController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _mobileTableWidth,
          child: Column(
            children: [
              _buildMobileHeader(),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: _profitLossItems.length,
                  itemBuilder: (context, index) => _buildMobileRow(_profitLossItems[index]),
                ),
              ),
              _buildTotalProfit(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalProfit() {
    final totalProfit = _profitLossItems.fold(0.0, (sum, item) => sum + item.profit).toInt();
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: _surfaceColorCache,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total Profit:',
            style: TextStyle(color: _textColorCache, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(
            '$totalProfit',
            style: TextStyle(
              color: totalProfit >= 0 ? Colors.green : Colors.red,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 1200;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('Profit and Loss', style: TextStyle(color: _textColorCache)),
            const SizedBox(width: 16),
            if (_selectedDateRange != null) ...[
              _buildDateFilterChip('From', _selectedDateRange!.start, true),
              const SizedBox(width: 16),
              _buildDateFilterChip('To', _selectedDateRange!.end, false),
            ],
          ],
        ),
        backgroundColor: _backgroundColorCache,
        elevation: 0,
        iconTheme: IconThemeData(color: _textColorCache),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            color: _textColorCache,
            onPressed: widget.toggleDarkMode,
          ),
        ],
      ),
      backgroundColor: _backgroundColorCache,
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }
}

class PurchaseBatch {
  final double purchasePrice;
  final double discount;
  double quantity;
  final DateTime date;

  PurchaseBatch({
    required this.purchasePrice,
    required this.discount,
    required this.quantity,
    required this.date,
  });
}

class ProfitLossItem {
  final String itemName;
  final String quality;
  final double quantitySold;
  final double revenue;
  final double cost;
  final double profit;
  final DateTime saleDate;
  final int invoiceNumber;
  final String invoiceId;

  ProfitLossItem({
    required this.itemName,
    required this.quality,
    required this.quantitySold,
    required this.revenue,
    required this.cost,
    required this.profit,
    required this.saleDate,
    required this.invoiceNumber,
    required this.invoiceId,
  });
}

class CartItem {
  final String quality;
  final String itemName;
  final String? covered;
  final double qty;
  final double originalQty;
  final String price;
  final String discount;
  final String total;

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

  factory CartItem.fromMap(Map<String, dynamic> map) => CartItem(
    quality: map['quality']?.toString() ?? '',
    itemName: map['item']?.toString() ?? '',
    covered: map['covered']?.toString(),
    qty: (map['qty'] is num ? map['qty'].toDouble() : double.tryParse(map['qty']?.toString() ?? '0')) ?? 0.0,
    originalQty: (map['originalQty'] is num
        ? map['originalQty'].toDouble()
        : double.tryParse(map['originalQty']?.toString() ?? '0')) ??
        (map['qty'] is num ? map['qty'].toDouble() : double.tryParse(map['qty']?.toString() ?? '0')) ??
        0.0,
    price: map['price']?.toString() ?? '0',
    discount: map['discount']?.toString() ?? '0',
    total: map['total']?.toString() ?? '0',
  );
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double? width;

  const _HeaderCell(this.text, [this.width]);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Center(
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final dynamic text;
  final double? width;
  final Color? color;
  final bool isDarkMode;

  const _DataCell(this.text, {this.width, this.color, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Center(
        child: Text(
          text.toString(),
          style: TextStyle(
            color: color ?? (isDarkMode ? Colors.white : _textColor),
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }
}