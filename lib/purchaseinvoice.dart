import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

// Color Scheme
const Color _primaryColor = Color(0xFF0D6EFD);
const Color _textColor = Color(0xFF2D2D2D);
const Color _secondaryTextColor = Color(0xFF4A4A4A);
const Color _backgroundColor = Color(0xFFF8F9FA);
const Color _surfaceColor = Colors.white;

// ======================
// Invoice List Screen
// ======================
class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  _InvoiceListScreenState createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final ScrollController _horizontalScrollController = ScrollController();
  final double _mobileTableWidth = 1200;

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  String _formatDate(dynamic dateValue) {
    try {
      DateTime date;
      if (dateValue is Timestamp) {
        date = dateValue.toDate();
      } else if (dateValue is String) {
        date = DateFormat('dd-MM-yyyy').parse(dateValue);
      } else {
        date = DateTime.fromMillisecondsSinceEpoch(dateValue.millisecondsSinceEpoch);
      }
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      print('Error parsing date: $e');
      return 'Invalid Date';
    }
  }

  void _viewInvoice(DocumentSnapshot invoiceDoc) {
    final invoice = invoiceDoc.data() as Map<String, dynamic>;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceViewScreen.fromData(
          company: invoice['company'] ?? 'Unknown Company',
          invoiceId: invoiceDoc.id,
          existingInvoice: invoice,
        ),
      ),
    );
  }

  void _editInvoice(DocumentSnapshot invoiceDoc) {
    final invoice = invoiceDoc.data() as Map<String, dynamic>;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceScreen(
          company: invoice['company'],
          invoiceId: invoiceDoc.id,
          existingInvoice: invoice,
        ),
      ),
    );
  }

  Future<void> _deleteInvoice(DocumentSnapshot invoiceDoc) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _surfaceColor,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 8))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Confirm Delete',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Are you sure you want to delete this invoice?',
                style: TextStyle(
                  fontSize: 14,
                  color: _secondaryTextColor,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: _secondaryTextColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        color: _surfaceColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmDelete == true) {
      await FirebaseFirestore.instance
          .collection('purchaseinvoices')
          .doc(invoiceDoc.id)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice deleted successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 1200;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Invoices', style: TextStyle(color: _textColor)),
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _textColor),
      ),
      backgroundColor: _backgroundColor,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(child: _buildSearchBar()),
                const SizedBox(width: 16),
                _buildAddButton(),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('purchaseinvoices').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _primaryColor));
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: _textColor)));
        }

        final invoices = snapshot.data?.docs.where((doc) {
          final company = doc['company'].toString().toLowerCase();
          return company.contains(_searchQuery);
        }).toList();

        if (invoices == null || invoices.isEmpty) {
          return Center(
              child: Text('No invoices found',
                  style: const TextStyle(color: _textColor)));
        }

        return Column(
          children: [
            _buildDesktopHeader(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: invoices.length,
                itemBuilder: (context, index) => _buildDesktopRow(invoices[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMobileLayout() {
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
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('purchaseinvoices')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                          child: CircularProgressIndicator(color: _primaryColor));
                    }
                    if (snapshot.hasError) {
                      return Center(
                          child: Text('Error: ${snapshot.error}',
                              style: const TextStyle(color: _textColor)));
                    }

                    final invoices = snapshot.data?.docs.where((doc) {
                      final company = doc['company'].toString().toLowerCase();
                      return company.contains(_searchQuery);
                    }).toList();

                    if (invoices == null || invoices.isEmpty) {
                      return Center(
                          child: Text('No invoices found',
                              style: const TextStyle(color: _textColor)));
                    }

                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemCount: invoices.length,
                      itemBuilder: (context, index) => _buildMobileRow(invoices[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(child: _HeaderCell('Invoice ID')),
            Expanded(child: _HeaderCell('Company')),
            Expanded(child: _HeaderCell('Total')),
            Expanded(child: _HeaderCell('Invoice Date')),
            Expanded(child: _HeaderCell('Receive Date')),
            Expanded(child: _HeaderCell('Actions')),
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
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _HeaderCell('Invoice ID', 150),
            _HeaderCell('Company', 200),
            _HeaderCell('Total', 100),
            _HeaderCell('Invoice Date', 150),
            _HeaderCell('Receive Date', 150),
            _HeaderCell('Actions', 150),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopRow(DocumentSnapshot invoiceDoc) {
    final invoice = invoiceDoc.data() as Map<String, dynamic>;
    final total = invoice['total'].toStringAsFixed(0);
    final invoiceDate = _formatDate(invoice['invoiceDate']);
    final receiveDate = _formatDate(invoice['receiveDate']);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(child: _DataCell(invoice['invoiceId'])),
            Expanded(child: _DataCell(invoice['company'])),
            Expanded(child: _DataCell(total)),
            Expanded(child: _DataCell(invoiceDate)),
            Expanded(child: _DataCell(receiveDate)),
            Expanded(
                child: _ActionCell(
                  invoiceDoc,
                  null,
                  onView: _viewInvoice,
                  onEdit: _editInvoice,
                  onDelete: _deleteInvoice,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileRow(DocumentSnapshot invoiceDoc) {
    final invoice = invoiceDoc.data() as Map<String, dynamic>;
    final total = invoice['total'].toStringAsFixed(0);
    final invoiceDate = _formatDate(invoice['invoiceDate']);
    final receiveDate = _formatDate(invoice['receiveDate']);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _DataCell(invoice['invoiceId'], 150),
            _DataCell(invoice['company'], 200),
            _DataCell(total, 100),
            _DataCell(invoiceDate, 150),
            _DataCell(receiveDate, 150),
            _ActionCell(
              invoiceDoc,
              150,
              onView: _viewInvoice,
              onEdit: _editInvoice,
              onDelete: _deleteInvoice,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search invoices...',
          filled: true,
          fillColor: _surfaceColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear, color: _secondaryTextColor),
            onPressed: () => setState(() => _searchController.clear()),
          ),
          prefixIcon: const Icon(Icons.search, color: _secondaryTextColor),
        ),
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
      ),
    );
  }

  Widget _buildAddButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add, size: 20, color: _surfaceColor),
        label: const Text('Add Invoice',
            style: TextStyle(fontSize: 14, color: _surfaceColor)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        onPressed: () => _showCompanySelectionDialog(context),
      ),
    );
  }

  Future<void> _showCompanySelectionDialog(BuildContext context) async {
    final selectedCompany = await showDialog<String>(
      context: context,
      builder: (context) => CompanySelectionDialog(),
    );

    if (selectedCompany != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InvoiceScreen(company: selectedCompany),
        ),
      );
    }
  }
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
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final String text;
  final double? width;

  const _DataCell(this.text, [this.width]);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Center(
        child: Text(
          text,
          style: const TextStyle(color: _textColor, fontSize: 14),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }
}

