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

// Modern Coverage Progress Indicator with Animation
class CoverageProgressPainter extends CustomPainter {
  final double progress;
  final Animation<double> animation;

  CoverageProgressPainter({required this.progress, required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 12.0;

    // Background Circle (Subtle Gradient)
    final backgroundPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(
        colors: [Colors.grey[300]!, Colors.grey[500]!.withOpacity(0.5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, backgroundPaint);

    // Animated Progress Arc (Modern Gradient)
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [_primaryColor, Color(0xFF4A90E2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final animatedProgress = progress * animation.value;
    final sweepAngle = 2 * 3.14159 * animatedProgress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      sweepAngle,
      false,
      progressPaint,
    );

    // Inner Glow Effect (Modern Touch)
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 2
      ..color = _primaryColor.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      sweepAngle,
      false,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(CoverageProgressPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.animation.value != animation.value;
}

// Purchase Orders List Screen
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
      if (dateValue is Timestamp) date = dateValue.toDate();
      else if (dateValue is String) date = DateTime.parse(dateValue);
      else if (dateValue is DateTime) date = dateValue;
      else date = DateTime.fromMillisecondsSinceEpoch(dateValue?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch);
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      print('Error parsing date: $e');
      return DateFormat('dd-MM-yyyy').format(DateTime.now());
    }
  }

  void _viewOrder(DocumentSnapshot orderDoc) {
    final order = orderDoc.data() as Map<String, dynamic>;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewPurchaseOrderPage.fromData(
          orderId: orderDoc.id,
          existingOrder: order,
          vehicleSize: order['vehicle_size'] ?? 0,
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
          vehicleSize: order['vehicle_size'] is int ? order['vehicle_size'] : 0,
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
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Confirm Delete', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textColor)),
              const SizedBox(height: 20),
              const Text('Are you sure you want to delete this order?', style: TextStyle(fontSize: 14, color: _secondaryTextColor)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: _secondaryTextColor, fontSize: 14)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Delete', style: TextStyle(color: _surfaceColor, fontSize: 14)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance.collection('purchase_orders').doc(orderDoc.id).delete();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order deleted successfully!')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting order: $e')));
      }
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
          Expanded(child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout()),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('purchase_orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _primaryColor));
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: _textColor)));

        final orders = snapshot.data?.docs.where((doc) => (doc['company_name'] as String? ?? '').toLowerCase().contains(_searchQuery)).toList() ?? [];
        if (orders.isEmpty) return const Center(child: Text('No orders found', style: TextStyle(color: _textColor)));

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
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _primaryColor));
                    if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: _textColor)));

                    final orders = snapshot.data?.docs.where((doc) => (doc['company_name'] as String? ?? '').toLowerCase().contains(_searchQuery)).toList() ?? [];
                    if (orders.isEmpty) return const Center(child: Text('No orders found', style: TextStyle(color: _textColor)));

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

  Widget _buildDesktopHeader() => Container(
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
          Expanded(child: _HeaderCell('Company')),
          Expanded(child: _HeaderCell('Vehicle')),
          Expanded(child: _HeaderCell('Total')),
          Expanded(child: _HeaderCell('Order Date')),
          Expanded(child: _HeaderCell('Actions')),
        ],
      ),
    ),
  );

  Widget _buildMobileHeader() => Container(
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
          _HeaderCell('Company', 200),
          _HeaderCell('Vehicle', 200),
          _HeaderCell('Total', 150),
          _HeaderCell('Order Date', 150),
          _HeaderCell('Actions', 150),
        ],
      ),
    ),
  );

  Widget _buildDesktopRow(DocumentSnapshot orderDoc) {
    final order = orderDoc.data() as Map<String, dynamic>;
    final total = order['total_after_tax']?.toStringAsFixed(0) ?? '0';
    final orderDate = _formatDate(order['order_date']);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(child: _DataCell(order['company_name'] ?? 'N/A')),
            Expanded(child: _DataCell(order['vehicle_name'] ?? 'N/A')),
            Expanded(child: _DataCell(total)),
            Expanded(child: _DataCell(orderDate)),
            Expanded(child: _ActionCell(orderDoc, null, onView: _viewOrder, onEdit: _editOrder, onDelete: _deleteOrder)),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileRow(DocumentSnapshot orderDoc) {
    final order = orderDoc.data() as Map<String, dynamic>;
    final total = order['total_after_tax']?.toStringAsFixed(0) ?? '0';
    final orderDate = _formatDate(order['order_date']);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _DataCell(order['company_name'] ?? 'N/A', 200),
            _DataCell(order['vehicle_name'] ?? 'N/A', 200),
            _DataCell(total, 150),
            _DataCell(orderDate, 150),
            _ActionCell(orderDoc, 150, onView: _viewOrder, onEdit: _editOrder, onDelete: _deleteOrder),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() => Container(
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear, color: _secondaryTextColor),
          onPressed: () {
            _searchController.clear();
            setState(() => _searchQuery = '');
          },
        ),
        prefixIcon: const Icon(Icons.search, color: _secondaryTextColor),
      ),
      onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
    ),
  );

  Widget _buildAddButton() => SizedBox(
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

// Data Models
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
  int stockQuantity;

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
    this.stockQuantity = 0,
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
    purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? 0.0,
    covered: map['covered']?.toString() ?? "No",
  );
}

