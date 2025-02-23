import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Color Scheme
const Color _primaryColor = Color(0xFF0D6EFD);
const Color _textColor = Color(0xFF2D2D2D);
const Color _secondaryTextColor = Color(0xFF4A4A4A);
const Color _backgroundColor = Color(0xFFF8F9FA);
const Color _surfaceColor = Colors.white;

class PurchaseOrdersPage extends StatefulWidget {
  @override
  _PurchaseOrdersPageState createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildTableHeader() {
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(child: _HeaderText('Company')),
            Expanded(child: _HeaderText('Vehicle')),
            Expanded(child: _HeaderText('Date')),
            Expanded(child: _HeaderText('Items')),
            Expanded(child: _HeaderText('Total')),
            Expanded(child: _HeaderText('Actions')),
          ],
        ),
      ),
    );
  }

  Future<void> _showCompanyVehicleDialog(BuildContext context) async {
    String? selectedCompany;
    String? selectedVehicle;
    int? selectedVehicleSize;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: _surfaceColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select Company & Vehicle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('companies').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();
                      return DropdownButtonFormField<String>(
                        decoration: _inputDecoration('Company'),
                        dropdownColor: _surfaceColor,
                        items: snapshot.data!.docs.map((doc) {
                          return DropdownMenuItem<String>(
                            value: doc['name'],
                            child: Text(doc['name'], style: const TextStyle(color: _textColor)),
                          );
                        }).toList(),
                        onChanged: (value) => selectedCompany = value,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('vehicles').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();
                      return DropdownButtonFormField<String>(
                        decoration: _inputDecoration('Vehicle'),
                        dropdownColor: _surfaceColor,
                        items: snapshot.data!.docs.map((doc) {
                          return DropdownMenuItem<String>(
                            value: doc['name'],
                            child: Text(doc['name'], style: const TextStyle(color: _textColor)),
                            onTap: () => selectedVehicleSize = doc['size'],
                          );
                        }).toList(),
                        onChanged: (value) => selectedVehicle = value,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(color: _secondaryTextColor)),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        onPressed: () {
                          if (selectedCompany != null && selectedVehicle != null) {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddPurchaseItemsPage(
                                  companyName: selectedCompany!,
                                  vehicleName: selectedVehicle!,
                                  vehicleSize: selectedVehicleSize!,
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text('Proceed', style: TextStyle(color: _surfaceColor)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteOrder(String id) async {
    await FirebaseFirestore.instance.collection('purchase_orders').doc(id).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order deleted successfully!')),
    );
  }

  Widget _buildOrderRow(DocumentSnapshot order) {
    final data = order.data() as Map<String, dynamic>;
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
            Expanded(child: _buildRowText(data['company_name'])),
            Expanded(child: _buildRowText(data['vehicle_name'])),
            Expanded(child: _buildRowText(data['order_date'])),
            Expanded(child: _buildRowText(data['total_quantity'].toString())),
            Expanded(child: _buildRowText(data['total_after_tax'].toStringAsFixed(0))),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility, color: _primaryColor, size: 20),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ViewPurchaseOrderPage(orderId: order.id)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _deleteOrder(order.id),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Orders', style: TextStyle(color: _textColor)),
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
          _buildTableHeader(),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('purchase_orders').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: _primaryColor));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: _textColor)));
                }

                final orders = snapshot.data?.docs.where((doc) {
                  final companyName = doc['company_name'].toString().toLowerCase();
                  return companyName.contains(_searchQuery);
                }).toList();

                if (orders == null || orders.isEmpty) {
                  return Center(child: Text('No orders found', style: const TextStyle(color: _textColor)));
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 16),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: orders.length,
                  itemBuilder: (context, index) => _buildOrderRow(orders[index]),
                );
              },
            ),
          ),
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
          hintText: 'Search orders...',
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
        label: const Text('Add Order', style: TextStyle(fontSize: 14, color: _surfaceColor)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        onPressed: () => _showCompanyVehicleDialog(context),
      ),
    );
  }

  Widget _buildRowText(String text) {
    return Text(
      text,
      style: const TextStyle(color: _textColor, fontSize: 14),
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _secondaryTextColor),
      filled: true,
      fillColor: _surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryColor),
      ),
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
        ),
      ),
    );
  }
}
class ViewPurchaseOrderPage extends StatefulWidget {
  final String orderId;