class _ActionCell extends StatelessWidget {
  final DocumentSnapshot invoiceDoc;
  final double? width;
  final Function(DocumentSnapshot) onView;
  final Function(DocumentSnapshot) onEdit;
  final Function(DocumentSnapshot) onDelete;

  const _ActionCell(this.invoiceDoc, this.width,
      {required this.onView, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_red_eye, color: Colors.blue, size: 20),
            onPressed: () => onView(invoiceDoc),
            tooltip: 'View Invoice',
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: _primaryColor, size: 20),
            onPressed: () => onEdit(invoiceDoc),
            tooltip: 'Edit Invoice',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            onPressed: () => onDelete(invoiceDoc),
            tooltip: 'Delete Invoice',
          ),
        ],
      ),
    );
  }
}

// Data Models
class InvoiceItem {
  final String itemId;
  final String name;
  final String quality;
  final String packagingUnit;
  int quantity;
  double price;
  double discount;
  final String covered;

  InvoiceItem({
    required this.itemId,
    required this.name,
    required this.quality,
    required this.packagingUnit,
    required this.quantity,
    required this.price,
    required this.discount,
    required this.covered,
  });

  Map<String, dynamic> toMap() => {
    'itemId': itemId,
    'name': name,
    'quality': quality,
    'packagingUnit': packagingUnit,
    'quantity': quantity,
    'price': price,
    'discount': discount,
    'isCovered': covered.toLowerCase() == "yes",
    'total': quantity * price * (1 - discount / 100),
  };
}

