import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart'; // For compute
import 'pointofsale.dart'; // Assuming this is where PointOfSalePage, Invoice, and CartItem are defined

// Color Scheme Matching Purchase Invoice
const Color _primaryColor = Color(0xFF0D6EFD);
const Color _textColor = Color(0xFF2D2D2D);
const Color _secondaryTextColor = Color(0xFF4A4A4A);
const Color _backgroundColor = Color(0xFFF8F9FA);
const Color _surfaceColor = Colors.white;

// Sorting function for isolate
List<CartItem> sortItems(List<CartItem> items) {
  return List<CartItem>.from(items)
    ..sort((a, b) {
      final aQuality = (a.quality ?? '').toLowerCase();
      final bQuality = (b.quality ?? '').toLowerCase();
      final qualityComparison = aQuality.compareTo(bQuality);
      if (qualityComparison != 0) return qualityComparison;
      final aName = (a.itemName ?? '').toLowerCase();
      final bName = (b.itemName ?? '').toLowerCase();
      return aName.compareTo(bName);
    });
}

class TransactionsPage extends StatefulWidget {
  @override
  _TransactionsPageState createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final ScrollController _horizontalScrollController = ScrollController();
  final double _mobileTableWidth = 1650;

  late TabController _tabController;
  late Uint8List logoImage;
  late pw.Font baseFont;
  late pw.Font boldFont;

