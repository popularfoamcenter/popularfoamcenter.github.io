import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ======================
// Invoice List Screen
// ======================
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Color Scheme
const Color _primaryColor = Color(0xFF0D6EFD);
const Color _textColor = Color(0xFF2D2D2D);
const Color _secondaryTextColor = Color(0xFF4A4A4A);
const Color _backgroundColor = Color(0xFFF8F9FA);
const Color _surfaceColor = Colors.white;

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
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 24, offset: const Offset(0, 8))],
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
      await FirebaseFirestore.instance.collection('purchaseinvoices').doc(invoiceDoc.id).delete();
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
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: _textColor)));
        }

        final invoices = snapshot.data?.docs.where((doc) {
          final company = doc['company'].toString().toLowerCase();
          return company.contains(_searchQuery);
        }).toList();

        if (invoices == null || invoices.isEmpty) {
          return Center(child: Text('No invoices found', style: const TextStyle(color: _textColor)));
        }

        return Column(
          children: [
            _buildDesktopHeader(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 16),
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
                  stream: FirebaseFirestore.instance.collection('purchaseinvoices').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: _primaryColor));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: _textColor)));
                    }

                    final invoices = snapshot.data?.docs.where((doc) {
                      final company = doc['company'].toString().toLowerCase();
                      return company.contains(_searchQuery);
                    }).toList();

                    if (invoices == null || invoices.isEmpty) {
                      return Center(child: Text('No invoices found', style: const TextStyle(color: _textColor)));
                    }

                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 16),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
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
            Expanded(child: _DataCell(invoice['invoiceId'])),
            Expanded(child: _DataCell(invoice['company'])),
            Expanded(child: _DataCell(total)),
            Expanded(child: _DataCell(invoiceDate)),
            Expanded(child: _DataCell(receiveDate)),
            Expanded(child: _ActionCell(
              invoiceDoc,
              150,
              onView: _viewInvoice,
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
            _DataCell(invoice['invoiceId'], 150),
            _DataCell(invoice['company'], 200),
            _DataCell(total, 100),
            _DataCell(invoiceDate, 150),
            _DataCell(receiveDate, 150),
            _ActionCell(
              invoiceDoc,
              150,
              onView: _viewInvoice,
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
        label: const Text('Add Invoice', style: TextStyle(fontSize: 14, color: _surfaceColor)),
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
  final Function(DocumentSnapshot) onDelete;

  const _ActionCell(
      this.invoiceDoc,
      this.width, {
        required this.onView,
        required this.onDelete,
      });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.visibility, color: _primaryColor, size: 20),
            onPressed: () => onView(invoiceDoc),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            onPressed: () => onDelete(invoiceDoc),
          ),
        ],
      ),
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

  // Modern blue color palette
  final Color primaryBlue = Color(0xFF1A73E8);
  final Color lightBlue = Color(0xFFE8F0FE);
  final Color darkBlue = Color(0xFF0D47A1);
  final Color white = Colors.white;
  final Color lightGrey = Color(0xFFF5F7FA);
  final Color textColor = Color(0xFF202124);
  final Color secondaryTextColor = Color(0xFF5F6368);

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
    final discount = (item.covered == "Covered")
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
        isCovered: item.covered == "Covered", // Check if string equals "Covered"
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
        SnackBar(
          content: Text('Please add at least one item'),
          backgroundColor: darkBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
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
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: white),
              SizedBox(width: 12),
              Text('Invoice saved successfully'),
            ],
          ),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      if (widget.invoiceId != null) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving invoice: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryBlue,
              onPrimary: white,
              onSurface: textColor,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primaryBlue,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.invoiceId != null ? 'Edit Invoice' : 'New Invoice',
          style: TextStyle(color: white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: primaryBlue,
        centerTitle: true,
        elevation: 0,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      backgroundColor: lightGrey,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInvoiceHeader(),
                const SizedBox(height: 24),
                _buildInvoiceItemsHeader(),
                const SizedBox(height: 12),
                Expanded(child: _buildItemsList()),
                _buildTotalSection(),
              ],
            ),
          ),
        ),
      ),

    );
  }

  Widget _buildInvoiceHeader() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
              color: darkBlue,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Invoice/Chalan #
              Expanded(
                child: _buildFormField(
                  controller: _invoiceIdController,
                  label: 'Invoice/Chalan #',
                  prefixIcon: Icons.receipt_rounded,
                  validator: (value) => value!.isEmpty ? 'Required field' : null,
                ),
              ),
              const SizedBox(width: 12),
              // Invoice Date
              Expanded(
                child: _buildFormField(
                  controller: _invoiceDateController,
                  label: 'Invoice Date',
                  prefixIcon: Icons.calendar_today_rounded,
                  onTap: () => _selectDate(_invoiceDateController),
                ),
              ),
              const SizedBox(width: 12),
              // Receive Date
              Expanded(
                child: _buildFormField(
                  controller: _receiveDateController,
                  label: 'Receive Date',
                  prefixIcon: Icons.event_available_rounded,
                  onTap: () => _selectDate(_receiveDateController),
                ),
              ),
              const SizedBox(width: 12),
              // Tax Percentage
              Expanded(
                child: _buildFormField(
                  controller: _taxController,
                  label: 'Tax Percentage (%)',
                  prefixIcon: Icons.percent_rounded,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required field';
                    if (double.tryParse(value) == null) return 'Invalid number';
                    return null;
                  },
                  onChanged: (value) => _calculateTotal(),
                ),
              ),
              const SizedBox(width: 12),
              // Add Item Button
              SizedBox(
                height: 56, // Match the height of the input fields
                child: ElevatedButton.icon(
                  onPressed: _showAddItemDialog,
                  icon: const Icon(Icons.add, size: 20, color: Colors.white),
                  label: const Text('Add Item', style: TextStyle(fontSize: 14, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function()? onTap,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: secondaryTextColor),
        filled: true,
        fillColor: white,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: primaryBlue) : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red[300]!),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        suffixText: label.contains('Percentage') ? '%' : null,
        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      keyboardType: keyboardType,
      readOnly: onTap != null,
      onTap: onTap,
      validator: validator,
      onChanged: onChanged,
    );
  }

  Widget _buildInvoiceItemsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D6EFD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Quality Name',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Item Name',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Qty',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              'Discount %',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              'Total',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 50, child: _HeaderText('', textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: primaryBlue.withOpacity(0.3),
            ),
            SizedBox(height: 16),
            Text(
              'No items added',
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Click the + button to add items',
              style: TextStyle(
                color: secondaryTextColor.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) => _buildInvoiceItemRow(_items[index], index),
      padding: EdgeInsets.symmetric(vertical: 8),
    );
  }

  Widget _buildInvoiceItemRow(InvoiceItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Quality Name
            Expanded(
              flex: 2,
              child: Text(
                item.quality,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
            // Item Name
            Expanded(
              flex: 3,
              child: Text(
                item.name,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            // Quantity
            Expanded(
              child: Container(
                height: 40,
                child: TextFormField(
                  initialValue: item.quantity.toString(),
                  style: TextStyle(color: Colors.black87),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
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
            ),
            // Discount
            Expanded(
              child: Container(
                height: 40,
                child: TextFormField(
                  initialValue: item.discount.toStringAsFixed(0),
                  style: TextStyle(color: Colors.black87),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
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
            ),
            // Total
            Expanded(
              child: Text(
                '${(item.quantity * item.price * (1 - item.discount / 100)).toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Color(0xFF0D6EFD),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Delete Button
            SizedBox(
              width: 50,
              child: IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: Colors.red[400]),
                onPressed: () {
                  setState(() {
                    _items.remove(item);
                    _calculateTotal();
                  });
                },
                tooltip: 'Remove Item',
                splashRadius: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: lightBlue.withOpacity(0.3),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: lightBlue),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primaryBlue),
      ),
      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      isDense: true,
    );
  }

  Widget _buildTotalSection() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Subtotal, Tax, and Total
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Subtotal
                _buildSummaryItem(
                  icon: Icons.receipt,
                  label: 'Subtotal',
                  value: '${_subtotal.toStringAsFixed(0)}',
                  color: const Color(0xFF4CAF50), // Green
                ),
                // Tax
                _buildSummaryItem(
                  icon: Icons.percent,
                  label: 'Tax',
                  value: '${(_total - _subtotal).toStringAsFixed(0)}',
                  color: const Color(0xFF2196F3), // Blue
                ),
                // Total
                _buildSummaryItem(
                  icon: Icons.attach_money,
                  label: 'Total',
                  value: '${_total.toStringAsFixed(0)}',
                  color: const Color(0xFFF44336), // Red
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Save Invoice Button
          SizedBox(
            height: 56, // Match the height of the summary items
            child: ElevatedButton.icon(
              onPressed: _submitInvoice,
              icon: const Icon(Icons.save, size: 20, color: Colors.white),
              label: const Text('Save Invoice', style: TextStyle(fontSize: 14, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        // Icon
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        // Label and Value
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
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
              color: isTotal ? darkBlue : secondaryTextColor,
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              color: isTotal ? primaryBlue : textColor,
              fontSize: isTotal ? 20 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
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
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: primaryBlue,
            onPrimary: white,
            secondary: lightBlue,
            onSecondary: primaryBlue,
          ),
        ),
        child: ItemSelectionDialog(items: items),
      ),
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
class _HeaderText extends StatelessWidget {
  final String text;
  final TextAlign textAlign;

  const _HeaderText(this.text, {this.textAlign = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      textAlign: textAlign,
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

            // Header Row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D6EFD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Quality Name',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Item Name',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Packaging',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Price',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Status',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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
                    onTap: () => Navigator.pop(context, item),
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
                          // Quality Name
                          Expanded(
                            flex: 2,
                            child: Text(
                              item.quality,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          // Item Name
                          Expanded(
                            flex: 3,
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          // Packaging
                          Expanded(
                            flex: 1,
                            child: Text(
                              item.packagingUnit,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                          // Price
                          Expanded(
                            flex: 1,
                            child: Text(
                              '${item.purchasePrice.toStringAsFixed(0)}',
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
                                color: item.covered == "Covered" ? Colors.green[100] : Colors.red[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item.covered,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: item.covered == "Covered" ? Colors.green[800] : Colors.red[800],
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
  final String covered; // Changed from bool to String

  Item({
    required this.id,
    required this.name,
    required this.quality,
    required this.packagingUnit,
    required this.purchasePrice,
    required this.covered, // Updated to String
  });

  factory Item.fromMap(Map<String, dynamic> map, String id) => Item(
    id: id,
    name: map['itemName'] ?? 'Unknown Item',
    quality: map['qualityName'] ?? 'N/A',
    packagingUnit: map['packagingUnit'] ?? 'Unit',
    purchasePrice: (map['purchasePrice'] ?? 0.0).toDouble(),
    covered: map['covered'] ?? "Uncovered", // Directly fetch the string value
  );
}