class Item {
  final String id;
  final String name;
  final String quality;
  final String packagingUnit;
  final double purchasePrice;
  final String covered;

  Item({
    required this.id,
    required this.name,
    required this.quality,
    required this.packagingUnit,
    required this.purchasePrice,
    required this.covered,
  });

  factory Item.fromMap(Map<String, dynamic> map, String id) => Item(
    id: id,
    name: map['itemName'] ?? 'Unknown Item',
    quality: map['qualityName'] ?? 'N/A',
    packagingUnit: map['packagingUnit'] ?? 'Unit',
    purchasePrice: (map['purchasePrice'] ?? 0.0).toDouble(),
    covered: map['covered']?.toString() ?? "No",
  );
}

// Invoice Screen
class InvoiceScreen extends StatefulWidget {
  final String company;
  final String? invoiceId;
  final Map<String, dynamic>? existingInvoice;
  const InvoiceScreen({
    super.key,
    required this.company,
    this.invoiceId,
    this.existingInvoice,
  });

  @override
  _InvoiceScreenState createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<InvoiceItem> _items = [];
  Map<String, int> _originalQuantities = {}; // Store original quantities by itemId
  double _subtotal = 0.0;
  double _total = 0.0;
  final TextEditingController _invoiceIdController = TextEditingController();
  final TextEditingController _invoiceDateController = TextEditingController();
  final TextEditingController _receiveDateController = TextEditingController();
  final TextEditingController _taxController = TextEditingController(text: '0.5');
  final ScrollController _itemsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.existingInvoice != null) {
      _initializeExistingInvoice();
    } else {
      final today = DateTime.now();
      _invoiceDateController.text = DateFormat('dd-MM-yyyy').format(today);
      _receiveDateController.text = DateFormat('dd-MM-yyyy').format(today);
    }
  }

  void _initializeExistingInvoice() {
    final invoice = widget.existingInvoice!;
    _invoiceIdController.text = invoice['invoiceId'];
    _invoiceDateController.text = invoice['invoiceDate'];
    _receiveDateController.text = invoice['receiveDate'];
    _taxController.text = invoice['taxPercentage'].toString();

    // Initialize items and original quantities
    final List<dynamic> invoiceItems = invoice['items'] as List<dynamic>;
    for (var item in invoiceItems) {
      final invoiceItem = InvoiceItem(
        itemId: item['itemId'],
        name: item['name'],
        quality: item['quality'],
        packagingUnit: item['packagingUnit'],
        quantity: (item['quantity'] as num).toInt(),
        price: (item['price'] as num).toDouble(),
        discount: (item['discount'] as num).toDouble(),
        covered: item['isCovered'] ? "Yes" : "No",
      );
      _items.add(invoiceItem);
      _originalQuantities[invoiceItem.itemId] = invoiceItem.quantity; // Store original quantity
    }

    _calculateTotal();
  }

  Future<void> _addItem(Item item) async {
    final QuerySnapshot qualitySnapshot = await _firestore
        .collection('qualities')
        .where('name', isEqualTo: item.quality)
        .limit(1)
        .get();

    if (qualitySnapshot.docs.isEmpty) return;

    final qualityData = qualitySnapshot.docs.first.data() as Map<String, dynamic>;
    final discount = (item.covered.toLowerCase() == "yes")
        ? (qualityData['covered_discount'] ?? 0.0).toDouble()
        : (qualityData['uncovered_discount'] ?? 0.0).toDouble();

    setState(() {
      _items.add(InvoiceItem(
        itemId: item.id,
        name: item.name,
        quality: item.quality,
        packagingUnit: item.packagingUnit,
        quantity: 1,
        price: item.purchasePrice,
        discount: discount,
        covered: item.covered,
      ));
      // If this is a new item (not in original), set original quantity to 0
      if (!_originalQuantities.containsKey(item.id)) {
        _originalQuantities[item.id] = 0;
      }
      _calculateTotal();
    });
    Navigator.pop(context);
  }

  void _calculateTotal() {
    _subtotal = _items.fold(
        0.0, (sum, item) => sum + (item.quantity * item.price * (1 - item.discount / 100)));
    final tax = _subtotal * (double.tryParse(_taxController.text) ?? 0.0) / 100;
    _total = _subtotal + tax;
    setState(() {});
  }

  Future<void> _submitInvoice() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    final invoiceData = {
      'invoiceId': _invoiceIdController.text,
      'company': widget.company,
      'invoiceDate': _invoiceDateController.text,
      'receiveDate': _receiveDateController.text,
      'items': _items.map((item) => item.toMap()).toList(),
      'subtotal': _subtotal,
      'taxPercentage': double.parse(_taxController.text),
      'taxAmount': _total - _subtotal,
      'total': _total,
      'createdAt': widget.invoiceId == null ? FieldValue.serverTimestamp() : widget.existingInvoice!['createdAt'],
    };

    try {
      if (widget.invoiceId != null) {
        await _updateStockQuantities();
        await _firestore.collection('purchaseinvoices').doc(widget.invoiceId).update(invoiceData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice updated successfully!')),
        );
      } else {
        final docRef = await _firestore.collection('purchaseinvoices').add(invoiceData);
        await _updateStockQuantities();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice saved successfully!')),
        );
      }
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving invoice: $e')),
      );
    }
  }

  Future<void> _updateStockQuantities() async {
    for (final item in _items) {
      final originalQty = _originalQuantities[item.itemId] ?? 0;
      final newQty = item.quantity;
      final qtyDifference = newQty - originalQty;

      if (qtyDifference != 0) {
        await _firestore.collection('items').doc(item.itemId).update({
          'stockQuantity': FieldValue.increment(qtyDifference),
        });
      }
    }

    // Handle items that were removed
    for (final originalItemId in _originalQuantities.keys) {
      if (!_items.any((item) => item.itemId == originalItemId)) {
        final originalQty = _originalQuantities[originalItemId] ?? 0;
        await _firestore.collection('items').doc(originalItemId).update({
          'stockQuantity': FieldValue.increment(-originalQty),
        });
      }
    }
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      controller.text = DateFormat('dd-MM-yyyy').format(pickedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        title: Text(
          widget.invoiceId != null ? "Edit Purchase Invoice" : "Add Purchase Invoice",
          style: TextStyle(color: _textColor),
        ),
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor),
      ),
      backgroundColor: _backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  _buildItemsHeader(),
                  const SizedBox(height: 16),
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.7,
                    ),
                    child: ListView.separated(
                      controller: _itemsScrollController,
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _buildItemRow(_items[index], index),
                    ),
                  ),
                  if (_items.isEmpty)
                    Container(
                      height: 200,
                      alignment: Alignment.center,
                      child: Text(
                        "No items added",
                        style: TextStyle(color: _secondaryTextColor, fontSize: 16),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 1,
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildInputPanel(),
                      const SizedBox(height: 24),
                      _buildSummaryCard(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsHeader() => Container(
    height: 56,
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    decoration: BoxDecoration(
      color: _primaryColor,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12),
      ],
    ),
    child: Row(
      children: [
        Expanded(
            flex: 2,
            child: Center(
                child: Text('Quality',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)))),
        Expanded(
            flex: 2,
            child: Center(
                child: Text('Item',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text('Cvrd',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text('Qty',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text('Price',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text('Disc%',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text('Total',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)))),
      ],
    ),
  );

  Widget _buildItemRow(InvoiceItem item, int index) => GestureDetector(
    onTap: () => setState(() => _selectedItemIndex = _selectedItemIndex == index ? null : index),
    child: Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Stack(
        children: [
          Row(
            children: [
              Expanded(
                  flex: 2,
                  child: Center(
                      child: Text(item.quality,
                          style: TextStyle(color: _textColor, fontSize: 14)))),
              Expanded(
                  flex: 2,
                  child: Center(
                      child: Text(item.name,
                          style: TextStyle(color: _textColor, fontSize: 14)))),
              Expanded(
                  flex: 1,
                  child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: item.covered.toLowerCase() == "yes"
                              ? Colors.green[100]
                              : Colors.red[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.covered,
                          style: TextStyle(
                            color: item.covered.toLowerCase() == "yes"
                                ? Colors.green[800]
                                : Colors.red[800],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ))),
              Expanded(
                  flex: 1,
                  child: Center(
                      child: TextFormField(
                        initialValue: item.quantity.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _textColor, fontSize: 14),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (value) {
                          if (value.isNotEmpty) {
                            setState(() {
                              item.quantity = int.parse(value);
                              _calculateTotal();
                            });
                          }
                        },
                      ))),
              Expanded(
                  flex: 1,
                  child: Center(
                      child: TextFormField(
                        initialValue: item.price.toStringAsFixed(0),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _textColor, fontSize: 14),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (value) {
                          if (value.isNotEmpty) {
                            setState(() {
                              item.price = double.parse(value);
                              _calculateTotal();
                            });
                          }
                        },
                      ))),
              Expanded(
                  flex: 1,
                  child: Center(
                      child: TextFormField(
                        initialValue: item.discount.toStringAsFixed(0),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _textColor, fontSize: 14),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (value) {
                          if (value.isNotEmpty) {
                            setState(() {
                              item.discount = double.parse(value);
                              _calculateTotal();
                            });
                          }
                        },
                      ))),
              Expanded(
                  flex: 1,
                  child: Center(
                      child: Text(
                        (item.quantity * item.price * (1 - item.discount / 100))
                            .toStringAsFixed(0),
                        style: TextStyle(
                            color: _textColor, fontWeight: FontWeight.bold, fontSize: 14),
                      ))),
            ],
          ),
          if (_selectedItemIndex == index)
            Positioned(
              right: 8,
              top: 8,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _items.removeAt(index);
                    _selectedItemIndex = null;
                    _calculateTotal();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _buildInputPanel() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 24),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
          label: const Text('ADD ITEM',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 24),
        _buildTextField('Challan #', _invoiceIdController),
        const SizedBox(height: 16),
        _buildTextField('Company', TextEditingController(text: widget.company), enabled: false),
        const SizedBox(height: 16),
        _buildDateField('Invoice Date', _invoiceDateController),
        const SizedBox(height: 16),
        _buildDateField('Receive Date', _receiveDateController),
        const SizedBox(height: 16),
        _buildTextField('Tax Percentage (%)', _taxController,
            isNumeric: true, onChanged: (value) => _calculateTotal()),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _submitInvoice,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          icon: const Icon(Icons.save, size: 20),
          label: const Text('SAVE INVOICE',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );

  Widget _buildTextField(String label, TextEditingController controller,
      {bool isNumeric = false, bool enabled = true, void Function(String)? onChanged}) =>
      TextFormField(
        controller: controller,
        style: TextStyle(color: _textColor, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: _backgroundColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: TextStyle(color: _secondaryTextColor),
        ),
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumeric ? [FilteringTextInputFormatter.digitsOnly] : null,
        validator: enabled ? (value) => value!.isEmpty ? 'Required field' : null : null,
        enabled: enabled,
        onChanged: onChanged,
      );

  Widget _buildDateField(String label, TextEditingController controller) => TextFormField(
    controller: controller,
    readOnly: true,
    onTap: () => _selectDate(controller),
    style: TextStyle(color: _textColor, fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      filled: true,
      fillColor: _backgroundColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: TextStyle(color: _secondaryTextColor),
      suffixIcon: Icon(Icons.calendar_today, color: _secondaryTextColor),
    ),
    validator: (value) => value!.isEmpty ? 'Required field' : null,
  );

  Widget _buildSummaryCard() => Container(
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
        _buildSummaryItem('Items', _items.length.toString()),
        const Divider(),
        _buildSummaryItem('Subtotal', '${_subtotal.toStringAsFixed(0)}/-'),
        _buildSummaryItem('Tax', '${(_total - _subtotal).toStringAsFixed(0)}/-'),
        const Divider(),
        _buildSummaryItem(
          'Total',
          '${_total.toStringAsFixed(0)}/-',
          valueStyle: TextStyle(
              color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ],
    ),
  );

  Widget _buildSummaryItem(String label, String value, {TextStyle? valueStyle}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: _secondaryTextColor)),
        Text(value, style: valueStyle ?? TextStyle(color: _textColor)),
      ],
    ),
  );

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
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 24),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search items...',
                    filled: true,
                    fillColor: _backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    suffixIcon: Icon(Icons.search, color: _secondaryTextColor),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                ),
                const SizedBox(height: 16),
                _buildInventoryHeader(),
                const SizedBox(height: 8),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('items').snapshots(),
                    builder: (_, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final items = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['itemName']
                            .toString()
                            .toLowerCase()
                            .contains(_searchQuery) ||
                            data['qualityName']
                                .toString()
                                .toLowerCase()
                                .contains(_searchQuery);
                      }).toList();
                      return ListView.separated(
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemCount: items.length,
                        itemBuilder: (_, index) => _buildInventoryItem(
                            Item.fromMap(items[index].data() as Map<String, dynamic>, items[index].id)),
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

  String _searchQuery = '';

  Widget _buildInventoryHeader() => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    decoration: BoxDecoration(
      color: _primaryColor,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12),
      ],
    ),
    child: Row(
      children: [
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
      ],
    ),
  );

  Widget _buildInventoryItem(Item item) => InkWell(
    onTap: () => _addItem(item),
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Expanded(
              child: Text(item.quality,
                  style: TextStyle(color: _textColor), textAlign: TextAlign.center)),
          Expanded(
              child: Text(item.name,
                  style: TextStyle(color: _textColor), textAlign: TextAlign.center)),
          Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.covered.toLowerCase() == "yes"
                      ? Colors.green[100]
                      : Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.covered,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: item.covered.toLowerCase() == "yes"
                        ? Colors.green[800]
                        : Colors.red[800],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )),
          Expanded(
              child: Text(item.purchasePrice.toStringAsFixed(0),
                  style: TextStyle(color: _textColor), textAlign: TextAlign.center)),
        ],
      ),
    ),
  );

  int? _selectedItemIndex;
}

