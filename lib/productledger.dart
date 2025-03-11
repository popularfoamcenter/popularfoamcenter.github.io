import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// Assuming these files contain the required classes
import 'pointofsale.dart'; // Replace with actual file path
import 'purchaseinvoice.dart';   // Replace with actual file path

// Color Scheme (unchanged)
const Color _primaryColor = Color(0xFF0D6EFD);
const Color _textColorLight = Color(0xFF2D2D2D);
const Color _secondaryTextColorLight = Color(0xFF4A4A4A);
const Color _backgroundColorLight = Color(0xFFF8F9FA);
const Color _surfaceColorLight = Colors.white;
const Color _backgroundColorDark = Color(0xFF1A1A2F);
const Color _surfaceColorDark = Color(0xFF252541);
const Color _textColorDark = Colors.white;
const Color _secondaryTextColorDark = Colors.white70;

class ProcessedTransaction {
  final String docId;
  final String type;
  final String details;
  final double received;
  final double given;
  final double returned;
  final double balance;
  final DateTime date;

  ProcessedTransaction(this.docId, this.type, this.details, this.received, this.given, this.returned, this.balance, this.date);
}

class ProductLedgerPage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback toggleDarkMode;

  const ProductLedgerPage({super.key, required this.isDarkMode, required this.toggleDarkMode});

  @override
  _ProductLedgerPageState createState() => _ProductLedgerPageState();
}

