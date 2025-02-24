import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
  final Color _primaryColor = const Color(0xFF0D6EFD);
  final Color _textColor = const Color(0xFF2D2D2D);
  final Color _surfaceColor = Colors.white;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return DateFormat('dd MMMM yyyy').format(date);
  }

  void _viewInvoice(DocumentSnapshot invoiceDoc) {
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
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice?'),
        content: const Text('Are you sure you want to delete this invoice?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: _textColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            child: Text('Delete', style: TextStyle(color: _surfaceColor)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('purchaseinvoices').doc(invoiceDoc.id).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Invoices', style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor),
      ),
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
          _buildTableHeader(),
          Expanded(child: _buildInvoiceList()),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
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
            Expanded(child: _HeaderText('Invoice ID')),
            Expanded(child: _HeaderText('Company')),
            Expanded(child: _HeaderText('Total')),
            Expanded(child: _HeaderText('Invoice Date')),
            Expanded(child: _HeaderText('Receive Date')),
            Expanded(child: _HeaderText('Actions')),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('purchaseinvoices').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _primaryColor));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No invoices found', style: TextStyle(color: _textColor)));
        }

        final invoices = snapshot.data!.docs.where((doc) {
          final company = doc['company'].toString().toLowerCase();
          return company.contains(_searchQuery);
        }).toList();

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 16),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: invoices.length,
          itemBuilder: (context, index) => _buildInvoiceRow(invoices[index]),
        );
      },
    );
  }

  Widget _buildInvoiceRow(DocumentSnapshot invoiceDoc) {
    final invoice = invoiceDoc.data() as Map<String, dynamic>;
    final total = invoice['total'].toStringAsFixed(0);
    final invoiceDate = _formatDate(invoice['invoiceDate']);
    final receiveDate = _formatDate(invoice['receiveDate']);

    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(child: _buildCell(invoice['invoiceId'])),
            Expanded(child: _buildCell(invoice['company'])),
            Expanded(child: _buildCell(total)),
            Expanded(child: _buildCell(invoiceDate)),
            Expanded(child: _buildCell(receiveDate)),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.visibility, color: _primaryColor, size: 20),
                    onPressed: () => _viewInvoice(invoiceDoc),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _deleteInvoice(invoiceDoc),
                  ),
                ],
              ),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search invoices...',
          filled: true,
          fillColor: _surfaceColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          suffixIcon: IconButton(
            icon: Icon(Icons.clear, color: const Color(0xFF4A4A4A)),
            onPressed: () => setState(() => _searchController.clear()),
          ),
          prefixIcon: Icon(Icons.search, color: const Color(0xFF4A4A4A)),
        ),
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
      ),
    );
  }

  Widget _buildAddButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        icon: Icon(Icons.add, size: 20, color: _surfaceColor),
        label: Text('Add Invoice', style: TextStyle(fontSize: 14, color: _surfaceColor)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildCell(String text) {
    return Text(
      text,
      style: TextStyle(color: _textColor, fontSize: 14),
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
  }
}

// ======================
// Invoice Screen
// ======================
class InvoiceScreen extends StatefulWidget {
  final String company;
  final String? invoiceId;
  final Map<String, dynamic>? existingInvoice;
  const InvoiceScreen({super.key, required this.company, this.invoiceId, this.existingInvoice});

  @override
  _InvoiceScreenState createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<InvoiceItem> _items = [];
  List<InvoiceItem> _originalItems = [];
  double _subtotal = 0.0;
  double _total = 0.0;
  final TextEditingController _invoiceIdController = TextEditingController();
  final TextEditingController _invoiceDateController = TextEditingController();
  final TextEditingController _receiveDateController = TextEditingController();
  final TextEditingController _taxController = TextEditingController(text: '0.5');

  @override
  void initState() {
    super.initState();
    if (widget.existingInvoice != null) {
      _initializeExistingInvoice();
    }
  }

  void _initializeExistingInvoice() {
    final invoice = widget.existingInvoice!;
    _invoiceIdController.text = invoice['invoiceId'];
    _invoiceDateController.text = invoice['invoiceDate'];
    _receiveDateController.text = invoice['receiveDate'];
    _taxController.text = invoice['taxPercentage'].toString();

    _originalItems = (invoice['items'] as List).map((item) => InvoiceItem(
      itemId: item['itemId'],
      name: item['name'],
      quality: item['quality'],
      packagingUnit: item['packagingUnit'],
      quantity: item['quantity'],
      price: item['price'],
      discount: item['discount'],
      isCovered: item['isCovered'],
    )).toList();

    _items.addAll(_originalItems);
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
    final discount = item.covered
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
        isCovered: item.covered,
      ));
      _calculateTotal();
    });
  }

  void _calculateTotal() {
    _subtotal = _items.fold(0.0, (sum, item) => sum + (item.quantity * item.price * (1 - item.discount / 100)));
    final tax = _subtotal * (double.parse(_taxController.text) / 100);
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
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.invoiceId != null) {
        await _updateStockQuantities();
        await _firestore.collection('purchaseinvoices').doc(widget.invoiceId).update(invoiceData);
      } else {
        await _firestore.collection('purchaseinvoices').add(invoiceData);
        await _updateStockQuantities();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice saved successfully')),
      );
      if (widget.invoiceId != null) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving invoice: $e')),
      );
    }
  }

  Future<void> _updateStockQuantities() async {
    if (widget.invoiceId != null) {
      for (final item in _originalItems) {
        await _firestore.collection('items').doc(item.itemId).update({
          'stockQuantity': FieldValue.increment(-item.quantity),
        });
      }
    }

    for (final item in _items) {
      await _firestore.collection('items').doc(item.itemId).update({
        'stockQuantity': FieldValue.increment(item.quantity),
      });
    }
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.invoiceId != null ? 'Edit Invoice' : 'New Invoice',
            style: TextStyle(color: Color(0xFFE9ECEF))),
        backgroundColor: Color(0xFF212529),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: Color(0xFFE9ECEF)),
            onPressed: _submitInvoice,
          ),
        ],
      ),
      backgroundColor: Color(0xFFE9ECEF),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInvoiceHeader(),
              const SizedBox(height: 20),
              const InvoiceItemsTableHeader(),
              const SizedBox(height: 10),
              Expanded(child: _buildItemsList()),
              _buildTotalSection(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFF0D6EFD),
        child: Icon(Icons.add, color: Colors.white),
        onPressed: _showAddItemDialog,
      ),
    );
  }

  Widget _buildInvoiceHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Color(0xFF343A40),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(3, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Company: ${widget.company}',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE9ECEF)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildFormField(
                controller: _invoiceIdController,
                label: 'Invoice/Chalan #',
                validator: (value) => value!.isEmpty ? 'Required field' : null,
              )),
              const SizedBox(width: 10),
              Expanded(child: _buildFormField(
                controller: _invoiceDateController,
                label: 'Invoice Date',
                onTap: () => _selectDate(_invoiceDateController),
              )),
              const SizedBox(width: 10),
              Expanded(child: _buildFormField(
                controller: _receiveDateController,
                label: 'Receive Date',
                onTap: () => _selectDate(_receiveDateController),
              )),
              const SizedBox(width: 10),
              Expanded(child: _buildFormField(
                controller: _taxController,
                label: 'Tax Percentage (%)',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required field';
                  if (double.tryParse(value) == null) return 'Invalid number';
                  return null;
                },
                onChanged: (value) => _calculateTotal(),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function()? onTap,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: Color(0xFFE9ECEF)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Color(0xFFADB5BD)),
        filled: true,
        fillColor: Color(0xFF495057),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixText: label.contains('Percentage') ? '%' : null,
        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
      keyboardType: keyboardType,
      readOnly: onTap != null,
      onTap: onTap,
      validator: validator,
      onChanged: onChanged,
    );
  }

  Widget _buildItemsList() {
    if (_items.isEmpty) {
      return Center(
        child: Text(
          'No items added',
          style: TextStyle(color: Color(0xFF212529), fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) => _buildInvoiceItemRow(_items[index]),
    );
  }

  Widget _buildInvoiceItemRow(InvoiceItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Color(0xFF343A40),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(3, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 3,
            child: Text('${item.quality}: ${item.name}',
              style: TextStyle(color: Color(0xFFE9ECEF)),
            ),
          ),
          Expanded(
            child: TextFormField(
              initialValue: item.quantity.toString(),
              style: TextStyle(color: Color(0xFFE9ECEF)),
              keyboardType: TextInputType.number,
              decoration: _inputDecoration(),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  setState(() {
                    item.quantity = int.parse(value);
                    _calculateTotal();
                  });
                }
              },
            ),
          ),
          Expanded(
            child: TextFormField(
              initialValue: item.discount.toStringAsFixed(0),
              style: TextStyle(color: Color(0xFFE9ECEF)),
              keyboardType: TextInputType.number,
              decoration: _inputDecoration(),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  setState(() {
                    item.discount = double.parse(value);
                    _calculateTotal();
                  });
                }
              },
            ),
          ),
          Expanded(
            child: Text(
              (item.quantity * item.price * (1 - item.discount / 100)).toStringAsFixed(0),
              style: TextStyle(color: Color(0xFFE9ECEF)),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: () => setState(() => _items.remove(item)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Color(0xFF495057),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    );
  }

  Widget _buildTotalSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Color(0xFF343A40),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildTotalRow('Subtotal:', _subtotal.toStringAsFixed(0)),
          _buildTotalRow('Tax:', (_total - _subtotal).toStringAsFixed(0)),
          Divider(color: Color(0xFF495057)),
          _buildTotalRow('TOTAL:', _total.toStringAsFixed(0), isTotal: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Color(0xFFE9ECEF),
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '\$$value',
            style: TextStyle(
              color: Color(0xFFE9ECEF),
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddItemDialog() async {
    final itemsSnapshot = await _firestore.collection('items').get();
    final items = itemsSnapshot.docs.map((doc) => Item.fromMap(doc.data(), doc.id)).toList();

    final selectedItem = await showDialog<Item>(
      context: context,
      builder: (context) => ItemSelectionDialog(items: items),
    );

    if (selectedItem != null) {
      await _addItem(selectedItem);
      _calculateTotal(); // Refresh the total after adding
    }
  }
}

// ======================
// Helper Components
// ======================
class InvoiceItemsTableHeader extends StatelessWidget {
  const InvoiceItemsTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Color(0xFF212529),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: _HeaderText('Quality & Item')),
          Expanded(child: _HeaderText('Packaging')),
          Expanded(child: _HeaderText('Qty')),
          Expanded(child: _HeaderText('Discount %')),
          Expanded(child: _HeaderText('Total')),
          Expanded(child: _HeaderText('Actions')),
        ],
      ),
    );
  }
}

