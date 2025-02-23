import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  _InvoiceListScreenState createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Color Scheme
  final Color _primaryColor = const Color(0xFF0D6EFD);
  final Color _textColor = const Color(0xFF2D2D2D);
  final Color _secondaryTextColor = const Color(0xFF4A4A4A);
  final Color _backgroundColor = const Color(0xFFF8F9FA);
  final Color _surfaceColor = Colors.white;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    final day = date.day;
    final month = _getMonthName(date.month);
    final year = date.year;
    return "$day $month $year";
  }

  String _getMonthName(int month) {
    switch (month) {
      case 1: return 'January';
      case 2: return 'February';
      case 3: return 'March';
      case 4: return 'April';
      case 5: return 'May';
      case 6: return 'June';
      case 7: return 'July';
      case 8: return 'August';
      case 9: return 'September';
      case 10: return 'October';
      case 11: return 'November';
      case 12: return 'December';
      default: return '';
    }
  }

  // Add the company selection dialog method
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

  Widget _buildCell(String text) {
    return Text(
      text,
      style: TextStyle(color: _textColor, fontSize: 14),
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
  }

  void _viewInvoice(DocumentSnapshot invoiceDoc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceDetailsScreen(invoiceId: invoiceDoc.id),
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

  // Keep existing _formatDate and _getMonthName methods

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Invoices', style: TextStyle(color: Colors.black)),
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor),
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
          _buildTableHeader(),
          const SizedBox(height: 8),
          Expanded(child: _buildInvoiceList()),
        ],
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
            icon: Icon(Icons.clear, color: _secondaryTextColor),
            onPressed: () => setState(() => _searchController.clear()),
          ),
          prefixIcon: Icon(Icons.search, color: _secondaryTextColor),
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
}

class _HeaderText extends StatelessWidget {
  final String text;

  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// Update CompanySelectionDialog to match QualityPage's dialogs
class CompanySelectionDialog extends StatefulWidget {
  @override
  _CompanySelectionDialogState createState() => _CompanySelectionDialogState();
}

class _CompanySelectionDialogState extends State<CompanySelectionDialog> {
  final Color _surfaceColor = Colors.white;
  final Color _textColor = const Color(0xFF2D2D2D);
  final Color _primaryColor = const Color(0xFF0D6EFD);
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
                backgroundColor: _primaryColor,
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
//page for viewing saved invoices details//

class InvoiceDetailsScreen extends StatefulWidget {
  final String invoiceId;

  const InvoiceDetailsScreen({super.key, required this.invoiceId});

