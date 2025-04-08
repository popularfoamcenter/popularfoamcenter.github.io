import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For RawKeyboard
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:printing/printing.dart'; // For printing
import 'package:pdf/pdf.dart'; // For PDF generation
import 'package:pdf/widgets.dart' as pw; // PDF widgets
import 'package:share_plus/share_plus.dart'; // For sharing the PDF
import 'dart:io'; // For file handling
import 'package:path_provider/path_provider.dart'; // For temporary file storage

// Import InvoiceViewScreen from the purchase invoice file
// Adjust the path based on your project structure
import 'purchaseinvoice.dart'; // Example path, update accordingly

class ProcessedTransaction {
  final DocumentSnapshot doc;
  final String type;
  final double creditAmount;
  final double debitAmount;
  final double balance;
  final DateTime date;
  final String? accountName; // Added to store account name for cash transactions

  ProcessedTransaction(this.doc, this.type, this.creditAmount, this.debitAmount,
      this.balance, this.date, {this.accountName});
}

class AccountTotal {
  final double credit;
  final double debit;

  AccountTotal(this.credit, this.debit);
}

class MonthClosing {
  final String monthYear; // e.g., "October 2023"
  final double closingBalance;
  final double monthCredit;
  final double monthDebit;

  MonthClosing(this.monthYear, this.closingBalance, this.monthCredit, this.monthDebit);
}

class MonthClosingData {
  final double credit;
  final double debit;
  final double closingBalance;

  MonthClosingData(this.credit, this.debit, this.closingBalance);
}

class ProcessedData {
  final List<ProcessedTransaction> transactions;
  final double totalCredit;
  final double totalDebit;
  final double finalBalance;
  final Map<String, AccountTotal> accountTotals;
  final List<MonthClosing> monthClosings; // Added for month-wise closings

  ProcessedData(this.transactions, this.totalCredit, this.totalDebit, this.finalBalance,
      this.accountTotals, this.monthClosings);
}

class CompanyLedgerPage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback toggleDarkMode;

  const CompanyLedgerPage({
    Key? key,
    required this.isDarkMode,
    required this.toggleDarkMode,
  }) : super(key: key);

  @override
  State<CompanyLedgerPage> createState() => _CompanyLedgerPageState();
}

class _CompanyLedgerPageState extends State<CompanyLedgerPage> {
  final CollectionReference _companies = FirebaseFirestore.instance.collection('companies');
  final CollectionReference _purchaseInvoices =
  FirebaseFirestore.instance.collection('purchaseinvoices');
  final CollectionReference _cashRegisters =
  FirebaseFirestore.instance.collection('cash_registers');
  final CollectionReference _accounts = FirebaseFirestore.instance.collection('accounts');

  String? _selectedCompanyId;
  String? _selectedCompanyName;
  String? _openingType;
  String? _openingDate;
  double _balanceLimit = 0.0;
  double _balanceAmount = 0.0;
  DateTime? _fromDate;
  DateTime? _toDate;

  // FocusNode for the entire page and dropdown
  final FocusNode _pageFocusNode = FocusNode();
  final FocusNode _dropdownFocusNode = FocusNode();

  // Color Scheme matching the purchase invoice code
  Color get _primaryColor => const Color(0xFF0D6EFD);
  Color get _textColor => widget.isDarkMode ? Colors.white : const Color(0xFF2D2D2D);
  Color get _secondaryTextColor => widget.isDarkMode ? Colors.white70 : const Color(0xFF4A4A4A);
  Color get _backgroundColor => widget.isDarkMode ? const Color(0xFF1A1A2F) : const Color(0xFFF8F9FA);
  Color get _surfaceColor => widget.isDarkMode ? const Color(0xFF252541) : Colors.white;