// Invoice View Screen (Read-Only)
class InvoiceViewScreen extends StatelessWidget {
  final String company;
  final String invoiceId;
  final Map<String, dynamic> existingInvoice;
  final List<InvoiceItem> items;

  const InvoiceViewScreen({
    super.key,
    required this.company,
    required this.invoiceId,
    required this.existingInvoice,
  }) : items = const [];

  factory InvoiceViewScreen.fromData({
    required String company,
    required String invoiceId,
    required Map<String, dynamic> existingInvoice,
  }) {
    final itemsList = existingInvoice['items'] as List<dynamic>? ?? [];
    final items = itemsList.map((item) => InvoiceItem(
      itemId: item['itemId'] ?? '',
      name: item['name'] ?? 'Unknown',
      quality: item['quality'] ?? 'N/A',
      packagingUnit: item['packagingUnit'] ?? 'Unit',
      quantity: item['quantity'] ?? 0,
      price: (item['price'] as num?)?.toDouble() ?? 0.0,
      discount: (item['discount'] as num?)?.toDouble() ?? 0.0,
      covered: item['isCovered'] == true ? "Yes" : "No",
    )).toList();
    return InvoiceViewScreen._(
      company: company,
      invoiceId: invoiceId,
      existingInvoice: existingInvoice,
      items: items,
    );
  }

