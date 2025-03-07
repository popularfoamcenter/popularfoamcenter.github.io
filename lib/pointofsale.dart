import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'transactionspage.dart';

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

  CartItem copyWith({
    double? qty,
    String? price,
    String? discount,
    String? total,
  }) =>
      CartItem(
        quality: quality,
        itemName: itemName,
        covered: covered,
        qty: qty ?? this.qty,
        originalQty: originalQty,
        price: price ?? this.price,
        discount: discount ?? this.discount,
        total: total ?? this.total,
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

class PointOfSalePage extends StatefulWidget {
  final Invoice? invoice;
  final bool isReadOnly;

  const PointOfSalePage({this.invoice, this.isReadOnly = false});

  @override
  _PointOfSalePageState createState() => _PointOfSalePageState();
}

class _PointOfSalePageState extends State<PointOfSalePage> {
  static const Map<String, dynamic> walkingCustomer = {
    'id': 'walking',
    'name': 'Walking Customer',
    'number': '',
  };

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _givenAmountController = TextEditingController();
  final TextEditingController _globalDiscountController = TextEditingController();
  final TextEditingController _customCustomerNameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late Map<String, dynamic> _selectedCustomer;
  late String _selectedTransactionType;
  List<CartItem> _cartItems = [];
  late String _searchQuery = '';
  bool _showPaymentDialog = false;
  bool _showUndoToast = false;
  int _globalDiscount = 0;
  CartItem? _deletedItem;
  int? _deletedIndex;
  String? _returnInvoiceNumber;
  bool _useCustomName = false;
  late DateTime _selectedDate;

  static const Color _primaryColor = Color(0xFF0D6EFD);
  static const Color _textColor = Color(0xFF2D2D2D);
  static const Color _secondaryTextColor = Color(0xFF4A4A4A);
  static const Color _backgroundColor = Color(0xFFF8F9FA);
  static const Color _surfaceColor = Colors.white;

  int? _selectedItemIndex;
  int _selectedFieldIndex = 0; // 0: qty, 1: price, 2: discount
  final List<List<FocusNode>> _focusNodes = [];

  @override
  void initState() {
    super.initState();
    _initializeState();
    _selectedDate = DateTime.now();
    _dateController.text = DateFormat('dd-MM-yyyy').format(_selectedDate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    for (var _ in _cartItems) {
      _focusNodes.add([
        FocusNode(),
        FocusNode(),
        FocusNode(),
      ]);
    }
  }

  void _initializeState() {
    if (widget.invoice != null) {
      _selectedCustomer = {
        'id': widget.invoice!.customer['id'] ?? '',
        'name': widget.invoice!.customer['name'] ?? 'Walking Customer',
        'number': widget.invoice!.customer['number'] ?? '',
      };
      _selectedTransactionType = widget.invoice!.type;
      _cartItems = widget.invoice!.items
          .map((item) => CartItem(
        quality: item.quality,
        itemName: item.itemName,
        covered: item.covered,
        qty: item.qty,
        originalQty: item.originalQty,
        price: item.price,
        discount: item.discount,
        total: item.total,
      ))
          .toList();
      _globalDiscount = widget.invoice!.globalDiscount;
      _givenAmountController.text = widget.invoice!.givenAmount.toString();
      _globalDiscountController.text = _globalDiscount.toString();
      _phoneController.text = _selectedCustomer['number'] ?? '';
      _customCustomerNameController.text = _selectedCustomer['name'] ?? '';
      _useCustomName = _selectedCustomer['id']?.isEmpty ?? true;
      _selectedDate = widget.invoice!.timestamp is Timestamp
          ? (widget.invoice!.timestamp as Timestamp).toDate()
          : DateTime.now();
      _dateController.text = DateFormat('dd-MM-yyyy').format(_selectedDate);
      if (widget.invoice!.type == 'Return') {
        _returnInvoiceNumber = widget.invoice!.toMap()['returnInvoice'];
      }
    } else {
      _selectedCustomer = walkingCustomer;
      _selectedTransactionType = 'Sale';
      _customCustomerNameController.text = 'Walking Customer';
      _useCustomName = false;
      _selectedDate = DateTime.now();
      _dateController.text = DateFormat('dd-MM-yyyy').format(_selectedDate);
    }
  }

  @override
  void dispose() {
    for (var nodes in _focusNodes) {
      for (var node in nodes) {
        node.dispose();
      }
    }
    _focusNode.dispose();
    _phoneController.dispose();
    _searchController.dispose();
    _givenAmountController.dispose();
    _globalDiscountController.dispose();
    _customCustomerNameController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  double _calculateSubtotal() =>
      _cartItems.fold(0.0, (sum, item) => sum + (double.tryParse(item.total) ?? 0.0));

  double _calculateTotal() => math.max(_calculateSubtotal() - _globalDiscount, 0.0);

  Future<int> _incrementInvoiceCounter() async {
    final counterRef = _firestore.collection('settings').doc('invoice_counter');
    return await _firestore.runTransaction<int>((transaction) async {
      final doc = await transaction.get(counterRef);
      final currentNumber = doc.exists ? (doc['lastInvoiceNumber'] as int) : 0;
      final newNumber = currentNumber + 1;
      transaction.set(counterRef, {'lastInvoiceNumber': newNumber}, SetOptions(merge: true));
      return newNumber;
    });
  }

  Future<void> _addItemToCart(Map<String, dynamic> inventoryItem) async {
    try {
      final itemName = inventoryItem['itemName']?.toString().trim() ?? '';
      final qualityName = inventoryItem['qualityName']?.toString().trim() ?? '';
      final coveredStatus = inventoryItem['covered']?.toString().trim() ?? '-';

      if (itemName.isEmpty || qualityName.isEmpty) {
        throw Exception('Invalid item - missing critical information');
      }

      final newItem = CartItem(
        quality: qualityName,
        itemName: itemName,
        covered: coveredStatus,
        qty: 1.0,
        originalQty: 0.0,
        price: ((inventoryItem['salePrice'] as num?) ?? 0).toStringAsFixed(0),
        discount: '0',
        total: ((inventoryItem['salePrice'] as num?) ?? 0).toStringAsFixed(0),
      );

      if (_selectedCustomer['id'] != 'walking' && !_useCustomName) {
        await _applyCustomerDiscounts(newItem);
      }

      setState(() {
        _cartItems.add(newItem);
        _focusNodes.add([
          FocusNode(),
          FocusNode(),
          FocusNode(),
        ]);
        _selectedItemIndex = _cartItems.length - 1;
        _selectedFieldIndex = 0;
        _searchController.clear();
        _searchQuery = '';
      });
      _focusNodes[_selectedItemIndex!][0].requestFocus();
      Navigator.pop(context);
    } catch (e, stack) {
      print('Error adding to cart: $e\n$stack');
      _showSnackBar('Failed to add item: ${e.toString()}', Colors.red);
      Navigator.pop(context);
    }
  }

  Future<void> _applyCustomerDiscounts(CartItem cartItem) async {
    try {
      final customerId = _selectedCustomer['id'];
      final qualityName = cartItem.quality;
      final isCovered = cartItem.covered?.toLowerCase() == 'yes';

      final discountsSnapshot = await _firestore
          .collection('customer_discounts')
          .where('customerId', isEqualTo: customerId)
          .where('qualityName', isEqualTo: qualityName)
          .where('item', whereIn: ['All', cartItem.itemName])
          .get();

      final discounts = discountsSnapshot.docs;
      Map<String, dynamic>? bestDiscount;

      if (discounts.isNotEmpty) {
        final specificDiscounts = discounts.where((doc) => doc['item'] == cartItem.itemName);
        if (specificDiscounts.isNotEmpty) {
          bestDiscount = specificDiscounts.first.data();
        } else {
          final qualityDiscounts = discounts.where((doc) => doc['item'] == 'All');
          if (qualityDiscounts.isNotEmpty) {
            bestDiscount = qualityDiscounts.first.data();
          }
        }
      }

      if (bestDiscount != null) {
        final discountValue = isCovered
            ? (bestDiscount['covered'] ?? 0.0).toDouble()
            : (bestDiscount['uncovered'] ?? 0.0).toDouble();
        _applyDiscount(cartItem, bestDiscount['type']?.toString() ?? 'Discount', discountValue);
      }
    } catch (e) {
      print('Error applying customer discounts: $e');
      _showSnackBar('Failed to apply discount: $e', Colors.red);
    }
  }

  void _applyDiscount(CartItem item, String type, double value) {
    final price = double.tryParse(item.price) ?? 0;
    final qty = item.qty;

    if (type == 'Price') {
      item.price = value.toStringAsFixed(0);
      item.discount = '0';
      item.total = (qty * value).toStringAsFixed(0);
    } else if (type == 'Discount') {
      item.discount = value.toStringAsFixed(0);
      item.total = (qty * price * (1 - value / 100)).toStringAsFixed(0);
    }

    setState(() {});
  }

  void _updateCartItem(int index, {double? qty, String? price, String? discount}) {
    setState(() {
      final item = _cartItems[index];
      final updatedItem = item.copyWith(
        qty: qty ?? item.qty,
        price: price ?? item.price,
        discount: discount ?? item.discount,
      );
      final newTotal = _calculateItemTotal(updatedItem);
      _cartItems[index] = updatedItem.copyWith(total: newTotal.toStringAsFixed(0));
    });
  }

  double _calculateItemTotal(CartItem item) {
    final qty = item.qty;
    final price = double.tryParse(item.price) ?? 0;
    final discount = double.tryParse(item.discount) ?? 0;
    return (qty * price * (1 - discount / 100));
  }

  Future<bool> _checkStockAvailability() async {
    if (widget.invoice != null) {
      for (final item in _cartItems) {
        final snapshot = await _firestore
            .collection('items')
            .where('itemName', isEqualTo: item.itemName)
            .where('qualityName', isEqualTo: item.quality)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final stock = (snapshot.docs.first['stockQuantity'] as num?)?.toDouble() ?? 0.0;
          final qtyChange = item.qty - item.originalQty;
          if (_selectedTransactionType != 'Return' && qtyChange > 0 && stock < qtyChange) {
            return true;
          }
        }
      }
      return false;
    }

    for (final item in _cartItems) {
      final snapshot = await _firestore
          .collection('items')
          .where('itemName', isEqualTo: item.itemName)
          .where('qualityName', isEqualTo: item.quality)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final stock = (snapshot.docs.first['stockQuantity'] as num?)?.toDouble() ?? 0.0;
        final qtyChange = item.qty - item.originalQty;
        if (_selectedTransactionType != 'Return' && qtyChange > 0 && stock < qtyChange) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _validateAndUpdateStock(Transaction transaction) async {
    if (_selectedTransactionType == 'Order Booking') return;

    for (final item in _cartItems) {
      final snapshot = await _firestore
          .collection('items')
          .where('itemName', isEqualTo: item.itemName)
          .where('qualityName', isEqualTo: item.quality)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) throw Exception('Item ${item.itemName} not found');
      final ref = snapshot.docs.first.reference;
      final stock = (snapshot.docs.first['stockQuantity'] as num?)?.toDouble() ?? 0.0;
      final qtyChange = item.qty - item.originalQty;

      if (qtyChange != 0) {
        final newStock = _selectedTransactionType == 'Return' ? stock + qtyChange : stock - qtyChange;
        if (newStock < 0) throw Exception('Insufficient stock for ${item.itemName}');
        transaction.update(ref, {'stockQuantity': newStock});
      }
    }
  }

  Future<void> _updateStockForEditedItems(Transaction transaction) async {
    if (_selectedTransactionType == 'Order Booking') return;

    for (final newItem in _cartItems) {
      final oldItem = widget.invoice!.items.firstWhere(
            (item) => item.itemName == newItem.itemName && item.quality == newItem.quality,
        orElse: () => CartItem(
          quality: newItem.quality,
          itemName: newItem.itemName,
          covered: newItem.covered,
          qty: 0.0,
          originalQty: 0.0,
          price: newItem.price,
          discount: newItem.discount,
          total: newItem.total,
        ),
      );

      final qtyChange = newItem.qty - oldItem.qty;
      if (qtyChange != 0) {
        final snapshot = await _firestore
            .collection('items')
            .where('itemName', isEqualTo: newItem.itemName)
            .where('qualityName', isEqualTo: newItem.quality)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final ref = snapshot.docs.first.reference;
          final currentStock = (snapshot.docs.first['stockQuantity'] as num?)?.toDouble() ?? 0.0;
          final stockAdjustment =
          _selectedTransactionType == 'Return' ? qtyChange : -qtyChange;
          final newStock = currentStock + stockAdjustment;

          if (newStock < 0) {
            throw Exception('Insufficient stock for ${newItem.itemName}');
          }

          transaction.update(ref, {'stockQuantity': newStock});
        }
      }
    }

    if (widget.invoice != null) {
      for (final oldItem in widget.invoice!.items) {
        final stillExists = _cartItems.any(
                (item) => item.itemName == oldItem.itemName && item.quality == oldItem.quality);

        if (!stillExists && oldItem.qty > 0) {
          final snapshot = await _firestore
              .collection('items')
              .where('itemName', isEqualTo: oldItem.itemName)
              .where('qualityName', isEqualTo: oldItem.quality)
              .limit(1)
              .get();

          if (snapshot.docs.isNotEmpty) {
            final ref = snapshot.docs.first.reference;
            final currentStock = (snapshot.docs.first['stockQuantity'] as num?)?.toDouble() ?? 0.0;
            final stockAdjustment =
            _selectedTransactionType == 'Return' ? -oldItem.qty : oldItem.qty;
            transaction.update(ref, {'stockQuantity': currentStock + stockAdjustment});
          }
        }
      }
    }
  }

  Future<void> _handleTransaction() async {
    if (await _checkStockAvailability()) {
      final proceed = await _showLowStockDialog();
      if (!proceed) return;
    }
    setState(() => _showPaymentDialog = true);
  }

  Future<bool> _showLowStockDialog() async {
    return (await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Low Stock Warning'),
        content: const Text('Some items have insufficient stock. Proceed?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true), child: const Text('Proceed')),
        ],
      ),
    )) ??
        false;
  }

  Future<Invoice?> _processTransaction({bool viewAfterSave = false}) async {
    if (_cartItems.isEmpty) {
      _showSnackBar('Cart is empty', Colors.red);
      return null;
    }

    final subtotal = _calculateSubtotal();
    final total = _calculateTotal();
    final givenAmount = double.tryParse(_givenAmountController.text) ?? 0.0;

    final isEditing = widget.invoice != null;
    final invoiceRef = isEditing
        ? _firestore.collection('invoices').doc(widget.invoice!.id)
        : _firestore.collection('invoices').doc();
    final invoiceNumber = isEditing ? widget.invoice!.invoiceNumber : 0;

    try {
      final invoice = await _firestore.runTransaction<Invoice>((transaction) async {
        if (isEditing) {
          await _updateStockForEditedItems(transaction);
        } else {
          await _validateAndUpdateStock(transaction);
        }

        final customerData = _useCustomName
            ? {
          'id': '',
          'name': _customCustomerNameController.text.trim().isEmpty
              ? 'Walking Customer'
              : _customCustomerNameController.text.trim(),
          'number': _phoneController.text.trim()
        }
            : _selectedCustomer;

        final tempInvoice = Invoice(
          id: invoiceRef.id,
          invoiceNumber: invoiceNumber,
          customer: customerData,
          type: _selectedTransactionType,
          items: List.from(_cartItems),
          subtotal: subtotal,
          globalDiscount: _globalDiscount,
          total: total,
          givenAmount: givenAmount,
          returnAmount: math.max(givenAmount - total, 0),
          balanceDue: math.max(total - givenAmount, 0),
          timestamp: Timestamp.fromDate(_selectedDate), // Always use _selectedDate
        );

        if (isEditing) {
          transaction.update(invoiceRef, tempInvoice.toMap());
        } else {
          transaction.set(invoiceRef, tempInvoice.toMap());
        }

        return tempInvoice;
      });

      Invoice finalInvoice = invoice;
      if (!isEditing) {
        final newInvoiceNumber = await _incrementInvoiceCounter();
        final updatedInvoice = Invoice(
          id: invoiceRef.id,
          invoiceNumber: newInvoiceNumber,
          customer: invoice.customer,
          type: invoice.type,
          items: invoice.items,
          subtotal: invoice.subtotal,
          globalDiscount: invoice.globalDiscount,
          total: invoice.total,
          givenAmount: invoice.givenAmount,
          returnAmount: invoice.returnAmount,
          balanceDue: invoice.balanceDue,
          timestamp: Timestamp.fromDate(_selectedDate), // Use _selectedDate here too
        );
        await invoiceRef.update({'invoiceNumber': newInvoiceNumber});
        finalInvoice = updatedInvoice;
      }

      setState(() {
        _cartItems.clear();
        _globalDiscount = 0;
        _givenAmountController.clear();
        _showPaymentDialog = false;
      });

      _showSnackBar('Transaction ${isEditing ? 'updated' : 'saved'}', Colors.green);

      if (viewAfterSave) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => PointOfSalePage(invoice: finalInvoice, isReadOnly: true)),
        );
      }

      return finalInvoice;
    } catch (e) {
      _showSnackBar('Transaction failed: $e', Colors.red);
      rethrow;
    }
  }

  Future<void> _printInvoice(Invoice invoice) async {
    try {
      final pdf = pw.Document();
      final numberFormat = NumberFormat.currency(decimalDigits: 0, symbol: '');
      final Uint8List logoImage =
      (await rootBundle.load('assets/images/logo1.png')).buffer.asUint8List();
      DateTime invoiceDate = invoice.timestamp is Timestamp
          ? (invoice.timestamp as Timestamp).toDate()
          : DateTime.now();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(
            base: await PdfGoogleFonts.openSansRegular(),
            bold: await PdfGoogleFonts.openSansBold(),
          ),
          build: (_) => pw.Stack(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('INVOICE',
                              style: pw.TextStyle(
                                  fontSize: 24,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromHex('#0D6EFD'))),
                          pw.SizedBox(height: 8),
                          pw.Text('Popular Foam Center',
                              style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black)),
                          pw.Text('Zanana Hospital Road, Bahawalpur (63100)',
                              style: pw.TextStyle(fontSize: 10, color: PdfColors.black)),
                        ],
                      ),
                      pw.Image(pw.MemoryImage(logoImage), width: 135, height: 135),
                    ],
                  ),
                  pw.Divider(color: PdfColor.fromHex('#0D6EFD'), height: 40),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Bill To:',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 12,
                                  color: PdfColors.black)),
                          pw.Text(invoice.customer['name'] ?? 'Walking Customer',
                              style: const pw.TextStyle(fontSize: 14, color: PdfColors.black)),
                          pw.SizedBox(height: 8),
                          pw.Text('Invoice Date:',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 12,
                                  color: PdfColors.black)),
                          pw.Text(DateFormat('dd-MM-yyyy').format(invoiceDate),
                              style: const pw.TextStyle(fontSize: 12, color: PdfColors.black)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Invoice #${invoice.invoiceNumber}',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 14,
                                  color: PdfColor.fromHex('#0D6EFD'))),
                          pw.SizedBox(height: 8),
                          pw.Text('Transaction Type:',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 12,
                                  color: PdfColors.black)),
                          pw.Text(invoice.type.toUpperCase(),
                              style: const pw.TextStyle(fontSize: 12, color: PdfColors.black)),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 30),
                  pw.Table(
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3.5),
                      1: const pw.FlexColumnWidth(1),
                      2: const pw.FlexColumnWidth(1.5),
                      3: const pw.FlexColumnWidth(1),
                      4: const pw.FlexColumnWidth(1.5),
                    },
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#0D6EFD')),
                        children: ['Item Description', 'Qty', 'Unit Price', 'Disc.%', 'Total']
                            .map((text) => pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(text,
                              style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold)),
                        ))
                            .toList(),
                      ),
                      ...invoice.items.map((item) => pw.TableRow(
                        children: [
                          pw.Container(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('${item.quality} ${item.itemName}',
                                  style: const pw.TextStyle(
                                      fontSize: 10, color: PdfColors.black))),
                          pw.Container(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(item.qty.toStringAsFixed(2),
                                  style: const pw.TextStyle(
                                      fontSize: 10, color: PdfColors.black))),
                          pw.Container(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(numberFormat.format(int.parse(item.price)),
                                  style: const pw.TextStyle(
                                      fontSize: 10, color: PdfColors.black))),
                          pw.Container(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('${item.discount}%',
                                  style: const pw.TextStyle(
                                      fontSize: 10, color: PdfColors.black))),
                          pw.Container(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(numberFormat.format(double.parse(item.total)),
                                  style: const pw.TextStyle(
                                      fontSize: 10, color: PdfColors.black))),
                        ],
                      )),
                    ],
                  ),
                  pw.SizedBox(height: 25),
                  pw.Container(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                          pw.Text('Subtotal:',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black)),
                          pw.SizedBox(width: 15),
                          pw.Text(numberFormat.format(invoice.subtotal),
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
                        ]),
                        pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                          pw.Text('Global Discount:',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black)),
                          pw.SizedBox(width: 15),
                          pw.Text('-${numberFormat.format(invoice.globalDiscount)}',
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.red)),
                        ]),
                        pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                          pw.Text('Total Amount:',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black)),
                          pw.SizedBox(width: 15),
                          pw.Text(numberFormat.format(invoice.total),
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
                        ]),
                        pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                          pw.Text('Amount Received:',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black)),
                          pw.SizedBox(width: 15),
                          pw.Text(numberFormat.format(invoice.givenAmount),
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
                        ]),
                        if (invoice.returnAmount > 0)
                          pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                            pw.Text('Change Due:',
                                style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.black)),
                            pw.SizedBox(width: 15),
                            pw.Text(numberFormat.format(invoice.returnAmount),
                                style: const pw.TextStyle(fontSize: 10, color: PdfColors.green)),
                          ]),
                        if (invoice.balanceDue > 0)
                          pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                            pw.Text('Balance Due:',
                                style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.black)),
                            pw.SizedBox(width: 15),
                            pw.Text(numberFormat.format(invoice.balanceDue),
                                style: const pw.TextStyle(fontSize: 10, color: PdfColors.orange)),
                          ]),
                        pw.SizedBox(height: 15),
                        pw.Container(
                          width: 250,
                          padding: const pw.EdgeInsets.all(12),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#F8F9FA'),
                            borderRadius: pw.BorderRadius.circular(6),
                            border: pw.Border.all(color: PdfColor.fromHex('#0D6EFD'), width: 1),
                          ),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('TOTAL AMOUNT',
                                  style: pw.TextStyle(
                                      fontSize: 12,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.black)),
                              pw.Text(numberFormat.format(invoice.total),
                                  style: pw.TextStyle(
                                      fontSize: 14,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColor.fromHex('#0D6EFD'))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F8F9FA'),
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColor.fromHex('#0D6EFD'), width: 1),
                    ),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Thank you for choosing Popular Foam Center',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#0D6EFD'),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Contact: 0302-9596046 | Facebook: Popular Foam Center',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.black)),
                      pw.Text('Notes: Claims as per company policy',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.black)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      final pdfBytes = await pdf.save();
      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'PFC-INV-${invoice.invoiceNumber}',
      );
    } catch (e) {
      print('Error in _printInvoice: $e');
      _showSnackBar('Failed to print invoice: $e', Colors.red);
      rethrow;
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3)));
  }

  Widget _buildCartHeader() => Container(
    height: 56,
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)]),
    child: Row(
      children: [
        Expanded(
            flex: 2,
            child: Center(
                child: Text('Quality',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(
            flex: 2,
            child: Center(
                child: Text('Item',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text('Cvrd',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text('Qty',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text('Price',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text('Dis%',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text('Amount',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text('Stock',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        if (!widget.isReadOnly)
          SizedBox(
              width: 40,
              child: Center(
                  child: Text('Del',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
      ],
    ),
  );

  Widget _buildCartItem(CartItem item, int index) {
    if (_focusNodes.length <= index) {
      _focusNodes.add([
        FocusNode(),
        FocusNode(),
        FocusNode(),
      ]);
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedItemIndex = index;
          _selectedFieldIndex = 0;
          _focusNodes[index][0].requestFocus();
        });
      },
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Expanded(
                flex: 2,
                child: Center(
                    child: Text(item.quality, style: TextStyle(color: _textColor, fontSize: 14)))),
            Expanded(
                flex: 2,
                child: Center(
                    child: Text(item.itemName, style: TextStyle(color: _textColor, fontSize: 14)))),
            Expanded(
                flex: 1,
                child: Center(
                    child:
                    Text(item.covered ?? '-', style: TextStyle(color: _textColor, fontSize: 14)))),
            Expanded(
              flex: 1,
              child: Center(
                child: widget.isReadOnly
                    ? Text(
                    item.qty % 1 == 0 ? item.qty.toStringAsFixed(0) : item.qty.toStringAsFixed(1),
                    style: TextStyle(color: _textColor, fontSize: 14))
                    : TextFormField(
                  focusNode: _focusNodes[index][0],
                  initialValue: item.qty % 1 == 0
                      ? item.qty.toStringAsFixed(0)
                      : item.qty.toStringAsFixed(1),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _textColor, fontSize: 14),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  onTap: () => setState(() {
                    _selectedItemIndex = index;
                    _selectedFieldIndex = 0;
                  }),
                  onChanged: (value) =>
                      _updateCartItem(index, qty: double.tryParse(value) ?? item.qty),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: widget.isReadOnly
                    ? Text(item.price, style: TextStyle(color: _textColor, fontSize: 14))
                    : TextFormField(
                  focusNode: _focusNodes[index][1],
                  initialValue: item.price,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _textColor, fontSize: 14),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  keyboardType: TextInputType.number,
                  onTap: () => setState(() {
                    _selectedItemIndex = index;
                    _selectedFieldIndex = 1;
                  }),
                  onChanged: (value) => _updateCartItem(index, price: value),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: widget.isReadOnly
                    ? Text(item.discount, style: TextStyle(color: _textColor, fontSize: 14))
                    : TextFormField(
                  focusNode: _focusNodes[index][2],
                  initialValue: item.discount,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _textColor, fontSize: 14),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  keyboardType: TextInputType.number,
                  onTap: () => setState(() {
                    _selectedItemIndex = index;
                    _selectedFieldIndex = 2;
                  }),
                  onChanged: (value) => _updateCartItem(index, discount: value),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  item.total,
                  style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            Expanded(flex: 1, child: Center(child: _buildStockIndicator(item))),
            if (!widget.isReadOnly)
              SizedBox(
                width: 40,
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _removeItem(index),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockIndicator(CartItem item) => StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('items')
          .where('qualityName', isEqualTo: item.quality)
          .where('itemName', isEqualTo: item.itemName)
          .limit(1)
          .snapshots(),
      builder: (_, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator(strokeWidth: 2);
        final stock = (snapshot.data!.docs.first['stockQuantity'] as num?)?.toDouble() ?? 0.0;
        final qty = item.qty;
        return Text(
            stock % 1 == 0 ? stock.toStringAsFixed(0) : stock.toStringAsFixed(1),
            style: TextStyle(
                color: stock < qty ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 12));
      });

  void _removeItem(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      _deletedItem = _cartItems[index];
      _deletedIndex = index;
      _cartItems.removeAt(index);
      final removedNodes = _focusNodes.removeAt(index);
      for (var node in removedNodes) {
        node.dispose();
      }
      if (_cartItems.isEmpty) {
        _selectedItemIndex = null;
      } else {
        _selectedItemIndex = _selectedItemIndex!.clamp(0, _cartItems.length - 1);
        _focusNodes[_selectedItemIndex!][_selectedFieldIndex].requestFocus();
      }
      _showUndoToast = true;
    });
    Future.delayed(const Duration(seconds: 5), () => setState(() => _showUndoToast = false));
  }

  Widget _buildUndoToast() => Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12)]),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("Item removed", style: TextStyle(color: _textColor)),
            TextButton(
                onPressed: _restoreItem,
                child: const Text('UNDO', style: TextStyle(color: Colors.red)))
          ])));

  void _restoreItem() {
    if (_deletedItem != null && _deletedIndex != null) {
      HapticFeedback.heavyImpact();
      setState(() {
        _cartItems.insert(_deletedIndex!, _deletedItem!);
        _focusNodes.insert(_deletedIndex!, [
          FocusNode(),
          FocusNode(),
          FocusNode(),
        ]);
        _selectedItemIndex = _deletedIndex;
        _focusNodes[_selectedItemIndex!][_selectedFieldIndex].requestFocus();
        _showUndoToast = false;
        _deletedItem = null;
        _deletedIndex = null;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    if (widget.isReadOnly) return;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _surfaceColor,
              onSurface: _textColor,
            ),
            dialogBackgroundColor: _backgroundColor,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd-MM-yyyy').format(_selectedDate);
      });
    }
  }

  Widget _buildCustomerPanel() => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 24)]),
      child: Column(children: [
        if (!widget.isReadOnly)
          ElevatedButton.icon(
              onPressed: _showAddItemDialog,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
              label: const Text('ADD ITEM',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
        if (!widget.isReadOnly) const SizedBox(height: 10),
        if (!widget.isReadOnly)
          Row(
            children: [
              Checkbox(
                value: _useCustomName,
                onChanged: (value) {
                  setState(() {
                    _useCustomName = value!;
                    if (_useCustomName) {
                      _selectedCustomer = {
                        'id': '',
                        'name': _customCustomerNameController.text.trim().isEmpty
                            ? 'Walking Customer'
                            : _customCustomerNameController.text.trim(),
                        'number': _phoneController.text.trim(),
                      };
                    } else {
                      _selectedCustomer = walkingCustomer;
                    }
                  });
                },
              ),
              const Text('Enter Custom Name', style: TextStyle(color: _textColor)),
            ],
          ),
        const SizedBox(height: 10),
        if (_useCustomName || widget.isReadOnly)
          TextField(
            controller: _customCustomerNameController,
            enabled: !widget.isReadOnly,
            decoration: InputDecoration(
              labelText: 'Customer Name',
              filled: true,
              fillColor: _backgroundColor,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              labelStyle: TextStyle(color: _secondaryTextColor),
            ),
            style: TextStyle(color: _textColor),
            onChanged: (value) {
              if (!widget.isReadOnly && _useCustomName) {
                setState(() {
                  _selectedCustomer = {
                    'id': '',
                    'name': value.trim().isEmpty ? 'Walking Customer' : value.trim(),
                    'number': _phoneController.text.trim(),
                  };
                });
              }
            },
          )
        else if (!widget.isReadOnly)
          _buildCustomerDropdown(),
        const SizedBox(height: 16),
        _buildTransactionTypeDropdown(),
        const SizedBox(height: 16),
        TextField(
            controller: _phoneController,
            enabled: !widget.isReadOnly,
            decoration: InputDecoration(
                labelText: 'Phone Number',
                filled: true,
                fillColor: _backgroundColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                labelStyle: TextStyle(color: _secondaryTextColor)),
            style: TextStyle(color: _textColor),
            onChanged: (value) {
              if (_useCustomName && !widget.isReadOnly) {
                setState(() {
                  _selectedCustomer['number'] = value.trim();
                });
              }
            }),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _selectDate(context),
          child: AbsorbPointer(
            child: TextField(
              enabled: !widget.isReadOnly,
              controller: _dateController,
              decoration: InputDecoration(
                labelText: 'Transaction Date',
                filled: true,
                fillColor: _backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                labelStyle: TextStyle(color: _secondaryTextColor),
                suffixIcon: const Icon(Icons.calendar_today, color: _secondaryTextColor),
              ),
              style: TextStyle(color: _textColor),
            ),
          ),
        ),
        if (!widget.isReadOnly) const SizedBox(height: 24),
        if (!widget.isReadOnly)
          ElevatedButton.icon(
              onPressed: _handleTransaction,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('PROCEED TO PAYMENT'))
      ]));

  Widget _buildCustomerDropdown() => StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('customers').snapshots(),
      builder: (_, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final customers = [
          walkingCustomer,
          ...snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'name': data['name'] ?? 'Unnamed Customer',
              'number': data['number'] ?? '',
            };
          }),
        ];

        final selectedValue = customers.firstWhere(
              (customer) => customer['id'] == _selectedCustomer['id'],
          orElse: () => walkingCustomer,
        );

        return widget.isReadOnly
            ? Text(selectedValue['name'], style: TextStyle(color: _textColor, fontSize: 14))
            : DropdownButtonFormField<Map<String, dynamic>>(
            value: selectedValue,
            dropdownColor: _surfaceColor,
            items: customers
                .map((c) => DropdownMenuItem(
                value: c,
                child: Text(c['name'], style: TextStyle(color: _textColor, fontSize: 14))))
                .toList(),
            onChanged: (value) => setState(() {
              _selectedCustomer = value!;
              _phoneController.text = value['number'] ?? '';
              _customCustomerNameController.text = value['name'] ?? '';
              _refreshCartDiscounts();
            }),
            decoration: InputDecoration(
                labelText: 'Customer',
                filled: true,
                fillColor: _backgroundColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                labelStyle: TextStyle(color: _secondaryTextColor)));
      });

  void _refreshCartDiscounts() {
    if (_selectedCustomer['id'] == 'walking' || _useCustomName) return;
    for (var item in _cartItems) {
      _applyCustomerDiscounts(item);
    }
  }

  Widget _buildTransactionTypeDropdown() => widget.isReadOnly
      ? Text(_selectedTransactionType, style: TextStyle(color: _textColor, fontSize: 14))
      : DropdownButtonFormField<String>(
      value: _selectedTransactionType,
      items: ['Sale', 'Return', 'Order Booking']
          .map((type) => DropdownMenuItem(
          value: type, child: Text(type, style: TextStyle(color: _textColor, fontSize: 14))))
          .toList(),
      onChanged: (value) async {
        if (value == 'Return') {
          final invoiceNumber = await _showInvoiceNumberDialog();
          if (invoiceNumber != null) setState(() => _returnInvoiceNumber = invoiceNumber);
          else return;
        }
        setState(() => _selectedTransactionType = value!);
      },
      decoration: InputDecoration(
          labelText: 'Transaction Type',
          filled: true,
          fillColor: _backgroundColor,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: TextStyle(color: _secondaryTextColor)));

  Future<String?> _showInvoiceNumberDialog() async {
    String? invoiceNumber;
    await showDialog(
        context: context,
        builder: (_) => AlertDialog(
            title: const Text('Enter Original Invoice Number'),
            content: TextField(
                autofocus: true,
                onChanged: (value) => invoiceNumber = value,
                decoration: const InputDecoration(hintText: 'Invoice Number')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(context, invoiceNumber), child: const Text('OK'))
            ]));
    return invoiceNumber;
  }

  Widget _buildModernSummaryCard() => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 24, spreadRadius: 2)
          ]),
      child: Column(children: [
        _buildSummaryItem('Items', _cartItems.length.toString()),
        const Divider(),
        _buildSummaryItem('Subtotal', _calculateSubtotal().toStringAsFixed(0) + '/-'),
        _buildSummaryItem('Global Discount', _globalDiscount.toString() + '/-'),
        const Divider(),
        _buildSummaryItem('Total', _calculateTotal().toStringAsFixed(0) + '/-',
            valueStyle: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
      ]));

  Widget _buildSummaryItem(String label, String value, {TextStyle? valueStyle}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: _secondaryTextColor)),
        Text(value, style: valueStyle ?? TextStyle(color: _textColor))
      ]));

  Widget _buildPaymentDialog() {
    final subtotal = _calculateSubtotal();
    final total = _calculateTotal();
    final givenAmount = double.tryParse(_givenAmountController.text) ?? 0.0;
    final returnAmount = givenAmount > total ? givenAmount - total : 0.0;
    final balanceDue = givenAmount < total ? total - givenAmount : 0.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 24)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Center(
                  child: Text('Payment Details',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryColor)),
                ),
                Positioned(
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: _secondaryTextColor),
                    onPressed: () => setState(() => _showPaymentDialog = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildPaymentDetailRow('Subtotal', '${subtotal.toStringAsFixed(0)}/-'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _globalDiscountController,
              decoration: const InputDecoration(labelText: 'Global Discount'),
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() => _globalDiscount = int.tryParse(value) ?? 0),
            ),
            const SizedBox(height: 12),
            _buildPaymentDetailRow('Total After Discount', '${total.toStringAsFixed(0)}/-',
                valueColor: _primaryColor),
            const SizedBox(height: 24),
            TextFormField(
              controller: _givenAmountController,
              decoration: InputDecoration(
                labelText: 'Amount Received',
                prefixIcon: Icon(Icons.payment, color: _primaryColor),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: _backgroundColor,
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            if (returnAmount > 0)
              _buildPaymentStatusIndicator(
                  'Change Due', returnAmount, Colors.green, Icons.arrow_upward),
            if (balanceDue > 0)
              _buildPaymentStatusIndicator(
                  'Balance Due', balanceDue, Colors.orange, Icons.error_outline),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      try {
                        final invoice = await _processTransaction(viewAfterSave: true);
                        if (invoice != null) await _printInvoice(invoice);
                      } catch (e) {
                        _showSnackBar('Error during print & save: $e', Colors.red);
                      }
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: _primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.print, color: Colors.white),
                    label: const Text('Print & Save', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      await _processTransaction(viewAfterSave: true);
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: _backgroundColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(Icons.save, color: _primaryColor),
                    label: Text('Save', style: TextStyle(color: _primaryColor)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetailRow(String label, String value, {Color? valueColor}) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: _secondaryTextColor)),
        Text(value,
            style: TextStyle(color: valueColor ?? _textColor, fontWeight: FontWeight.bold))
      ]);

  Widget _buildPaymentStatusIndicator(String label, double value, Color color, IconData icon) =>
      Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(color: _textColor))),
            Text('${value.toStringAsFixed(0)}/-',
                style: TextStyle(color: color, fontWeight: FontWeight.bold))
          ]));

  Future<void> _showAddItemDialog() async {
    await showDialog(
        context: context,
        builder: (_) => StatefulBuilder(
            builder: (context, setState) => Dialog(
                backgroundColor: _backgroundColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        color: _surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 24)
                        ]),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: InputDecoration(
                              hintText: 'Search inventory...',
                              filled: true,
                              fillColor: _backgroundColor,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              suffixIcon: const Icon(Icons.search, color: Color(0xFF6C757D))),
                          onChanged: (value) => setState(() => _searchQuery = value.toLowerCase())),
                      const SizedBox(height: 16),
                      _buildInventoryHeader(),
                      const SizedBox(height: 8),
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: StreamBuilder<QuerySnapshot>(
                              stream: _firestore.collection('items').snapshots(),
                              builder: (_, snapshot) {
                                if (!snapshot.hasData)
                                  return const Center(child: CircularProgressIndicator());
                                final items = snapshot.data!.docs.where((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  return data['itemName']
                                      .toString()
                                      .toLowerCase()
                                      .contains(_searchQuery) ||
                                      data['qualityName'].toString().toLowerCase().contains(_searchQuery);
                                }).toList();
                                return ListView.separated(
                                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                                    itemCount: items.length,
                                    itemBuilder: (_, index) => _buildInventoryItem(
                                        items[index].data() as Map<String, dynamic>));
                              }))
                    ])))));
  }

  Widget _buildInventoryHeader() => Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
          color: _primaryColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)]),
      child: Row(children: [
        Expanded(
            child: Text('Quality',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center)),
        Expanded(
            child: Text('Item',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center)),
        Expanded(
            child: Text('Covered',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center)),
        Expanded(
            child: Text('Price',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center)),
        Expanded(
            child: Text('Stock',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center))
      ]));

  Widget _buildInventoryItem(Map<String, dynamic> item) => InkWell(
      onTap: () => _addItemToCart(item),
      child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
          child: Row(children: [
            Expanded(
                child: Text(item['qualityName'] ?? '',
                    style: TextStyle(color: _textColor), textAlign: TextAlign.center)),
            Expanded(
                child: Text(item['itemName'] ?? '',
                    style: TextStyle(color: _textColor), textAlign: TextAlign.center)),
            Expanded(
                child: Text(item['covered'] ?? '-',
                    style: TextStyle(color: _textColor), textAlign: TextAlign.center)),
            Expanded(
                child: Text('${(item['salePrice'] as num?)?.toStringAsFixed(0) ?? '0'}',
                    style: TextStyle(color: _textColor), textAlign: TextAlign.center)),
            Expanded(
                child: Text((item['stockQuantity'] as num?)?.toDouble().toStringAsFixed(0) ?? '0.00',
                    style: TextStyle(color: _textColor), textAlign: TextAlign.center))
          ])));

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent && !widget.isReadOnly) {
          if (HardwareKeyboard.instance.isControlPressed &&
              event.logicalKey == LogicalKeyboardKey.keyA) {
            _showAddItemDialog();
            return;
          }

          if (_selectedItemIndex != null && _cartItems.isNotEmpty) {
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              setState(() {
                _selectedItemIndex = (_selectedItemIndex! - 1).clamp(0, _cartItems.length - 1);
                _focusNodes[_selectedItemIndex!][_selectedFieldIndex].requestFocus();
              });
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              setState(() {
                _selectedItemIndex = (_selectedItemIndex! + 1).clamp(0, _cartItems.length - 1);
                _focusNodes[_selectedItemIndex!][_selectedFieldIndex].requestFocus();
              });
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              setState(() {
                _selectedFieldIndex = (_selectedFieldIndex - 1).clamp(0, 2);
                _focusNodes[_selectedItemIndex!][_selectedFieldIndex].requestFocus();
              });
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              setState(() {
                _selectedFieldIndex = (_selectedFieldIndex + 1).clamp(0, 2);
                _focusNodes[_selectedItemIndex!][_selectedFieldIndex].requestFocus();
              });
            }
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _backgroundColor,
          title: Text(widget.isReadOnly ? "View Transaction" : "Point Of Sale",
              style: TextStyle(color: _textColor)),
          elevation: 0,
          actions: widget.isReadOnly
              ? null
              : [
            IconButton(
              icon: Icon(Icons.history, color: _primaryColor),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TransactionsPage()),
              ),
            ),
          ],
        ),
        backgroundColor: _backgroundColor,
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          _buildCartHeader(),
                          const SizedBox(height: 16),
                          Container(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(context).size.height * 0.7,
                            ),
                            child: ListView.separated(
                              itemCount: _cartItems.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) => _buildCartItem(_cartItems[index], index),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 1,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildCustomerPanel(),
                            const SizedBox(height: 24),
                            _buildModernSummaryCard(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showPaymentDialog && !widget.isReadOnly) _buildPaymentDialog(),
            if (_showUndoToast && !widget.isReadOnly) _buildUndoToast(),
          ],
        ),
      ),
    );
  }
}