  Stream<List<DocumentSnapshot>> get _combinedTransactions {
    if (_selectedCompanyId == null || _selectedCompanyName == null) {
      print('No company selected yet.');
      return Stream.value([]);
    }

    print('Fetching transactions for company: $_selectedCompanyName (ID: $_selectedCompanyId)');
    return CombineLatestStream.combine2(
      _purchaseInvoices.where('company', isEqualTo: _selectedCompanyName).snapshots(),
      _cashRegisters.where('entity_id', isEqualTo: _selectedCompanyId).snapshots(),
          (QuerySnapshot purchases, QuerySnapshot cash) {
        print('Purchase Invoices fetched: ${purchases.docs.length}');
        for (var doc in purchases.docs) {
          print('Purchase Invoice: ${doc.id}, Data: ${doc.data()}');
        }
        print('Cash Registers fetched: ${cash.docs.length}');
        for (var doc in cash.docs) {
          print('Cash Register: ${doc.id}, Data: ${doc.data()}');
        }
        List<DocumentSnapshot> transactions = [];
        transactions.addAll(purchases.docs);
        transactions.addAll(cash.docs);
        return transactions;
      },
    );
  }

  Future<ProcessedData> _processTransactions(List<DocumentSnapshot> transactions) async {
    double totalCredit = 0.0;
    double totalDebit = 0.0;
    double currentBalance = _balanceAmount;
    Map<String, AccountTotal> accountTotals = {};
    List<ProcessedTransaction> processed = [];
    Map<String, MonthClosingData> monthData = {};
    List<MonthClosing> monthClosings = [];

    print('Processing ${transactions.length} transactions...');
    transactions.sort((a, b) {
      DateTime? aDate = _getDate(a);
      DateTime? bDate = _getDate(b);
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });

    for (var doc in transactions) {
      final isPurchase = doc.reference.parent.id == 'purchaseinvoices';
      final amount = (isPurchase ? doc['total'] : doc['amount'])?.toDouble() ?? 0.0;
      final date = _getDate(doc);

      if (date == null) {
        print('Skipping transaction ${doc.id} due to invalid date.');
        continue;
      }
      if (_fromDate != null && date.isBefore(_fromDate!)) continue;
      if (_toDate != null && date.isAfter(_toDate!)) continue;

      String type;
      String accountName;
      double credit = 0.0;
      double debit = 0.0;

      if (isPurchase) {
        type = 'Credit';
        accountName = 'Purchase Invoices';
        credit = amount;
        totalCredit += amount;
        currentBalance += amount;
        print('Processed Purchase Invoice ${doc.id}: Amount: $amount, Balance: $currentBalance');
      } else {
        final accountId = doc['account_id'];
        final accountSnapshot = await _accounts.doc(accountId).get();
        if (!accountSnapshot.exists) {
          print('Account $accountId for Cash Register ${doc.id} not found.');
          accountName = 'Unknown Account';
          type = 'Debit'; // Default to Debit if account type is missing
        } else {
          final account = accountSnapshot.data() as Map<String, dynamic>;
          accountName = account['name'] ?? 'Unknown Account';
          type = account['type'] == 'Credit' ? 'Credit' : 'Debit';
        }

        if (type == 'Credit') {
          credit = amount;
          totalCredit += amount;
          currentBalance += amount;
        } else {
          debit = amount;
          totalDebit += amount;
          currentBalance -= amount;
        }
        print('Processed Cash Transaction ${doc.id}: Type: $type, Amount: $amount, Balance: $currentBalance');
      }

      // Update month-wise data
      final monthKey = DateFormat('MMMM yyyy').format(date);
      monthData.update(
        monthKey,
            (value) => MonthClosingData(
          value.credit + credit,
          value.debit + debit,
          currentBalance,
        ),
        ifAbsent: () => MonthClosingData(credit, debit, currentBalance),
      );

      accountTotals.update(
        accountName,
            (value) => AccountTotal(
          value.credit + (type == 'Credit' ? amount : 0),
          value.debit + (type == 'Debit' ? amount : 0),
        ),
        ifAbsent: () => AccountTotal(
          type == 'Credit' ? amount : 0,
          type == 'Debit' ? amount : 0,
        ),
      );

      processed.add(ProcessedTransaction(
        doc,
        type,
        type == 'Credit' ? amount : 0.0,
        type == 'Debit' ? amount : 0.0,
        currentBalance,
        date,
        accountName: accountName,
      ));
    }

    // Create month closings list
    monthClosings = monthData.entries.map((entry) {
      return MonthClosing(
        entry.key,
        entry.value.closingBalance,
        entry.value.credit,
        entry.value.debit,
      );
    }).toList();

    monthClosings.sort((a, b) {
      final aDate = DateFormat('MMMM yyyy').parse(a.monthYear);
      final bDate = DateFormat('MMMM yyyy').parse(b.monthYear);
      return aDate.compareTo(bDate);
    });

    print('Processed Data: ${processed.length} transactions, Total Credit: $totalCredit, Total Debit: $totalDebit');
    return ProcessedData(processed, totalCredit, totalDebit, currentBalance, accountTotals, monthClosings);
  }