class _ProductLedgerPageState extends State<ProductLedgerPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _horizontalScrollController = ScrollController();
  final double _mobileTableWidth = 1400; // Increased width to accommodate "Returned" column
  String? _selectedQuality;
  String? _selectedItem;
  DateTime? _fromDate;
  DateTime? _toDate;

  Color get _textColor => widget.isDarkMode ? _textColorDark : _textColorLight;
  Color get _secondaryTextColor => widget.isDarkMode ? _secondaryTextColorDark : _secondaryTextColorLight;
  Color get _backgroundColor => widget.isDarkMode ? _backgroundColorDark : _backgroundColorLight;
  Color get _surfaceColor => widget.isDarkMode ? _surfaceColorDark : _surfaceColorLight;

  Future<List<ProcessedTransaction>> _fetchLedgerTransactions(String quality) async {
    List<ProcessedTransaction> transactions = [];
    double initialBalance = await _fetchOpeningBalance();

    // Fetch and process all transactions without calculating balance yet
    QuerySnapshot purchasesSnapshot = await _firestore.collection('purchaseinvoices').get();
    for (var purchase in purchasesSnapshot.docs) {
      var purchaseData = purchase.data() as Map<String, dynamic>;
      var items = purchaseData['items'] as List<dynamic>? ?? [];
      DateTime? date;
      try {
        date = DateFormat('dd-MM-yyyy').parse(purchaseData['receiveDate'] ?? '');
      } catch (e) {
        continue;
      }
      if (_fromDate != null && date.isBefore(_fromDate!)) continue;
      if (_toDate != null && date.isAfter(_toDate!)) continue;

      for (var item in items) {
        if (item['quality'] == quality && (_selectedItem == null || item['name'] == _selectedItem)) {
          double qty = item['quantity'] is String
              ? double.tryParse(item['quantity'] as String) ?? 0.0
              : (item['quantity'] as num?)?.toDouble() ?? 0.0;
          if (qty > 0) {
            String invoiceId = purchaseData['invoiceId']?.toString() ?? purchase.id;
            transactions.add(ProcessedTransaction(
              purchase.id,
              'Purchase',
              'Purchase #$invoiceId',
              qty,
              0.0,
              0.0, // No returns here
              0.0, // Placeholder balance
              date,
            ));
          }
        }
      }
    }

    QuerySnapshot salesSnapshot = await _firestore.collection('invoices').where('type', isEqualTo: 'Sale').get();
    for (var sale in salesSnapshot.docs) {
      var saleData = sale.data() as Map<String, dynamic>;
      var items = saleData['items'] as List<dynamic>? ?? [];
      DateTime? date = (saleData['timestamp'] as Timestamp?)?.toDate();
      if (date == null) continue;
      if (_fromDate != null && date.isBefore(_fromDate!)) continue;
      if (_toDate != null && date.isAfter(_toDate!)) continue;

      for (var item in items) {
        if (item['quality'] == quality && (_selectedItem == null || item['item'] == _selectedItem)) {
          double qty = item['qty'] is String
              ? double.tryParse(item['qty'] as String) ?? 0.0
              : (item['qty'] as num?)?.toDouble() ?? 0.0;
          if (qty > 0) {
            String invoiceNumber = saleData['invoiceNumber']?.toString() ?? sale.id;
            transactions.add(ProcessedTransaction(
              sale.id,
              'Sale',
              'Sale #$invoiceNumber',
              0.0,
              qty,
              0.0, // No returns here
              0.0, // Placeholder balance
              date,
            ));
          }
        }
      }
    }

    // Fetch and process return transactions
    QuerySnapshot returnsSnapshot = await _firestore.collection('invoices').where('type', isEqualTo: 'Return').get();
    for (var returnDoc in returnsSnapshot.docs) {
      var returnData = returnDoc.data() as Map<String, dynamic>;
      var items = returnData['items'] as List<dynamic>? ?? [];
      DateTime? date = (returnData['timestamp'] as Timestamp?)?.toDate();
      if (date == null) continue;
      if (_fromDate != null && date.isBefore(_fromDate!)) continue;
      if (_toDate != null && date.isAfter(_toDate!)) continue;

      for (var item in items) {
        if (item['quality'] == quality && (_selectedItem == null || item['item'] == _selectedItem)) {
          double qty = item['qty'] is String
              ? double.tryParse(item['qty'] as String) ?? 0.0
              : (item['qty'] as num?)?.toDouble() ?? 0.0;
          if (qty > 0) {
            String returnNumber = returnData['invoiceNumber']?.toString() ?? returnDoc.id;
            transactions.add(ProcessedTransaction(
              returnDoc.id,
              'Return',
              'Return #$returnNumber',
              0.0,
              0.0,
              qty, // Returned quantity
              0.0, // Placeholder balance
              date,
            ));
          }
        }
      }
    }

    // Sort transactions by date
    transactions.sort((a, b) => a.date.compareTo(b.date));

    // Calculate running balance chronologically
    double runningBalance = initialBalance;
    List<ProcessedTransaction> updatedTransactions = [];
    for (var transaction in transactions) {
      if (transaction.type == 'Purchase') {
        runningBalance += transaction.received;
      } else if (transaction.type == 'Sale') {
        runningBalance -= transaction.given;
      } else if (transaction.type == 'Return') {
        runningBalance += transaction.returned; // Returns increase stock
      }
      updatedTransactions.add(ProcessedTransaction(
        transaction.docId,
        transaction.type,
        transaction.details,
        transaction.received,
        transaction.given,
        transaction.returned,
        runningBalance,
        transaction.date,
      ));
    }
    transactions = updatedTransactions; // Assign the updated list

    // Debugging logs
    print('Initial Balance: $initialBalance');
    for (var transaction in transactions) {
      print('Date: ${DateFormat('dd-MM-yyyy').format(transaction.date)}, Type: ${transaction.type}, '
          'Received: ${transaction.received}, Given: ${transaction.given}, Returned: ${transaction.returned}, '
          'Balance: ${transaction.balance}');
    }

    return transactions;
  }

  Future<double> _fetchOpeningBalance() async {
    if (_selectedQuality == null) return 0.0;

    QuerySnapshot itemsSnapshot = await _firestore
        .collection('items')
        .where('qualityName', isEqualTo: _selectedQuality)
        .get();

    double totalOpeningBalance = 0.0;
    for (var itemDoc in itemsSnapshot.docs) {
      var itemData = itemDoc.data() as Map<String, dynamic>;
      String itemName = itemData['itemName'] ?? 'Unknown';
      if (_selectedItem != null && itemName != _selectedItem) continue;
      double stock = itemData['openingStock'] is String
          ? double.tryParse(itemData['openingStock'] as String) ?? 0.0
          : (itemData['openingStock'] as num?)?.toDouble() ?? 0.0;
      totalOpeningBalance += stock;
    }
    return totalOpeningBalance;
  }

  Future<Map<String, dynamic>> _calculateSummary() async {
    if (_selectedQuality == null) return {'totalReceived': 0.0, 'totalGiven': 0.0, 'totalReturned': 0.0, 'finalBalance': 0.0};

    final transactions = await _fetchLedgerTransactions(_selectedQuality!);
    double totalReceived = 0.0;
    double totalGiven = 0.0;
    double totalReturned = 0.0;
    double initialBalance = await _fetchOpeningBalance();

    for (var transaction in transactions) {
      totalReceived += transaction.received;
      totalGiven += transaction.given;
      totalReturned += transaction.returned;
    }
    double finalBalance = initialBalance + totalReceived - totalGiven + totalReturned;

    return {
      'totalReceived': totalReceived,
      'totalGiven': totalGiven,
      'totalReturned': totalReturned,
      'finalBalance': finalBalance,
    };
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: widget.isDarkMode ? ThemeData.dark() : ThemeData.light(),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) _fromDate = picked;
        else _toDate = picked;
      });
    }
  }

  void _showSummaryBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _calculateSummary(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: _textColor)));
              }

              final summary = snapshot.data ?? {'totalReceived': 0.0, 'totalGiven': 0.0, 'totalReturned': 0.0, 'finalBalance': 0.0};
              return _buildSummaryFooter(
                summary['totalReceived'] as double,
                summary['totalGiven'] as double,
                summary['totalReturned'] as double,
                summary['finalBalance'] as double,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _navigateToInvoiceView(ProcessedTransaction transaction) async {
    try {
      if (transaction.type == 'Purchase') {
        DocumentSnapshot purchaseDoc = await _firestore.collection('purchaseinvoices').doc(transaction.docId).get();
        if (!purchaseDoc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase invoice not found')),
          );
          return;
        }
        final purchaseData = purchaseDoc.data() as Map<String, dynamic>;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InvoiceViewScreen.fromData(
              company: purchaseData['company'] ?? 'Unknown Company',
              invoiceId: transaction.docId,
              existingInvoice: purchaseData,
            ),
          ),
        );
      } else if (transaction.type == 'Sale' || transaction.type == 'Return') {
        DocumentSnapshot doc = await _firestore.collection('invoices').doc(transaction.docId).get();
        if (!doc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice not found')),
          );
          return;
        }
        final data = doc.data() as Map<String, dynamic>;
        Invoice invoice = Invoice.fromMap(transaction.docId, data);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PointOfSalePage(
              invoice: invoice,
              isReadOnly: true,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading invoice: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 1200;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('Product Ledger', style: TextStyle(color: _textColor)),
            const SizedBox(width: 16),
            Expanded(child: _buildQualityDropdown()),
            const SizedBox(width: 16),
            Expanded(child: _buildItemDropdown()),
            const SizedBox(width: 16),
            _buildDateFilterChip('From', _fromDate, true),
            const SizedBox(width: 16),
            _buildDateFilterChip('To', _toDate, false),
          ],
        ),
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            color: _textColor,
            onPressed: widget.toggleDarkMode,
          ),
        ],
      ),
      backgroundColor: _backgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSummaryBottomSheet(context),
        backgroundColor: _primaryColor,
        child: const Icon(Icons.info_outline, color: Colors.white),
      ),
      body: Column(
        children: [
          if (_selectedQuality != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: _buildOpeningBalanceCard(),
            ),
            Expanded(child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout()),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() => _buildLedgerTable(isDesktop: true);

  Widget _buildMobileLayout() => Scrollbar(
    controller: _horizontalScrollController,
    thumbVisibility: true,
    child: SingleChildScrollView(
      controller: _horizontalScrollController,
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _mobileTableWidth,
        child: _buildLedgerTable(isDesktop: false),
      ),
    ),
  );

  Widget _buildLedgerTable({required bool isDesktop}) {
    if (_selectedQuality == null) {
      return Center(child: Text('Please select a quality', style: TextStyle(color: _textColor)));
    }

    return FutureBuilder<List<ProcessedTransaction>>(
      future: _fetchLedgerTransactions(_selectedQuality!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _primaryColor));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: _textColor)));
        }

        final transactions = snapshot.data ?? [];
        if (transactions.isEmpty) {
          return Center(child: Text('No transactions found', style: TextStyle(color: _textColor)));
        }

        return Column(
          children: [
            _buildTableHeader(isDesktop),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: transactions.length,
                itemBuilder: (context, index) => _buildTableRow(transactions[index], isDesktop),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTableHeader(bool isDesktop) => Container(
    height: 56,
    margin: const EdgeInsets.symmetric(horizontal: 24),
    decoration: BoxDecoration(
      color: _primaryColor,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          isDesktop ? const Expanded(child: _HeaderCell('Date')) : const _HeaderCell('Date', 150),
          isDesktop ? const Expanded(flex: 2, child: _HeaderCell('Details')) : const _HeaderCell('Details', 300),
          isDesktop ? const Expanded(child: _HeaderCell('Received')) : const _HeaderCell('Received', 150),
          isDesktop ? const Expanded(child: _HeaderCell('Given')) : const _HeaderCell('Given', 150),
          isDesktop ? const Expanded(child: _HeaderCell('Returned')) : const _HeaderCell('Returned', 150),
          isDesktop ? const Expanded(child: _HeaderCell('Balance')) : const _HeaderCell('Balance', 150),
        ],
      ),
    ),
  );

  Widget _buildTableRow(ProcessedTransaction transaction, bool isDesktop) => GestureDetector(
    onTap: () => _navigateToInvoiceView(transaction),
    child: Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            isDesktop
                ? Expanded(child: _DataCell(DateFormat('dd-MM-yyyy').format(transaction.date)))
                : _DataCell(DateFormat('dd-MM-yyyy').format(transaction.date), 150),
            isDesktop
                ? Expanded(
              flex: 2,
              child: _DataCell(transaction.details, null, _primaryColor), // Blue for invoices
            )
                : _DataCell(transaction.details, 300, _primaryColor), // Blue for invoices
            isDesktop
                ? Expanded(
              child: _DataCell(
                transaction.received > 0 ? transaction.received.toStringAsFixed(0) : '-',
                null,
                transaction.received > 0 ? Colors.green : _secondaryTextColor,
              ),
            )
                : _DataCell(
              transaction.received > 0 ? transaction.received.toStringAsFixed(0) : '-',
              150,
              transaction.received > 0 ? Colors.green : _secondaryTextColor,
            ),
            isDesktop
                ? Expanded(
              child: _DataCell(
                transaction.given > 0 ? transaction.given.toStringAsFixed(0) : '-',
                null,
                transaction.given > 0 ? Colors.red : _secondaryTextColor,
              ),
            )
                : _DataCell(
              transaction.given > 0 ? transaction.given.toStringAsFixed(0) : '-',
              150,
              transaction.given > 0 ? Colors.red : _secondaryTextColor,
            ),
            isDesktop
                ? Expanded(
              child: _DataCell(
                transaction.returned > 0 ? transaction.returned.toStringAsFixed(0) : '-',
                null,
                transaction.returned > 0 ? Colors.orange : _secondaryTextColor, // Orange for returns
              ),
            )
                : _DataCell(
              transaction.returned > 0 ? transaction.returned.toStringAsFixed(0) : '-',
              150,
              transaction.returned > 0 ? Colors.orange : _secondaryTextColor,
            ),
            isDesktop
                ? Expanded(
              child: _DataCell(
                transaction.balance.toStringAsFixed(0),
                null,
                transaction.balance >= 0 ? Colors.green : Colors.red,
              ),
            )
                : _DataCell(
              transaction.balance.toStringAsFixed(0),
              150,
              transaction.balance >= 0 ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildOpeningBalanceCard() => FutureBuilder<double>(
    future: _fetchOpeningBalance(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return CircularProgressIndicator(color: _primaryColor);
      }
      final openingBalance = snapshot.data ?? 0.0;
      return Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Product Details', style: GoogleFonts.roboto(color: _primaryColor, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            _buildDetailRow('Quality', _selectedQuality ?? 'N/A'),
            if (_selectedItem != null) _buildDetailRow('Item', _selectedItem ?? 'N/A'),
            _buildDetailRow('Opening Balance', openingBalance.toStringAsFixed(0)),
          ],
        ),
      );
    },
  );

  Widget _buildDetailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(width: 100, child: Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: _secondaryTextColor, fontSize: 12))),
        Expanded(child: Text(value, style: TextStyle(color: _textColor, fontSize: 12))),
      ],
    ),
  );

  Widget _buildSummaryFooter(double totalReceived, double totalGiven, double totalReturned, double finalBalance) => Container(
    margin: const EdgeInsets.all(24),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildFooterColumn('Total Received', totalReceived, Colors.green),
            _buildFooterColumn('Total Given', totalGiven, Colors.red),
            _buildFooterColumn('Total Returned', totalReturned, Colors.orange),
            _buildFooterColumn('Final Balance', finalBalance, finalBalance >= 0 ? Colors.green : Colors.red),
          ],
        ),
      ],
    ),
  );

  Widget _buildFooterColumn(String label, double value, Color color) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: TextStyle(color: _secondaryTextColor, fontSize: 14)),
      const SizedBox(height: 4),
      Text(
        '${value.toStringAsFixed(0)}',
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    ],
  );

  Widget _buildQualityDropdown() => StreamBuilder<QuerySnapshot>(
    stream: _firestore.collection('qualities').snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return CircularProgressIndicator(color: _primaryColor, strokeWidth: 2);
      final qualities = snapshot.data!.docs.map((doc) => doc['name'] as String).toList();
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            dropdownColor: _surfaceColor,
            value: _selectedQuality,
            hint: Text('Select quality', style: TextStyle(color: _secondaryTextColor, fontSize: 14)),
            icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
            items: qualities.map((quality) => DropdownMenuItem(
              value: quality,
              child: Text(quality, style: TextStyle(color: _textColor, fontSize: 14)),
            )).toList(),
            onChanged: (value) => setState(() {
              _selectedQuality = value;
              _selectedItem = null;
            }),
          ),
        ),
      );
    },
  );

  Widget _buildItemDropdown() => _selectedQuality == null
      ? Container(
    height: 56,
    decoration: BoxDecoration(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        isExpanded: true,
        dropdownColor: _surfaceColor,
        value: null,
        hint: Text('Select item', style: TextStyle(color: _secondaryTextColor, fontSize: 14)),
        icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
        items: const [],
        onChanged: null,
      ),
    ),
  )
      : StreamBuilder<QuerySnapshot>(
    stream: _firestore.collection('items').where('qualityName', isEqualTo: _selectedQuality).snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return CircularProgressIndicator(color: _primaryColor, strokeWidth: 2);
      final items = snapshot.data!.docs.map((doc) => doc['itemName'] as String).toList();
      items.insert(0, 'All Items');
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            dropdownColor: _surfaceColor,
            value: _selectedItem,
            hint: Text('Select item', style: TextStyle(color: _secondaryTextColor, fontSize: 14)),
            icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
            items: items.map((item) => DropdownMenuItem(
              value: item == 'All Items' ? null : item,
              child: Text(item, style: TextStyle(color: _textColor, fontSize: 14)),
            )).toList(),
            onChanged: (value) => setState(() => _selectedItem = value),
          ),
        ),
      );
    },
  );

  Widget _buildDateFilterChip(String label, DateTime? date, bool isFromDate) => InputChip(
    label: Text(
      date != null ? DateFormat('dd-MM-yyyy').format(date) : label,
      style: TextStyle(color: date != null ? _primaryColor : _secondaryTextColor, fontWeight: FontWeight.w500),
    ),
    backgroundColor: _surfaceColor,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _primaryColor.withOpacity(0.3))),
    onPressed: () => _selectDate(context, isFromDate),
  );
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double? width;

  const _HeaderCell(this.text, [this.width]);

  @override
  Widget build(BuildContext context) => SizedBox(
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

class _DataCell extends StatelessWidget {
  final String text;
  final double? width;
  final Color? color; // Added color parameter

  const _DataCell(this.text, [this.width, this.color]);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = (context.findAncestorWidgetOfExactType<ProductLedgerPage>())!.isDarkMode;
    return SizedBox(
      width: width,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: color ?? (isDarkMode ? Colors.white : _textColorLight), // Use provided color or default
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }
}