import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

// Color Scheme Matching Purchase Invoice
const Color _primaryColor = Color(0xFF0D6EFD);
const Color _textColor = Color(0xFF2D2D2D);
const Color _secondaryTextColor = Color(0xFF4A4A4A);
const Color _backgroundColor = Color(0xFFF8F9FA);
const Color _surfaceColor = Colors.white;

// Purchase Orders List Screen (Matches InvoiceListScreen)
class PurchaseOrdersPage extends StatefulWidget {
  const PurchaseOrdersPage({super.key});

  @override
  _PurchaseOrdersPageState createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> {
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
        date = DateTime.parse(dateValue);
      } else {
        date = DateTime.fromMillisecondsSinceEpoch(dateValue.millisecondsSinceEpoch);
      }
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      print('Error parsing date: $e');
      return 'Invalid Date';
    }
  }

  void _viewOrder(DocumentSnapshot orderDoc) {
    final order = orderDoc.data() as Map<String, dynamic>;
    print('Retrieved Order Data: $order'); // Debug: Full order data
    print('Retrieved Items: ${order['items']}'); // Debug: Items specifically
    if (order['items'] == null || (order['items'] as List).isEmpty) {
      print('Warning: No items found in order ${orderDoc.id}');
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewPurchaseOrderPage.fromData(
          orderId: orderDoc.id,
          existingOrder: order,
        ),
      ),
    );
  }

  void _editOrder(DocumentSnapshot orderDoc) {
    final order = orderDoc.data() as Map<String, dynamic>;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPurchaseItemsPage(
          companyName: order['company_name'] ?? '',
          vehicleName: order['vehicle_name'] ?? '',
          vehicleSize: order['total_occupied_space'] is int ? order['total_occupied_space'] : 0,
          orderId: orderDoc.id,
          existingOrder: order,
        ),
      ),
    );
  }

  Future<void> _deleteOrder(DocumentSnapshot orderDoc) async {
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
                'Are you sure you want to delete this order?',
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
      await FirebaseFirestore.instance.collection('purchase_orders').doc(orderDoc.id).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order deleted successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 1200;

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
          Expanded(
            child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('purchase_orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _primaryColor));
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Error: ${snapshot.error}', style: const TextStyle(color: _textColor)));
        }

        final orders = snapshot.data?.docs.where((doc) {
          final companyName = doc['company_name'].toString().toLowerCase();
          return companyName.contains(_searchQuery);
        }).toList();

        if (orders == null || orders.isEmpty) {
          return const Center(
              child: Text('No orders found', style: TextStyle(color: _textColor)));
        }

        return Column(
          children: [
            _buildDesktopHeader(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: orders.length,
                itemBuilder: (context, index) => _buildDesktopRow(orders[index]),
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
                  stream: FirebaseFirestore.instance.collection('purchase_orders').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: _primaryColor));
                    }
                    if (snapshot.hasError) {
                      return Center(
                          child: Text('Error: ${snapshot.error}',
                              style: const TextStyle(color: _textColor)));
                    }

                    final orders = snapshot.data?.docs.where((doc) {
                      final companyName = doc['company_name'].toString().toLowerCase();
                      return companyName.contains(_searchQuery);
                    }).toList();

                    if (orders == null || orders.isEmpty) {
                      return const Center(
                          child: Text('No orders found',
                              style: TextStyle(color: _textColor)));
                    }

                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemCount: orders.length,
                      itemBuilder: (context, index) => _buildMobileRow(orders[index]),
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
              color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(child: _HeaderCell('Company')),
            Expanded(child: _HeaderCell('Vehicle')),
            Expanded(child: _HeaderCell('Total')),
            Expanded(child: _HeaderCell('Order Date')),
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
              color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _HeaderCell('Company', 200),
            _HeaderCell('Vehicle', 200),
            _HeaderCell('Total', 150),
            _HeaderCell('Order Date', 150),
            _HeaderCell('Actions', 150),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopRow(DocumentSnapshot orderDoc) {
    final order = orderDoc.data() as Map<String, dynamic>;
    final total = order['total_after_tax']?.toStringAsFixed(0) ?? '0';
    final orderDate = _formatDate(order['order_date']); // Use dd-MM-yyyy format

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(child: _DataCell(order['company_name'] ?? 'N/A')),
            Expanded(child: _DataCell(order['vehicle_name'] ?? 'N/A')),
            Expanded(child: _DataCell(total)),
            Expanded(child: _DataCell(orderDate)),
            Expanded(
                child: _ActionCell(
                  orderDoc,
                  null,
                  onView: _viewOrder,
                  onEdit: _editOrder,
                  onDelete: _deleteOrder,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileRow(DocumentSnapshot orderDoc) {
    final order = orderDoc.data() as Map<String, dynamic>;
    final total = order['total_after_tax']?.toStringAsFixed(0) ?? '0';
    final orderDate = _formatDate(order['order_date']); // Use dd-MM-yyyy format

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _DataCell(order['company_name'] ?? 'N/A', 200),
            _DataCell(order['vehicle_name'] ?? 'N/A', 200),
            _DataCell(total, 150),
            _DataCell(orderDate, 150),
            _ActionCell(
              orderDoc,
              150,
              onView: _viewOrder,
              onEdit: _editOrder,
              onDelete: _deleteOrder,
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
              color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))
        ],
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

  Future<void> _showCompanyVehicleDialog(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CompanyVehicleSelectionDialog(),
    );

    if (result != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddPurchaseItemsPage(
            companyName: result['company'],
            vehicleName: result['vehicle'],
            vehicleSize: result['vehicleSize'],
          ),
        ),
      );
    }
  }
}