  DateTime? _getDate(DocumentSnapshot doc) {
    try {
      if (doc.reference.parent.id == 'purchaseinvoices') {
        final invoiceDate = doc['invoiceDate'];
        print('Parsing invoiceDate for ${doc.id}: $invoiceDate');
        return DateFormat('dd-MM-yyyy').parse(invoiceDate);
      }
      final createdAt = doc['created_at'] as Timestamp?;
      return createdAt?.toDate();
    } catch (e) {
      print('Error parsing date for ${doc.id}: $e');
      return null;
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: widget.isDarkMode ? ThemeData.dark() : ThemeData.light(),
          child: child!,
        );
      },
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
          child: StreamBuilder<List<DocumentSnapshot>>(
            stream: _combinedTransactions,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return FutureBuilder<ProcessedData>(
                future: _processTransactions(snapshot.data!),
                builder: (context, asyncSnapshot) {
                  if (!asyncSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = asyncSnapshot.data!;
                  return SingleChildScrollView(
                    child: _buildFooter(
                      data.totalCredit,
                      data.totalDebit,
                      data.finalBalance,
                      data.accountTotals,
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _printLedger() async {
    print('Print button pressed');
    if (_selectedCompanyId == null || _selectedCompanyName == null) {
      print('No company selected');
      _showSnackBar('Please select a company to print the ledger', Colors.red);
      return;
    }

    try {
      print('Fetching transactions...');
      final transactions = await _combinedTransactions.first;
      print('Transactions fetched: ${transactions.length}');
      if (transactions.isEmpty) {
        print('No transactions to print');
        _showSnackBar('No transactions found for this company', Colors.orange);
        return;
      }

      print('Processing transactions...');
      final processedData = await _processTransactions(transactions);
      print('Transactions processed: ${processedData.transactions.length}');

      print('Generating PDF...');
      final pdf = pw.Document();
      final numberFormat = NumberFormat.currency(decimalDigits: 0, symbol: '');
      final Uint8List logoImage = (await rootBundle.load('assets/images/logo1.png')).buffer.asUint8List();

      // Prepare display items (transactions and month closings)
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

      // Build the table rows for transactions and month closings
      final List<pw.TableRow> tableRows = [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#0D6EFD')),
          children: [
            'Sr#',
            'Date',
            'Details',
            'Credit',
            'Debit',
            'Balance',
          ].map((text) => pw.Container(
            padding: const pw.EdgeInsets.all(3),
            alignment: pw.Alignment.center,
            child: pw.Text(
              text,
              style: pw.TextStyle(
                color: PdfColors.white, // Header text remains white for contrast
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
            final isPurchase = item.doc.reference.parent.id == 'purchaseinvoices';
            String details = isPurchase
                ? 'Invoice ${item.doc['invoiceId'] ?? 'N/A'}'
                : item.accountName ?? 'Unknown Account';

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
                    details,
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.black), // Changed to black
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    item.creditAmount > 0 ? numberFormat.format(item.creditAmount) : '-',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.black), // Changed to black
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    item.debitAmount > 0 ? numberFormat.format(item.debitAmount) : '-',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.black), // Changed to black
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    numberFormat.format(item.balance),
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.black), // Changed to black
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
                    item.monthCredit > 0 ? numberFormat.format(item.monthCredit) : '-',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    item.monthDebit > 0 ? numberFormat.format(item.monthDebit) : '-',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(3),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    '${numberFormat.format(item.closingBalance)} (${item.closingBalance >= 0 ? "Cr" : "Dr"})',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                  ),
                ),
              ],
            );
          }
          return pw.TableRow(children: List.filled(6, pw.SizedBox()));
        }),
      ];

      // Build the totals table rows
      final List<pw.TableRow> totalsTableRows = [
        pw.TableRow(children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(3),
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total Credit:',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(3),
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              numberFormat.format(processedData.totalCredit),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
            ),
          ),
        ]),
        pw.TableRow(children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(3),
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total Debit:',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(3),
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              numberFormat.format(processedData.totalDebit),
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
                        'COMPANY LEDGER',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#0D6EFD'), // Title remains blue
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
                        'Company:',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.Text(
                        _selectedCompanyName ?? 'N/A',
                        style: const pw.TextStyle(fontSize: 13, color: PdfColors.black),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Balance Limit:',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.Text(
                        numberFormat.format(_balanceLimit),
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.black),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Account Type:',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.Text(
                        _openingType ?? 'N/A',
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.black),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Opening Date:',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.Text(
                        _formatDate(_openingDate),
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
                3: const pw.FlexColumnWidth(1.5),  // Credit
                4: const pw.FlexColumnWidth(1.5),  // Debit
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
                        color: PdfColor.fromHex('#0D6EFD'), // Remains blue as per purchase order
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
          name: 'PFC-LEDGER-${_selectedCompanyId}-${DateTime.now().millisecondsSinceEpoch}-A4',
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

  // Fallback method to save and share the PDF if printing fails
  Future<void> _saveAndSharePdf(pw.Document pdf) async {
    try {
      print('Saving PDF to temporary file...');
      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/company_ledger.pdf');
      await file.writeAsBytes(bytes);
      print('PDF saved to ${file.path}');

      print('Sharing PDF...');
      await Share.shareXFiles([XFile(file.path)],
          text: 'Company Ledger PDF',
          subject: 'Company Ledger');
      print('Share dialog opened');
    } catch (e) {
      print('Error saving/sharing PDF: $e');
      _showSnackBar('Failed to save/share PDF: $e', Colors.red);
    }
  }

  void _viewInvoice(DocumentSnapshot invoiceDoc) {
    final invoice = invoiceDoc.data() as Map<String, dynamic>;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceViewScreen.fromData(
          company: invoice['company'] ?? 'Unknown Company',
          invoiceId: invoiceDoc.id,
          existingInvoice: invoice,
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      print('Key pressed: ${event.logicalKey.keyLabel}'); // Debug log
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        _showSummaryBottomSheet(context);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() {
          _selectedCompanyId = null;
          _selectedCompanyName = null;
          _openingType = null;
          _openingDate = null;
          _balanceLimit = 0.0;
          _balanceAmount = 0.0;
          _fromDate = null;
          _toDate = null;
        });
        return KeyEventResult.handled;
      } else if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyF) {
        _dropdownFocusNode.requestFocus();
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
    // Request focus on the page when it loads to ensure keyboard events are captured
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pageFocusNode.dispose();
    _dropdownFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _pageFocusNode,
      onKey: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Text('Company Ledger', style: TextStyle(color: _textColor)),
              const SizedBox(width: 16),
              Expanded(child: _buildCompanyDropdown()),
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
            if (_selectedCompanyId != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: _buildOpeningBalanceCard(),
              ),
              Expanded(
                child: StreamBuilder<List<DocumentSnapshot>>(
                  stream: _combinedTransactions,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: _primaryColor));
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Text('No transactions found', style: TextStyle(color: _textColor)),
                      );
                    }

                    return FutureBuilder<ProcessedData>(
                      future: _processTransactions(snapshot.data!),
                      builder: (context, asyncSnapshot) {
                        if (asyncSnapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator(color: _primaryColor));
                        }

                        if (asyncSnapshot.hasError) {
                          print('Error in FutureBuilder: ${asyncSnapshot.error}');
                          return Center(
                              child: Text('Error loading transactions',
                                  style: TextStyle(color: _textColor)));
                        }

                        final data = asyncSnapshot.data!;
                        List<dynamic> displayItems = [];
                        int transactionIndex = 0;
                        int monthClosingIndex = 0;

                        while (transactionIndex < data.transactions.length ||
                            monthClosingIndex < data.monthClosings.length) {
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
                                DateFormat('MMMM yyyy').format(data.transactions[transactionIndex].date) !=
                                    monthClosing.monthYear) {
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
                            _buildTableHeader(),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                itemCount: displayItems.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final item = displayItems[index];
                                  if (item is ProcessedTransaction) {
                                    return _buildTransactionRow(item);
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
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilterChip(String label, DateTime? date, bool isFromDate) {
    return InputChip(
      label: Text(
        date != null ? DateFormat('dd-MM-yyyy').format(date) : label,
        style: TextStyle(
          color: date != null ? _primaryColor : _secondaryTextColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: _surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _primaryColor.withOpacity(0.3)),
      ),
      onPressed: () => _selectDate(context, isFromDate),
    );
  }

  Widget _buildCompanyDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _companies.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator(color: _primaryColor, strokeWidth: 2);
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          print('No companies found in Firestore.');
          return const Text('No companies available');
        }

        // Sort the company list alphabetically by name
        List<DocumentSnapshot> companyList = snapshot.data!.docs;
        companyList.sort((a, b) {
          String nameA = (a['name'] as String).toLowerCase();
          String nameB = (b['name'] as String).toLowerCase();
          return nameA.compareTo(nameB);
        });

        print('Sorted company list: ${companyList.map((e) => e['name']).toList()}');

        return Container(
          height: 56,
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownSearch<String>(
            popupProps: PopupProps.menu(
              showSearchBox: true,
              showSelectedItems: true,
              searchFieldProps: TextFieldProps(
                focusNode: _dropdownFocusNode,
                autofocus: true, // Automatically focus the search field when popup opens
                decoration: InputDecoration(
                  hintText: 'Search company...',
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
                hintText: 'Select company',
                hintStyle: TextStyle(color: _secondaryTextColor, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
              ),
              baseStyle: TextStyle(color: _textColor, fontSize: 14),
            ),
            items: companyList.map((company) => company['name'] as String).toList(),
            selectedItem: _selectedCompanyName,
            onChanged: (String? value) async {
              if (value == null) return;
              final selectedCompany = companyList.firstWhere((company) => company['name'] == value);
              setState(() {
                _selectedCompanyId = selectedCompany.id;
                _selectedCompanyName = selectedCompany['name'];
                _openingType = selectedCompany['balance_type'] ?? 'N/A';
                _openingDate = selectedCompany['balance_date'] ?? 'N/A';
                _balanceLimit = (selectedCompany['balance_limit'] ?? 0).toDouble();
                _balanceAmount = (selectedCompany['balance_amount'] ?? 0).toDouble();
                print(
                  'Company selected: $_selectedCompanyName (ID: $_selectedCompanyId), Balance: $_balanceAmount',
                );
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
                  _selectedCompanyId = null;
                  _selectedCompanyName = null;
                  _openingType = null;
                  _openingDate = null;
                  _balanceLimit = 0.0;
                  _balanceAmount = 0.0;
                });
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildOpeningBalanceCard() {
    if (_selectedCompanyId == null || _selectedCompanyName == null) {
      return Center(
        child: Text(
          'Please select a company',
          style: TextStyle(color: _textColor),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Company Details',
            style: GoogleFonts.roboto(
              color: _primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          _buildDetailRow('Balance Limit', '${_balanceLimit.toStringAsFixed(0)}/-'),
          _buildDetailRow('Account Type', _openingType ?? 'N/A'),
          _buildDetailRow('Opening Date', _formatDate(_openingDate)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: _secondaryTextColor,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: _textColor,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(child: _HeaderCell('Date')),
            Expanded(child: _HeaderCell('Details')),
            Expanded(child: _HeaderCell('Credit')),
            Expanded(child: _HeaderCell('Debit')),
            Expanded(child: _HeaderCell('Balance')),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionRow(ProcessedTransaction pt) {
    final isPurchase = pt.doc.reference.parent.id == 'purchaseinvoices';

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(child: _DataCell(DateFormat('dd-MM-yyyy').format(pt.date))),
            Expanded(
              child: isPurchase
                  ? GestureDetector(
                onTap: () => _viewInvoice(pt.doc),
                child: _DataCell(
                  'Invoice ${pt.doc['invoiceId'] ?? 'N/A'}',
                  color: _primaryColor,
                ),
              )
                  : _DataCell(pt.accountName ?? 'Unknown Account'),
            ),
            Expanded(
              child: _DataCell(
                pt.creditAmount > 0 ? '${pt.creditAmount.toStringAsFixed(0)}/-' : '-',
                color: pt.creditAmount > 0 ? Colors.green : _secondaryTextColor,
              ),
            ),
            Expanded(
              child: _DataCell(
                pt.debitAmount > 0 ? '${pt.debitAmount.toStringAsFixed(0)}/-' : '-',
                color: pt.debitAmount > 0 ? Colors.red : _secondaryTextColor,
              ),
            ),
            Expanded(
              child: _DataCell(
                '${pt.balance.toStringAsFixed(0)}/-',
                color: pt.balance >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthClosingRow(MonthClosing mc) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(child: _DataCell('Total in')),
            Expanded(child: _DataCell(mc.monthYear, color: Colors.white)),
            Expanded(
              child: _DataCell(
                mc.monthCredit > 0 ? '${mc.monthCredit.toStringAsFixed(0)}/-' : '-',
                color: Colors.white,
              ),
            ),
            Expanded(
              child: _DataCell(
                mc.monthDebit > 0 ? '${mc.monthDebit.toStringAsFixed(0)}/-' : '-',
                color: Colors.white,
              ),
            ),
            Expanded(
              child: _DataCell(
                '${mc.closingBalance.toStringAsFixed(0)} (${mc.closingBalance >= 0 ? "Cr" : "Dr"})',
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(double totalCredit, double totalDebit, double finalBalance,
      Map<String, AccountTotal> accountTotals) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          if (accountTotals.isNotEmpty) ...[
            ...accountTotals.entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      entry.key,
                      style: TextStyle(
                          color: _textColor, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${entry.value.credit.toStringAsFixed(0)}/-',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.green, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${entry.value.debit.toStringAsFixed(0)}/-',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.red, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            )),
            const Divider(),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFooterColumn('Total Credit', totalCredit, Colors.green),
              _buildFooterColumn('Total Debit', totalDebit, Colors.red),
              _buildFooterColumn('Final Balance', finalBalance,
                  finalBalance >= 0 ? Colors.green : Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterColumn(String label, double value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: _secondaryTextColor, fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(0)}/-',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateFormat('dd-MM-yyyy').parse(dateString);
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      print('Error formatting date: $e');
      return dateString;
    }
  }

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

  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final dynamic text;
  final Color? color;

  const _DataCell(this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = (context.findAncestorWidgetOfExactType<CompanyLedgerPage>())!.isDarkMode;
    return Center(
      child: text is Widget
          ? text
          : Text(
        text.toString(),
        style: TextStyle(
          color: color ?? (isDarkMode ? Colors.white : const Color(0xFF2D2D2D)),
          fontSize: 14,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}