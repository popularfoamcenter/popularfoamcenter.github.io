import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';

class PointOfSalePage extends StatefulWidget {
  final Map<String, dynamic>? invoice;

  PointOfSalePage({this.invoice});

  @override
  _PointOfSalePageState createState() => _PointOfSalePageState();
}

class _PointOfSalePageState extends State<PointOfSalePage> {
  static const Map<String, dynamic> walkingCustomer = {
    'id': 'walking',
    'name': 'Walking Customer',
    'phone': ''
  };

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _givenAmountController = TextEditingController();
  final TextEditingController _globalDiscountController = TextEditingController();

  // App State
  Map<String, dynamic> _selectedCustomer = walkingCustomer;
  String? _selectedTransactionType = 'Sale';
  List<Map<String, dynamic>> _cartItems = [];
  String _searchQuery = '';
  bool _showPaymentDialog = false;
  bool _showUndoToast = false;
  int _globalDiscount = 0;

  // Item Management
  int? _selectedItemIndex;
  Map<String, dynamic>? _deletedItem;
  int? _deletedIndex;

  // Return Invoice Handling
  String? _returnInvoiceNumber;

  // Design System
  final Color _primaryColor = const Color(0xFF0D6EFD);
  final Color _textColor = const Color(0xFF2D2D2D);
  final Color _secondaryTextColor = const Color(0xFF4A4A4A);
  final Color _backgroundColor = const Color(0xFFF8F9FA);
  final Color _surfaceColor = Colors.white;

  @override
  void initState() {
    super.initState();
    if (widget.invoice != null) {
      _selectedCustomer = widget.invoice!['customer'];
      _selectedTransactionType = widget.invoice!['type'];
      _cartItems = List<Map<String, dynamic>>.from(widget.invoice!['items']);
      _globalDiscount = (widget.invoice!['globalDiscount'] ?? 0).toInt();
      _givenAmountController.text = widget.invoice!['givenAmount'].toString();
      _globalDiscount = (widget.invoice!['globalDiscount'] ?? 0).toInt();
      _globalDiscountController.text = _globalDiscount.toString();
      if (_selectedTransactionType == 'Return') {
        _returnInvoiceNumber = widget.invoice!['returnInvoice'];
      }
      _phoneController.text = _selectedCustomer['phone'] ?? '';
    }
  }

  void dispose() {
    _phoneController.dispose();
    _searchController.dispose();
    _givenAmountController.dispose();

    super.dispose();
  }

  int _calculateSubtotal() {
    return _cartItems.fold(0, (sum, item) {
      final total = int.tryParse(item['total']?.toString() ?? '0') ?? 0;
      return sum + total;
    });
  }

  Future<int> _getNextInvoiceNumber() async {
    final counterRef = _firestore.collection('settings').doc('invoice_counter');

    // Update _getNextInvoiceNumber transaction
    return _firestore.runTransaction<int>((transaction) async {
      final counterDoc = await transaction.get(counterRef);

      int currentNumber = 0;
      if (counterDoc.exists) {
        currentNumber = counterDoc['lastInvoiceNumber'] as int;
      } else {
        await transaction.set(counterRef, {'lastInvoiceNumber': 0});
      }

      final newNumber = currentNumber + 1;
      transaction.update(counterRef, {'lastInvoiceNumber': newNumber});
      return newNumber;
    });
  }