// View Purchase Order Page
class ViewPurchaseOrderPage extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> existingOrder;
  final List<OrderItem> items;
  final int vehicleSize;

  const ViewPurchaseOrderPage({super.key, required this.orderId, required this.existingOrder, required this.vehicleSize}) : items = const [];

  factory ViewPurchaseOrderPage.fromData({required String orderId, required Map<String, dynamic> existingOrder, required int vehicleSize}) {
    final itemsList = existingOrder['items'] as List<dynamic>? ?? [];
    final items = itemsList.map((item) => OrderItem(
      itemId: item['itemId'] ?? '',
      name: item['name'] ?? 'Unknown',
      quality: item['quality'] ?? 'N/A',
      packagingUnit: item['packagingUnit'] ?? 'Unit',
      quantity: item['quantity'] is int ? item['quantity'] : int.tryParse(item['quantity']?.toString() ?? '0') ?? 0,
      price: (item['price'] as num?)?.toDouble() ?? 0.0,
      discount: (item['discount'] as num?)?.toDouble() ?? 0.0,
      covered: item['covered']?.toString() ?? "No",
      size: item['size'] is int ? item['size'] : int.tryParse(item['size']?.toString() ?? '0') ?? 0,
    )).toList();
    return ViewPurchaseOrderPage._(orderId: orderId, existingOrder: existingOrder, items: items, vehicleSize: vehicleSize);
  }

  const ViewPurchaseOrderPage._({required this.orderId, required this.existingOrder, required this.items, required this.vehicleSize});

  @override
  _ViewPurchaseOrderPageState createState() => _ViewPurchaseOrderPageState();
}

