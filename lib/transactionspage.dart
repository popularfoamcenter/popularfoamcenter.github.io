import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'pointofsale.dart'; // Assuming this is where PointOfSalePage is defined

// Color Scheme Matching Purchase Invoice
const Color _primaryColor = Color(0xFF0D6EFD);
const Color _textColor = Color(0xFF2D2D2D);
const Color _secondaryTextColor = Color(0xFF4A4A4A);
const Color _backgroundColor = Color(0xFFF8F9FA);
const Color _surfaceColor = Colors.white;

class TransactionsPage extends StatefulWidget {
  @override
  _TransactionsPageState createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final ScrollController _horizontalScrollController = ScrollController();
  final double _mobileTableWidth = 1400; // Increased to accommodate new ID column

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Trigger rebuild when tab changes
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  void _viewTransaction(DocumentSnapshot transactionDoc) {
    final invoice = Invoice.fromMap(transactionDoc.id, transactionDoc.data() as Map<String, dynamic>);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PointOfSalePage(invoice: invoice, isReadOnly: true),
      ),
    );
  }

  void _editTransaction(DocumentSnapshot transactionDoc) {
    final invoice = Invoice.fromMap(transactionDoc.id, transactionDoc.data() as Map<String, dynamic>);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PointOfSalePage(invoice: invoice),
      ),
    );
  }

  Future<void> _deleteTransaction(DocumentSnapshot transactionDoc) async {
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
              const Text('Are you sure you want to delete this transaction?', style: TextStyle(fontSize: 14, color: _secondaryTextColor)),
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
        await _firestore.collection('invoices').doc(transactionDoc.id).delete();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction deleted successfully!')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting transaction: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 1200;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History', style: TextStyle(color: _textColor)),
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _textColor),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: _secondaryTextColor,
              indicator: const BoxDecoration(), // Remove default indicator
              tabs: [
                _TabButton(label: 'Today', index: 0, controller: _tabController),
                _TabButton(label: 'Sales', index: 1, controller: _tabController),
                _TabButton(label: 'Returns', index: 2, controller: _tabController),
                _TabButton(label: 'Orders', index: 3, controller: _tabController),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: _backgroundColor,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(child: _buildSearchBar()),
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
    return TabBarView(
      controller: _tabController,
      physics: const NeverScrollableScrollPhysics(), // Disable swiping
      children: [
        _buildTodayTransactions(),
        _buildTransactionsByType('Sale'),
        _buildTransactionsByType('Return'),
        _buildTransactionsByType('Order Booking'),
      ],
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
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(), // Disable swiping
            children: [
              _buildTodayTransactions(),
              _buildTransactionsByType('Sale'),
              _buildTransactionsByType('Return'),
              _buildTransactionsByType('Order Booking'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayTransactions() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('invoices')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('timestamp', descending: true) // Latest to oldest
          .snapshots(),
      builder: (context, snapshot) => _buildTransactionList(snapshot),
    );
  }

  Widget _buildTransactionsByType(String type) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('invoices')
          .where('type', isEqualTo: type)
          .orderBy('timestamp', descending: true) // Latest to oldest
          .snapshots(),
      builder: (context, snapshot) => _buildTransactionList(snapshot),
    );
  }

  Widget _buildTransactionList(AsyncSnapshot<QuerySnapshot> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _primaryColor));
    if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: _textColor)));

    final transactions = snapshot.data?.docs.where((doc) => (doc['customer']?['name'] as String? ?? '').toLowerCase().contains(_searchQuery)).toList() ?? [];
    if (transactions.isEmpty) return const Center(child: Text('No transactions found', style: TextStyle(color: _textColor)));

    return Column(
      children: [
        _buildDesktopHeader(),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: transactions.length,
            itemBuilder: (context, index) => _buildDesktopRow(transactions[index]),
          ),
        ),
      ],
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
          Expanded(child: _HeaderCell('ID')),
          Expanded(child: _HeaderCell('Customer')),
          Expanded(child: _HeaderCell('Type')),
          Expanded(child: _HeaderCell('Total')),
          Expanded(child: _HeaderCell('Pending')),
          Expanded(child: _HeaderCell('Date')),
          Expanded(child: _HeaderCell('Actions')),
        ],
      ),
    ),
  );

  Widget _buildDesktopRow(DocumentSnapshot transactionDoc) {
    final invoice = Invoice.fromMap(transactionDoc.id, transactionDoc.data() as Map<String, dynamic>);
    final total = invoice.total.toStringAsFixed(0);
    final pending = invoice.balanceDue.toStringAsFixed(0);
    final date = _formatDate(invoice.timestamp);

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
            Expanded(child: _DataCell(invoice.invoiceNumber.toString())),
            Expanded(child: _DataCell(invoice.customer['name'] ?? 'Walking Customer')),
            Expanded(child: _DataCell('', null, _getTypeLabel(invoice.type), _getTypeColor(invoice.type))),
            Expanded(child: _DataCell(total)),
            Expanded(child: _DataCell(invoice.balanceDue > 0 ? pending : '', null, invoice.balanceDue > 0 ? 'Pending' : 'Paid', invoice.balanceDue > 0 ? Colors.red : Colors.green)),
            Expanded(child: _DataCell(date)),
            Expanded(child: _ActionCell(transactionDoc, null, onView: _viewTransaction, onEdit: _editTransaction, onDelete: _deleteTransaction)),
          ],
        ),
      ),
    );
  }

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
          _HeaderCell('ID', 200),
          _HeaderCell('Customer', 200),
          _HeaderCell('Type', 150),
          _HeaderCell('Total', 150),
          _HeaderCell('Pending', 150),
          _HeaderCell('Date', 150),
          _HeaderCell('Actions', 200),
        ],
      ),
    ),
  );

  Widget _buildMobileRow(DocumentSnapshot transactionDoc) {
    final invoice = Invoice.fromMap(transactionDoc.id, transactionDoc.data() as Map<String, dynamic>);
    final total = invoice.total.toStringAsFixed(0);
    final pending = invoice.balanceDue.toStringAsFixed(0);
    final date = _formatDate(invoice.timestamp);

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
            _DataCell(invoice.invoiceNumber.toString(), 200),
            _DataCell(invoice.customer['name'] ?? 'Walking Customer', 200),
            _DataCell('', 150, _getTypeLabel(invoice.type), _getTypeColor(invoice.type)),
            _DataCell(total, 150),
            _DataCell(invoice.balanceDue > 0 ? pending : '', 150, invoice.balanceDue > 0 ? 'Pending' : 'Paid', invoice.balanceDue > 0 ? Colors.red : Colors.green),
            _DataCell(date, 150),
            _ActionCell(transactionDoc, 200, onView: _viewTransaction, onEdit: _editTransaction, onDelete: _deleteTransaction),
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
        hintText: 'Search transactions...',
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

  Widget _buildTransactionListMobile(AsyncSnapshot<QuerySnapshot> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _primaryColor));
    if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: _textColor)));

    final transactions = snapshot.data?.docs.where((doc) => (doc['customer']?['name'] as String? ?? '').toLowerCase().contains(_searchQuery)).toList() ?? [];
    if (transactions.isEmpty) return const Center(child: Text('No transactions found', style: TextStyle(color: _textColor)));

    return Column(
      children: [
        _buildMobileHeader(),
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: transactions.length,
            itemBuilder: (context, index) => _buildMobileRow(transactions[index]),
          ),
        ),
      ],
    );
  }

  String _getTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'sale':
        return 'SALE';
      case 'return':
        return 'RETURN';
      case 'order booking':
        return 'ORDER';
      default:
        return type.toUpperCase();
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'sale':
        return Colors.blue;
      case 'return':
        return Colors.orange;
      case 'order booking':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