  Future<Map<String, dynamic>?> _processTransaction() async {
    // Validate cart items
    if (_cartItems.isEmpty) {
      _showError('Add items to process');
      return null;
    }

    try {
      // Parse given amount and calculate total after discount
      final givenAmount = int.tryParse(_givenAmountController.text) ?? 0;
      final totalAfterDiscount = _calculateSubtotal() - _globalDiscount;

      // Check if editing an existing invoice
      final bool isEditing = widget.invoice != null &&
          widget.invoice!.containsKey('id');
      DocumentReference invoiceRef;
      int invoiceNumber;
      final counterRef = _firestore.collection('settings').doc(
          'invoice_counter');

      // Set invoice reference and number
      if (isEditing) {
        invoiceRef =
            _firestore.collection('invoices').doc(widget.invoice!['id']);
        invoiceNumber = widget.invoice!['invoiceNumber'];
      } else {
        invoiceRef = _firestore.collection('invoices').doc();
        invoiceNumber = await _getNextInvoiceNumber();
      }

      Map<String, dynamic>? invoiceData;

      // Run Firestore transaction
      await _firestore.runTransaction((transaction) async {
        try {
          // Revert original stock if editing
          if (isEditing) {
            final originalItems = List<Map<String, dynamic>>.from(
                widget.invoice!['items']);
            for (final originalItem in originalItems) {
              final query = _firestore.collection('items')
                  .where('itemName', isEqualTo: originalItem['item'])
                  .limit(1);
              final snapshot = await query.get();
              if (snapshot.docs.isNotEmpty) {
                final itemRef = snapshot.docs.first.reference;
                final doc = await transaction.get(itemRef);
                if (doc.exists) {
                  final currentStock = doc['stockQuantity'] as int;
                  final qtyChange = int.parse(originalItem['qty']);
                  final stockAdjustment = widget.invoice!['type'] == 'Return'
                      ? -qtyChange // Revert return
                      : qtyChange; // Revert sale
                  transaction.update(itemRef, {
                    'stockQuantity': currentStock + stockAdjustment
                  });
                }
              }
            }
          }

          // Prepare new stock changes
          final List<DocumentReference> itemRefs = [];
          for (final item in _cartItems) {
            final query = _firestore.collection('items')
                .where('itemName', isEqualTo: item['item'])
                .limit(1);
            final snapshot = await query.get();
            if (snapshot.docs.isNotEmpty) {
              itemRefs.add(snapshot.docs.first.reference);
            }
          }

          // Update stock for new items
          if (_selectedTransactionType != 'Order Booking') {
            for (int i = 0; i < _cartItems.length; i++) {
              final doc = await transaction.get(itemRefs[i]);
              if (doc.exists) {
                final currentStock = doc['stockQuantity'] as int;
                final qtyChange = int.parse(_cartItems[i]['qty']);
                final newStock = _selectedTransactionType == 'Return'
                    ? currentStock + qtyChange
                    : currentStock - qtyChange;

                if (newStock < 0) {
                  throw Exception(
                      'Insufficient stock: ${_cartItems[i]['item']}');
                }
                transaction.update(itemRefs[i], {'stockQuantity': newStock});
              }
            }
          }

          // Create invoice data
          invoiceData = {
            'status': _selectedTransactionType == 'Order Booking'
                ? 'booked'
                : 'completed',
            'invoiceNumber': invoiceNumber,
            'customer': _selectedCustomer,
            'type': _selectedTransactionType,
            'items': _cartItems,
            'subtotal': _cartItems.fold(
                0, (sum, item) => sum + int.parse(item['total'])),
            'globalDiscount': _globalDiscount,
            'total': totalAfterDiscount,
            'givenAmount': givenAmount,
            'returnAmount': givenAmount > totalAfterDiscount ? givenAmount -
                totalAfterDiscount : 0,
            'balanceDue': givenAmount < totalAfterDiscount
                ? totalAfterDiscount - givenAmount
                : 0,
            'timestamp': FieldValue.serverTimestamp(),
            if (_selectedTransactionType ==
                'Return') 'returnInvoice': _returnInvoiceNumber,
          };

          // Update or create invoice
          if (isEditing) {
            transaction.update(invoiceRef, invoiceData!);
          } else {
            transaction.set(invoiceRef, invoiceData!);
            transaction.update(
                counterRef, {'lastInvoiceNumber': invoiceNumber});
          }
        } catch (e) {
          print('Firestore transaction error: $e');
          throw e; // Re-throw to handle in the outer catch block
        }
      });

      // Fetch complete invoice data
      final invoiceDoc = await invoiceRef.get();
      final completeData = {
        ...invoiceDoc.data()! as Map<String, dynamic>,
        'id': invoiceDoc.id,
      };

      // Update UI state
      if (mounted) {
        setState(() {
          _cartItems.clear();
          _globalDiscount = 0;
          _givenAmountController.clear();
          _showPaymentDialog = false;
          _returnInvoiceNumber = null;
        });
      }

      // Show success message
      _showSuccess('Transaction ${isEditing ? 'updated' : 'completed'}');
      return completeData;
    } catch (e, stackTrace) {
      print('Error processing transaction: $e');
      print(stackTrace);
      _showError('Failed to process transaction: ${e.toString()}');
      return null;
    }
  }

  void _handleTransactionTypeChange(String? value) async {
    if (value == 'Return') {
      final invoiceNumber = await _showInvoiceNumberDialog();
      if (invoiceNumber == null || invoiceNumber.isEmpty) return;
      setState(() {
        _selectedTransactionType = value;
        _returnInvoiceNumber = invoiceNumber;
      });
    } else {
      setState(() {
        _selectedTransactionType = value;
        _returnInvoiceNumber = null;
      });
    }
  }

