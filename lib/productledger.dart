import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For RawKeyboard
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';

// Assuming these files contain the required classes
import 'pointofsale.dart'; // Replace with actual file path
import 'purchaseinvoice.dart'; // Replace with actual file path

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
  final double inQty;
  final double outQty;
  final double balance;
  final DateTime date;

  ProcessedTransaction(this.docId, this.type, this.details, this.inQty, this.outQty, this.balance, this.date);
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
  final double _mobileTableWidth = 1200;
  String? _selectedQuality;
  String? _selectedItem;
  DateTime? _fromDate;
  DateTime? _toDate;

  // FocusNodes for page and dropdowns
  final FocusNode _pageFocusNode = FocusNode();
  final FocusNode _qualityDropdownFocusNode = FocusNode();
  final FocusNode _itemDropdownFocusNode = FocusNode();

  Color get _textColor => widget.isDarkMode ? _textColorDark : _textColorLight;
  Color get _secondaryTextColor => widget.isDarkMode ? _secondaryTextColorDark : _secondaryTextColorLight;
  Color get _backgroundColor => widget.isDarkMode ? _backgroundColorDark : _backgroundColorLight;
  Color get _surfaceColor => widget.isDarkMode ? _surfaceColorDark : _surfaceColorLight;

  String _formatDouble(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    } else {
      return value.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
  }

  Future<List<ProcessedTransaction>> _fetchLedgerTransactions(String quality) async {
    List<ProcessedTransaction> transactions = [];
    double initialBalance = await _fetchOpeningBalance();

    if (_selectedItem == null && _selectedQuality != null) {
      return transactions;
    }

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
        if (item['quality'] == quality && item['name'] == _selectedItem) {
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
              0.0,
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
        if (item['quality'] == quality && item['item'] == _selectedItem) {
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
              0.0,
              date,
            ));
          }
        }
      }
    }

    QuerySnapshot returnsSnapshot = await _firestore.collection('invoices').where('type', isEqualTo: 'Return').get();
    for (var returnDoc in returnsSnapshot.docs) {
      var returnData = returnDoc.data() as Map<String, dynamic>;
      var items = returnData['items'] as List<dynamic>? ?? [];
      DateTime? date = (returnData['timestamp'] as Timestamp?)?.toDate();
      if (date == null) continue;
      if (_fromDate != null && date.isBefore(_fromDate!)) continue;
      if (_toDate != null && date.isAfter(_toDate!)) continue;

      for (var item in items) {
        if (item['quality'] == quality && item['item'] == _selectedItem) {
          double qty = item['qty'] is String
              ? double.tryParse(item['qty'] as String) ?? 0.0
              : (item['qty'] as num?)?.toDouble() ?? 0.0;
          if (qty > 0) {
            String returnNumber = returnData['invoiceNumber']?.toString() ?? returnDoc.id;
            transactions.add(ProcessedTransaction(
              returnDoc.id,
              'Return',
              'Return #$returnNumber',
              qty,
              0.0,
              0.0,
              date,
            ));
          }
        }
      }
    }

    transactions.sort((a, b) => a.date.compareTo(b.date));

    double runningBalance = initialBalance;
    List<ProcessedTransaction> updatedTransactions = [];
    for (var transaction in transactions) {
      runningBalance += transaction.inQty - transaction.outQty;
      updatedTransactions.add(ProcessedTransaction(
        transaction.docId,
        transaction.type,
        transaction.details,
        transaction.inQty,
        transaction.outQty,
        runningBalance,
        transaction.date,
      ));
    }
    return updatedTransactions;
  }

  Future<double> _fetchOpeningBalance() async {
    if (_selectedQuality == null || _selectedItem == null) return 0.0;

    QuerySnapshot itemsSnapshot = await _firestore
        .collection('items')
        .where('qualityName', isEqualTo: _selectedQuality)
        .where('itemName', isEqualTo: _selectedItem)
        .get();

    double totalOpeningBalance = 0.0;
    for (var itemDoc in itemsSnapshot.docs) {
      var itemData = itemDoc.data() as Map<String, dynamic>;
      double stock = itemData['openingStock'] is String
          ? double.tryParse(itemData['openingStock'] as String) ?? 0.0
          : (itemData['openingStock'] as num?)?.toDouble() ?? 0.0;
      totalOpeningBalance += stock;
    }
    return totalOpeningBalance;
  }

  Future<Map<String, dynamic>> _calculateSummary() async {
    if (_selectedQuality == null || _selectedItem == null) return {'totalIn': 0.0, 'totalOut': 0.0, 'finalBalance': 0.0};

    final transactions = await _fetchLedgerTransactions(_selectedQuality!);
    double totalIn = 0.0;
    double totalOut = 0.0;
    double initialBalance = await _fetchOpeningBalance();

    for (var transaction in transactions) {
      totalIn += transaction.inQty;
      totalOut += transaction.outQty;
    }
    double finalBalance = initialBalance + totalIn - totalOut;

    return {
      'totalIn': totalIn,
      'totalOut': totalOut,
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

              final summary = snapshot.data ?? {'totalIn': 0.0, 'totalOut': 0.0, 'finalBalance': 0.0};
              return _buildSummaryFooter(
                summary['totalIn'] as double,
                summary['totalOut'] as double,
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
      } else {
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

  KeyEventResult _handleKeyEvent(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      print('Key pressed: ${event.logicalKey.keyLabel}');
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        _showSummaryBottomSheet(context);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() {
          _selectedQuality = null;
          _selectedItem = null;
          _fromDate = null;
          _toDate = null;
        });
        return KeyEventResult.handled;
      } else if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyF) {
        _qualityDropdownFocusNode.requestFocus();
        return KeyEventResult.handled;
      } else if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyI) {
        if (_selectedQuality != null) {
          _itemDropdownFocusNode.requestFocus();
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pageFocusNode.dispose();
    _qualityDropdownFocusNode.dispose();
    _itemDropdownFocusNode.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 1200;
    return Focus(
      focusNode: _pageFocusNode,
      onKey: _handleKeyEvent,
      child: Scaffold(
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
    if (_selectedQuality == null || _selectedItem == null) {
      return Center(child: Text('Please select a quality and item', style: TextStyle(color: _textColor)));
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
          isDesktop ? const Expanded(child: _HeaderCell('In')) : const _HeaderCell('In', 150),
          isDesktop ? const Expanded(child: _HeaderCell('Out')) : const _HeaderCell('Out', 150),
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
                ? Expanded(flex: 2, child: _DataCell(transaction.details, null, _primaryColor))
                : _DataCell(transaction.details, 300, _primaryColor),
            isDesktop
                ? Expanded(
              child: _DataCell(
                transaction.inQty > 0 ? _formatDouble(transaction.inQty) : '-',
                null,
                transaction.inQty > 0 ? Colors.green : _secondaryTextColor,
              ),
            )
                : _DataCell(
              transaction.inQty > 0 ? _formatDouble(transaction.inQty) : '-',
              150,
              transaction.inQty > 0 ? Colors.green : _secondaryTextColor,
            ),
            isDesktop
                ? Expanded(
              child: _DataCell(
                transaction.outQty > 0 ? _formatDouble(transaction.outQty) : '-',
                null,
                transaction.outQty > 0 ? Colors.red : _secondaryTextColor,
              ),
            )
                : _DataCell(
              transaction.outQty > 0 ? _formatDouble(transaction.outQty) : '-',
              150,
              transaction.outQty > 0 ? Colors.red : _secondaryTextColor,
            ),
            isDesktop
                ? Expanded(
              child: _DataCell(
                _formatDouble(transaction.balance),
                null,
                transaction.balance >= 0 ? Colors.green : Colors.red,
              ),
            )
                : _DataCell(
              _formatDouble(transaction.balance),
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
            Text('Product Details',
                style: GoogleFonts.roboto(color: _primaryColor, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            _buildDetailRow('Quality', _selectedQuality ?? 'N/A'),
            if (_selectedItem != null) _buildDetailRow('Item', _selectedItem ?? 'N/A'),
            _buildDetailRow('Opening Balance', _formatDouble(openingBalance)),
          ],
        ),
      );
    },
  );

  Widget _buildDetailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(fontWeight: FontWeight.w500, color: _secondaryTextColor, fontSize: 12))),
        Expanded(child: Text(value, style: TextStyle(color: _textColor, fontSize: 12))),
      ],
    ),
  );

  Widget _buildSummaryFooter(double totalIn, double totalOut, double finalBalance) => Container(
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
            _buildFooterColumn('Total In', totalIn, Colors.green),
            _buildFooterColumn('Total Out', totalOut, Colors.red),
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
        _formatDouble(value),
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
        child: DropdownSearch<String>(
          popupProps: PopupProps.menu(
            showSearchBox: true,
            showSelectedItems: true,
            searchFieldProps: TextFieldProps(
              focusNode: _qualityDropdownFocusNode,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search quality...',
                hintStyle: TextStyle(color: _secondaryTextColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _primaryColor.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _primaryColor),
                ),
              ),
              style: TextStyle(color: _textColor),
            ),
            itemBuilder: (context, item, isSelected) => ListTile(
              title: Text(
                item,
                style: TextStyle(
                  color: isSelected ? _primaryColor : _textColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              tileColor: isSelected ? _primaryColor.withOpacity(0.1) : _surfaceColor,
            ),
            menuProps: MenuProps(
              backgroundColor: _surfaceColor,
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
            ),
            fit: FlexFit.loose,
            constraints: const BoxConstraints(maxHeight: 300),
          ),
          dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              hintText: 'Select quality',
              hintStyle: TextStyle(color: _secondaryTextColor, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            baseStyle: TextStyle(color: _textColor, fontSize: 14),
          ),
          dropdownBuilder: (context, selectedItem) {
            return GestureDetector(
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _qualityDropdownFocusNode.requestFocus();
                });
              },
              child: Text(
                selectedItem ?? 'Select quality',
                style: TextStyle(
                  color: selectedItem != null ? _textColor : _secondaryTextColor,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
          items: qualities,
          selectedItem: _selectedQuality,
          onChanged: (String? value) {
            setState(() {
              _selectedQuality = value;
              _selectedItem = null; // Reset item when quality changes
            });
          },
          filterFn: (item, filter) => item.toLowerCase().contains(filter.toLowerCase()),
          dropdownButtonProps: DropdownButtonProps(
            icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
          ),
          clearButtonProps: ClearButtonProps(
            isVisible: true,
            icon: Icon(Icons.clear, color: _primaryColor),
            onPressed: () {
              setState(() {
                _selectedQuality = null;
                _selectedItem = null;
              });
            },
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
    child: Text(
      'Select item',
      style: TextStyle(color: _secondaryTextColor, fontSize: 14),
    ),
  )
      : StreamBuilder<QuerySnapshot>(
    stream: _firestore.collection('items').where('qualityName', isEqualTo: _selectedQuality).snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return CircularProgressIndicator(color: _primaryColor, strokeWidth: 2);
      final items = snapshot.data!.docs.map((doc) => doc['itemName'] as String).toList();

      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownSearch<String>(
          popupProps: PopupProps.menu(
            showSearchBox: true,
            showSelectedItems: true,
            searchFieldProps: TextFieldProps(
              focusNode: _itemDropdownFocusNode,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search item...',
                hintStyle: TextStyle(color: _secondaryTextColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _primaryColor.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _primaryColor),
                ),
              ),
              style: TextStyle(color: _textColor),
            ),
            itemBuilder: (context, item, isSelected) => ListTile(
              title: Text(
                item,
                style: TextStyle(
                  color: isSelected ? _primaryColor : _textColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              tileColor: isSelected ? _primaryColor.withOpacity(0.1) : _surfaceColor,
            ),
            menuProps: MenuProps(
              backgroundColor: _surfaceColor,
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
            ),
            fit: FlexFit.loose,
            constraints: const BoxConstraints(maxHeight: 300),
          ),
          dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              hintText: 'Select item',
              hintStyle: TextStyle(color: _secondaryTextColor, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            baseStyle: TextStyle(color: _textColor, fontSize: 14),
          ),
          dropdownBuilder: (context, selectedItem) {
            return GestureDetector(
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _itemDropdownFocusNode.requestFocus();
                });
              },
              child: Text(
                selectedItem ?? 'Select item',
                style: TextStyle(
                  color: selectedItem != null ? _textColor : _secondaryTextColor,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
          items: items,
          selectedItem: _selectedItem,
          onChanged: (String? value) {
            setState(() {
              _selectedItem = value;
            });
          },
          filterFn: (item, filter) => item.toLowerCase().contains(filter.toLowerCase()),
          dropdownButtonProps: DropdownButtonProps(
            icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
          ),
          clearButtonProps: ClearButtonProps(
            isVisible: true,
            icon: Icon(Icons.clear, color: _primaryColor),
            onPressed: () {
              setState(() {
                _selectedItem = null;
              });
            },
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
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), side: BorderSide(color: _primaryColor.withOpacity(0.3))),
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
  final Color? color;

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
            color: color ?? (isDarkMode ? Colors.white : _textColorLight),
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }
}