// Tab Button Widget with Hover Effect
class _TabButton extends StatefulWidget {
  final String label;
  final int index;
  final TabController controller;

  const _TabButton({required this.label, required this.index, required this.controller});

  @override
  __TabButtonState createState() => __TabButtonState();
}

class __TabButtonState extends State<_TabButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => widget.controller.animateTo(widget.index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: _primaryColor, width: 1),
            borderRadius: BorderRadius.circular(12),
            color: widget.controller.index == widget.index ? _primaryColor : _surfaceColor,
            boxShadow: _isHovered ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: widget.controller.index == widget.index ? Colors.white : _secondaryTextColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Helper Components
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
  final String? label;
  final Color? labelColor;

  const _DataCell(this.text, [this.width, this.label, this.labelColor]);

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    width: width,
    child: Center(
      child: label != null && text.isNotEmpty
          ? Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: labelColor?.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label!,
              style: TextStyle(
                color: labelColor ?? _textColor,
                fontSize: 12, // Increased from 10 to 12 for larger labels
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: _textColor, fontSize: 14),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      )
          : label != null
          ? Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: labelColor?.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label!,
          style: TextStyle(
            color: labelColor ?? _textColor,
            fontSize: 12, // Increased from 10 to 12 for larger labels
            fontWeight: FontWeight.w600,
          ),
        ),
      )
          : Text(
        text,
        style: const TextStyle(color: _textColor, fontSize: 14),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    ),
  );
}

class _ActionCell extends StatelessWidget {
  final DocumentSnapshot transactionDoc;
  final double? width;
  final Function(DocumentSnapshot) onView;
  final Function(DocumentSnapshot) onEdit;
  final Function(DocumentSnapshot) onDelete;

  const _ActionCell(this.transactionDoc, this.width, {required this.onView, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.remove_red_eye, color: Colors.blue, size: 20), onPressed: () => onView(transactionDoc), tooltip: 'View Transaction'),
          IconButton(icon: const Icon(Icons.edit, color: _primaryColor, size: 20), onPressed: () => onEdit(transactionDoc), tooltip: 'Edit Transaction'),
          IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => onDelete(transactionDoc), tooltip: 'Delete Transaction'),
        ],
      ),
    );
  }
}