  Future<String?> _showInvoiceNumberDialog() async {
    String? invoiceNumber;
    await showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Enter Original Invoice Number'),
            content: TextField(
              autofocus: true,
              onChanged: (value) => invoiceNumber = value,
              decoration: const InputDecoration(hintText: 'Invoice Number'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, invoiceNumber),
                child: const Text('OK'),
              ),
            ],
          ),
    );
    return invoiceNumber;
  }

  Widget _buildPaymentDialog() {
    final subtotal = _calculateSubtotal();
    final totalAfterDiscount = subtotal - _globalDiscount;
    final givenAmount = int.tryParse(_givenAmountController.text) ?? 0;
    final returnAmount = givenAmount > totalAfterDiscount ? givenAmount -
        totalAfterDiscount : 0;
    final balanceDue = givenAmount < totalAfterDiscount ? totalAfterDiscount -
        givenAmount : 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 24)
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Center(
                  child: Text(
                    'Payment Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: InkWell(
                    onTap: () => setState(() => _showPaymentDialog = false),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _backgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: _secondaryTextColor,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildPaymentDetailRow('Subtotal', '$subtotal/-'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _globalDiscountController,
              decoration: InputDecoration(labelText: 'Global Discount'),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _globalDiscount = int.tryParse(value) ?? 0;
                });
              },
            ),
            const SizedBox(height: 12),
            _buildPaymentDetailRow(
              'Total After Discount',
              '$totalAfterDiscount/-',
              valueColor: _primaryColor,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _givenAmountController,
              decoration: InputDecoration(
                labelText: 'Amount Received',
                prefixIcon: Icon(Icons.payment, color: _primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: _backgroundColor,
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            if (returnAmount > 0)
              _buildPaymentStatusIndicator(
                'Change Due',
                returnAmount,
                Colors.green,
                Icons.arrow_upward,
              ),
            if (balanceDue > 0)
              _buildPaymentStatusIndicator(
                'Balance Due',
                balanceDue,
                Colors.orange,
                Icons.error_outline,
              ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      setState(() => _showPaymentDialog = false);
                      final invoiceData = await _processTransaction();
                      if (invoiceData != null) {
                        await _printInvoice(invoiceData);
                      }
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: _primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.print, color: Colors.white),
                    label: const Text(
                      'Print & Save',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() => _showPaymentDialog = false);
                      _processTransaction();
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: _backgroundColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(Icons.save, color: _primaryColor),
                    label: Text(
                      'Save',
                      style: TextStyle(color: _primaryColor),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  void _updateCartItem(int index, String field, String value) {
    setState(() {
      _cartItems[index][field] = value;

      if (['qty', 'price', 'discount'].contains(field)) {
        final qty = int.tryParse(_cartItems[index]['qty'] ?? '0') ?? 0;
        final price = int.tryParse(_cartItems[index]['price'] ?? '0') ?? 0;
        final discount = int.tryParse(_cartItems[index]['discount'] ?? '0') ??
            0;

        // Calculate total with discount
        final total = (qty * price * (100 - discount) / 100).round();
        _cartItems[index]['total'] = total.toString();
      }
    });
  }

  Future<void> _showAddItemDialog() async {
    await showDialog(
      context: context,
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setState) =>
                Dialog(
                  backgroundColor: _backgroundColor,
                  insetPadding: const EdgeInsets.all(24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05),
                            blurRadius: 24)
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search inventory...',
                            filled: true,
                            fillColor: _backgroundColor,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            suffixIcon: const Icon(
                                Icons.search, color: Color(0xFF6C757D)),
                          ),
                          onChanged: (value) => setState(() =>
                          _searchQuery = value.toLowerCase()),
                        ),
                        const SizedBox(height: 16),
                        _buildInventoryHeader(),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: MediaQuery
                              .of(context)
                              .size
                              .height * 0.6,
                          child: StreamBuilder<QuerySnapshot>(
                            stream: _firestore.collection('items').snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) return Text(
                                  'Error: ${snapshot.error}');
                              if (!snapshot.hasData) return const Center(
                                  child: CircularProgressIndicator());

                              final items = snapshot.data!.docs.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                return data['itemName'].toString()
                                    .toLowerCase()
                                    .contains(_searchQuery) ||
                                    data['qualityName'].toString()
                                        .toLowerCase()
                                        .contains(_searchQuery);
                              }).toList();

                              return ListView.separated(
                                separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                                itemCount: items.length,
                                itemBuilder: (context, index) =>
                                    _buildInventoryItem(
                                        items[index].data() as Map<
                                            String,
                                            dynamic>),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Widget _buildInventoryHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)
        ],
      ),
      child: const Row(
        children: [
          Expanded(child: Text('Quality', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
          Expanded(child: Text('Item', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
          Expanded(child: Text('Covered', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
          Expanded(child: Text('Price', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
          Expanded(child: Text('Stock', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildInventoryItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)
        ],
      ),
      child: InkWell(
        onTap: () => _addToCart(item),
        child: Row(
          children: [
            Expanded(child: Text(
                item['qualityName'] ?? '', style: TextStyle(color: _textColor),
                textAlign: TextAlign.center)),
            Expanded(child: Text(
                item['itemName'] ?? '', style: TextStyle(color: _textColor),
                textAlign: TextAlign.center)),
            Expanded(child: Text(
                item['covered'] ?? '-', style: TextStyle(color: _textColor),
                textAlign: TextAlign.center)),
            Expanded(child: Text(
                '${(item['salePrice'] as num).toStringAsFixed(0)}',
                style: TextStyle(color: _textColor),
                textAlign: TextAlign.center)),
            Expanded(child: Text(item['stockQuantity']?.toString() ?? '0',
                style: TextStyle(color: _textColor),
                textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }

  Future<void> _addToCart(Map<String, dynamic> item) async {
    try {
      final newItem = {
        'quality': item['qualityName']?.toString() ?? '',
        'item': item['itemName']?.toString() ?? '',
        'covered': item['covered']?.toString() ?? '-',
        'price': ((item['salePrice'] as num?) ?? 0).toStringAsFixed(0),
        'qty': '1',
        'discount': '0',
        'total': ((item['salePrice'] as num?) ?? 0).toStringAsFixed(0),
        'stockQuantity': (item['stockQuantity'] as int?) ?? 0,
      };

      if (_selectedCustomer['id'] != 'walking') {
        final customerId = _selectedCustomer['id'];
        final quality = newItem['quality'];
        final itemName = newItem['item'];
        final isCovered = (newItem['covered']?.toString()
            .trim()
            .toLowerCase() == 'yes');

        final discountsSnapshot = await _firestore
            .collection('customer_discounts')
            .where('customerId', isEqualTo: customerId)
            .where('qualityName', isEqualTo: quality)
            .where('item', whereIn: ['All', itemName])
            .get()
            .timeout(const Duration(seconds: 5));

        final discounts = discountsSnapshot.docs;
        Map<String, dynamic>? bestDiscount;

        final specificDiscounts = discounts.where((doc) =>
        doc['item'] == itemName).toList();
        if (specificDiscounts.isNotEmpty) {
          bestDiscount = specificDiscounts.first.data();
        }

        if (bestDiscount == null) {
          final qualityDiscounts = discounts.where((doc) =>
          doc['item'] == 'All').toList();
          if (qualityDiscounts.isNotEmpty) {
            bestDiscount = qualityDiscounts.first.data();
          }
        }

        if (bestDiscount != null) {
          final discountValue = isCovered
              ? bestDiscount['covered']
              : bestDiscount['uncovered'];

          if (discountValue != null) {
            _applyDiscount(newItem,
                bestDiscount['type']?.toString() ?? 'Discount',
                discountValue
            );
          }
        }
      }

      setState(() => _cartItems.add(newItem));
      Navigator.pop(context);
    } catch (e, stack) {
      print('Error adding to cart: $e');
      print(stack);
      _showError('Failed to add item: ${e.toString()}');
      Navigator.pop(context);
    }
  }


  void _applyDiscount(Map<String, dynamic> item, String discountType,
      dynamic discountValue) {
    if (discountValue == null) return;
    final parsedValue = discountValue is String ? double.tryParse(
        discountValue) ?? 0 : discountValue.toDouble();

    if (discountType == 'Price') {
      item['price'] = parsedValue.toStringAsFixed(0);
      item['discount'] = '0';
      item['total'] = (int.parse(item['qty']) * parsedValue).toStringAsFixed(0);
    } else if (discountType == 'Discount') {
      item['discount'] = parsedValue.toStringAsFixed(0);
      final total = int.parse(item['qty']) *
          int.parse(item['price']) *
          (1 - (parsedValue / 100));
      item['total'] = total.toStringAsFixed(0);
    }
  }

  Widget _buildCartHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)
        ],
      ),
      child: const Row(
        children: [
          Expanded(child: Text('Quality', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
          Expanded(child: Text('Item', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
          Expanded(child: Text('Cvrd', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
          Expanded(child: Text('Qty', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
          Expanded(child: Text('Price', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
          Expanded(child: Text('Dis%', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
          Expanded(child: Text('Amount', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
          Expanded(child: Text('Stock', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item, int index) {
    final isSelected = _selectedItemIndex == index;

    return GestureDetector(
      onTap: () =>
          setState(() {
            HapticFeedback.lightImpact();
            _selectedItemIndex = isSelected ? null : index;
          }),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)
          ],
        ),
        child: Stack(
          children: [
            Row(
              children: [
                _buildEditableField(item['quality'], index, 'quantity', false),
                _buildEditableField(item['item'], index, 'item', false),
                _buildEditableField(item['covered'], index, 'covered', false),
                _buildEditableField(item['qty'], index, 'qty', true),
                _buildEditableField(item['price'], index, 'price', true),
                _buildEditableField(item['discount'], index, 'discount', true),
                Expanded(
                  child: Text(item['total'],
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center),
                ),
                Expanded(
                  child: Text(item['stockQuantity']?.toString() ?? '0',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center),
                ),
              ],
            ),
            if (isSelected)
              Positioned(
                right: 8,
                top: 8,
                child: GestureDetector(
                  onTap: () => _removeItem(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.1), blurRadius: 4)
                      ],
                    ),
                    child: const Icon(
                        Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }


  Future<void> _printInvoice(Map<String, dynamic> invoiceData) async {
    try {
      final pdf = pw.Document();
      final date = (invoiceData['timestamp'] as Timestamp).toDate();
      final totalAmount = invoiceData['total'] as num;
      final primaryColor = PdfColor.fromHex('#0D6EFD');
      final accentColor = PdfColor.fromHex('#6C757D');
      final numberFormat = NumberFormat.currency(decimalDigits: 0, symbol: '');

      // PDF Content
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(
            base: await PdfGoogleFonts.openSansRegular(),
            bold: await PdfGoogleFonts.openSansBold(),
          ),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Section
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
                            color: primaryColor,
                          )),
                      pw.SizedBox(height: 8),
                      pw.Text('Popular Foam Center',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: accentColor,
                          )),
                      pw.Text('Zanana Hospital Road, Bahawalpur (63100)',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: accentColor,
                          )),
                    ],
                  ),
                  pw.Container(
                    width: 80,
                    height: 80,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Center(
                      child: pw.Text('Your Logo',
                          style: pw.TextStyle(color: PdfColors.grey600)),
                    ),
                  ),
                ],
              ),
              pw.Divider(color: primaryColor, height: 40),

              // Invoice Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Bill To:',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.Text(invoiceData['customer']['name'] ?? 'Walking Customer',
                          style: pw.TextStyle(fontSize: 14)),
                      pw.SizedBox(height: 8),
                      pw.Text('Invoice Date:',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.Text(DateFormat('dd MMM yyyy').format(date)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Invoice #${invoiceData['invoiceNumber']}',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 14,
                              color: primaryColor)),
                      pw.SizedBox(height: 8),
                      pw.Text('Transaction Type:',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.Text(invoiceData['type'].toString().toUpperCase(),
                          style: pw.TextStyle(color: accentColor)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Items Table
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
                    decoration: pw.BoxDecoration(color: primaryColor),
                    children: [
                      _tableHeaderCell('Item Description'),
                      _tableHeaderCell('Qty'),
                      _tableHeaderCell('Unit Price'),
                      _tableHeaderCell('Disc.%'),
                      _tableHeaderCell('Total'),
                    ],
                  ),
                  ...(invoiceData['items'] as List<dynamic>).map((item) {
                    final price = int.parse(item['price']?.toString() ?? '0');
                    final total = int.parse(item['total']?.toString() ?? '0');
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(
                            color: PdfColors.grey200,
                            width: 0.5,
                          ),
                        ),
                      ),
                      children: [
                        _tableCell('${item['quality']} ${item['item']}'),
                        _tableCell(item['qty']?.toString() ?? '0'),
                        _tableCell(numberFormat.format(price)),
                        _tableCell('${item['discount']?.toString() ?? '0'}%'),
                        _tableCell(numberFormat.format(total)),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 25),

              // Total Section
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _amountRow('Subtotal:', invoiceData['subtotal'], numberFormat),
                    _amountRow('Global Discount:',
                        -invoiceData['globalDiscount'], numberFormat,
                        isNegative: true),
                    pw.SizedBox(height: 15),
                    pw.Container(
                      width: 250,
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F8F9FA'),
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: primaryColor, width: 1),
                      ),
                      child: pw.Column(
                        children: [
                          _totalRow('TOTAL AMOUNT', totalAmount, numberFormat,
                              primaryColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      // Generate PDF bytes
      final Uint8List bytes = await pdf.save();

      // Platform handling
      if (kIsWeb) {
        await Printing.sharePdf(
          bytes: bytes,
          filename: 'PFC-INV-${invoiceData['invoiceNumber']}.pdf',
        );
      } else {
        final String? path = await FileSaver.instance.saveFile(
          name: 'PFC-INV-${invoiceData['invoiceNumber']}',
          bytes: bytes,
          ext: 'pdf',
          mimeType: MimeType.pdf,
        );

        if (path != null) {
          _showSuccess('Invoice saved to: $path');
        } else {
          _showError('Save operation cancelled');
        }
      }
    } catch (e, stack) {
      print('PDF Error: $e\n$stack');
      _showError('Failed to generate invoice: ${e.toString()}');
    }
  }

// PDF Helper Widgets
  pw.Widget _tableHeaderCell(String text) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    child: pw.Text(text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        )),
  );

  pw.Widget _tableCell(String text) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
  );

  pw.Widget _amountRow(String label, num value, NumberFormat format,
      {bool isNegative = false}) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(width: 15),
        pw.Container(
          width: 100,
          child: pw.Text(
              '${isNegative && value > 0 ? '-' : ''}${format.format(value)}',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 10,
                color: isNegative ? PdfColors.red : PdfColors.black,
              )),
        ),
      ],
    ),
  );

  pw.Widget _totalRow(String label, num value, NumberFormat format,
      PdfColor color) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(label,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          )),
      pw.Text(format.format(value),
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: color,
          )),
    ],
  );

// Helper Methods
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  Widget _buildEditableField(String value, int index, String field, bool editable) {
    return Expanded(
      child: editable ? TextFormField(
        initialValue: value,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _textColor,
          fontSize: 14,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        keyboardType: TextInputType.number,
        onChanged: (newValue) => _updateCartItem(index, field, newValue),
      ) : Text(value,
          style: TextStyle(
              color: _textColor,
              fontSize: 14
          ),
          textAlign: TextAlign.center),
    );
  }

  void _removeItem(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      _deletedItem = _cartItems[index];
      _deletedIndex = index;
      _cartItems.removeAt(index);
      _selectedItemIndex = null;
      _showUndoToast = true;
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _showUndoToast) setState(() => _showUndoToast = false);
    });
  }

  Widget _buildUndoToast() {
    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Item removed", style: TextStyle(color: _textColor)),
            TextButton(
              onPressed: _restoreItem,
              child: const Text('UNDO', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  void _restoreItem() {
    if (_deletedItem != null && _deletedIndex != null) {
      HapticFeedback.heavyImpact();
      setState(() {
        _cartItems.insert(_deletedIndex!, _deletedItem!);
        _showUndoToast = false;
        _deletedItem = null;
        _deletedIndex = null;
      });
    }
  }

  Widget _buildModernSummaryCard() {
    final subtotal = _calculateSubtotal();
    final total = _calculateTotal();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSummaryItem('Items', '${_cartItems.length}'),
          const Divider(),
          _buildSummaryItem('Subtotal', '$subtotal/-'),
          _buildSummaryItem('Global Discount', '$_globalDiscount/-'),
          const Divider(),
          _buildSummaryItem(
            'Total',
            '$total/-',
            valueStyle: TextStyle(
              color: _primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }


  int _calculateTotal() {
    final subtotal = _calculateSubtotal();
    final total = subtotal - _globalDiscount;
    return total < 0 ? 0 : total; // Ensure total is not negative
  }

  Widget _buildSummaryItem(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: _secondaryTextColor)),
          Text(value, style: valueStyle ?? TextStyle(color: _textColor)),
        ],
      ),
    );
  }

  Widget _buildPaymentStatusIndicator(String label, int value, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(color: _textColor))),
          Text('$value/-', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: _secondaryTextColor)),
        Text(value, style: TextStyle(
          color: valueColor ?? _textColor,
          fontWeight: FontWeight.bold,
        )),
      ],
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        title: Text("Point Of Sale", style: TextStyle(color: _textColor)),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: _primaryColor),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => TransactionsPage()),
            ),),],),
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Panel - Cart Items
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

                  // Right Panel - Customer Info & Summary
                  Expanded(
                    flex: 1,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: _surfaceColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 24,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _showAddItemDialog,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryColor,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 56),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                                  label: const Text(
                                    'ADD ITEM',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                StreamBuilder<QuerySnapshot>(
                                  stream: _firestore.collection('customers').snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return Text(
                                        'Error loading customers',
                                        style: TextStyle(color: Colors.red),
                                      );
                                    }

                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const CircularProgressIndicator();
                                    }

                                    final customers = [
                                      walkingCustomer,
                                      ...snapshot.data!.docs.map((doc) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        return {
                                          'id': doc.id,
                                          'name': data['name'],
                                          'phone': data.containsKey('phone') ? data['phone'] : ''
                                        };
                                      }),
                                    ];

                                    return DropdownButtonFormField<Map<String, dynamic>>(
                                      value: customers.firstWhere(
                                            (customer) => customer['id'] == _selectedCustomer['id'],
                                        orElse: () => walkingCustomer,
                                      ),
                                      items: customers.map((customer) => DropdownMenuItem<Map<String, dynamic>>(
                                        value: customer,
                                        child: Text(
                                          customer['name'],
                                          style: TextStyle(color: _textColor, fontSize: 14),
                                        ),
                                      )).toList(),
                                      onChanged: (value) => setState(() {
                                        _selectedCustomer = value!;
                                        _phoneController.text = value['phone'] ?? '';
                                      }),
                                      decoration: InputDecoration(
                                        labelText: 'Customer',
                                        filled: true,
                                        fillColor: _backgroundColor,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 14),
                                        labelStyle: TextStyle(color: _secondaryTextColor),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value: _selectedTransactionType,
                                  items: ['Sale', 'Return', 'Order Booking'].map((type) => DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(
                                      type,
                                      style: TextStyle(color: _textColor, fontSize: 14),
                                    ),
                                  )).toList(),
                                  onChanged: _handleTransactionTypeChange,
                                  decoration: InputDecoration(
                                    labelText: 'Transaction Type',
                                    filled: true,
                                    fillColor: _backgroundColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    labelStyle: TextStyle(color: _secondaryTextColor),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _phoneController,
                                  decoration: InputDecoration(
                                    labelText: 'Phone Number',
                                    filled: true,
                                    fillColor: _backgroundColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    labelStyle: TextStyle(color: _secondaryTextColor),
                                  ),
                                  style: TextStyle(color: _textColor),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: () => setState(() => _showPaymentDialog = true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryColor,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 56),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  icon: const Icon(Icons.arrow_forward_rounded),
                                  label: const Text('PROCEED TO PAYMENT'),
                                ),
                              ],
                            ),
                          ),
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

          // Overlay Dialogs
          if (_showPaymentDialog) _buildPaymentDialog(),
          if (_showUndoToast) _buildUndoToast(),
        ],
      ),
    );
  }
}


