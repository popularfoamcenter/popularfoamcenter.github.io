import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceListPage extends StatefulWidget {
  @override
  _InvoiceListPageState createState() => _InvoiceListPageState();
}

class _InvoiceListPageState extends State<InvoiceListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color _primaryColor = const Color(0xFF0D6EFD);
  final Color _textColor = const Color(0xFF2D2D2D);
  final Color _secondaryTextColor = const Color(0xFF4A4A4A);
  final Color _backgroundColor = const Color(0xFFF8F9FA);
  final Color _surfaceColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        title: Text("Invoices", style: TextStyle(
            color: _textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600
        )),
      ),
      backgroundColor: _backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildInvoiceHeader(),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('invoices')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: _primaryColor));
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}',
                        style: TextStyle(color: _textColor)));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('No invoices found.',
                        style: TextStyle(color: _textColor)));
                  }

                  final invoices = snapshot.data!.docs;

                  return ListView.separated(
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: invoices.length,
                    itemBuilder: (context, index) {
                      final invoice = invoices[index].data() as Map<String, dynamic>;
                      final invoiceId = invoices[index].id;
                      return _buildInvoiceItem(invoice, invoiceId);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4)
        )],
      ),
      child: const Row(
        children: [
          Expanded(child: Text('Invoice#',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
          Expanded(child: Text('Customer',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
          Expanded(child: Text('Total',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
          Expanded(child: Text('Type',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
          Expanded(child: Text('Date',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildInvoiceItem(Map<String, dynamic> invoice, String invoiceId) {
    final customer = invoice['customer'] ?? walkingCustomer;
    final total = invoice['total'] ?? 0;
    final type = invoice['type'] ?? 'Sale';
    final date = (invoice['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

    return GestureDetector(
      onTap: () => _showInvoiceDetails(invoiceId),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4)
          )],
        ),
        child: Row(
          children: [
            Expanded(child: Text('#${invoice['invoiceNumber']}',
                style: TextStyle(color: _textColor), textAlign: TextAlign.center)),
            Expanded(child: Text(customer['name'],
                style: TextStyle(color: _textColor), textAlign: TextAlign.center)),
            Expanded(child: Text('$total',
                style: TextStyle(color: _textColor), textAlign: TextAlign.center)),
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: type == 'Return'
                    ? Colors.red.withOpacity(0.1)
                    : _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(type,
                  style: TextStyle(
                      color: type == 'Return' ? Colors.red : _primaryColor,
                      fontWeight: FontWeight.w600
                  ),
                  textAlign: TextAlign.center),
            )),
            Expanded(child: Text(
                '${date.day}/${date.month}/${date.year}',
                style: TextStyle(color: _secondaryTextColor),
                textAlign: TextAlign.center
            )),
          ],
        ),
      ),
    );
  }

  void _showInvoiceDetails(String invoiceId) {
    Navigator.push(context, MaterialPageRoute(
        builder: (context) => InvoiceDetailsPage(invoiceId: invoiceId)
    ));
  }
}

class InvoiceDetailsPage extends StatelessWidget {
  final String invoiceId;
  final Color _primaryColor = const Color(0xFF0D6EFD);
  final Color _textColor = const Color(0xFF2D2D2D);
  final Color _secondaryTextColor = const Color(0xFF4A4A4A);
  final Color _backgroundColor = const Color(0xFFF8F9FA);
  final Color _surfaceColor = Colors.white;

  const InvoiceDetailsPage({required this.invoiceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        title: Text("Invoice Details", style: TextStyle(
            color: _textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600
        )),
      ),
      backgroundColor: _backgroundColor,
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('invoices').doc(invoiceId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _primaryColor));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Invoice not found',
                style: TextStyle(color: _textColor)));
          }

          final invoice = snapshot.data!.data() as Map<String, dynamic>;
          final items = invoice['items'] as List<dynamic>;
          final customer = invoice['customer'] ?? walkingCustomer;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Customer Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4)
                    )],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customer: ${customer['name']}',
                          style: TextStyle(
                              color: _textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600
                          )),
                      if (customer['phone']?.isNotEmpty ?? false)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Phone: ${customer['phone']}',
                              style: TextStyle(color: _secondaryTextColor)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Items List
                Expanded(
                  child: Column(
                    children: [
                      _buildItemsHeader(),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemCount: items.length,
                          itemBuilder: (context, index) =>
                              _buildItemRow(items[index] as Map<String, dynamic>),
                        ),
                      ),
                    ],
                  ),
                ),

                // Payment Summary
                _buildPaymentSummary(invoice),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4)
        )],
      ),
      child: const Row(
        children: [
          Expanded(child: Text('Quality',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
          Expanded(child: Text('Item',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
          Expanded(child: Text('Cvrd',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
          Expanded(child: Text('Qty',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
          Expanded(child: Text('Price',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
          Expanded(child: Text('Dis%',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
          Expanded(child: Text('Amount',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4)
        )],
      ),
      child: Row(
        children: [
          Expanded(child: Text(item['quality'],
              style: TextStyle(color: _textColor), textAlign: TextAlign.center)),
          Expanded(child: Text(item['item'],
              style: TextStyle(color: _textColor), textAlign: TextAlign.center)),
          Expanded(child: Text(item['covered'],
              style: TextStyle(color: _textColor), textAlign: TextAlign.center)),
          Expanded(child: Text(item['qty'],
              style: TextStyle(color: _textColor), textAlign: TextAlign.center)),
          Expanded(child: Text(item['price'],
              style: TextStyle(color: _textColor), textAlign: TextAlign.center)),
          Expanded(child: Text(item['discount'],
              style: TextStyle(color: _textColor), textAlign: TextAlign.center)),
          Expanded(child: Text(item['total'],
              style: TextStyle(
                  color: _textColor,
                  fontWeight: FontWeight.w600
              ), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildPaymentSummary(Map<String, dynamic> invoice) {
    final subtotal = invoice['subtotal'] ?? 0;
    final discount = invoice['globalDiscount'] ?? 0;
    final total = invoice['total'] ?? 0;
    final paid = invoice['paid'] ?? 0;
    final due = invoice['due'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 8)
        )],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal:', style: TextStyle(color: _secondaryTextColor)),
              Text('$subtotal', style: TextStyle(color: _textColor)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Global Discount:', style: TextStyle(color: _secondaryTextColor)),
              Text('$discount', style: TextStyle(color: _textColor)),
            ],
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total:', style: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 16
              )),
              Text('$total', style: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16
              )),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Paid Amount:', style: TextStyle(color: _secondaryTextColor)),
              Text('$paid', style: TextStyle(color: _textColor)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Balance Due:', style: TextStyle(color: _secondaryTextColor)),
              Text('$due', style: TextStyle(
                  color: due > 0 ? Colors.red : _textColor,
                  fontWeight: FontWeight.w600
              )),
            ],
          ),
        ],
      ),
    );
  }
}

// Add this at the bottom of your file (same as POS page)
const Map<String, dynamic> walkingCustomer = {
  'id': 'walking',
  'name': 'Walking Customer',
  'phone': ''
};