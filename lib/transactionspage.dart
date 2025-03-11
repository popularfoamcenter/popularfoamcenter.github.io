import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'pointofsale.dart'; // Assuming this is where PointOfSalePage, Invoice, and CartItem are defined

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
  final double _mobileTableWidth = 1500; // Adjusted width after removing delete button

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

  void _showPrintOptions(DocumentSnapshot transactionDoc) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _backgroundColor,
          title: const Text('Select Print Size'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('A4'),
                onTap: () {
                  Navigator.pop(context);
                  _printA4(transactionDoc);
                },
              ),
              ListTile(
                title: const Text('80x297 (Thermal)'),
                onTap: () {
                  Navigator.pop(context);
                  _print800(transactionDoc);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _printA4(DocumentSnapshot transactionDoc) async {
    final invoice = Invoice.fromMap(transactionDoc.id, transactionDoc.data() as Map<String, dynamic>);
    try {
      final pdf = pw.Document();
      final numberFormat = NumberFormat.currency(decimalDigits: 0, symbol: '');
      final Uint8List logoImage = (await rootBundle.load('assets/images/logo1.png')).buffer.asUint8List();
      DateTime invoiceDate = invoice.timestamp is Timestamp
          ? (invoice.timestamp as Timestamp).toDate()
          : DateTime.now();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(
            base: await PdfGoogleFonts.openSansRegular(),
            bold: await PdfGoogleFonts.openSansBold(),
          ),
          build: (_) => pw.Stack(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
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
                                  color: PdfColor.fromHex('#0D6EFD'))),
                          pw.SizedBox(height: 8),
                          pw.Text('Popular Foam Center',
                              style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black)),
                          pw.Text('Zanana Hospital Road, Bahawalpur (63100)',
                              style: pw.TextStyle(fontSize: 10, color: PdfColors.black)),
                        ],
                      ),
                      pw.Image(pw.MemoryImage(logoImage), width: 135, height: 135),
                    ],
                  ),
                  pw.Divider(color: PdfColor.fromHex('#0D6EFD'), height: 40),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Bill To:',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 12,
                                  color: PdfColors.black)),
                          pw.Text(invoice.customer['name'] ?? 'Walking Customer',
                              style: const pw.TextStyle(fontSize: 14, color: PdfColors.black)),
                          pw.SizedBox(height: 8),
                          pw.Text('Invoice Date:',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 12,
                                  color: PdfColors.black)),
                          pw.Text(DateFormat('dd-MM-yyyy').format(invoiceDate),
                              style: const pw.TextStyle(fontSize: 12, color: PdfColors.black)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Invoice #${invoice.invoiceNumber}',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 14,
                                  color: PdfColor.fromHex('#0D6EFD'))),
                          pw.SizedBox(height: 8),
                          pw.Text('Transaction Type:',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 12,
                                  color: PdfColors.black)),
                          pw.Text(invoice.type.toUpperCase(),
                              style: const pw.TextStyle(fontSize: 12, color: PdfColors.black)),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 30),
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
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#0D6EFD')),
                        children: ['Item Description', 'Qty', 'Unit Price', 'Disc.%', 'Total']
                            .map((text) => pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(text,
                              style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold)),
                        ))
                            .toList(),
                      ),
                      ...invoice.items.map((item) => pw.TableRow(
                        children: [
                          pw.Container(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('${item.quality} ${item.itemName}',
                                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
                          pw.Container(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(item.qty.toStringAsFixed(2),
                                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
                          pw.Container(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(numberFormat.format(int.parse(item.price)),
                                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
                          pw.Container(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('${item.discount}%',
                                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
                          pw.Container(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(numberFormat.format(double.parse(item.total)),
                                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
                        ],
                      )),
                    ],
                  ),
                  pw.SizedBox(height: 25),
                  pw.Container(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                          pw.Text('Subtotal:',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black)),
                          pw.SizedBox(width: 15),
                          pw.Text(numberFormat.format(invoice.subtotal),
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
                        ]),
                        pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                          pw.Text('Global Discount:',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black)),
                          pw.SizedBox(width: 15),
                          pw.Text('-${numberFormat.format(invoice.globalDiscount)}',
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.red)),
                        ]),
                        pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                          pw.Text('Total Amount:',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black)),
                          pw.SizedBox(width: 15),
                          pw.Text(numberFormat.format(invoice.total),
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
                        ]),
                        pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                          pw.Text('Amount Received:',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black)),
                          pw.SizedBox(width: 15),
                          pw.Text(numberFormat.format(invoice.givenAmount),
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
                        ]),
                        if (invoice.returnAmount > 0)
                          pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                            pw.Text('Change Due:',
                                style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.black)),
                            pw.SizedBox(width: 15),
                            pw.Text(numberFormat.format(invoice.returnAmount),
                                style: const pw.TextStyle(fontSize: 10, color: PdfColors.green)),
                          ]),
                        if (invoice.balanceDue > 0)
                          pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                            pw.Text('Balance Due:',
                                style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.black)),
                            pw.SizedBox(width: 15),
                            pw.Text(numberFormat.format(invoice.balanceDue),
                                style: const pw.TextStyle(fontSize: 10, color: PdfColors.orange)),
                          ]),
                        pw.SizedBox(height: 15),
                        pw.Container(
                          width: 250,
                          padding: const pw.EdgeInsets.all(12),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#F8F9FA'),
                            borderRadius: pw.BorderRadius.circular(6),
                            border: pw.Border.all(color: PdfColor.fromHex('#0D6EFD'), width: 1),
                          ),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('TOTAL AMOUNT',
                                  style: pw.TextStyle(
                                      fontSize: 12,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.black)),
                              pw.Text(numberFormat.format(invoice.total),
                                  style: pw.TextStyle(
                                      fontSize: 14,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColor.fromHex('#0D6EFD'))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F8F9FA'),
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColor.fromHex('#0D6EFD'), width: 1),
                    ),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Thank you for choosing Popular Foam Center',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#0D6EFD'),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Contact: 0302-9596046 | Facebook: Popular Foam Center',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.black)),
                      pw.Text('Notes: Claims as per company policy',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.black)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      final pdfBytes = await pdf.save();
      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'PFC-INV-${invoice.invoiceNumber}-A4',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A4 Invoice printed successfully!')),
      );
    } catch (e) {
      print('Error in _printA4: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to print A4 invoice: $e')),
      );
    }
  }

  Future<void> _print800(DocumentSnapshot transactionDoc) async {
    final invoice = Invoice.fromMap(transactionDoc.id, transactionDoc.data() as Map<String, dynamic>);
    try {
      final pdf = pw.Document();
      final numberFormat = NumberFormat.currency(decimalDigits: 0, symbol: '');
      final Uint8List logoImage = (await rootBundle.load('assets/images/logo1.png')).buffer.asUint8List();
      DateTime invoiceDate = invoice.timestamp is Timestamp
          ? (invoice.timestamp as Timestamp).toDate()
          : DateTime.now();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 5 * PdfPageFormat.mm),
          theme: pw.ThemeData.withFont(
            base: await PdfGoogleFonts.robotoRegular(),
            bold: await PdfGoogleFonts.robotoBold(),
          ),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Logo and Header
              pw.Image(pw.MemoryImage(logoImage), width: 40, height: 40),
              pw.SizedBox(height: 3),
              pw.Text(
                'Popular Foam Center',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Zanana Hospital Road, Bahawalpur',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 3),
              pw.Divider(thickness: 1, color: PdfColor.fromHex('#0D6EFD')),

              // Invoice Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'INV #${invoice.invoiceNumber}',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0D6EFD')),
                  ),
                  pw.Text(
                    DateFormat('dd-MM-yy HH:mm').format(invoiceDate),
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Type: ${invoice.type.toUpperCase()}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                  pw.Text('Cashier: M.Hashim', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'To: ${invoice.customer['name'] ?? 'Walking Customer'}',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),

              // Items Table
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.5), // Item Name
                  1: const pw.FlexColumnWidth(1),   // Qty
                  2: const pw.FlexColumnWidth(1.5), // Total
                },
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text('Item', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text('Qty', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text('Total', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  ...invoice.items.map((item) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text(
                          '${item.quality} ${item.itemName}',
                          style: pw.TextStyle(fontSize: 7, color: PdfColors.black),
                          maxLines: 2,
                          overflow: pw.TextOverflow.clip,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text(
                          item.qty.toStringAsFixed(0),
                          style: pw.TextStyle(fontSize: 7),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text(
                          numberFormat.format(double.parse(item.total)),
                          style: pw.TextStyle(fontSize: 7),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  )),
                ],
              ),
              pw.SizedBox(height: 8),

              // Totals Section
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#0D6EFD'), width: 1),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Subtotal:', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                        pw.Text(numberFormat.format(invoice.subtotal), style: pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                    if (invoice.globalDiscount > 0)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Discount:', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                          pw.Text('-${numberFormat.format(invoice.globalDiscount)}', style: pw.TextStyle(fontSize: 8, color: PdfColors.red)),
                        ],
                      ),
                    pw.SizedBox(height: 3),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                        pw.Text(
                          numberFormat.format(invoice.total),
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0D6EFD')),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 3),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Received:', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                        pw.Text(numberFormat.format(invoice.givenAmount), style: pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                    if (invoice.returnAmount > 0)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Change:', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                          pw.Text(numberFormat.format(invoice.returnAmount), style: pw.TextStyle(fontSize: 8, color: PdfColors.green)),
                        ],
                      ),
                    if (invoice.balanceDue > 0)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Due:', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                          pw.Text(numberFormat.format(invoice.balanceDue), style: pw.TextStyle(fontSize: 8, color: PdfColors.orange)),
                        ],
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1, color: PdfColor.fromHex('#0D6EFD')),

              // Footer
              pw.Text(
                'Thank You!',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0D6EFD')),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Contact: 0302-9596046',
                style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'FB: Popular Foam Center',
                style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Claims as per policy',
                style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 5), // Final spacing to ensure footer is fully printed
            ],
          ),
        ),
      );

      final pdfBytes = await pdf.save();
      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'PFC-INV-${invoice.invoiceNumber}-80mm',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('80mm Invoice printed successfully!')),
      );
    } catch (e) {
      print('Error in _print800: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to print 80mm invoice: $e')),
      );
    }
  }

  Future<void> _completeOrder(DocumentSnapshot transactionDoc, double additionalAmount) async {
    final invoice = Invoice.fromMap(transactionDoc.id, transactionDoc.data() as Map<String, dynamic>);
    if (invoice.type != 'Order Booking') return;

    final invoiceRef = _firestore.collection('invoices').doc(invoice.id);

    try {
      await _firestore.runTransaction((transaction) async {
        // Update stock for Order Booking to Sale conversion
        for (final item in invoice.items) {
          final snapshot = await _firestore
              .collection('items')
              .where('itemName', isEqualTo: item.itemName)
              .where('qualityName', isEqualTo: item.quality)
              .limit(1)
              .get(GetOptions(source: Source.server));

          if (snapshot.docs.isNotEmpty) {
            final ref = snapshot.docs.first.reference;
            final currentStock = (snapshot.docs.first['stockQuantity'] as num?)?.toDouble() ?? 0.0;
            final newStock = currentStock - item.qty; // Deduct full qty as per PointOfSalePage logic
            if (newStock < 0) throw Exception('Insufficient stock for ${item.itemName}');
            transaction.update(ref, {'stockQuantity': newStock});
          }
        }

        // Update invoice with new payment details
        final newGivenAmount = invoice.givenAmount + additionalAmount;
        final newBalanceDue = (invoice.total - newGivenAmount).clamp(0, double.infinity);
        final newReturnAmount = (newGivenAmount - invoice.total).clamp(0, double.infinity);

        final updatedData = invoice.toMap()
          ..['type'] = 'Sale'
          ..['givenAmount'] = newGivenAmount
          ..['balanceDue'] = newBalanceDue
          ..['returnAmount'] = newReturnAmount;

        transaction.update(invoiceRef, updatedData);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order completed successfully!'), backgroundColor: Colors.green),
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing order: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showPaymentDialog(DocumentSnapshot transactionDoc) {
    final invoice = Invoice.fromMap(transactionDoc.id, transactionDoc.data() as Map<String, dynamic>);
    final numberFormat = NumberFormat.currency(decimalDigits: 0, symbol: '');
    TextEditingController amountReceivedController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 24)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Center(
                    child: Text('Complete Order Payment',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor)),
                  ),
                  Positioned(
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: _secondaryTextColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildPaymentDetailRow('Subtotal', '${invoice.subtotal.toStringAsFixed(0)}/-'),
              const SizedBox(height: 12),
              _buildPaymentDetailRow('Total After Discount', '${invoice.total.toStringAsFixed(0)}/-',
                  valueColor: _primaryColor),
              const SizedBox(height: 12),
              _buildPaymentDetailRow('Paid Amount', '${numberFormat.format(invoice.givenAmount)}/-',
                  valueColor: Colors.green),
              const SizedBox(height: 12),
              _buildPaymentDetailRow('Remaining Amount', '${numberFormat.format(invoice.balanceDue)}/-',
                  valueColor: Colors.orange),
              const SizedBox(height: 24),
              TextFormField(
                controller: amountReceivedController,
                decoration: InputDecoration(
                  labelText: 'Amount Received',
                  prefixIcon: const Icon(Icons.payment, color: _primaryColor),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: _backgroundColor,
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                onChanged: (value) {
                  // Optionally, you can add real-time feedback here if needed
                },
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final additionalAmount = double.tryParse(amountReceivedController.text) ?? 0.0;
                        final newTotalPaid = invoice.givenAmount + additionalAmount;

                        if (additionalAmount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid amount!'), backgroundColor: Colors.red),
                          );
                          return;
                        }

                        if (newTotalPaid >= invoice.total) {
                          await _completeOrder(transactionDoc, additionalAmount);
                          Navigator.pop(context); // Close dialog after completion
                          // Navigate to view the updated invoice
                          final updatedInvoice = Invoice.fromMap(transactionDoc.id, (await transactionDoc.reference.get()).data() as Map<String, dynamic>);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => PointOfSalePage(invoice: updatedInvoice, isReadOnly: true)),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Total paid amount (${newTotalPaid.toStringAsFixed(0)}) must be at least the total amount (${invoice.total.toStringAsFixed(0)})!'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text('Complete & Save', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentDetailRow(String label, String value, {Color? valueColor}) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: _secondaryTextColor)),
        Text(value, style: TextStyle(color: valueColor ?? _textColor, fontWeight: FontWeight.bold))
      ]);

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
    final isOrderBooking = invoice.type == 'Order Booking';

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
            Expanded(
              child: _ActionCell(
                transactionDoc,
                null, // No explicit width for desktop, using Expanded
                onView: _viewTransaction,
                onEdit: _editTransaction,
                onPrint: _showPrintOptions,
                onComplete: isOrderBooking ? () => _showPaymentDialog(transactionDoc) : null,
              ),
            ),
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
          _HeaderCell('Actions', 150),
        ],
      ),
    ),
  );

  Widget _buildMobileRow(DocumentSnapshot transactionDoc) {
    final invoice = Invoice.fromMap(transactionDoc.id, transactionDoc.data() as Map<String, dynamic>);
    final total = invoice.total.toStringAsFixed(0);
    final pending = invoice.balanceDue.toStringAsFixed(0);
    final date = _formatDate(invoice.timestamp);
    final isOrderBooking = invoice.type == 'Order Booking';

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
            _ActionCell(
              transactionDoc,
              150, // Explicitly pass width for mobile layout
              onView: _viewTransaction,
              onEdit: _editTransaction,
              onPrint: _showPrintOptions,
              onComplete: isOrderBooking ? () => _showPaymentDialog(transactionDoc) : null,
            ),
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
                fontSize: 12,
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
            fontSize: 12,
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
  final Function(DocumentSnapshot)? onView;
  final Function(DocumentSnapshot)? onEdit;
  final Function(DocumentSnapshot)? onPrint;
  final Function()? onComplete;

  const _ActionCell(this.transactionDoc, this.width,
      {this.onView, this.onEdit, this.onPrint, this.onComplete});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (onView != null)
            IconButton(icon: const Icon(Icons.remove_red_eye, color: Colors.blue, size: 20), onPressed: () => onView!(transactionDoc), tooltip: 'View Transaction'),
          if (onEdit != null)
            IconButton(icon: const Icon(Icons.edit, color: _primaryColor, size: 20), onPressed: () => onEdit!(transactionDoc), tooltip: 'Edit Transaction'),
          if (onPrint != null)
            IconButton(icon: const Icon(Icons.print, color: Colors.green, size: 20), onPressed: () => onPrint!(transactionDoc), tooltip: 'Print Invoice'),
          if (onComplete != null)
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.purple, size: 20),
              onPressed: onComplete,
              tooltip: 'Complete Order',
            ),
        ],
      ),
    );
  }
}