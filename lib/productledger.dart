import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For RawKeyboard and rootBundle
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:printing/printing.dart'; // For printing
import 'package:pdf/pdf.dart'; // For PDF generation
import 'package:pdf/widgets.dart' as pw; // PDF widgets
import 'package:share_plus/share_plus.dart'; // For sharing the PDF
import 'dart:io'; // For file handling
import 'package:path_provider/path_provider.dart'; // For temporary file storage

// Assuming these files contain the required classes
import 'pointofsale.dart'; // Replace with actual file path
import 'purchaseinvoice.dart'; // Replace with actual file path

// Color Scheme (unchanged)
const Color _primaryColor = Color(0xFF0D6EFD);
const Color _textColorLight = Color(0xFF2D2D2D);
const Color _secondaryTextColorLight = Color(0xFF4A4A4A);
const Color _backgroundColorLight = Color(0xFFF8F9FA);
const Color _surfaceColorLight = Colors.white;
const Color _backgroundColorDark = Color(0xFF1A1A2F);
const Color _surfaceColorDark = Color(0xFF252541);
const Color _textColorDark = Colors.white;
const Color _secondaryTextColorDark = Colors.white70;

class ProcessedTransaction {
  final String docId;
  final String type;
  final String details;
  final double inQty;
  final double outQty;
  final double balance;
  final DateTime date;

  ProcessedTransaction(this.docId, this.type, this.details, this.inQty, this.outQty, this.balance, this.date);
}

class MonthClosing {
  final String monthYear; // e.g., "October 2023"
  final double closingBalance;
  final double monthIn;
  final double monthOut;

  MonthClosing(this.monthYear, this.closingBalance, this.monthIn, this.monthOut);
}

class MonthClosingData {
  final double inQty;
  final double outQty;
  final double closingBalance;

  MonthClosingData(this.inQty, this.outQty, this.closingBalance);
}

class ProcessedData {
  final List<ProcessedTransaction> transactions;
  final double totalIn;
  final double totalOut;
  final double finalBalance;
  final List<MonthClosing> monthClosings;

  ProcessedData(this.transactions, this.totalIn, this.totalOut, this.finalBalance, this.monthClosings);
}

class ProductLedgerPage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback toggleDarkMode;

  const ProductLedgerPage({super.key, required this.isDarkMode, required this.toggleDarkMode});

  @override
  _ProductLedgerPageState createState() => _ProductLedgerPageState();
}