class _ViewPurchaseOrderPageState extends State<ViewPurchaseOrderPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDate(dynamic dateValue) {
    try {
      DateTime date;
      if (dateValue is Timestamp) date = dateValue.toDate();
      else if (dateValue is String) date = DateTime.parse(dateValue);
      else if (dateValue is DateTime) date = dateValue;
      else date = DateTime.fromMillisecondsSinceEpoch(dateValue?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch);
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      print('Error parsing date: $e');
      return DateFormat('dd-MM-yyyy').format(DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
                    child: ListView.separated(
                      itemCount: widget.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _buildItemRow(widget.items[index]),
                    ),
                  ),
                  if (widget.items.isEmpty)
                    Container(
                      height: 200,
                      alignment: Alignment.center,
                      child: const Text("No items", style: TextStyle(color: _secondaryTextColor, fontSize: 16)),
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
                    _buildSummaryCard(),
                    const SizedBox(height: 24),
                    _buildInputPanel(),
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
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)],
    ),
    child: const Row(
      children: [
        Expanded(flex: 2, child: Center(child: Text('Quality', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(flex: 2, child: Center(child: Text('Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(flex: 1, child: Center(child: Text('Cvrd', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(flex: 1, child: Center(child: Text('Qty', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(flex: 1, child: Center(child: Text('Price', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(flex: 1, child: Center(child: Text('Disc%', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(flex: 1, child: Center(child: Text('Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(flex: 1, child: Center(child: Text('Stock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
      ],
    ),
  );

  Widget _buildItemRow(OrderItem item) => Container(
    height: 56,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
    ),
    child: Row(
      children: [
        Expanded(flex: 2, child: Center(child: Text(item.quality, style: const TextStyle(color: _textColor, fontSize: 14)))),
        Expanded(flex: 2, child: Center(child: Text(item.name, style: const TextStyle(color: _textColor, fontSize: 14)))),
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
                    item.covered,
                    style: TextStyle(color: item.covered.toLowerCase() == "yes" ? Colors.green[800] : Colors.red[800], fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ))),
        Expanded(flex: 1, child: Center(child: Text(item.quantity.toString(), style: const TextStyle(color: _textColor, fontSize: 14)))),
        Expanded(flex: 1, child: Center(child: Text(item.price.toStringAsFixed(0), style: const TextStyle(color: _textColor, fontSize: 14)))),
        Expanded(flex: 1, child: Center(child: Text(item.discount.toStringAsFixed(0), style: const TextStyle(color: _textColor, fontSize: 14)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text(
                  (item.quantity * item.price * (1 - item.discount / 100)).toStringAsFixed(0),
                  style: const TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 14),
                ))),
        Expanded(flex: 1, child: Center(child: Text(item.stockQuantity.toString(), style: const TextStyle(color: _textColor, fontSize: 14)))),
      ],
    ),
  );

  Widget _buildInputPanel() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 24)],
    ),
    child: Column(
      children: [
        _buildTextField('Company', widget.existingOrder['company_name'] ?? 'N/A'),
        const SizedBox(height: 16),
        _buildTextField('Vehicle', widget.existingOrder['vehicle_name'] ?? 'N/A'),
        const SizedBox(height: 16),
        _buildTextField('Order Date', _formatDate(widget.existingOrder['order_date'])),
        const SizedBox(height: 16),
        _buildTextField('Tax Percentage (%)', widget.existingOrder['tax_percentage']?.toString() ?? '0.0'),
        const SizedBox(height: 16),
        _buildTextField('Total Vehicle Size', widget.vehicleSize.toString()),
      ],
    ),
  );

  Widget _buildTextField(String label, String value) => TextFormField(
    controller: TextEditingController(text: value),
    readOnly: true,
    style: const TextStyle(color: _textColor, fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      filled: true,
      fillColor: _backgroundColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: _secondaryTextColor),
    ),
  );

  Widget _buildSummaryCard() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 24, spreadRadius: 2)],
    ),
    child: Column(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: CustomPaint(
            painter: CoverageProgressPainter(
              progress: widget.vehicleSize > 0 ? widget.items.fold(0, (sum, item) => sum + item.size * item.quantity) / widget.vehicleSize : 0.0,
              animation: _animation,
            ),
            child: Center(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  final animatedProgress = (widget.vehicleSize > 0 ? widget.items.fold(0, (sum, item) => sum + item.size * item.quantity) / widget.vehicleSize : 0.0) * _animation.value;
                  return Text(
                    widget.vehicleSize > 0 ? '${(animatedProgress * 100).toStringAsFixed(0)}%' : '0%',
                    style: const TextStyle(color: _textColor, fontSize: 20, fontWeight: FontWeight.bold),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildSummaryItem('Covered Items', widget.items.where((item) => item.covered.toLowerCase() == 'yes').fold(0, (sum, item) => sum + item.quantity).toString()),
        _buildSummaryItem('Uncovered Items', widget.items.where((item) => item.covered.toLowerCase() != 'yes').fold(0, (sum, item) => sum + item.quantity).toString()),
        _buildSummaryItem('Total Items', widget.items.fold(0, (sum, item) => sum + item.quantity).toString()),
        const Divider(),
        _buildSummaryItem('Subtotal', '${widget.existingOrder['subtotal']?.toStringAsFixed(0) ?? '0'}/-'),
        _buildSummaryItem('Tax', '${widget.existingOrder['tax_amount']?.toStringAsFixed(0) ?? '0'}/-'),
        const Divider(),
        _buildSummaryItem('Total', '${widget.existingOrder['total_after_tax']?.toStringAsFixed(0) ?? '0'}/-', valueStyle: const TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
      ],
    ),
  );

  Widget _buildSummaryItem(String label, String value, {TextStyle? valueStyle}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: _secondaryTextColor)),
        Text(value, style: valueStyle ?? const TextStyle(color: _textColor)),
      ],
    ),
  );
}