// Data Models (Matches InvoiceItem and Item from purchaseinvoice.dart)
class OrderItem {
  final String itemId;
  final String name;
  final String quality;
  final String packagingUnit;
  int quantity;
  double price;
  double discount;
  final String covered;
  final int size;
  int stockQuantity; // Changed to non-nullable with default value in constructor

  OrderItem({
    required this.itemId,
    required this.name,
    required this.quality,
    required this.packagingUnit,
    required this.quantity,
    required this.price,
    required this.discount,
    required this.covered,
    required this.size,
    this.stockQuantity = 0, // Default value to avoid null
  });

  Map<String, dynamic> toMap() => {
    'itemId': itemId,
    'name': name,
    'quality': quality,
    'packagingUnit': packagingUnit,
    'quantity': quantity,
    'price': price,
    'discount': discount,
    'covered': covered,
    'size': size,
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

// View Purchase Order Page (Matches InvoiceViewScreen)
class ViewPurchaseOrderPage extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> existingOrder;
  final List<OrderItem> items;

  const ViewPurchaseOrderPage({super.key, required this.orderId, required this.existingOrder})
      : items = const [];

  factory ViewPurchaseOrderPage.fromData(
      {required String orderId, required Map<String, dynamic> existingOrder}) {
    final itemsList = existingOrder['items'] as List<dynamic>? ?? [];
    final items = itemsList.map((item) => OrderItem(
      itemId: item['itemId'] ?? '',
      name: item['name'] ?? 'Unknown',
      quality: item['quality'] ?? 'N/A', // Ensure quality is mapped correctly
      packagingUnit: item['packagingUnit'] ?? 'Unit',
      quantity: item['quantity'] is int ? item['quantity'] : int.tryParse(item['quantity']?.toString() ?? '0') ?? 0,
      price: (item['price'] as num?)?.toDouble() ?? 0.0,
      discount: (item['discount'] as num?)?.toDouble() ?? 0.0,
      covered: item['covered']?.toString() ?? "No", // Use raw Firestore value
      size: item['size'] is int ? item['size'] : int.tryParse(item['size']?.toString() ?? '0') ?? 0,
    )).toList();
    return ViewPurchaseOrderPage._(
      orderId: orderId,
      existingOrder: existingOrder,
      items: items,
    );
  }

  const ViewPurchaseOrderPage._({
    required this.orderId,
    required this.existingOrder,
    required this.items,
  });

  String _formatDate(dynamic dateValue) {
    try {
      DateTime date;
      if (dateValue is Timestamp) {
        date = dateValue.toDate();
      } else if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else {
        date = DateTime.fromMillisecondsSinceEpoch(dateValue.millisecondsSinceEpoch);
      }
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      print('Error parsing date: $e');
      return 'Invalid Date';
    }
  }

  Future<int> _fetchStockQuantity(String itemId) async {
    final doc = await FirebaseFirestore.instance.collection('items').doc(itemId).get();
    final data = doc.data();
    return data?['stockQuantity'] is int ? data!['stockQuantity'] : int.tryParse(data?['stockQuantity']?.toString() ?? '0') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    print('ViewPurchaseOrderPage Items: ${items.map((item) => item.toMap()).toList()}'); // Debug: Log items
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        title: const Text("View Purchase Order", style: TextStyle(color: _textColor)),
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
                child: Text('Disc%',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text('Total',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text('Stock',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
      ],
    ),
  );

  Widget _buildItemRow(OrderItem item) => Container(
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
                    color: item.covered.toLowerCase() == "yes" ? Colors.green[100] : Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.covered, // Display raw Firestore value
                    style: TextStyle(
                      color: item.covered.toLowerCase() == "yes" ? Colors.green[800] : Colors.red[800],
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
                  (item.quantity * item.price * (1 - item.discount / 100)).toStringAsFixed(0),
                  style: TextStyle(
                      color: _textColor, fontWeight: FontWeight.bold, fontSize: 14),
                ))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text(
                  item.stockQuantity.toString(),
                  style: TextStyle(color: _textColor, fontSize: 14),
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
        _buildTextField('Company', existingOrder['company_name']),
        const SizedBox(height: 16),
        _buildTextField('Vehicle', existingOrder['vehicle_name']),
        const SizedBox(height: 16),
        _buildTextField('Order Date', _formatDate(existingOrder['order_date'])),
        const SizedBox(height: 16),
        _buildTextField('Tax Percentage (%)', existingOrder['tax_percentage'].toString()),
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
        _buildSummaryItem('Subtotal', '${existingOrder['subtotal']?.toStringAsFixed(0) ?? '0'}/-'),
        _buildSummaryItem('Tax', '${existingOrder['tax_amount']?.toStringAsFixed(0) ?? '0'}/-'),
        const Divider(),
        _buildSummaryItem(
          'Total',
          '${existingOrder['total_after_tax']?.toStringAsFixed(0) ?? '0'}/-',
          valueStyle: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
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

// Add/Edit Purchase Items Page (Matches InvoiceScreen)
class AddPurchaseItemsPage extends StatefulWidget {
  final String companyName;
  final String vehicleName;
  final int vehicleSize;
  final String? orderId;
  final Map<String, dynamic>? existingOrder;

  const AddPurchaseItemsPage({
    Key? key,
    required this.companyName,
    required this.vehicleName,
    required this.vehicleSize,
    this.orderId,
    this.existingOrder,
  }) : super(key: key);

  @override
  _AddPurchaseItemsPageState createState() => _AddPurchaseItemsPageState();
}

class _AddPurchaseItemsPageState extends State<AddPurchaseItemsPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<OrderItem> _items = [];
  List<OrderItem> _originalItems = [];
  double _subtotal = 0.0;
  double _total = 0.0;
  final TextEditingController _orderDateController = TextEditingController();
  final TextEditingController _taxController = TextEditingController();
  final ScrollController _itemsScrollController = ScrollController();
  int? _selectedItemIndex;

  @override
  void initState() {
    super.initState();
    if (widget.existingOrder != null) {
      _initializeExistingOrder();
    } else {
      _orderDateController.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
      _taxController.text = '0.5';
    }
  }

  Future<void> _initializeExistingOrder() async {
    final order = widget.existingOrder!;
    _orderDateController.text = _formatDate(order['order_date'] ?? DateTime.now());
    _taxController.text = order['tax_percentage']?.toString() ?? '0.5';

    _originalItems = (order['items'] as List<dynamic>? ?? []).map((item) => OrderItem(
      itemId: item['itemId'] ?? '',
      name: item['name'] ?? 'Unknown',
      quality: item['quality'] ?? 'N/A', // Ensure quality is mapped correctly
      packagingUnit: item['packagingUnit'] ?? 'Unit',
      quantity: item['quantity'] is int ? item['quantity'] : int.tryParse(item['quantity']?.toString() ?? '0') ?? 0,
      price: (item['price'] as num?)?.toDouble() ?? 0.0,
      discount: (item['discount'] as num?)?.toDouble() ?? 0.0,
      covered: item['covered']?.toString() ?? "No", // Use raw Firestore value
      size: item['size'] is int ? item['size'] : int.tryParse(item['size']?.toString() ?? '0') ?? 0,
    )).toList();

    // Fetch stock quantities for all items at once
    for (var item in _originalItems) {
      item.stockQuantity = await _fetchStockQuantity(item.itemId);
    }

    setState(() {
      _items.addAll(_originalItems);
      _calculateTotal();
    });
  }

  String _formatDate(dynamic dateValue) {
    try {
      DateTime date;
      if (dateValue is Timestamp) {
        date = dateValue.toDate();
      } else if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else if (dateValue is DateTime) {
        date = dateValue;
      } else {
        date = DateTime.fromMillisecondsSinceEpoch(dateValue?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch);
      }
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      print('Error parsing date: $e');
      return DateFormat('dd-MM-yyyy').format(DateTime.now());
    }
  }

  Future<int> _fetchStockQuantity(String itemId) async {
    final doc = await FirebaseFirestore.instance.collection('items').doc(itemId).get();
    final data = doc.data();
    return data?['stockQuantity'] is int ? data!['stockQuantity'] : int.tryParse(data?['stockQuantity']?.toString() ?? '0') ?? 0;
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

    final doc = await _firestore.collection('items').doc(item.id).get();
    final itemData = doc.data() as Map<String, dynamic>;

    final length = (itemData['length'] as num?)?.toInt() ?? 0;
    final width = (itemData['width'] as num?)?.toInt() ?? 0;
    final height = (itemData['height'] as num?)?.toInt() ?? 0;
    final size = length * width * height;

    final stockQuantity = itemData['stockQuantity'] is int
        ? itemData['stockQuantity']
        : int.tryParse(itemData['stockQuantity']?.toString() ?? '0') ?? 0;

    setState(() {
      _items.add(OrderItem(
        itemId: item.id,
        name: item.name,
        quality: item.quality,
        packagingUnit: item.packagingUnit,
        quantity: 1,
        price: item.purchasePrice,
        discount: discount,
        covered: item.covered, // Use raw Firestore value from Item
        size: size,
        stockQuantity: stockQuantity,
      ));
      _calculateTotal();
    });
    Navigator.pop(context);
  }

  void _calculateTotal() {
    _subtotal = _items.fold(0.0, (sum, item) => sum + (item.quantity * item.price * (1 - item.discount / 100)));
    final tax = _subtotal * (double.tryParse(_taxController.text) ?? 0.0) / 100;
    _total = _subtotal + tax;
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      print('No items to save'); // Debug: Confirm items list is empty
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    print('Items to save: ${_items.map((item) => item.toMap()).toList()}'); // Debug: Log items before saving

    final orderData = {
      'company_name': widget.companyName,
      'vehicle_name': widget.vehicleName,
      'order_date': _orderDateController.text,
      'tax_percentage': double.tryParse(_taxController.text) ?? 0.5,
      'subtotal': _subtotal,
      'tax_amount': _total - _subtotal,
      'total_after_tax': _total,
      'total_quantity': _items.fold(0, (sum, item) => sum + item.quantity),
      'total_occupied_space': _items.fold(0, (sum, item) => sum + item.size),
      'items': _items.map((item) => item.toMap()).toList(),
      'created_at': FieldValue.serverTimestamp(),
    };

    print('Order Data to Save: $orderData'); // Debug: Log full order data

    try {
      if (widget.orderId != null) {
        await _firestore.collection('purchase_orders').doc(widget.orderId).update(orderData);
        print('Updated order with ID: ${widget.orderId}');
      } else {
        final docRef = await _firestore.collection('purchase_orders').add(orderData);
        print('Saved new order with ID: ${docRef.id}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order saved successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      print('Error saving order: $e'); // Debug: Log any errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving order: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        title: Text(widget.orderId != null ? "Edit Purchase Order" : "Add Purchase Order",
            style: const TextStyle(color: _textColor)),
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
                child: Text('Disc%',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text('Total',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text('Stock',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
      ],
    ),
  );

  Widget _buildItemRow(OrderItem item, int index) => GestureDetector(
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
                          color: item.covered.toLowerCase() == "yes" ? Colors.green[100] : Colors.red[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.covered, // Display raw Firestore value
                          style: TextStyle(
                            color: item.covered.toLowerCase() == "yes" ? Colors.green[800] : Colors.red[800],
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
                        (item.quantity * item.price * (1 - item.discount / 100)).toStringAsFixed(0),
                        style: TextStyle(
                            color: _textColor, fontWeight: FontWeight.bold, fontSize: 14),
                      ))),
              Expanded(
                  flex: 1,
                  child: Center(
                      child: Text(
                        item.stockQuantity.toString(),
                        style: TextStyle(color: _textColor, fontSize: 14),
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
        _buildTextField('Company',
            TextEditingController(text: widget.companyName), enabled: false),
        const SizedBox(height: 16),
        _buildTextField('Vehicle',
            TextEditingController(text: widget.vehicleName), enabled: false),
        const SizedBox(height: 16),
        _buildDateField('Order Date', _orderDateController),
        const SizedBox(height: 16),
        _buildTextField('Tax Percentage (%)', _taxController,
            isNumeric: true, onChanged: (value) => setState(() => _calculateTotal())),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _submitOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          icon: const Icon(Icons.save, size: 20),
          label: const Text('SAVE ORDER',
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
      suffixIcon: const Icon(Icons.calendar_today, color: _secondaryTextColor),
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
          valueStyle: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
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
                    suffixIcon: const Icon(Icons.search, color: _secondaryTextColor),
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
                            data['qualityName'].toString().toLowerCase().contains(_searchQuery);
                      }).toList();
                      return ListView.separated(
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemCount: items.length,
                        itemBuilder: (_, index) => _buildInventoryItem(Item.fromMap(
                            items[index].data() as Map<String, dynamic>, items[index].id)),
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
                  color: item.covered.toLowerCase() == "yes" ? Colors.green[100] : Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.covered,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: item.covered.toLowerCase() == "yes" ? Colors.green[800] : Colors.red[800],
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

  Future<void> _selectDate(TextEditingController controller) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      setState(() {
        controller.text = DateFormat('dd-MM-yyyy').format(pickedDate);
      });
    }
  }
}

// Helper Components
class CompanyVehicleSelectionDialog extends StatefulWidget {
  @override
  _CompanyVehicleSelectionDialogState createState() => _CompanyVehicleSelectionDialogState();
}

class _CompanyVehicleSelectionDialogState extends State<CompanyVehicleSelectionDialog> {
  String? selectedCompany;
  String? selectedVehicle;
  int? selectedVehicleSize;

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
                color: Colors.black.withOpacity(0.05), blurRadius: 24, offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select Company & Vehicle',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textColor)),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('companies').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                return DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Company',
                    labelStyle: const TextStyle(color: _secondaryTextColor),
                    filled: true,
                    fillColor: _backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  dropdownColor: _surfaceColor,
                  items: snapshot.data!.docs
                      .map((doc) => DropdownMenuItem<String>(
                    value: doc['name'],
                    child: Text(doc['name'], style: const TextStyle(color: _textColor)),
                  ))
                      .toList(),
                  onChanged: (value) => setState(() => selectedCompany = value),
                  validator: (value) => value == null ? 'Required field' : null,
                );
              },
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('vehicles').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                return DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Vehicle',
                    labelStyle: const TextStyle(color: _secondaryTextColor),
                    filled: true,
                    fillColor: _backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  dropdownColor: _surfaceColor,
                  items: snapshot.data!.docs
                      .map((doc) => DropdownMenuItem<String>(
                    value: doc['name'],
                    child: Text(doc['name'], style: const TextStyle(color: _textColor)),
                    onTap: () => selectedVehicleSize = doc['size'],
                  ))
                      .toList(),
                  onChanged: (value) => setState(() => selectedVehicle = value),
                  validator: (value) => value == null ? 'Required field' : null,
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(color: _secondaryTextColor, fontSize: 14)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (selectedCompany != null && selectedVehicle != null && selectedVehicleSize != null) {
                      Navigator.pop(context, {
                        'company': selectedCompany,
                        'vehicle': selectedVehicle,
                        'vehicleSize': selectedVehicleSize,
                      });
                    }
                  },
                  child: const Text('Proceed', style: TextStyle(color: _surfaceColor, fontSize: 14)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
  final DocumentSnapshot orderDoc;
  final double? width;
  final Function(DocumentSnapshot) onView;
  final Function(DocumentSnapshot) onEdit;
  final Function(DocumentSnapshot) onDelete;

  const _ActionCell(this.orderDoc, this.width,
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
            onPressed: () => onView(orderDoc),
            tooltip: 'View Order',
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: _primaryColor, size: 20),
            onPressed: () => onEdit(orderDoc),
            tooltip: 'Edit Order',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            onPressed: () => onDelete(orderDoc),
            tooltip: 'Delete Order',
          ),
        ],
      ),
    );
  }
}