  @override
  _InvoiceDetailsScreenState createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen> {
  Future<DocumentSnapshot>? _invoiceFuture;

  @override
  void initState() {
    super.initState();
    _invoiceFuture = FirebaseFirestore.instance
        .collection('purchaseinvoices')
        .doc(widget.invoiceId)
        .get();
  }

  void _refreshInvoice() {
    setState(() {
      _invoiceFuture = FirebaseFirestore.instance
          .collection('purchaseinvoices')
          .doc(widget.invoiceId)
          .get();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Details'),
        backgroundColor: const Color(0xFF212529),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFE9ECEF),
      body: FutureBuilder<DocumentSnapshot>(
        future: _invoiceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'Invoice not found',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final invoice = snapshot.data!.data() as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF212529),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: const Offset(3, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow('Invoice ID:', invoice['invoiceId']),
                      _infoRow('Company:', invoice['company']),
                      _infoRow('Invoice Date:', invoice['invoiceDate']),
                      _infoRow('Receive Date:', invoice['receiveDate']),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                const SizedBox(height: 10),
                _buildTableHeader(),
                Expanded(
                  child: ListView.builder(
                    itemCount: invoice['items'].length,
                    itemBuilder: (context, index) {
                      final item = invoice['items'][index];
                      return _buildInvoiceRow(index, item);
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                decoration: BoxDecoration(
          color: const Color(0xFF212529),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
          BoxShadow(
          color: Colors.black26,
          blurRadius: 6,
          offset: const Offset(3, 3),
          ),
          ],
          ),
                  child:_infoRow(
                    'Total:',
                    '${invoice['total'].toStringAsFixed(2)}',
                    fontSize: 20,
                    bold: true,
                  ),
                )

              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value, {double fontSize = 16, bool bold = false}) {
    return Container(
       // Set background color
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0), // Adjusted padding for better spacing
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
               // Ensure text remains readable
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
               // Ensure text remains readable
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF212529),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Expanded(
            child: Text(
              'Item Name',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE9ECEF)),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              'Quantity',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE9ECEF)),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              'Price',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE9ECEF)),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              'Total',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE9ECEF)),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              'Actions',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE9ECEF)),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceRow(int index, Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF343A40),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: const Offset(3, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: _styledText(item['name'])),
          Expanded(child: _styledText(item['quantity'].toString())),
          Expanded(child: _styledText('${item['price'].toStringAsFixed(2)}')),
          Expanded(child: _styledText('${item['total'].toStringAsFixed(2)}')),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _actionButton(Icons.edit, Colors.blue, () => _editItem(index, item)),
                const SizedBox(width: 8),
                _actionButton(Icons.delete, Colors.red, () => _deleteItem(index)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _styledText(String text) {
    return Text(
      text,
      style: const TextStyle(color: Color(0xFFE9ECEF), fontSize: 14),
      textAlign: TextAlign.center,
    );
  }

  Widget _actionButton(IconData icon, Color color, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: color),
      onPressed: onPressed,
    );
  }

  Future<void> _editItem(int index, Map<String, dynamic> item) async {
    TextEditingController quantityController = TextEditingController(text: item['quantity'].toString());
    TextEditingController priceController = TextEditingController(text: item['price'].toString());
    TextEditingController discountController = TextEditingController(text: item['discount'].toString());

    bool? saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            TextFormField(
              controller: priceController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Price'),
            ),
            TextFormField(
              controller: discountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Discount (%)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      int quantity = int.tryParse(quantityController.text) ?? item['quantity'];
      double price = double.tryParse(priceController.text) ?? item['price'];
      double discount = double.tryParse(discountController.text) ?? item['discount'];

      DocumentSnapshot invoiceSnapshot = await _invoiceFuture!;
      Map<String, dynamic> invoice = invoiceSnapshot.data() as Map<String, dynamic>;
      List<dynamic> items = List.from(invoice['items']);

      items[index] = {
        ...items[index],
        'quantity': quantity,
        'price': price,
        'discount': discount,
        'total': quantity * price * (1 - discount / 100),
      };

      double total = items.fold(0.0, (sum, item) => sum + (item['total'] as double));

      await FirebaseFirestore.instance.collection('purchaseinvoices').doc(widget.invoiceId).update({
        'items': items,
        'total': total,
      });

      _refreshInvoice();
    }
  }

  Future<void> _deleteItem(int index) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Delete Item?'),
            content: const Text('Are you sure you want to delete this item?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }
}

//page for adding the purchase invoice//