// Add/Edit Purchase Items Page
class AddPurchaseItemsPage extends StatefulWidget {
  final String companyName;
  final String vehicleName;
  final int vehicleSize;
  final String? orderId;
  final Map<String, dynamic>? existingOrder;

  const AddPurchaseItemsPage({Key? key, required this.companyName, required this.vehicleName, required this.vehicleSize, this.orderId, this.existingOrder}) : super(key: key);

  @override
  _AddPurchaseItemsPageState createState() => _AddPurchaseItemsPageState();
}

class _AddPurchaseItemsPageState extends State<AddPurchaseItemsPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<OrderItem> _items = [];
  double _subtotal = 0.0;
  double _total = 0.0;
  final TextEditingController _orderDateController = TextEditingController();
  final TextEditingController _taxController = TextEditingController();
  final ScrollController _itemsScrollController = ScrollController();
  int? _selectedItemIndex;
  bool _isLoading = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.existingOrder != null) _initializeExistingOrder();
    else {
      _orderDateController.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
      _taxController.text = '0.5';
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeExistingOrder() async {
    setState(() => _isLoading = true);
    final order = widget.existingOrder!;
    _orderDateController.text = _formatDate(order['order_date'] ?? DateTime.now());
    _taxController.text = order['tax_percentage']?.toString() ?? '0.5';

    final itemsList = order['items'] as List<dynamic>? ?? [];
    for (var item in itemsList) {
      try {
        final orderItem = OrderItem(
          itemId: item['itemId'] ?? '',
          name: item['name'] ?? 'Unknown',
          quality: item['quality'] ?? 'N/A',
          packagingUnit: item['packagingUnit'] ?? 'Unit',
          quantity: item['quantity'] is int ? item['quantity'] : int.tryParse(item['quantity']?.toString() ?? '0') ?? 0,
          price: (item['price'] as num?)?.toDouble() ?? 0.0,
          discount: (item['discount'] as num?)?.toDouble() ?? 0.0,
          covered: item['covered']?.toString() ?? "No",
          size: item['size'] is int ? item['size'] : int.tryParse(item['size']?.toString() ?? '0') ?? 0,
        );
        orderItem.stockQuantity = await _fetchStockQuantity(orderItem.itemId);
        _items.add(orderItem);
      } catch (e) {
        print('Error initializing item: $e');
      }
    }

    setState(() {
      _calculateTotal();
      _isLoading = false;
    });
  }

  String _formatDate(dynamic dateValue) {
    try {
      DateTime date;
      if (dateValue is Timestamp) date = dateValue.toDate();
      else if (dateValue is String) date = DateTime.parse(dateValue);
      else if (dateValue is DateTime) date = dateValue;
      else date = DateTime.fromMillisecondsSinceEpoch(dateValue?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch);
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      print('Error parsing date: $e');
      return DateFormat('dd-MM-yyyy').format(DateTime.now());
    }
  }

  Future<int> _fetchStockQuantity(String itemId) async {
    try {
      final doc = await _firestore.collection('items').doc(itemId).get();
      final data = doc.data();
      return data?['stockQuantity'] is int ? data!['stockQuantity'] : int.tryParse(data?['stockQuantity']?.toString() ?? '0') ?? 0;
    } catch (e) {
      print('Error fetching stock quantity: $e');
      return 0;
    }
  }

  Future<void> _addItem(Item item) async {
    setState(() => _isLoading = true);
    try {
      final qualitySnapshot = await _firestore.collection('qualities').where('name', isEqualTo: item.quality).limit(1).get();
      if (qualitySnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quality not found')));
        return;
      }

      final qualityData = qualitySnapshot.docs.first.data() as Map<String, dynamic>;
      final discount = (item.covered.toLowerCase() == "yes") ? (qualityData['covered_discount'] ?? 0.0).toDouble() : (qualityData['uncovered_discount'] ?? 0.0).toDouble();

      final doc = await _firestore.collection('items').doc(item.id).get();
      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item not found')));
        return;
      }

      final itemData = doc.data() as Map<String, dynamic>;
      final length = (itemData['length'] as num?)?.toInt() ?? 0;
      final width = (itemData['width'] as num?)?.toInt() ?? 0;
      final height = (itemData['height'] as num?)?.toInt() ?? 0;
      final size = length * width * height;
      final stockQuantity = itemData['stockQuantity'] is int ? itemData['stockQuantity'] : int.tryParse(itemData['stockQuantity']?.toString() ?? '0') ?? 0;

      setState(() {
        _items.add(OrderItem(
          itemId: item.id,
          name: item.name,
          quality: item.quality,
          packagingUnit: item.packagingUnit,
          quantity: 1,
          price: item.purchasePrice,
          discount: discount,
          covered: item.covered,
          size: size,
          stockQuantity: stockQuantity,
        ));
        _calculateTotal();
      });
      Navigator.pop(context);
    } catch (e) {
      print('Error adding item: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add item')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateTotal() {
    _subtotal = _items.fold(0.0, (sum, item) => sum + (item.quantity * item.price * (1 - item.discount / 100)));
    final tax = _subtotal * (double.tryParse(_taxController.text) ?? 0.0) / 100;
    _total = _subtotal + tax;
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one item')));
      return;
    }

    setState(() => _isLoading = true);

    final orderData = {
      'company_name': widget.companyName,
      'vehicle_name': widget.vehicleName,
      'vehicle_size': widget.vehicleSize,
      'order_date': _orderDateController.text,
      'tax_percentage': double.tryParse(_taxController.text) ?? 0.5,
      'subtotal': _subtotal,
      'tax_amount': _total - _subtotal,
      'total_after_tax': _total,
      'total_quantity': _items.fold(0, (sum, item) => sum + item.quantity),
      'total_occupied_space': _items.fold(0, (sum, item) => sum + item.size * item.quantity),
      'items': _items.map((item) => item.toMap()).toList(),
      'created_at': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.orderId != null) {
        await _firestore.collection('purchase_orders').doc(widget.orderId).update(orderData);
      } else {
        await _firestore.collection('purchase_orders').add(orderData);
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order saved successfully!')));
      Navigator.pop(context);
    } catch (e) {
      print('Error saving order: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving order: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        title: Text(widget.orderId != null ? "Edit Purchase Order" : "Add Purchase Order", style: const TextStyle(color: _textColor)),
        elevation: 0,
        iconTheme: const IconThemeData(color: _textColor),
      ),
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          Padding(
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
                        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
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
                          child: const Text("No items added", style: TextStyle(color: _secondaryTextColor, fontSize: 16)),
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
                          _buildSummaryCard(),
                          const SizedBox(height: 24),
                          _buildInputPanel(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator(color: _primaryColor)),
        ],
      ),
    );
  }

  Widget _buildItemsHeader() => Container(
    height: 56,
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    decoration: BoxDecoration(
      color: _primaryColor,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)],
    ),
    child: const Row(
      children: [
        Expanded(flex: 2, child: Center(child: Text('Quality', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(flex: 2, child: Center(child: Text('Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(flex: 1, child: Center(child: Text('Cvrd', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(flex: 1, child: Center(child: Text('Qty', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(flex: 1, child: Center(child: Text('Price', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(flex: 1, child: Center(child: Text('Disc%', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(flex: 1, child: Center(child: Text('Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
        Expanded(flex: 1, child: Center(child: Text('Stock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)))),
      ],
    ),
  );

  Widget _buildItemRow(OrderItem item, int index) => GestureDetector(
    onTap: _isLoading ? null : () => setState(() => _selectedItemIndex = _selectedItemIndex == index ? null : index),
    child: Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Stack(
        children: [
          Row(
            children: [
              Expanded(flex: 2, child: Center(child: Text(item.quality, style: const TextStyle(color: _textColor, fontSize: 14)))),
              Expanded(flex: 2, child: Center(child: Text(item.name, style: const TextStyle(color: _textColor, fontSize: 14)))),
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
                          item.covered,
                          style: TextStyle(color: item.covered.toLowerCase() == "yes" ? Colors.green[800] : Colors.red[800], fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ))),
              Expanded(
                  flex: 1,
                  child: Center(
                      child: TextFormField(
                        initialValue: item.quantity.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _textColor, fontSize: 14),
                        decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        enabled: !_isLoading,
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
                        style: const TextStyle(color: _textColor, fontSize: 14),
                        decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        enabled: !_isLoading,
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
                        style: const TextStyle(color: _textColor, fontSize: 14),
                        decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        enabled: !_isLoading,
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
                        style: const TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 14),
                      ))),
              Expanded(flex: 1, child: Center(child: Text(item.stockQuantity.toString(), style: const TextStyle(color: _textColor, fontSize: 14)))),
            ],
          ),
          if (_selectedItemIndex == index)
            Positioned(
              right: 8,
              top: 8,
              child: GestureDetector(
                onTap: _isLoading
                    ? null
                    : () {
                  setState(() {
                    _items.removeAt(index);
                    _selectedItemIndex = null;
                    _calculateTotal();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.9), shape: BoxShape.circle),
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
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 24)],
    ),
    child: Column(
      children: [
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _showAddItemDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
          label: const Text('ADD ITEM', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 24),
        _buildTextField('Company', TextEditingController(text: widget.companyName), enabled: false),
        const SizedBox(height: 16),
        _buildTextField('Vehicle', TextEditingController(text: widget.vehicleName), enabled: false),
        const SizedBox(height: 16),
        _buildDateField('Order Date', _orderDateController),
        const SizedBox(height: 16),
        _buildTextField('Tax Percentage (%)', _taxController, isNumeric: true, onChanged: (value) => setState(() => _calculateTotal())),
        const SizedBox(height: 16),
        _buildTextField('Total Vehicle Size', TextEditingController(text: widget.vehicleSize.toString()), enabled: false),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _submitOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          icon: const Icon(Icons.save, size: 20),
          label: const Text('SAVE ORDER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );

  Widget _buildTextField(String label, TextEditingController controller, {bool isNumeric = false, bool enabled = true, void Function(String)? onChanged}) => TextFormField(
    controller: controller,
    style: const TextStyle(color: _textColor, fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      filled: true,
      fillColor: _backgroundColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: _secondaryTextColor),
    ),
    keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
    inputFormatters: isNumeric ? [FilteringTextInputFormatter.digitsOnly] : null,
    validator: enabled ? (value) => value!.isEmpty ? 'Required field' : null : null,
    enabled: enabled && !_isLoading,
    onChanged: onChanged,
  );

  Widget _buildDateField(String label, TextEditingController controller) => TextFormField(
    controller: controller,
    readOnly: true,
    onTap: _isLoading ? null : () => _selectDate(controller),
    style: const TextStyle(color: _textColor, fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      filled: true,
      fillColor: _backgroundColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: _secondaryTextColor),
      suffixIcon: const Icon(Icons.calendar_today, color: _secondaryTextColor),
    ),
    validator: (value) => value!.isEmpty ? 'Required field' : null,
  );

  Widget _buildSummaryCard() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 24, spreadRadius: 2)],
    ),
    child: Column(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: CustomPaint(
            painter: CoverageProgressPainter(
              progress: widget.vehicleSize > 0 ? _items.fold(0, (sum, item) => sum + item.size * item.quantity) / widget.vehicleSize : 0.0,
              animation: _animation,
            ),
            child: Center(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  final animatedProgress = (widget.vehicleSize > 0 ? _items.fold(0, (sum, item) => sum + item.size * item.quantity) / widget.vehicleSize : 0.0) * _animation.value;
                  return Text(
                    widget.vehicleSize > 0 ? '${(animatedProgress * 100).toStringAsFixed(0)}%' : '0%',
                    style: const TextStyle(color: _textColor, fontSize: 20, fontWeight: FontWeight.bold),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildSummaryItem('Covered Items', _items.where((item) => item.covered.toLowerCase() == 'yes').fold(0, (sum, item) => sum + item.quantity).toString()),
        _buildSummaryItem('Uncovered Items', _items.where((item) => item.covered.toLowerCase() != 'yes').fold(0, (sum, item) => sum + item.quantity).toString()),
        _buildSummaryItem('Total Items', _items.fold(0, (sum, item) => sum + item.quantity).toString()),
        const Divider(),
        _buildSummaryItem('Subtotal', '${_subtotal.toStringAsFixed(0)}/-'),
        _buildSummaryItem('Tax', '${(_total - _subtotal).toStringAsFixed(0)}/-'),
        const Divider(),
        _buildSummaryItem('Total', '${_total.toStringAsFixed(0)}/-', valueStyle: const TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
      ],
    ),
  );

  Widget _buildSummaryItem(String label, String value, {TextStyle? valueStyle}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: _secondaryTextColor)),
        Text(value, style: valueStyle ?? const TextStyle(color: _textColor)),
      ],
    ),
  );

  Future<void> _showAddItemDialog() async {
    if (_isLoading) return;
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
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 24)],
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
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
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final items = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return (data['itemName'] as String? ?? '').toLowerCase().contains(_searchQuery) ||
                            (data['qualityName'] as String? ?? '').toLowerCase().contains(_searchQuery);
                      }).toList();
                      return ListView.separated(
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemCount: items.length,
                        itemBuilder: (_, index) => _buildInventoryItem(Item.fromMap(items[index].data() as Map<String, dynamic>, items[index].id)),
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
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)],
    ),
    child: const Row(
      children: [
        Expanded(child: Text('Quality', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
        Expanded(child: Text('Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
        Expanded(child: Text('Covered', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
        Expanded(child: Text('Price', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
      ],
    ),
  );

  Widget _buildInventoryItem(Item item) => InkWell(
    onTap: _isLoading ? null : () => _addItem(item),
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Expanded(child: Text(item.quality, style: const TextStyle(color: _textColor), textAlign: TextAlign.center)),
          Expanded(child: Text(item.name, style: const TextStyle(color: _textColor), textAlign: TextAlign.center)),
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
                  style: TextStyle(color: item.covered.toLowerCase() == "yes" ? Colors.green[800] : Colors.red[800], fontSize: 12, fontWeight: FontWeight.w500),
                ),
              )),
          Expanded(child: Text(item.purchasePrice.toStringAsFixed(0), style: const TextStyle(color: _textColor), textAlign: TextAlign.center)),
        ],
      ),
    ),
  );

  Future<void> _selectDate(TextEditingController controller) async {
    if (_isLoading) return;
    final pickedDate = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2101));
    if (pickedDate != null) setState(() => controller.text = DateFormat('dd-MM-yyyy').format(pickedDate));
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
  bool _isLoading = false;

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
            const Text('Select Company & Vehicle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textColor)),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  items: snapshot.data!.docs.map((doc) => DropdownMenuItem<String>(value: doc['name'], child: Text(doc['name'] ?? '', style: const TextStyle(color: _textColor)))).toList(),
                  onChanged: _isLoading ? null : (value) => setState(() => selectedCompany = value),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  items: snapshot.data!.docs
                      .map((doc) => DropdownMenuItem<String>(
                    value: doc['name'],
                    child: Text(doc['name'] ?? '', style: const TextStyle(color: _textColor)),
                    onTap: () => selectedVehicleSize = doc['size'] as int? ?? 0,
                  ))
                      .toList(),
                  onChanged: _isLoading ? null : (value) => setState(() => selectedVehicle = value),
                  validator: (value) => value == null ? 'Required field' : null,
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel', style: TextStyle(color: _secondaryTextColor, fontSize: 14)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () {
                    if (selectedCompany != null && selectedVehicle != null && selectedVehicleSize != null) {
                      Navigator.pop(context, {'company': selectedCompany, 'vehicle': selectedVehicle, 'vehicleSize': selectedVehicleSize});
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
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Center(child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis)),
  );
}

class _DataCell extends StatelessWidget {
  final String text;
  final double? width;

  const _DataCell(this.text, [this.width]);

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Center(child: Text(text, style: const TextStyle(color: _textColor, fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 1)),
  );
}

class _ActionCell extends StatelessWidget {
  final DocumentSnapshot orderDoc;
  final double? width;
  final Function(DocumentSnapshot) onView;
  final Function(DocumentSnapshot) onEdit;
  final Function(DocumentSnapshot) onDelete;

  const _ActionCell(this.orderDoc, this.width, {required this.onView, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.remove_red_eye, color: Colors.blue, size: 20), onPressed: () => onView(orderDoc), tooltip: 'View Order'),
          IconButton(icon: const Icon(Icons.edit, color: _primaryColor, size: 20), onPressed: () => onEdit(orderDoc), tooltip: 'Edit Order'),
          IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => onDelete(orderDoc), tooltip: 'Delete Order'),
        ],
      ),
    );
  }
}