  const InvoiceViewScreen._({
    required this.company,
    required this.invoiceId,
    required this.existingInvoice,
    required this.items,
  });

  String _formatDate(dynamic dateValue) {
    try {
      DateTime date;
      if (dateValue is Timestamp) {
        date = dateValue.toDate();
      } else if (dateValue is String) {
        date = DateFormat('dd-MM-yyyy').parse(dateValue);
      } else {
        date = DateTime.fromMillisecondsSinceEpoch(dateValue.millisecondsSinceEpoch);
      }
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      print('Error parsing date: $e');
      return 'Invalid Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        title: const Text("View Purchase Invoice", style: TextStyle(color: _textColor)),
        elevation: 0,
        iconTheme: const IconThemeData(color: _textColor),
      ),
      backgroundColor: _backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  _buildItemsHeader(),
                  const SizedBox(height: 16),
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.7,
                    ),
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _buildItemRow(items[index]),
                    ),
                  ),
                  if (items.isEmpty)
                    Container(
                      height: 200,
                      alignment: Alignment.center,
                      child: Text(
                        "No items",
                        style: TextStyle(color: _secondaryTextColor, fontSize: 16),
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
                    _buildInputPanel(),
                    const SizedBox(height: 24),
                    _buildSummaryCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsHeader() => Container(
    height: 56,
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    decoration: BoxDecoration(
      color: _primaryColor,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12),
      ],
    ),
    child: Row(
      children: [
        Expanded(
            flex: 2,
            child: Center(
                child: Text('Quality',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)))),
        Expanded(
            flex: 2,
            child: Center(
                child: Text('Item',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text('Cvrd',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text('Qty',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text('Price',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text('Disc%',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text('Total',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)))),
      ],
    ),
  );

  Widget _buildItemRow(InvoiceItem item) => Container(
    height: 56,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
      ],
    ),
    child: Row(
      children: [
        Expanded(
            flex: 2,
            child: Center(
                child: Text(item.quality,
                    style: TextStyle(color: _textColor, fontSize: 14)))),
        Expanded(
            flex: 2,
            child: Center(
                child: Text(item.name,
                    style: TextStyle(color: _textColor, fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.covered.toLowerCase() == "yes"
                        ? Colors.green[100]
                        : Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.covered,
                    style: TextStyle(
                      color: item.covered.toLowerCase() == "yes"
                          ? Colors.green[800]
                          : Colors.red[800],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text(item.quantity.toString(),
                    style: TextStyle(color: _textColor, fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text(item.price.toStringAsFixed(0),
                    style: TextStyle(color: _textColor, fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text(item.discount.toStringAsFixed(0),
                    style: TextStyle(color: _textColor, fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text(
                  (item.quantity * item.price * (1 - item.discount / 100))
                      .toStringAsFixed(0),
                  style: TextStyle(
                      color: _textColor, fontWeight: FontWeight.bold, fontSize: 14),
                ))),
      ],
    ),
  );

  Widget _buildInputPanel() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 24),
      ],
    ),
    child: Column(
      children: [
        _buildTextField('Challan #', existingInvoice['invoiceId']),
        const SizedBox(height: 16),
        _buildTextField('Company', company),
        const SizedBox(height: 16),
        _buildTextField('Invoice Date', existingInvoice['invoiceDate']),
        const SizedBox(height: 16),
        _buildTextField('Receive Date', existingInvoice['receiveDate']),
        const SizedBox(height: 16),
        _buildTextField('Tax Percentage (%)', existingInvoice['taxPercentage'].toString()),
      ],
    ),
  );

  Widget _buildTextField(String label, String value) => TextFormField(
    controller: TextEditingController(text: value),
    readOnly: true,
    style: TextStyle(color: _textColor, fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      filled: true,
      fillColor: _backgroundColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: TextStyle(color: _secondaryTextColor),
    ),
  );

  Widget _buildSummaryCard() => Container(
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
        _buildSummaryItem('Items', items.length.toString()),
        const Divider(),
        _buildSummaryItem('Subtotal', '${existingInvoice['subtotal'].toStringAsFixed(0)}/-'),
        _buildSummaryItem('Tax', '${existingInvoice['taxAmount'].toStringAsFixed(0)}/-'),
        const Divider(),
        _buildSummaryItem(
          'Total',
          '${existingInvoice['total'].toStringAsFixed(0)}/-',
          valueStyle: TextStyle(
              color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ],
    ),
  );

  Widget _buildSummaryItem(String label, String value, {TextStyle? valueStyle}) => Padding(
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

// Helper Components
class CompanySelectionDialog extends StatefulWidget {
  @override
  _CompanySelectionDialogState createState() => _CompanySelectionDialogState();
}

class _CompanySelectionDialogState extends State<CompanySelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _surfaceColor,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 24,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select Company',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: _textColor)),
            const SizedBox(height: 20),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search companies...',
                filled: true,
                fillColor: _surfaceColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: _secondaryTextColor),
                  onPressed: () => setState(() => _searchController.clear()),
                ),
                prefixIcon: const Icon(Icons.search, color: _secondaryTextColor),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('companies').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();

                  final companies = snapshot.data!.docs.where((doc) {
                    final name = doc['name'].toString().toLowerCase();
                    return name.contains(_searchQuery);
                  }).toList();

                  return ListView.builder(
                    itemCount: companies.length,
                    itemBuilder: (context, index) => ListTile(
                      title: Text(companies[index]['name'],
                          style: const TextStyle(color: _textColor)),
                      onTap: () => Navigator.pop(context, companies[index]['name']),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: _surfaceColor)),
            ),
          ],
        ),
      ),
    );
  }
}