class InvoiceItemsTableHeader extends StatelessWidget {
  const InvoiceItemsTableHeader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF212529),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Expanded(
            flex: 3,
            child: Text(
              'Quality & Item',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFE9ECEF),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              'Packaging',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFE9ECEF),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              'Qty',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFE9ECEF),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              'Price',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFE9ECEF),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              'Discount',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFE9ECEF),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              'Total',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFE9ECEF),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              'Actions',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFE9ECEF),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class InvoiceScreen extends StatefulWidget {
  final String company;
  const InvoiceScreen({super.key, required this.company});

  @override
  _InvoiceScreenState createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  List<InvoiceItem> items = [];
  List<Item> _filteredItems = [];
  double subtotal = 0.0;
  double total = 0.0;
  final TextEditingController _invoiceIdController = TextEditingController();
  final TextEditingController _invoiceDateController = TextEditingController();
  final TextEditingController _receiveDateController = TextEditingController();
  final TextEditingController _taxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _taxController.text = '0.5';
  }

  Future<void> _addItem(Item item) async {
    try {
      final QuerySnapshot qualitySnapshot = await _firestore
          .collection('qualities')
          .where('name', isEqualTo: item.quality)
          .limit(1)
          .get();

      if (qualitySnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quality "${item.quality}" not found')),
        );
        return;
      }

      final qualityData = qualitySnapshot.docs.first.data() as Map<String, dynamic>;
      final double discount = item.covered
          ? (qualityData['covered_discount'] ?? 0.0).toDouble()
          : (qualityData['uncovered_discount'] ?? 0.0).toDouble();

      setState(() {
        items.add(InvoiceItem(
          itemId: item.id,
          name: item.name,
          quality: item.quality,
          packagingUnit: item.packagingUnit,
          quantity: 1,
          price: item.purchasePrice,
          discount: discount,
          isCovered: item.covered,
        ));
      });
      _calculateTotal();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching quality data: $e')),
      );
    }
  }

  void _calculateTotal() {
    subtotal = items.fold(0.0, (sum, item) {
      final itemTotal = item.quantity * item.price * (1 - item.discount / 100);
      return sum + itemTotal;
    });

    final taxPercentage = double.tryParse(_taxController.text) ?? 0.0;
    final taxAmount = subtotal * (taxPercentage / 100);
    total = subtotal + taxAmount;

    setState(() {});
  }

  Future<void> _submitInvoice() async {
    if (!_formKey.currentState!.validate()) return;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    final invoice = {
      'invoiceId': _invoiceIdController.text,
      'company': widget.company,
      'invoiceDate': _invoiceDateController.text,
      'receiveDate': _receiveDateController.text,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'taxPercentage': double.parse(_taxController.text),
      'taxAmount': total - subtotal,
      'total': total,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      final docRef = await _firestore.collection('purchaseinvoices').add(invoice);
      for (var item in items) {
        await _firestore.collection('items').doc(item.itemId).update({
          'stockQuantity': FieldValue.increment(item.quantity),
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice saved successfully')),
      );
      _resetForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving invoice: $e')),
      );
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      items.clear();
      subtotal = 0.0;
      total = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9ECEF),
      appBar: AppBar(
        title: const Text('Purchase Invoice', style: TextStyle(color: Color(0xFFE9ECEF))),
        backgroundColor: const Color(0xFF212529),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFFE9ECEF)),
            onPressed: _showAddItemDialog,
            tooltip: 'Add Items',
          ),
        ],
      ),
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
    );
  }

  Widget _buildInvoiceHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF343A40),
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
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE9ECEF),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  controller: _invoiceIdController,
                  label: 'Invoice/Chalan #',
                  validator: (value) => value!.isEmpty ? 'Required field' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFormField(
                  controller: _invoiceDateController,
                  label: 'Invoice Date',
                  onTap: () => _selectDate(_invoiceDateController),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFormField(
                  controller: _receiveDateController,
                  label: 'Receive Date',
                  onTap: () => _selectDate(_receiveDateController),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFormField(
                  controller: _taxController,
                  label: 'Tax Percentage (%)',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required field';
                    if (double.tryParse(value) == null) return 'Invalid number';
                    return null;
                  },
                  onChanged: (value) => _calculateTotal(),
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
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    void Function()? onTap,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Color(0xFFE9ECEF)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFFADB5BD)),
        filled: true,
        fillColor: const Color(0xFF495057),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixText: label.contains('Percentage') ? '%' : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
      keyboardType: keyboardType,
      readOnly: onTap != null,
      onTap: onTap,
      validator: validator,
      onChanged: onChanged,
    );
  }

  Widget _buildItemsList() {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No items added',
          style: TextStyle(color: Color(0xFF212529), fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildInvoiceItemRow(items[index]),
    );
  }

  Widget _buildInvoiceItemRow(InvoiceItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF343A40),
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
            child: Text(
              '${item.quality}: ${item.name}',
              style: const TextStyle(color: Color(0xFFE9ECEF), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              item.packagingUnit,
              style: const TextStyle(color: Color(0xFFE9ECEF), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: TextFormField(
              initialValue: item.quantity.toString(),
              style: const TextStyle(color: Color(0xFFE9ECEF)),
              textAlign: TextAlign.center,
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
              style: const TextStyle(color: Color(0xFFE9ECEF)),
              textAlign: TextAlign.center,
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
              style: const TextStyle(color: Color(0xFFE9ECEF), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () {
                setState(() {
                  items.remove(item);
                  _calculateTotal();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFF495057),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    );
  }

  Widget _buildTotalSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF343A40),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(color: Color(0xFF495057)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTotalRow('Subtotal:', subtotal.toStringAsFixed(0)),
                _buildTotalRow('Tax:', (total - subtotal).toStringAsFixed(0)),
                Text(
                  'TOTAL: ${total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Color(0xFFE9ECEF),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                ElevatedButton(
                  onPressed: _submitInvoice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF212529),
                    foregroundColor: const Color(0xFFE9ECEF),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24.0),
                    ),
                  ),
                  child: const Text('SUBMIT', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE9ECEF),
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFE9ECEF),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
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

  Future<void> _showAddItemDialog() async {
    final itemsSnapshot = await _firestore.collection('items').get();
    List<Item> itemList = itemsSnapshot.docs
        .map((doc) => Item.fromMap(doc.data(), doc.id))
        .toList();

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFE9ECEF),
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: StatefulBuilder(
            builder: (context, setState) {
              String searchQuery = '';
              List<Item> filteredItems = itemList;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value.toLowerCase();
                          filteredItems = itemList.where((item) {
                            return item.name.toLowerCase().contains(searchQuery) ||
                                item.quality.toLowerCase().contains(searchQuery);
                          }).toList();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search Items',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(32),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF212529)),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF212529)),
                          onPressed: () => setState(() => searchQuery = ''),
                        )
                            : null,
                      ),
                    ),
                  ),
                  _buildDialogTableHeader(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) => _buildDialogItemRow(filteredItems[index]),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDialogTableHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF212529),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Row(
          children: [
            _buildHeaderCell('Item Name', flex: 2),
            _buildHeaderCell('Quality'),
            _buildHeaderCell('Price'),
            _buildHeaderCell('Dimensions'),
            _buildHeaderCell('Packaging'),
            _buildHeaderCell('Status', flex: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFE9ECEF),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDialogItemRow(Item item) {
    final dimensions = '${item.length}x${item.width}x${item.height}';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF343A40),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(3, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            Navigator.pop(context);
            await _addItem(item);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDialogCell(item.name, flex: 2),
                _buildDialogCell(item.quality),
                _buildDialogCell(item.purchasePrice.toStringAsFixed(0)),
                _buildDialogCell(dimensions),
                _buildDialogCell(item.packagingUnit),
                _buildDialogCell(
                  item.covered ? 'Covered' : 'Uncovered',
                  color: item.covered ? Colors.green : Colors.red,
                  flex: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogCell(String text, {int flex = 1, Color color = const Color(0xFFE9ECEF)}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class InvoiceItem {
  final String itemId;
  final String name;
  final String quality;
  final String packagingUnit;
  int quantity;
  final double price;
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
  final int length;
  final int width;
  final int height;

  Item({
    required this.id,
    required this.name,
    required this.quality,
    required this.packagingUnit,
    required this.purchasePrice,
    required this.covered,
    required this.length,
    required this.width,
    required this.height,
  });

  factory Item.fromMap(Map<String, dynamic> map, String id) => Item(
    id: id,
    name: map['itemName'] ?? 'Unnamed Item',
    quality: map['qualityName'] ?? 'N/A',
    packagingUnit: map['packagingUnit'] ?? 'Unit',
    purchasePrice: (map['purchasePrice'] ?? 0.0).toDouble(),
    covered: map['covered'] == "Covered",
    length: (map['length'] ?? 0).toInt(),
    width: (map['width'] ?? 0).toInt(),
    height: (map['height'] ?? 0).toInt(),
  );
}