  const ViewPurchaseOrderPage({super.key, required this.orderId});

  @override
  _ViewPurchaseOrderPageState createState() => _ViewPurchaseOrderPageState();
}

class _ViewPurchaseOrderPageState extends State<ViewPurchaseOrderPage> {
  final TextEditingController _taxController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  double _subtotal = 0.0;
  double _taxAmount = 0.0;
  double _total = 0.0;
  DocumentSnapshot? _orderSnapshot;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('purchase_orders')
        .doc(widget.orderId)
        .get();

    if (snapshot.exists) {
      setState(() {
        _orderSnapshot = snapshot;
        _items = List<Map<String, dynamic>>.from(snapshot['items']);
        _taxController.text = snapshot['tax_percentage'].toString();
        _calculateTotal();
      });
    }
  }

  void _calculateTotal() {
    _subtotal = _items.fold(0.0, (sum, item) => sum + (item['total'] as num).toDouble());
    final taxPercentage = double.tryParse(_taxController.text) ?? 0.0;
    _taxAmount = _subtotal * (taxPercentage / 100);
    _total = _subtotal + _taxAmount;
  }

  Future<void> _saveChanges() async {
    try {
      await FirebaseFirestore.instance
          .collection('purchase_orders')
          .doc(widget.orderId)
          .update({
        'items': _items,
        'tax_percentage': double.parse(_taxController.text),
        'subtotal': _subtotal,
        'tax_amount': _taxAmount,
        'total_after_tax': _total,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating order: $e')),
      );
    }
  }

  Widget _buildEditableField(
      Map<String, dynamic> item,
      String field,
      String suffix,
      ) {
    final controller = TextEditingController(
      text: item[field].toString(),
    );

    return SizedBox(
      width: 80,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Color(0xFFE9ECEF), fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: const Color(0xFF495057),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
          suffixText: suffix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        onChanged: (value) {
          final newValue = double.tryParse(value) ?? item[field];
          setState(() {
            item[field] = newValue;
            item['total'] = item['quantity'] * item['price'] * (1 - item['discount'] / 100);
            _calculateTotal();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_orderSnapshot == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final order = _orderSnapshot!.data() as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details', style: TextStyle(color: Color(0xFFE9ECEF))),
        backgroundColor: const Color(0xFF212529),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Color(0xFFE9ECEF)),
            onPressed: _saveChanges,
          ),
        ],
      ),
      backgroundColor: const Color(0xFFE9ECEF),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF212529),
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
                children: [
                  _buildDetailRow('Company:', order['company_name']),
                  _buildDetailRow('Vehicle:', order['vehicle_name']),
                  _buildDetailRow('Order Date:', order['order_date']),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('Tax (%):', style: TextStyle(color: Color(0xFFE9ECEF))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _taxController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Color(0xFFE9ECEF)),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFF495057),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: (_) => _calculateTotal(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildTableHeader(),
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) => Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF343A40),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          _items[index]['name'],
                          style: const TextStyle(color: Color(0xFFE9ECEF), fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      _buildEditableField(_items[index], 'quantity', ''),
                      _buildEditableField(_items[index], 'price', ''),
                      _buildEditableField(_items[index], 'discount', '%'),
                      Expanded(
                        child: Text(
                          '\$${_items[index]['total'].toStringAsFixed(0)}',
                          style: const TextStyle(color: Color(0xFFE9ECEF), fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                        onPressed: () {
                          setState(() {
                            _items.removeAt(index);
                            _calculateTotal();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF212529),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTotalRow('Subtotal:', _subtotal),
                  _buildTotalRow('Tax:', _taxAmount),
                  _buildTotalRow('Total:', _total),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFFE9ECEF), fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(color: Color(0xFFE9ECEF))),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF212529),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Expanded(
            flex: 3,
            child: Text('Item', style: TextStyle(color: Color(0xFFE9ECEF), fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ),
          Expanded(child: Text('Qty', style: TextStyle(color: Color(0xFFE9ECEF), fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          Expanded(child: Text('Price', style: TextStyle(color: Color(0xFFE9ECEF), fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          Expanded(child: Text('Disc%', style: TextStyle(color: Color(0xFFE9ECEF), fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          Expanded(child: Text('Total', style: TextStyle(color: Color(0xFFE9ECEF), fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          Expanded(child: Text('Actions', style: TextStyle(color: Color(0xFFE9ECEF), fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Color(0xFFADB5BD), fontSize: 14)),
        Text('\$${value.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFE9ECEF), fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class AddPurchaseItemsPage extends StatefulWidget {
  final String companyName;
  final String vehicleName;
  final int vehicleSize;

  const AddPurchaseItemsPage({
    Key? key,
    required this.companyName,
    required this.vehicleName,
    required this.vehicleSize,
  }) : super(key: key);

  @override
  State<AddPurchaseItemsPage> createState() => _AddPurchaseItemsPageState();
}

class _AddPurchaseItemsPageState extends State<AddPurchaseItemsPage> {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _taxController = TextEditingController();
  final List<Map<String, dynamic>> addedItems = [];
  int totalQuantity = 0;
  int totalOccupiedSpace = 0;
  int totalOrderValue = 0;
  double taxPercentage = 0.0;

  @override
  void initState() {
    super.initState();
    _dateController.text = _formatDate(DateTime.now());
    _taxController.text = '0.5';
  }

  String _formatDate(DateTime date) {
    return DateFormat('d MMMM y').format(date);
  }

  Widget _buildTableHeader() {
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
            // Item Name (flex: 3)
            Expanded(
              flex: 3,
              child: _buildHeaderCell('Item'),
            ),
            // Quantity (flex: 1)
            Expanded(
              flex: 1,
              child: _buildHeaderCell('Qty'),
            ),
            // Price (flex: 1)
            Expanded(
              flex: 1,
              child: _buildHeaderCell('Price'),
            ),
            // Discount (flex: 1)
            Expanded(
              flex: 1,
              child: _buildHeaderCell('Discount'),
            ),
            // Total (flex: 1)
            Expanded(
              flex: 1,
              child: _buildHeaderCell('Total'),
            ),
            // Packaging Unit (flex: 1)
            Expanded(
              flex: 1,
              child: _buildHeaderCell('Packaging Unit'),
            ),
            // Status (flex: 1)
            Expanded(
              flex: 1,
              child: _buildHeaderCell('Cvrd'),
            ),
            // Actions (flex: 0)
            Expanded(
              flex: 0,
              child: _buildHeaderCell('Actions'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex, // Use the flex parameter here
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

  Widget _buildFormField({
    required TextEditingController controller,
    bool isDate = false,
    bool isTax = false,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Color(0xFFE9ECEF)),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF495057),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIcon: isDate
            ? const Icon(Icons.calendar_today, size: 20, color: Color(0xFFE9ECEF))
            : null,
        suffixText: isTax ? '%' : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
      readOnly: isDate,
      keyboardType: isTax ? TextInputType.number : null,
      onTap: isDate ? () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (date != null) {
          setState(() => _dateController.text = _formatDate(date));
        }
      } : null,
      onChanged: isTax ? (value) {
        setState(() => taxPercentage = double.tryParse(value) ?? 0.0);
      } : null,
    );
  }

  Future<void> _showItemSelectionDialog() async {
    try {
      final items = await FirebaseFirestore.instance.collection('items').get();

      // Sort items by qualityName + itemName
      final sortedItems = items.docs.map((doc) => doc).toList()
        ..sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final qualityCompare = (aData['qualityName']?.toString().toLowerCase() ?? '')
              .compareTo(bData['qualityName']?.toString().toLowerCase() ?? '');
          if (qualityCompare != 0) return qualityCompare;
          return (aData['itemName']?.toString().toLowerCase() ?? '')
              .compareTo(bData['itemName']?.toString().toLowerCase() ?? '');
        });

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            String searchQuery = '';
            List<DocumentSnapshot> filteredItems = sortedItems;

            return Dialog(
              backgroundColor: const Color(0xFFE9ECEF),
              insetPadding: const EdgeInsets.all(20),
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.8,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: TextField(
                        onChanged: (value) {
                          final query = value.trim().toLowerCase();
                          setState(() {
                            searchQuery = query;
                            filteredItems = sortedItems.where((doc) {
                              final item = doc.data() as Map<String, dynamic>;
                              final itemName = item['itemName']?.toString().toLowerCase() ?? '';
                              final qualityName = item['qualityName']?.toString().toLowerCase() ?? '';
                              return itemName.contains(query) || qualityName.contains(query);
                            }).toList();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search Items...',
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
                            onPressed: () {
                              setState(() {
                                searchQuery = '';
                                filteredItems = sortedItems;
                              });
                            },
                          )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 20),
                        ),
                      ),
                    ),
                    _buildDialogTableHeader(),
                    Expanded(
                      child: filteredItems.isEmpty
                          ? const Center(
                        child: Text(
                          'No items found',
                          style: TextStyle(color: Color(0xFF212529)),
                        ),
                      )
                          : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) =>
                            _buildDialogItemRow(filteredItems[index]),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading items: $e')),
      );
    }
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildHeaderCell('Quality + Item', flex: 3), // Combined column
            _buildHeaderCell('Price'),
            _buildHeaderCell('Dimensions'),
            _buildHeaderCell('Packaging Unit'),
            _buildHeaderCell('Cvrd'),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogItemRow(DocumentSnapshot itemDoc) {
    final item = itemDoc.data() as Map<String, dynamic>;
    final dimensions = [
      (item['length'] as num).toInt(),
      (item['width'] as num).toInt(),
      (item['height'] as num).toInt(),
    ];
    final size = dimensions[0] * dimensions[1] * dimensions[2];
    final coveredStatus = item['covered'] ?? 'Uncovered';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF343A40),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(3, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            Navigator.pop(context);
            await _addItemWithDefaults(itemDoc);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Combined Quality + Item Name
                _buildDialogCell(
                  '${item['qualityName']}: ${item['itemName']}', // Format: "Quality: Item"
                  flex: 3,
                  color: const Color(0xFFE9ECEF),
                ),
                // Price
                _buildDialogCell('${item['purchasePrice']}'),
                // Dimensions
                _buildDialogCell('${item['length']}x${item['width']}x${item['height']}'),
                // Packaging Unit
                _buildDialogCell(item['packagingUnit']),
                // Status (Covered/Uncovered)
                _buildDialogCell(
                  coveredStatus,
                  color: coveredStatus == 'Covered' ? Colors.green : Colors.red,
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
  Future<void> _addItemWithDefaults(DocumentSnapshot itemDoc) async {
    try {
      final item = itemDoc.data() as Map<String, dynamic>;
      final quality = await FirebaseFirestore.instance
          .collection('qualities')
          .doc(item['qualityId'])
          .get();

      // Fetch the "covered" status from the item document
      final coveredStatus = item['covered'] ?? 'Uncovered'; // Default to 'Uncovered' if null

      // Fetch the correct discount based on the coverage status
      final discount = coveredStatus == 'Covered'
          ? (quality.data()?['covered_discount'] ?? 0.0).toDouble()
          : (quality.data()?['uncovered_discount'] ?? 0.0).toDouble();

      const quantity = 1;
      final price = (item['purchasePrice'] as num).toInt();
      final dimensions = [
        (item['length'] as num).toInt(),
        (item['width'] as num).toInt(),
        (item['height'] as num).toInt(),
      ];
      final size = dimensions[0] * dimensions[1] * dimensions[2] * quantity;
      final total = (price * quantity * (1 - discount / 100)).toInt();

      setState(() {
        addedItems.add({
          'id': itemDoc.id,
          'name': '${item['qualityName']} ${item['itemName']}',
          'quantity': quantity,
          'price': price,
          'discount': discount.toInt(),
          'total': total,
          'size': size,
          'dimensions': dimensions,
          'editingQuantity': false,
          'editingPrice': false,
          'editingDiscount': false,
          'covered': coveredStatus, // Add the "covered" status to the item
          'packagingUnit': item['packagingUnit'], // Add the packaging unit
        });

        totalQuantity += quantity;
        totalOccupiedSpace += size;
        totalOrderValue += total;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding item: ${e.toString()}')),
      );
    }
  }

  void _updateItemValues(int index, String field, int newValue) {
    setState(() {
      final item = addedItems[index];
      final int oldQuantity = item['quantity'];
      final int oldTotal = item['total'];
      final int oldSize = item['size'];

      item[field] = newValue;

      if (field == 'quantity' || field == 'price' || field == 'discount') {
        final List<int> dimensions = List<int>.from(item['dimensions']);
        final int quantity = field == 'quantity' ? newValue : item['quantity'];
        final int price = field == 'price' ? newValue : item['price'];
        final int discount = field == 'discount' ? newValue : item['discount'];

        item['total'] = (price * quantity * (1 - discount / 100)).toInt();
        item['size'] = dimensions[0] * dimensions[1] * dimensions[2] * quantity;
      }

      totalOccupiedSpace += (item['size'] as int) - oldSize;
      totalOrderValue += (item['total'] as int) - oldTotal;
      totalQuantity += (field == 'quantity') ? (newValue - oldQuantity) : 0;

      // Update the "isCovered" status for all items
      int cumulativeSpace = 0;
      for (var i = 0; i < addedItems.length; i++) {
        cumulativeSpace += addedItems[i]['size'] as int;
        addedItems[i]['isCovered'] = cumulativeSpace <= widget.vehicleSize;
      }
    });
  }

  void _deleteItemFromList(int index) {
    setState(() {
      final item = addedItems.removeAt(index);
      totalQuantity -= item['quantity'] as int;
      totalOccupiedSpace -= item['size'] as int;
      totalOrderValue -= item['total'] as int;

      // Update the "isCovered" status for all items
      int cumulativeSpace = 0;
      for (var i = 0; i < addedItems.length; i++) {
        cumulativeSpace += addedItems[i]['size'] as int;
        addedItems[i]['isCovered'] = cumulativeSpace <= widget.vehicleSize;
      }
    });
  }

  double _calculateCoverage() {
    if (widget.vehicleSize == 0) return 0;
    return (totalOccupiedSpace / widget.vehicleSize * 100).clamp(0, 200);
  }

  double get subtotal => totalOrderValue.toDouble();
  double get taxAmount => subtotal * (taxPercentage / 100);
  double get totalAfterTax => subtotal + taxAmount;

  Future<void> _saveOrder() async {
    if (addedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('purchase_orders').add({
        'company_name': widget.companyName,
        'vehicle_name': widget.vehicleName,
        'order_date': _dateController.text,
        'tax_percentage': taxPercentage,
        'subtotal': subtotal,
        'tax_amount': taxAmount,
        'total_after_tax': totalAfterTax,
        'total_quantity': totalQuantity,
        'total_occupied_space': totalOccupiedSpace,
        'items': addedItems,
        'created_at': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order saved successfully!')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save order: $error')),
      );
    }
  }

  Widget _buildEditableField(int index, String field) {
    final item = addedItems[index];
    final bool isEditing = item['editing${field.capitalize()}'];
    final String value = item[field].toString();
    final String suffix = field == 'discount' ? '%' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: isEditing
          ? TextFormField(
        initialValue: value,
        keyboardType: TextInputType.number,
        autofocus: true,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: const Color(0xFF495057),
        ),
        onFieldSubmitted: (newValue) {
          final int parsedValue = int.tryParse(newValue) ?? item[field];
          _updateItemValues(index, field, parsedValue);
          setState(() => item['editing${field.capitalize()}'] = false);
        },
      )
          : GestureDetector(
        onTap: () =>
            setState(() => item['editing${field.capitalize()}'] = true),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF343A40),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$value$suffix',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFE9ECEF),
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9ECEF),
      appBar: AppBar(
        title: Text(
          'New Order - ${widget.companyName}',
          style: const TextStyle(color: Color(0xFFE9ECEF)),
        ),
        backgroundColor: const Color(0xFF212529),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFFE9ECEF)),
            onPressed: _showItemSelectionDialog,
            tooltip: 'Add Items',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Date',
                        style: TextStyle(
                          color: Color(0xFF495057),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildFormField(
                        controller: _dateController,
                        isDate: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tax Percentage',
                        style: TextStyle(
                          color: Color(0xFF495057),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildFormField(
                        controller: _taxController,
                        isTax: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildTableHeader(),
          Expanded(
            child: ListView.builder(
              itemCount: addedItems.length,
              itemBuilder: (context, index) => Container(
                margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B3035),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 3,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    children: [
                      // Item Name (flex: 3)
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            addedItems[index]['name'],
                            style: const TextStyle(
                              color: Color(0xFFE9ECEF),
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      // Quantity (flex: 1)
                      Expanded(
                        flex: 1,
                        child: _buildEditableField(index, 'quantity'),
                      ),
                      // Price (flex: 1)
                      Expanded(
                        flex: 1,
                        child: _buildEditableField(index, 'price'),
                      ),
                      // Discount (flex: 1)
                      Expanded(
                        flex: 1,
                        child: _buildEditableField(index, 'discount'),
                      ),
                      // Total (flex: 1)
                      Expanded(
                        flex: 1,
                        child: Text(
                          '\$${addedItems[index]['total']}',
                          style: const TextStyle(
                            color: Color(0xFFE9ECEF),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Packaging Unit (flex: 1)
                      Expanded(
                        flex: 1,
                        child: Text(
                          addedItems[index]['packagingUnit'],
                          style: const TextStyle(
                            color: Color(0xFFE9ECEF),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Status (flex: 1) - Updated Code
                      Expanded(
                        flex: 1,
                        child: Text(
                          addedItems[index]['covered'] ?? 'Uncovered', // Display the "covered" status
                          style: TextStyle(
                            color: addedItems[index]['covered'] == 'Covered' ? Colors.green : Colors.red,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Delete Button (flex: 0)
                      Expanded(
                        flex: 0,
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () => _deleteItemFromList(index),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: const BoxDecoration(
              color: Color(0xFF212529),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryTile('Items', totalQuantity.toString()),
                _buildSummaryTile('Space', '$totalOccupiedSpace in³'),
                _buildSummaryTile('Coverage', '${_calculateCoverage().toStringAsFixed(1)}%'),
                _buildSummaryTile('Subtotal', '\$${subtotal.toStringAsFixed(0)}'),
                _buildSummaryTile('Tax', '\$${taxAmount.toStringAsFixed(0)}'),
                _buildSummaryTile('Total', '\$${totalAfterTax.toStringAsFixed(0)}'),
                ElevatedButton(
                  onPressed: _saveOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF343A40),
                    foregroundColor: const Color(0xFFE9ECEF),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24.0),
                    ),
                  ),
                  child: const Text('Save Order'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTile(String title, String value) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
              color: Color(0xFFADB5BD),
              fontSize: 14,
              fontWeight: FontWeight.w500
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFE9ECEF),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}