class ItemSelectionDialog extends StatefulWidget {
  final List<Item> items;

  const ItemSelectionDialog({super.key, required this.items});

  @override
  _ItemSelectionDialogState createState() => _ItemSelectionDialogState();
}

class _ItemSelectionDialogState extends State<ItemSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _surfaceColor,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: MediaQuery.of(context).size.width * 0.8,
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 24,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select Item',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: _textColor)),
            const SizedBox(height: 20),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items...',
                filled: true,
                fillColor: _surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                prefixIcon: const Icon(Icons.search, color: _secondaryTextColor),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: _secondaryTextColor),
                  onPressed: () => setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  }),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
            const SizedBox(height: 16),
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: _primaryColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(child: _HeaderCell('Quality')),
                    Expanded(child: _HeaderCell('Item Name')),
                    Expanded(child: _HeaderCell('Covered')),
                    Expanded(child: _HeaderCell('Packaging')),
                    Expanded(child: _HeaderCell('Price')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  if (!item.name.toLowerCase().contains(_searchQuery) &&
                      !item.quality.toLowerCase().contains(_searchQuery)) {
                    return const SizedBox.shrink();
                  }
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, item),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(item.quality,
                                  style: const TextStyle(
                                      color: _textColor, fontSize: 14))),
                          Expanded(
                              child: Text(item.name,
                                  style: const TextStyle(
                                      color: _textColor, fontSize: 14))),
                          Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: item.covered.toLowerCase() == "yes"
                                      ? Colors.green[100]
                                      : Colors.red[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.covered,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: item.covered.toLowerCase() == "yes"
                                        ? Colors.green[800]
                                        : Colors.red[800],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )),
                          Expanded(
                              child: Text(item.packagingUnit,
                                  style: const TextStyle(
                                      color: _textColor, fontSize: 14))),
                          Expanded(
                              child: Text(item.purchasePrice.toStringAsFixed(0),
                                  style: const TextStyle(
                                      color: _textColor, fontSize: 14))),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: _surfaceColor)),
            ),
          ],
        ),
      ),
    );
  }
}