class TransactionsPage extends StatefulWidget {
  @override
  _TransactionsPageState createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color _primaryColor = const Color(0xFF0D6EFD);
  final Color _textColor = const Color(0xFF2D2D2D);
  final Color _secondaryTextColor = const Color(0xFF4A4A4A);
  final Color _backgroundColor = const Color(0xFFF8F9FA);


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Transaction History',
            style: TextStyle(
                color: _textColor,
                fontWeight: FontWeight.w600,
                fontSize: 20)),
        backgroundColor: _backgroundColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: _primaryColor),
      ),
      backgroundColor: _backgroundColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('invoices')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Error loading transactions'));

          return ListView.separated(
            padding: EdgeInsets.all(24),
            separatorBuilder: (_, __) => SizedBox(height: 16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildTransactionCard({
                ...data,
                'id': doc.id, // Add document ID to the data
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> data) {
    final date = (data['timestamp'] as Timestamp).toDate();
    final customerName = data['customer']['name']?.toString() ?? 'Walking Customer';
    final balanceDue = (data['balanceDue'] ?? 0).toDouble();
    final isPending = balanceDue > 0;
    final transactionType = data['type'].toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.receipt_long, color: _primaryColor),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('INV-${data['invoiceNumber']}',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16)),
                      SizedBox(width: 12),
                      _buildStatusChip(isPending),
                      SizedBox(width: 8),
                      _buildTypeChip(transactionType),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    DateFormat('MMM dd, yyyy • hh:mm a').format(date),
                    style: TextStyle(
                      color: _secondaryTextColor,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(customerName,
                      style: TextStyle(
                          color: _textColor,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.open_in_new, size: 20, color: _primaryColor),
                  // In TransactionsPage build method
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PointOfSalePage(
                          invoice: data, // Now contains the 'id' field
                        ),
                      ),
                    );
                  },

                ),
                IconButton(
                  icon: Icon(Icons.print, size: 20, color: _primaryColor),
                  onPressed: () => _printInvoice(data),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isPending) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPending ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPending ? Icons.pending_actions : Icons.verified,
            size: 14,
            color: isPending ? Colors.red : Colors.green,
          ),
          SizedBox(width: 6),
          Text(
            isPending ? 'Pending' : 'Paid',
            style: TextStyle(
                color: isPending ? Colors.red : Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.w600
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String type) {
    final isSale = type.toLowerCase() == 'sale';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSale
            ? Colors.blue.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSale ? Icons.shopping_cart : Icons.reply,
            size: 14,
            color: isSale ? Colors.blue : Colors.orange,
          ),
          SizedBox(width: 6),
          Text(
            type.toUpperCase(),
            style: TextStyle(
                color: isSale ? Colors.blue : Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

// Keep the _printInvoice method and PDF generation code from original
// if you still need printing functionality

  Future<void> _printInvoice(Map<String, dynamic> invoiceData) async {
    final pdf = pw.Document();
    final date = (invoiceData['timestamp'] as Timestamp).toDate();
    final totalAmount = invoiceData['total'] as num;
    final primaryColor = PdfColor.fromHex('#0D6EFD');
    final accentColor = PdfColor.fromHex('#6C757D');
    final numberFormat = NumberFormat.currency(
      decimalDigits: 0,
      symbol: '',
    );

    final boldFont = await PdfGoogleFonts.openSansBold();
    final regularFont = await PdfGoogleFonts.openSansRegular();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: regularFont,
          bold: boldFont,
        ),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildInvoiceHeader(primaryColor, accentColor),
            pw.Divider(color: primaryColor, height: 40),
            _buildInvoiceDetails(invoiceData, date, primaryColor, accentColor),
            pw.SizedBox(height: 30),
            _buildItemsTable(invoiceData, numberFormat, primaryColor),
            pw.SizedBox(height: 25),
            _buildSummarySection(invoiceData, numberFormat, primaryColor),
            pw.SizedBox(height: 30),
            _buildPaymentSection(invoiceData, numberFormat),
            pw.SizedBox(height: 25),
            _buildFooter(accentColor),
          ],
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'PFC-INV-${invoiceData['invoiceNumber']}.pdf',
    );
  }

  pw.Widget _buildInvoiceHeader(PdfColor primaryColor, PdfColor accentColor) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('INVOICE',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                )),
            pw.SizedBox(height: 8),
            pw.Text('Popular Foam Center',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: accentColor,
                )),
            pw.Text('Zanana Hospital Road, Bahawalpur (63100)',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: accentColor,
                )),
          ],
        ),
        pw.Container(
          width: 80,
          height: 80,
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Center(
            child: pw.Text('Your Logo',
                style: pw.TextStyle(color: PdfColors.grey600)),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildInvoiceDetails(
      Map<String, dynamic> invoiceData, DateTime date, PdfColor primaryColor, PdfColor accentColor) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Bill To:',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.Text(invoiceData['customer']['name']?.toString() ?? 'Walking Customer',
                style: pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.Text('Invoice Date:',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.Text(DateFormat('dd MMM yyyy').format(date)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Invoice #${invoiceData['invoiceNumber']}',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                    color: primaryColor)),
            pw.SizedBox(height: 8),
            pw.Text('Transaction Type:',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.Text(invoiceData['type'].toString().toUpperCase(),
                style: pw.TextStyle(color: accentColor)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildItemsTable(
      Map<String, dynamic> invoiceData, NumberFormat format, PdfColor primaryColor) {
    return pw.Table(
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
          decoration: pw.BoxDecoration(color: primaryColor),
          children: [
            _tableHeaderCell('Item Description'),
            _tableHeaderCell('Qty'),
            _tableHeaderCell('Unit Price'),
            _tableHeaderCell('Disc.%'),
            _tableHeaderCell('Total'),
          ],
        ),
        ...(invoiceData['items'] as List<dynamic>).map((item) {
          final price = int.parse(item['price']?.toString() ?? '0');
          final total = int.parse(item['total']?.toString() ?? '0');
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
              ),
            ),
            children: [
              _tableCell('${item['quality']} ${item['item']}'),
              _tableCell(item['qty']?.toString() ?? '0'),
              _tableCell(format.format(price)),
              _tableCell('${item['discount']?.toString() ?? '0'}%'),
              _tableCell(format.format(total)),
            ],
          );
        }).toList(),
      ],
    );
  }

  pw.Widget _buildSummarySection(
      Map<String, dynamic> invoiceData, NumberFormat format, PdfColor primaryColor) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          _amountRow('Subtotal:', invoiceData['subtotal'], format),
          _amountRow('Global Discount:', -invoiceData['globalDiscount'], format,
              isNegative: true),
          pw.SizedBox(height: 15),
          pw.Container(
            width: 250,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F8F9FA'),
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: primaryColor, width: 1),
            ),
            child: pw.Column(
              children: [
                _totalRow('TOTAL AMOUNT', invoiceData['total'], format,
                    primaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPaymentSection(
      Map<String, dynamic> invoiceData, NumberFormat format) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          _paymentRow('Amount Received:', invoiceData['givenAmount'], format),
          if ((invoiceData['returnAmount'] as num) > 0)
            _paymentRow('Change Returned:', invoiceData['returnAmount'], format,
                isPositive: true),
          if ((invoiceData['balanceDue'] as num) > 0)
            _paymentRow('Balance Due:', invoiceData['balanceDue'], format,
                isNegative: true),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(PdfColor accentColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 12),
      child: pw.Column(
        children: [
          pw.Text('Thank you for choosing Popular Foam Center',
              style: pw.TextStyle(
                fontSize: 10,
                color: accentColor,
              )),
          pw.SizedBox(height: 6),
          pw.Text('Contact: 0302-9596046 | Facebook: Popular Foam Center',
              style: pw.TextStyle(
                fontSize: 9,
                color: accentColor,
              )),
          pw.SizedBox(height: 10),
          pw.Text(
            'Notes: Claims as per company policy | ',
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey600,
              fontStyle: pw.FontStyle.italic,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper functions (same as PointOfSalePage)
  pw.Widget _tableHeaderCell(String text) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    child: pw.Text(text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        )),
  );

  pw.Widget _tableCell(String text) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    child: pw.Text(text,
        style: const pw.TextStyle(
          fontSize: 10,
        )),
  );

  pw.Widget _amountRow(String label, num value, NumberFormat format,
      {bool isNegative = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(width: 15),
            pw.Container(
              width: 100,
              child: pw.Text(
                  '${isNegative && value > 0 ? '-' : ''}${format.format(value)}',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: isNegative ? PdfColors.red : PdfColors.black,
                  )),
            ),
          ],
        ),
      );

  pw.Widget _totalRow(String label, num value, NumberFormat format,
      PdfColor color) =>
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              )),
          pw.Text(format.format(value),
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: color,
              )),
        ],
      );

  pw.Widget _paymentRow(String label, num value, NumberFormat format,
      {bool isPositive = false, bool isNegative = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: isNegative
                      ? PdfColors.red
                      : isPositive
                      ? PdfColors.green
                      : PdfColors.black,
                )),
            pw.Text(
                '${isNegative ? '-' : ''}${format.format(value.abs())}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: isNegative
                      ? PdfColors.red
                      : isPositive
                      ? PdfColors.green
                      : PdfColors.black,
                )),
          ],
        ),
      );

}