class CompanySelectionDialog extends StatefulWidget {
  @override
  _CompanySelectionDialogState createState() => _CompanySelectionDialogState();
}

class _CompanySelectionDialogState extends State<CompanySelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Color _surfaceColor = Colors.white;
  final Color _textColor = const Color(0xFF2D2D2D);

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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select Company',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textColor)),
            const SizedBox(height: 20),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search companies...',
                filled: true,
                fillColor: _surfaceColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear, color: _textColor.withOpacity(0.5)),
                  onPressed: () => setState(() => _searchController.clear()),
                ),
                prefixIcon: Icon(Icons.search, color: _textColor.withOpacity(0.5)),
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
                      title: Text(companies[index]['name'], style: TextStyle(color: _textColor)),
                      onTap: () => Navigator.pop(context, companies[index]['name']),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6EFD),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: _surfaceColor)),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================
// Item Selection Dialog (Updated)
// ======================
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
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: MediaQuery.of(context).size.width * 0.8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF4A4A4A)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF4A4A4A)),
                  onPressed: () => setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  }),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
            const SizedBox(height: 16),

            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D6EFD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text('Item Details',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text('Packaging',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text('Price',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text('Status',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Items List
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  if (!item.name.toLowerCase().contains(_searchQuery) &&
                      !item.quality.toLowerCase().contains(_searchQuery)) {
                    return const SizedBox.shrink();
                  }

                  return InkWell(
                    onTap: () => Navigator.pop(context, item), // Fix here
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Quality and Item Name
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.quality,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Packaging
                          Expanded(
                            flex: 1,
                            child: Text(item.packagingUnit,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[700],
                              ),
                            ),
                          ),

                          // Price
                          Expanded(
                            flex: 1,
                            child: Text('\$${item.purchasePrice.toStringAsFixed(0)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF0D6EFD),
                              ),
                            ),
                          ),

                          // Status
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: item.covered ? Colors.green[100] : Colors.red[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item.covered ? 'Covered' : 'Uncovered',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: item.covered ? Colors.green[800] : Colors.red[800],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _HeaderText extends StatelessWidget {
  final String text;
  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
      textAlign: TextAlign.center,
    );
  }
}

// ======================
// Data Models
// ======================
class InvoiceItem {
  final String itemId;
  final String name;
  final String quality;
  final String packagingUnit;
  int quantity;
  double price;
  double discount;
  final bool isCovered;

  InvoiceItem({
    required this.itemId,
    required this.name,
    required this.quality,
    required this.packagingUnit,
    required this.quantity,
    required this.price,
    required this.discount,
    required this.isCovered,
  });

  Map<String, dynamic> toMap() => {
    'itemId': itemId,
    'name': name,
    'quality': quality,
    'packagingUnit': packagingUnit,
    'quantity': quantity,
    'price': price,
    'discount': discount,
    'isCovered': isCovered,
    'total': quantity * price * (1 - discount / 100),
  };
}

class Item {
  final String id;
  final String name;
  final String quality;
  final String packagingUnit;
  final double purchasePrice;
  final bool covered;

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
    covered: (map['covered'] ?? "Uncovered") == "Covered",
  );
}