class _ProductLedgerPageState extends State<ProductLedgerPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _horizontalScrollController = ScrollController();
  final double _mobileTableWidth = 1200;
  String? _selectedQuality;
  String? _selectedItem;
  DateTime? _fromDate;
  DateTime? _toDate;

  // FocusNodes for page and dropdowns
  final FocusNode _pageFocusNode = FocusNode();
  final FocusNode _qualityDropdownFocusNode = FocusNode();
  final FocusNode _itemDropdownFocusNode = FocusNode();

  Color get _textColor => widget.isDarkMode ? _textColorDark : _textColorLight;
  Color get _secondaryTextColor => widget.isDarkMode ? _secondaryTextColorDark : _secondaryTextColorLight;
  Color get _backgroundColor => widget.isDarkMode ? _backgroundColorDark : _backgroundColorLight;
  Color get _surfaceColor => widget.isDarkMode ? _surfaceColorDark : _surfaceColorLight;

  String _formatDouble(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    } else {
      return value.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
  }

  Future<ProcessedData> _fetchLedgerTransactions(String quality) async {
    List<ProcessedTransaction> transactions = [];
    Map<String, MonthClosingData> monthData = {};
    List<MonthClosing> monthClosings = [];
    double totalIn = 0.0;
    double totalOut = 0.0;
    double initialBalance = await _fetchOpeningBalance();

    if (_selectedItem == null || _selectedQuality == null) {
      return ProcessedData(transactions, totalIn, totalOut, initialBalance, monthClosings);
    }

    QuerySnapshot purchasesSnapshot = await _firestore.collection('purchaseinvoices').get();
    for (var purchase in purchasesSnapshot.docs) {
      var purchaseData = purchase.data() as Map<String, dynamic>;
      var items = purchaseData['items'] as List<dynamic>? ?? [];
      DateTime? date;
      try {
        date = DateFormat('dd-MM-yyyy').parse(purchaseData['receiveDate'] ?? '');
      } catch (e) {
        continue;
      }
      if (_fromDate != null && date.isBefore(_fromDate!)) continue;
      if (_toDate != null && date.isAfter(_toDate!)) continue;

      for (var item in items) {
        if (item['quality'] == quality && item['name'] == _selectedItem) {
          double qty = item['quantity'] is String
              ? double.tryParse(item['quantity'] as String) ?? 0.0
              : (item['quantity'] as num?)?.toDouble() ?? 0.0;
          if (qty > 0) {
            String invoiceId = purchaseData['invoiceId']?.toString() ?? purchase.id;
            transactions.add(ProcessedTransaction(
              purchase.id,
              'Purchase',
              'Purchase #$invoiceId',
              qty,
              0.0,
              0.0,
              date,
            ));
            totalIn += qty;
          }
        }
      }
    }

    QuerySnapshot salesSnapshot = await _firestore.collection('invoices').where('type', isEqualTo: 'Sale').get();
    for (var sale in salesSnapshot.docs) {
      var saleData = sale.data() as Map<String, dynamic>;
      var items = saleData['items'] as List<dynamic>? ?? [];
      DateTime? date = (saleData['timestamp'] as Timestamp?)?.toDate();
      if (date == null) continue;
      if (_fromDate != null && date.isBefore(_fromDate!)) continue;
      if (_toDate != null && date.isAfter(_toDate!)) continue;

      for (var item in items) {
        if (item['quality'] == quality && item['item'] == _selectedItem) {
          double qty = item['qty'] is String
              ? double.tryParse(item['qty'] as String) ?? 0.0
              : (item['qty'] as num?)?.toDouble() ?? 0.0;
          if (qty > 0) {
            String invoiceNumber = saleData['invoiceNumber']?.toString() ?? sale.id;
            transactions.add(ProcessedTransaction(
              sale.id,
              'Sale',
              'Sale #$invoiceNumber',
              0.0,
              qty,
              0.0,
              date,
            ));
            totalOut += qty;
          }
        }
      }
    }

    QuerySnapshot returnsSnapshot = await _firestore.collection('invoices').where('type', isEqualTo: 'Return').get();
    for (var returnDoc in returnsSnapshot.docs) {
      var returnData = returnDoc.data() as Map<String, dynamic>;
      var items = returnData['items'] as List<dynamic>? ?? [];
      DateTime? date = (returnData['timestamp'] as Timestamp?)?.toDate();
      if (date == null) continue;
      if (_fromDate != null && date.isBefore(_fromDate!)) continue;
      if (_toDate != null && date.isAfter(_toDate!)) continue;

      for (var item in items) {
        if (item['quality'] == quality && item['item'] == _selectedItem) {
          double qty = item['qty'] is String
              ? double.tryParse(item['qty'] as String) ?? 0.0
              : (item['qty'] as num?)?.toDouble() ?? 0.0;
          if (qty > 0) {
            String returnNumber = returnData['invoiceNumber']?.toString() ?? returnDoc.id;
            transactions.add(ProcessedTransaction(
              returnDoc.id,
              'Return',
              'Return #$returnNumber',
              qty,
              0.0,
              0.0,
              date,
            ));
            totalIn += qty;
          }
        }
      }
    }

    transactions.sort((a, b) => a.date.compareTo(b.date));

    double runningBalance = initialBalance;
    List<ProcessedTransaction> updatedTransactions = [];
    for (var transaction in transactions) {
      runningBalance += transaction.inQty - transaction.outQty;
      updatedTransactions.add(ProcessedTransaction(
        transaction.docId,
        transaction.type,
        transaction.details,
        transaction.inQty,
        transaction.outQty,
        runningBalance,
        transaction.date,
      ));

      final monthKey = DateFormat('MMMM yyyy').format(transaction.date);
      monthData.update(
        monthKey,
            (value) => MonthClosingData(
          value.inQty + transaction.inQty,
          value.outQty + transaction.outQty,
          runningBalance,
        ),
        ifAbsent: () => MonthClosingData(transaction.inQty, transaction.outQty, runningBalance),
      );
    }

    monthClosings = monthData.entries.map((entry) {
      return MonthClosing(
        entry.key,
        entry.value.closingBalance,
        entry.value.inQty,
        entry.value.outQty,
      );
    }).toList();

    monthClosings.sort((a, b) {
      final aDate = DateFormat('MMMM yyyy').parse(a.monthYear);
      final bDate = DateFormat('MMMM yyyy').parse(b.monthYear);
      return aDate.compareTo(bDate);
    });

    return ProcessedData(updatedTransactions, totalIn, totalOut, runningBalance, monthClosings);
  }

  Future<double> _fetchOpeningBalance() async {
    if (_selectedQuality == null || _selectedItem == null) return 0.0;

    QuerySnapshot itemsSnapshot = await _firestore
        .collection('items')
        .where('qualityName', isEqualTo: _selectedQuality)
        .where('itemName', isEqualTo: _selectedItem)
        .get();

    double totalOpeningBalance = 0.0;
    for (var itemDoc in itemsSnapshot.docs) {
      var itemData = itemDoc.data() as Map<String, dynamic>;
      double stock = itemData['openingStock'] is String
          ? double.tryParse(itemData['openingStock'] as String) ?? 0.0
          : (itemData['openingStock'] as num?)?.toDouble() ?? 0.0;
      totalOpeningBalance += stock;
    }
    return totalOpeningBalance;
  }

  Future<Map<String, dynamic>> _calculateSummary() async {
    if (_selectedQuality == null || _selectedItem == null) return {'totalIn': 0.0, 'totalOut': 0.0, 'finalBalance': 0.0};

    final data = await _fetchLedgerTransactions(_selectedQuality!);
    return {
      'totalIn': data.totalIn,
      'totalOut': data.totalOut,
      'finalBalance': data.finalBalance,
    };
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: widget.isDarkMode ? ThemeData.dark() : ThemeData.light(),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) _fromDate = picked;
        else _toDate = picked;
      });
    }
  }

  void _showSummaryBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _calculateSummary(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: _textColor)));
              }

              final summary = snapshot.data ?? {'totalIn': 0.0, 'totalOut': 0.0, 'finalBalance': 0.0};
              return _buildSummaryFooter(
                summary['totalIn'] as double,
                summary['totalOut'] as double,
                summary['finalBalance'] as double,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _printLedger() async {
    print('Print button pressed');
    if (_selectedQuality == null || _selectedItem == null) {
      print('No quality or item selected');
      _showSnackBar('Please select a quality and item to print the ledger', Colors.red);
      return;
    }

    try {
      print('Fetching transactions...');
      final processedData = await _fetchLedgerTransactions(_selectedQuality!);
      print('Transactions fetched: ${processedData.transactions.length}');
      if (processedData.transactions.isEmpty) {
        print('No transactions to print');
        _showSnackBar('No transactions found for this quality and item', Colors.orange);
        return;
      }

      print('Fetching opening balance...');
      final openingBalance = await _fetchOpeningBalance();
      print('Opening balance fetched: $openingBalance');

      print('Generating PDF...');
      final pdf = pw.Document();
      final numberFormat = NumberFormat.currency(decimalDigits: 0, symbol: '');
      final Uint8List logoImage = (await rootBundle.load('assets/images/logo1.png')).buffer.asUint8List();

      List<dynamic> displayItems = [];
      int transactionIndex = 0;
      int monthClosingIndex = 0;

      while (transactionIndex < processedData.transactions.length ||
          monthClosingIndex < processedData.monthClosings.length) {
        if (monthClosingIndex >= processedData.monthClosings.length) {
          displayItems.add(processedData.transactions[transactionIndex]);
          transactionIndex++;
          continue;
        }

        if (transactionIndex >= processedData.transactions.length) {
          displayItems.add(processedData.monthClosings[monthClosingIndex]);
          monthClosingIndex++;
          continue;
        }

        final transaction = processedData.transactions[transactionIndex];
        final monthClosing = processedData.monthClosings[monthClosingIndex];
        final transactionMonth = DateFormat('MMMM yyyy').format(transaction.date);
        final monthClosingDate = DateFormat('MMMM yyyy').parse(monthClosing.monthYear);

        if (transactionMonth == monthClosing.monthYear) {
          displayItems.add(transaction);
          transactionIndex++;

          if (transactionIndex == processedData.transactions.length ||
              DateFormat('MMMM yyyy').format(processedData.transactions[transactionIndex].date) != monthClosing.monthYear) {
            displayItems.add(monthClosing);
            monthClosingIndex++;
          }
        } else {
          final transactionDate = DateFormat('MMMM yyyy').parse(transactionMonth);
          if (transactionDate.isAfter(monthClosingDate)) {
            displayItems.add(monthClosing);
            monthClosingIndex++;
          } else {
            displayItems.add(transaction);
            transactionIndex++;
          }
        }
      }

      final List<pw.TableRow> tableRows = [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#0D6EFD')),
          children: [
            'Sr#',
            'Date',
            'Details',
            'In',
            'Out',
            'Balance',
          ].map((text) => pw.Container(
            padding: const pw.EdgeInsets.all(3),
            alignment: pw.Alignment.center,
            child: pw.Text(
              text,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          )).toList(),
        ),
        ...displayItems.asMap().entries.map((entry) {
          final int index = entry.key + 1;
          final item = entry.value;

          if (item is ProcessedTransaction) {
            return pw.TableRow(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    index.toString(),
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    DateFormat('dd-MM-yyyy').format(item.date),
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    item.details,
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    item.inQty > 0 ? numberFormat.format(item.inQty) : '-',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    item.outQty > 0 ? numberFormat.format(item.outQty) : '-',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    numberFormat.format(item.balance),
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
                  ),
                ),
              ],
            );
          } else if (item is MonthClosing) {
            return pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('#0D6EFD')),
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    '',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'Total in ${item.monthYear}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    '',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    item.monthIn > 0 ? numberFormat.format(item.monthIn) : '-',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    item.monthOut > 0 ? numberFormat.format(item.monthOut) : '-',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    numberFormat.format(item.closingBalance),
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                  ),
                ),
              ],
            );
          }
          return pw.TableRow(children: List.filled(6, pw.SizedBox()));
        }),
      ];

      final List<pw.TableRow> totalsTableRows = [
        pw.TableRow(children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(3),
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total In:',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(3),
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              numberFormat.format(processedData.totalIn),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
            ),
          ),
        ]),
        pw.TableRow(children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(3),
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total Out:',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(3),
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              numberFormat.format(processedData.totalOut),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
            ),
          ),
        ]),
        pw.TableRow(children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(3),
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Final Balance:',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(3),
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              numberFormat.format(processedData.finalBalance),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
            ),
          ),
        ]),
      ];

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(25),
          header: (context) => context.pageNumber == 1
              ? pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PRODUCT LEDGER',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#0D6EFD'),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Popular Foam Center',
                        style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.Text(
                        'Zanana Hospital Road, Bahawalpur (63100)',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.black),
                      ),
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
                      pw.Text(
                        'Quality:',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.Text(
                        _selectedQuality ?? 'N/A',
                        style: const pw.TextStyle(fontSize: 13, color: PdfColors.black),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Item:',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.Text(
                        _selectedItem ?? 'N/A',
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.black),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Opening Balance:',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.Text(
                        numberFormat.format(openingBalance),
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.black),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Date Range:',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.Text(
                        _fromDate != null && _toDate != null
                            ? '${DateFormat('dd-MM-yyyy').format(_fromDate!)} to ${DateFormat('dd-MM-yyyy').format(_toDate!)}'
                            : 'All Time',
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.black),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
            ],
          )
              : pw.SizedBox(),
          build: (context) => [
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(0.8),  // Sr#
                1: const pw.FlexColumnWidth(1.5),  // Date
                2: const pw.FlexColumnWidth(3.0),  // Details
                3: const pw.FlexColumnWidth(1.5),  // In
                4: const pw.FlexColumnWidth(1.5),  // Out
                5: const pw.FlexColumnWidth(1.5),  // Balance
              },
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
              defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
              children: tableRows,
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 220,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Table(
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1),
                  },
                  border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
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
                    pw.Text(
                      'TOTAL TRANSACTIONS',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                    pw.Text(
                      processedData.transactions.length.toString(),
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#0D6EFD'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          footer: (context) => context.pageNumber == context.pagesCount
              ? pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 0.5, color: PdfColors.black),
              pw.Text(
                'Contact: 0302-9596046 | FB: Popular Foam Center',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.black),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.black),
              ),
              pw.SizedBox(height: 10),
            ],
          )
              : pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.black),
            textAlign: pw.TextAlign.center,
          ),
        ),
      );

      print('PDF generated, attempting to print...');
      try {
        final printed = await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
          name: 'PFC-PRODUCT-LEDGER-${_selectedItem}-${DateTime.now().millisecondsSinceEpoch}-A4',
        );
        if (printed) {
          print('Printing successful');
          _showSnackBar('Ledger printed successfully', Colors.green);
        } else {
          print('Printing cancelled or failed, saving PDF as fallback...');
          await _saveAndSharePdf(pdf);
        }
      } catch (e) {
        print('Error during printing: $e');
        _showSnackBar('Failed to print ledger: $e', Colors.red);
        print('Saving PDF as fallback...');
        await _saveAndSharePdf(pdf);
      }
    } catch (e) {
      print('Error in _printLedger: $e');
      _showSnackBar('Error generating ledger: $e', Colors.red);
    }
  }

  Future<void> _saveAndSharePdf(pw.Document pdf) async {
    try {
      print('Saving PDF to temporary file...');
      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/product_ledger.pdf');
      await file.writeAsBytes(bytes);
      print('PDF saved to ${file.path}');

      print('Sharing PDF...');
      await Share.shareXFiles([XFile(file.path)],
          text: 'Product Ledger PDF',
          subject: 'Product Ledger');
      print('Share dialog opened');
    } catch (e) {
      print('Error saving/sharing PDF: $e');
      _showSnackBar('Failed to save/share PDF: $e', Colors.red);
    }
  }

  Future<void> _navigateToInvoiceView(ProcessedTransaction transaction) async {
    try {
      if (transaction.type == 'Purchase') {
        DocumentSnapshot purchaseDoc = await _firestore.collection('purchaseinvoices').doc(transaction.docId).get();
        if (!purchaseDoc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase invoice not found')),
          );
          return;
        }
        final purchaseData = purchaseDoc.data() as Map<String, dynamic>;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InvoiceViewScreen.fromData(
              company: purchaseData['company'] ?? 'Unknown Company',
              invoiceId: transaction.docId,
              existingInvoice: purchaseData,
            ),
          ),
        );
      } else {
        DocumentSnapshot doc = await _firestore.collection('invoices').doc(transaction.docId).get();
        if (!doc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice not found')),
          );
          return;
        }
        final data = doc.data() as Map<String, dynamic>;
        Invoice invoice = Invoice.fromMap(transaction.docId, data);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PointOfSalePage(
              invoice: invoice,
              isReadOnly: true,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading invoice: $e')),
      );
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      print('Key pressed: ${event.logicalKey.keyLabel}');
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        _showSummaryBottomSheet(context);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() {
          _selectedQuality = null;
          _selectedItem = null;
          _fromDate = null;
          _toDate = null;
        });
        return KeyEventResult.handled;
      } else if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyF) {
        _qualityDropdownFocusNode.requestFocus();
        return KeyEventResult.handled;
      } else if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyI) {
        if (_selectedQuality != null) {
          _itemDropdownFocusNode.requestFocus();
        }
        return KeyEventResult.handled;
      } else if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyP) {
        print('Ctrl + P pressed');
        _printLedger();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pageFocusNode.dispose();
    _qualityDropdownFocusNode.dispose();
    _itemDropdownFocusNode.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 1200;
    return Focus(
      focusNode: _pageFocusNode,
      onKey: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Text('Product Ledger', style: TextStyle(color: _textColor)),
              const SizedBox(width: 16),
              Expanded(child: _buildQualityDropdown()),
              const SizedBox(width: 16),
              Expanded(child: _buildItemDropdown()),
              const SizedBox(width: 16),
              _buildDateFilterChip('From', _fromDate, true),
              const SizedBox(width: 16),
              _buildDateFilterChip('To', _toDate, false),
            ],
          ),
          backgroundColor: _backgroundColor,
          elevation: 0,
          iconTheme: IconThemeData(color: _textColor),
          actions: [
            IconButton(
              icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
              color: _textColor,
              onPressed: widget.toggleDarkMode,
            ),
          ],
        ),
        backgroundColor: _backgroundColor,
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              onPressed: () {
                print('Summary button pressed');
                _showSummaryBottomSheet(context);
              },
              backgroundColor: _primaryColor,
              heroTag: 'summary',
              child: const Icon(Icons.info_outline, color: Colors.white),
            ),
            const SizedBox(height: 16),
            FloatingActionButton(
              onPressed: () {
                print('Print button pressed in FloatingActionButton');
                _printLedger();
              },
              backgroundColor: _primaryColor,
              heroTag: 'print',
              child: const Icon(Icons.print, color: Colors.white),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_selectedQuality != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: _buildOpening612BalanceCard(), // Corrected method name
              ),
              Expanded(child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() => _buildLedgerTable(isDesktop: true);

  Widget _buildMobileLayout() => Scrollbar(
    controller: _horizontalScrollController,
    thumbVisibility: true,
    child: SingleChildScrollView(
      controller: _horizontalScrollController,
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _mobileTableWidth,
        child: _buildLedgerTable(isDesktop: false),
      ),
    ),
  );

  Widget _buildLedgerTable({required bool isDesktop}) {
    if (_selectedQuality == null || _selectedItem == null) {
      return Center(child: Text('Please select a quality and item', style: TextStyle(color: _textColor)));
    }

    return FutureBuilder<ProcessedData>(
      future: _fetchLedgerTransactions(_selectedQuality!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _primaryColor));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: _textColor)));
        }

        final data = snapshot.data!;
        if (data.transactions.isEmpty) {
          return Center(child: Text('No transactions found', style: TextStyle(color: _textColor)));
        }

        List<dynamic> displayItems = [];
        int transactionIndex = 0;
        int monthClosingIndex = 0;

        while (transactionIndex < data.transactions.length || monthClosingIndex < data.monthClosings.length) {
          if (monthClosingIndex >= data.monthClosings.length) {
            displayItems.add(data.transactions[transactionIndex]);
            transactionIndex++;
            continue;
          }

          if (transactionIndex >= data.transactions.length) {
            displayItems.add(data.monthClosings[monthClosingIndex]);
            monthClosingIndex++;
            continue;
          }

          final transaction = data.transactions[transactionIndex];
          final monthClosing = data.monthClosings[monthClosingIndex];
          final transactionMonth = DateFormat('MMMM yyyy').format(transaction.date);
          final monthClosingDate = DateFormat('MMMM yyyy').parse(monthClosing.monthYear);

          if (transactionMonth == monthClosing.monthYear) {
            displayItems.add(transaction);
            transactionIndex++;

            if (transactionIndex == data.transactions.length ||
                DateFormat('MMMM yyyy').format(data.transactions[transactionIndex].date) != monthClosing.monthYear) {
              displayItems.add(monthClosing);
              monthClosingIndex++;
            }
          } else {
            final transactionDate = DateFormat('MMMM yyyy').parse(transactionMonth);
            if (transactionDate.isAfter(monthClosingDate)) {
              displayItems.add(monthClosing);
              monthClosingIndex++;
            } else {
              displayItems.add(transaction);
              transactionIndex++;
            }
          }
        }

        return Column(
          children: [
            _buildTableHeader(isDesktop),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: displayItems.length,
                itemBuilder: (context, index) {
                  final item = displayItems[index];
                  if (item is ProcessedTransaction) {
                    return _buildTableRow(item, isDesktop);
                  } else if (item is MonthClosing) {
                    return _buildMonthClosingRow(item);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTableHeader(bool isDesktop) => Container(
    height: 56,
    margin: const EdgeInsets.symmetric(horizontal: 24),
    decoration: BoxDecoration(
      color: _primaryColor,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          isDesktop ? const Expanded(child: _HeaderCell('Date')) : const _HeaderCell('Date', 150),
          isDesktop ? const Expanded(flex: 2, child: _HeaderCell('Details')) : const _HeaderCell('Details', 300),
          isDesktop ? const Expanded(child: _HeaderCell('In')) : const _HeaderCell('In', 150),
          isDesktop ? const Expanded(child: _HeaderCell('Out')) : const _HeaderCell('Out', 150),
          isDesktop ? const Expanded(child: _HeaderCell('Balance')) : const _HeaderCell('Balance', 150),
        ],
      ),
    ),
  );

  Widget _buildTableRow(ProcessedTransaction transaction, bool isDesktop) => GestureDetector(
    onTap: () => _navigateToInvoiceView(transaction),
    child: Container(
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
            isDesktop
                ? Expanded(child: _DataCell(DateFormat('dd-MM-yyyy').format(transaction.date)))
                : _DataCell(DateFormat('dd-MM-yyyy').format(transaction.date), width: 150),
            isDesktop
                ? Expanded(flex: 2, child: _DataCell(transaction.details, color: _primaryColor))
                : _DataCell(transaction.details, width: 300, color: _primaryColor),
            isDesktop
                ? Expanded(
              child: _DataCell(
                transaction.inQty > 0 ? _formatDouble(transaction.inQty) : '-',
                color: transaction.inQty > 0 ? Colors.green : _secondaryTextColor,
              ),
            )
                : _DataCell(
              transaction.inQty > 0 ? _formatDouble(transaction.inQty) : '-',
              width: 150,
              color: transaction.inQty > 0 ? Colors.green : _secondaryTextColor,
            ),
            isDesktop
                ? Expanded(
              child: _DataCell(
                transaction.outQty > 0 ? _formatDouble(transaction.outQty) : '-',
                color: transaction.outQty > 0 ? Colors.red : _secondaryTextColor,
              ),
            )
                : _DataCell(
              transaction.outQty > 0 ? _formatDouble(transaction.outQty) : '-',
              width: 150,
              color: transaction.outQty > 0 ? Colors.red : _secondaryTextColor,
            ),
            isDesktop
                ? Expanded(
              child: _DataCell(
                _formatDouble(transaction.balance),
                color: transaction.balance >= 0 ? Colors.green : Colors.red,
              ),
            )
                : _DataCell(
              _formatDouble(transaction.balance),
              width: 150,
              color: transaction.balance >= 0 ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildMonthClosingRow(MonthClosing mc) => Container(
    height: 56,
    decoration: BoxDecoration(
      color: _primaryColor,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(child: _DataCell('Total in')),
          Expanded(child: _DataCell(mc.monthYear, color: Colors.white)),
          Expanded(
            child: _DataCell(
              mc.monthIn > 0 ? _formatDouble(mc.monthIn) : '-',
              width: null,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: _DataCell(
              mc.monthOut > 0 ? _formatDouble(mc.monthOut) : '-',
              width: null,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: _DataCell(
              _formatDouble(mc.closingBalance),
              width: null,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildOpening612BalanceCard() => FutureBuilder<double>(
    future: _fetchOpeningBalance(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return CircularProgressIndicator(color: _primaryColor);
      }
      final openingBalance = snapshot.data ?? 0.0;
      return Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Product Details',
                style: GoogleFonts.roboto(color: _primaryColor, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            _buildDetailRow('Quality', _selectedQuality ?? 'N/A'),
            if (_selectedItem != null) _buildDetailRow('Item', _selectedItem ?? 'N/A'),
            _buildDetailRow('Opening Balance', _formatDouble(openingBalance)),
          ],
        ),
      );
    },
  );

  Widget _buildDetailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(fontWeight: FontWeight.w500, color: _secondaryTextColor, fontSize: 12))),
        Expanded(child: Text(value, style: TextStyle(color: _textColor, fontSize: 12))),
      ],
    ),
  );

  Widget _buildSummaryFooter(double totalIn, double totalOut, double finalBalance) => Container(
    margin: const EdgeInsets.all(24),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildFooterColumn('Total In', totalIn, Colors.green),
            _buildFooterColumn('Total Out', totalOut, Colors.red),
            _buildFooterColumn('Final Balance', finalBalance, finalBalance >= 0 ? Colors.green : Colors.red),
          ],
        ),
      ],
    ),
  );

  Widget _buildFooterColumn(String label, double value, Color color) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: TextStyle(color: _secondaryTextColor, fontSize: 14)),
      const SizedBox(height: 4),
      Text(
        _formatDouble(value),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    ],
  );

  Widget _buildQualityDropdown() => StreamBuilder<QuerySnapshot>(
    stream: _firestore.collection('qualities').snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return CircularProgressIndicator(color: _primaryColor, strokeWidth: 2);
      List<String> qualities = snapshot.data!.docs.map((doc) => doc['name'] as String).toList();
      qualities.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      print('Sorted qualities list: $qualities');

      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownSearch<String>(
          popupProps: PopupProps.menu(
            showSearchBox: true,
            showSelectedItems: true,
            searchFieldProps: TextFieldProps(
              focusNode: _qualityDropdownFocusNode,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search quality...',
                hintStyle: TextStyle(color: _secondaryTextColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _primaryColor.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _primaryColor),
                ),
              ),
              style: TextStyle(color: _textColor),
            ),
            itemBuilder: (context, item, isSelected) => ListTile(
              title: Text(
                item,
                style: TextStyle(
                  color: isSelected ? _primaryColor : _textColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              tileColor: isSelected ? _primaryColor.withOpacity(0.1) : _surfaceColor,
            ),
            menuProps: MenuProps(
              backgroundColor: _surfaceColor,
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
            ),
            fit: FlexFit.loose,
            constraints: const BoxConstraints(maxHeight: 300),
          ),
          dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              hintText: 'Select quality',
              hintStyle: TextStyle(color: _secondaryTextColor, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
            ),
            baseStyle: TextStyle(color: _textColor, fontSize: 14),
          ),
          items: qualities,
          selectedItem: _selectedQuality,
          onChanged: (String? value) {
            setState(() {
              _selectedQuality = value;
              _selectedItem = null; // Reset item when quality changes
            });
          },
          filterFn: (item, filter) => item.toLowerCase().contains(filter.toLowerCase()),
          dropdownButtonProps: DropdownButtonProps(
            icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
          ),
          clearButtonProps: ClearButtonProps(
            isVisible: true,
            icon: Icon(Icons.clear, color: _primaryColor),
            onPressed: () {
              setState(() {
                _selectedQuality = null;
                _selectedItem = null;
              });
            },
          ),
        ),
      );
    },
  );

  Widget _buildItemDropdown() => _selectedQuality == null
      ? Container(
    height: 56,
    decoration: BoxDecoration(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Text(
      'Select item',
      style: TextStyle(color: _secondaryTextColor, fontSize: 14),
    ),
  )
      : StreamBuilder<QuerySnapshot>(
    stream: _firestore.collection('items').where('qualityName', isEqualTo: _selectedQuality).snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return CircularProgressIndicator(color: _primaryColor, strokeWidth: 2);
      List<String> items = snapshot.data!.docs.map((doc) => doc['itemName'] as String).toList();
      items.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      print('Sorted items list: $items');

      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownSearch<String>(
          popupProps: PopupProps.menu(
            showSearchBox: true,
            showSelectedItems: true,
            searchFieldProps: TextFieldProps(
              focusNode: _itemDropdownFocusNode,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search item...',
                hintStyle: TextStyle(color: _secondaryTextColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _primaryColor.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _primaryColor),
                ),
              ),
              style: TextStyle(color: _textColor),
            ),
            itemBuilder: (context, item, isSelected) => ListTile(
              title: Text(
                item,
                style: TextStyle(
                  color: isSelected ? _primaryColor : _textColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              tileColor: isSelected ? _primaryColor.withOpacity(0.1) : _surfaceColor,
            ),
            menuProps: MenuProps(
              backgroundColor: _surfaceColor,
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
            ),
            fit: FlexFit.loose,
            constraints: const BoxConstraints(maxHeight: 300),
          ),
          dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              hintText: 'Select item',
              hintStyle: TextStyle(color: _secondaryTextColor, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
            ),
            baseStyle: TextStyle(color: _textColor, fontSize: 14),
          ),
          items: items,
          selectedItem: _selectedItem,
          onChanged: (String? value) {
            setState(() {
              _selectedItem = value;
            });
          },
          filterFn: (item, filter) => item.toLowerCase().contains(filter.toLowerCase()),
          dropdownButtonProps: DropdownButtonProps(
            icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
          ),
          clearButtonProps: ClearButtonProps(
            isVisible: true,
            icon: Icon(Icons.clear, color: _primaryColor),
            onPressed: () {
              setState(() {
                _selectedItem = null;
              });
            },
          ),
        ),
      );
    },
  );

  Widget _buildDateFilterChip(String label, DateTime? date, bool isFromDate) => InputChip(
    label: Text(
      date != null ? DateFormat('dd-MM-yyyy').format(date) : label,
      style: TextStyle(color: date != null ? _primaryColor : _secondaryTextColor, fontWeight: FontWeight.w500),
    ),
    backgroundColor: _surfaceColor,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), side: BorderSide(color: _primaryColor.withOpacity(0.3))),
    onPressed: () => _selectDate(context, isFromDate),
  );

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
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
    child: Center(
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

class _DataCell extends StatelessWidget {
  final String text;
  final double? width;
  final Color? color;

  const _DataCell(this.text, {this.width, this.color});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = (context.findAncestorWidgetOfExactType<ProductLedgerPage>())!.isDarkMode;
    return SizedBox(
      width: width,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: color ?? (isDarkMode ? Colors.white : _textColorLight),
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }
}