  @override
  void initState() {
    super.initState();
    _loadAssets();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  Future<void> _loadAssets() async {
    logoImage = (await rootBundle.load('assets/images/logo1.png')).buffer.asUint8List();
    baseFont = await PdfGoogleFonts.openSansRegular();
    boldFont = await PdfGoogleFonts.openSansBold();
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: _primaryColor)),
    );

    final invoice = Invoice.fromMap(transactionDoc.id, transactionDoc.data() as Map<String, dynamic>);
    try {
      final pdf = pw.Document();
      final numberFormat = NumberFormat.currency(decimalDigits: 0, symbol: '');
      DateTime invoiceDate = invoice.timestamp is Timestamp
          ? (invoice.timestamp as Timestamp).toDate()
          : DateTime.now();

      // Batch fetch packaging units
      final Map<String, String> packagingUnits = {};
      final itemKeys = invoice.items.map((item) => '${item.itemName}-${item.quality}').toSet().toList();
      if (itemKeys.isNotEmpty) {
        final uniqueItemNames = itemKeys.map((key) => key.split('-')[0]).toSet().toList();
        // Split into batches of 10 due to Firestore 'whereIn' limit
        for (int i = 0; i < uniqueItemNames.length; i += 10) {
          final batch = uniqueItemNames.sublist(i, i + 10 > uniqueItemNames.length ? uniqueItemNames.length : i + 10);
          final querySnapshot = await FirebaseFirestore.instance
              .collection('items')
              .where('itemName', whereIn: batch)
              .get();
          for (var doc in querySnapshot.docs) {
            final data = doc.data();
            final key = '${data['itemName']}-${data['qualityName']}';
            packagingUnits[key] = data['packagingUnit'] ?? 'Unit';
          }
        }
      }
      // Fill in defaults for missing items
      for (final item in invoice.items) {
        packagingUnits.putIfAbsent('${item.itemName}-${item.quality}', () => 'Unit');
      }

      // Sort items asynchronously
      final sortedItems = await compute(sortItems, invoice.items);

      // Debug print to verify sorting
      print('Original Items:');
      for (var item in invoice.items) {
        print('${item.quality} - ${item.itemName}');
      }
      print('Sorted Items:');
      for (var item in sortedItems) {
        print('${item.quality} - ${item.itemName}');
      }

      // Build items table rows with sorted items
      final List<pw.TableRow> itemTableRows = [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#0D6EFD')),
          children: [
            'Sr No',
            'Description',
            'Pack Unit',
            'Qty',
            'Unit Price',
            'Disc.%',
            'Total',
          ].map((text) => pw.Container(
            padding: const pw.EdgeInsets.all(5),
            alignment: text == 'Description' ? pw.Alignment.centerLeft : pw.Alignment.center,
            child: pw.Text(text,
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold)),
          )).toList(),
        ),
        ...sortedItems.asMap().entries.map((entry) {
          final int index = entry.key + 1;
          final item = entry.value;
          final qtyString = item.qty % 1 == 0 ? item.qty.toInt().toString() : item.qty.toStringAsFixed(2);
          final discountValue = double.tryParse(item.discount ?? '0') ?? 0.0;
          final packagingUnit = packagingUnits['${item.itemName}-${item.quality}'] ?? 'Unit';
          return pw.TableRow(
            children: [
              pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  alignment: pw.Alignment.center,
                  child: pw.Text(index.toString(),
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
              pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('${item.quality}   ${item.itemName}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
              pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  alignment: pw.Alignment.center,
                  child: pw.Text(packagingUnit,
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
              pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  alignment: pw.Alignment.center,
                  child: pw.Text(qtyString,
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
              pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  alignment: pw.Alignment.center,
                  child: pw.Text(numberFormat.format(double.parse(item.price ?? '0')),
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
              pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  alignment: pw.Alignment.center,
                  child: pw.Text('$discountValue%',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
              pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  alignment: pw.Alignment.center,
                  child: pw.Text(numberFormat.format(double.parse(item.total ?? '0')),
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
            ],
          );
        }),
      ];

      // Build totals table rows
      final List<pw.TableRow> totalsTableRows = [
        pw.TableRow(
          children: [
            pw.Container(
                padding: const pw.EdgeInsets.all(5),
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Subtotal:',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black))),
            pw.Container(
                padding: const pw.EdgeInsets.all(5),
                alignment: pw.Alignment.centerRight,
                child: pw.Text(numberFormat.format(invoice.subtotal),
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Container(
                padding: const pw.EdgeInsets.all(5),
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Global Discount:',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black))),
            pw.Container(
                padding: const pw.EdgeInsets.all(5),
                alignment: pw.Alignment.centerRight,
                child: pw.Text('-${numberFormat.format(invoice.globalDiscount)}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Container(
                padding: const pw.EdgeInsets.all(5),
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Total Amount:',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black))),
            pw.Container(
                padding: const pw.EdgeInsets.all(5),
                alignment: pw.Alignment.centerRight,
                child: pw.Text(numberFormat.format(invoice.total),
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Container(
                padding: const pw.EdgeInsets.all(5),
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Amount Received:',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black))),
            pw.Container(
                padding: const pw.EdgeInsets.all(5),
                alignment: pw.Alignment.centerRight,
                child: pw.Text(numberFormat.format(invoice.givenAmount),
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
          ],
        ),
        if (invoice.returnAmount > 0)
          pw.TableRow(
            children: [
              pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text('Change Due:',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black))),
              pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(numberFormat.format(invoice.returnAmount),
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
            ],
          ),
        if (invoice.balanceDue > 0)
          pw.TableRow(
            children: [
              pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text('Balance Due:',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black))),
              pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(numberFormat.format(invoice.balanceDue),
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
            ],
          ),
      ];

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(25),
          theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
          header: (_) => pw.Column(
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
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#0D6EFD'))),
                      pw.SizedBox(height: 6),
                      pw.Text('Popular Foam Center',
                          style: pw.TextStyle(
                              fontSize: 15,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black)),
                      pw.Text('Zanana Hospital Road, Bahawalpur (63100)',
                          style: pw.TextStyle(fontSize: 10, color: PdfColors.black)),
                    ],
                  ),
                  pw.Image(pw.MemoryImage(logoImage), width: 110, height: 110),
                ],
              ),
              pw.Divider(color: PdfColor.fromHex('#0D6EFD'), height: 25),
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
                          style: const pw.TextStyle(fontSize: 13, color: PdfColors.black)),
                      pw.SizedBox(height: 6),
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
                              fontSize: 13,
                              color: PdfColor.fromHex('#0D6EFD'))),
                      pw.SizedBox(height: 6),
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
              pw.SizedBox(height: 20),
            ],
          ),
          build: (context) => [
            pw.Container(
              decoration: pw.BoxDecoration(
                borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(10)),
                border: pw.Border.all(color: PdfColors.black, width: 1),
              ),
              child: pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(3.5),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(1.5),
                  5: const pw.FlexColumnWidth(1),
                  6: const pw.FlexColumnWidth(1.5),
                },
                border: pw.TableBorder.all(color: PdfColors.black, width: 1),
                defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                children: itemTableRows,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 220,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Table(
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1),
                  },
                  border: pw.TableBorder.all(color: PdfColors.black, width: 1),
                  defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                  children: totalsTableRows,
                ),
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 220,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8F9FA'),
                  borderRadius: pw.BorderRadius.circular(5),
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
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#0D6EFD'))),
                  ],
                ),
              ),
            ),
          ],
          footer: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 0.5, color: PdfColors.black),
              pw.Text(
                'Thankyou for choosing Popular Foam Center!',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Contact: 0302-9596046 | FB: Popular Foam Center',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.black),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Claims as per policy',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.black),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 10),
            ],
          ),
        ),
      );

      final pdfBytes = await pdf.save();
      final String invoiceType = invoice.type.replaceAll(' ', '');
      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'PFC-${invoiceType}-INV-${invoice.invoiceNumber}-A4',
      );
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A4 Invoice printed successfully!')),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog on error
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
      DateTime invoiceDate = invoice.timestamp is Timestamp
          ? (invoice.timestamp as Timestamp).toDate()
          : DateTime.now();

      // Sort items asynchronously
      final sortedItems = await compute(sortItems, invoice.items);

      // Debug print to verify sorting
      print('Original Items:');
      for (var item in invoice.items) {
        print('${item.quality} - ${item.itemName}');
      }
      print('Sorted Items:');
      for (var item in sortedItems) {
        print('${item.quality} - ${item.itemName}');
      }

      const double baseHeight = 50;
      const double headerHeight = 10;
      const double itemHeight = 10;
      const double totalHeight = 12;
      const double footerHeight = 12;
      final double dynamicHeight = baseHeight + headerHeight + (sortedItems.length * itemHeight) + totalHeight + footerHeight;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            80 * PdfPageFormat.mm,
            dynamicHeight * PdfPageFormat.mm,
            marginAll: 2 * PdfPageFormat.mm,
          ),
          theme: pw.ThemeData.withFont(
            base: await PdfGoogleFonts.robotoRegular(),
            bold: await PdfGoogleFonts.robotoBold(),
          ),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Image(pw.MemoryImage(logoImage), width: 35, height: 35),
              pw.SizedBox(height: 2),
              pw.Text(
                'Popular Foam Center',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Zanana Hospital Road, Bahawalpur',
                style: pw.TextStyle(fontSize: 7, color: PdfColors.black),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Divider(thickness: 0.5, color: PdfColors.black),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'INV #${invoice.invoiceNumber}',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                  ),
                  pw.Text(
                    DateFormat('dd-MM-yy HH:mm').format(invoiceDate),
                    style: pw.TextStyle(fontSize: 7, color: PdfColors.black),
                  ),
                ],
              ),
              pw.Text(
                'Type: ${invoice.type.toUpperCase()}  Cashier: M.Hashim',
                style: pw.TextStyle(fontSize: 7, color: PdfColors.black),
              ),
              pw.SizedBox(height: 2),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'To: ${invoice.customer['name'] ?? 'Walking Customer'}',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Divider(thickness: 0.5, color: PdfColors.black),
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                },
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          'Sr',
                          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          'Item',
                          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                          textAlign: pw.TextAlign.left,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          'Qty',
                          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                          'Total',
                          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  ...sortedItems.asMap().entries.map((entry) {
                    final int index = entry.key + 1;
                    final item = entry.value;
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(
                            index.toString(),
                            style: pw.TextStyle(fontSize: 7, color: PdfColors.black),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(
                            '${item.quality} ${item.itemName}',
                            style: pw.TextStyle(fontSize: 7, color: PdfColors.black),
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(
                            item.qty.toStringAsFixed(0),
                            style: pw.TextStyle(fontSize: 7, color: PdfColors.black),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(
                            numberFormat.format(double.parse(item.total)),
                            style: pw.TextStyle(fontSize: 7, color: PdfColors.black),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Divider(thickness: 0.5, color: PdfColors.black),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Subtotal:', style: pw.TextStyle(fontSize: 7, color: PdfColors.black)),
                        pw.Text(numberFormat.format(invoice.subtotal), style: pw.TextStyle(fontSize: 7, color: PdfColors.black)),
                      ],
                    ),
                    if (invoice.globalDiscount > 0)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Discount:', style: pw.TextStyle(fontSize: 7, color: PdfColors.black)),
                          pw.Text('-${numberFormat.format(invoice.globalDiscount)}', style: pw.TextStyle(fontSize: 7, color: PdfColors.black)),
                        ],
                      ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                        pw.Text(
                          numberFormat.format(invoice.total),
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                        ),
                      ],
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Received:', style: pw.TextStyle(fontSize: 7, color: PdfColors.black)),
                        pw.Text(numberFormat.format(invoice.givenAmount), style: pw.TextStyle(fontSize: 7, color: PdfColors.black)),
                      ],
                    ),
                    if (invoice.returnAmount > 0)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Change:', style: pw.TextStyle(fontSize: 7, color: PdfColors.black)),
                          pw.Text(numberFormat.format(invoice.returnAmount), style: pw.TextStyle(fontSize: 7, color: PdfColors.black)),
                        ],
                      ),
                    if (invoice.balanceDue > 0)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Due:', style: pw.TextStyle(fontSize: 7, color: PdfColors.black)),
                          pw.Text(numberFormat.format(invoice.balanceDue), style: pw.TextStyle(fontSize: 7, color: PdfColors.black)),
                        ],
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Divider(thickness: 0.5, color: PdfColors.black),
              pw.Text(
                'Thank You!',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Contact: 0302-9596046 | FB: Popular Foam Center',
                style: pw.TextStyle(fontSize: 6, color: PdfColors.black),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Claims as per policy',
                style: pw.TextStyle(fontSize: 6, color: PdfColors.black),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 5),
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
            final newStock = currentStock - item.qty;
            if (newStock < 0) throw Exception('Insufficient stock for ${item.itemName}');
            transaction.update(ref, {'stockQuantity': newStock});
          }
        }

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
                onChanged: (value) {},
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
                          Navigator.pop(context);
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
              indicator: const BoxDecoration(),
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
      physics: const NeverScrollableScrollPhysics(),
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
            physics: const NeverScrollableScrollPhysics(),
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
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) => _buildTransactionList(snapshot),
    );
  }

  Widget _buildTransactionsByType(String type) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('invoices')
          .where('type', isEqualTo: type)
          .orderBy('timestamp', descending: true)
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
          Expanded(child: _HeaderCell('Received')),
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
    final received = invoice.givenAmount.toStringAsFixed(0);
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
            Expanded(child: _DataCell(received)),
            Expanded(child: _DataCell(invoice.balanceDue > 0 ? pending : '', null, invoice.balanceDue > 0 ? 'Pending' : 'Paid', invoice.balanceDue > 0 ? Colors.red : Colors.green)),
            Expanded(child: _DataCell(date)),
            Expanded(
              child: _ActionCell(
                transactionDoc,
                null,
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
          _HeaderCell('Received', 150),
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
    final received = invoice.givenAmount.toStringAsFixed(0);
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
            _DataCell(received, 150),
            _DataCell(invoice.balanceDue > 0 ? pending : '', 150, invoice.balanceDue > 0 ? 'Pending' : 'Paid', invoice.balanceDue > 0 ? Colors.red : Colors.green),
            _DataCell(date, 150),
            _ActionCell(
              transactionDoc,
              150,
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