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
import 'pointofsale.dart'; // Assuming this contains Invoice class and PointOfSalePage

class ProcessedTransaction {
  final DocumentSnapshot doc;
  final String type;
  final double creditAmount;
  final double debitAmount;
  final double paidAmount;
  final double balance;
  final DateTime date;
  final String? accountName; // Added to store account name for cash transactions

  ProcessedTransaction(this.doc, this.type, this.creditAmount, this.debitAmount,
      this.paidAmount, this.balance, this.date, {this.accountName});
}

class AccountTotal {
  final double credit;
  final double debit;

  AccountTotal(this.credit, this.debit);
}

class ProcessedData {
  final List<ProcessedTransaction> transactions;
  final double totalCredit;
  final double totalDebit;
  final double finalBalance;
  final Map<String, AccountTotal> accountTotals;

  ProcessedData(this.transactions, this.totalCredit, this.totalDebit,
      this.finalBalance, this.accountTotals);
}

class CustomerLedgerPage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback toggleDarkMode;

  const CustomerLedgerPage({
    super.key,
    required this.isDarkMode,
    required this.toggleDarkMode,
  });

  @override
  _CustomerLedgerPageState createState() => _CustomerLedgerPageState();
}

class _CustomerLedgerPageState extends State<CustomerLedgerPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _customers =
  FirebaseFirestore.instance.collection('customers');
  final CollectionReference _invoices =
  FirebaseFirestore.instance.collection('invoices');
  final CollectionReference _cashRegisters =
  FirebaseFirestore.instance.collection('cash_registers');
  final CollectionReference _accounts =
  FirebaseFirestore.instance.collection('accounts');

  String? _selectedCustomerId;
  Map<String, dynamic>? _selectedCustomerData;
  List<Map<String, dynamic>> _customersList = [];
  bool _isLoadingCustomers = false;
  String? _errorMessage;
  DateTime? _fromDate;
  DateTime? _toDate;

  // FocusNode for the page and dropdown
  final FocusNode _pageFocusNode = FocusNode();
  final FocusNode _dropdownFocusNode = FocusNode();

  Color get _primaryColor => const Color(0xFF0D6EFD);
  Color get _textColor => widget.isDarkMode ? Colors.white : const Color(0xFF2D2D2D);
  Color get _secondaryTextColor =>
      widget.isDarkMode ? Colors.white70 : const Color(0xFF4A4A4A);
  Color get _backgroundColor =>
      widget.isDarkMode ? const Color(0xFF1A1A2F) : const Color(0xFFF8F9FA);
  Color get _surfaceColor =>
      widget.isDarkMode ? const Color(0xFF252541) : Colors.white;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    // Request focus on the page when it loads
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

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoadingCustomers = true;
      _errorMessage = null;
      print('Starting to load customers from Firestore...');
    });

    try {
      final snapshot = await _customers.get();
      print('Customers snapshot received with ${snapshot.docs.length} documents');

      setState(() {
        _customersList = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Unnamed Customer',
            'number': data['number'] ?? '',
            'address': data['address'] ?? '',
            'balanceAmount': (data['balanceAmount'] ?? 0.0).toDouble(),
            'balanceType': data['balanceType'] ?? 'N/A',
          };
        }).toList();

        // Sort the customers list alphabetically by name
        _customersList.sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));

        _isLoadingCustomers = false;
        print('Customers loaded and sorted: ${_customersList.length}');
      });
    } catch (e) {
      print('Error loading customers: $e');
      setState(() {
        _errorMessage = 'Error loading customers: $e';
        _isLoadingCustomers = false;
      });
      _showSnackBar('Failed to load customers: $e', Colors.red);
    }
  }

  Stream<List<DocumentSnapshot>> get _combinedTransactions {
    if (_selectedCustomerId == null) {
      print('No customer selected yet.');
      return Stream.value([]);
    }

    print('Fetching transactions for customer ID: $_selectedCustomerId');
    final invoiceStream = _invoices
        .where('customer.id', isEqualTo: _selectedCustomerId)
        .snapshots()
        .map((snapshot) {
      print('Invoices fetched: ${snapshot.docs.length}');
      for (var doc in snapshot.docs) {
        print('Invoice: ${doc.id}, Data: ${doc.data()}');
      }
      return snapshot.docs;
    });

    final cashStream = _cashRegisters
        .where('entity_id', isEqualTo: _selectedCustomerId)
        .where('entity_type', isEqualTo: 'Customer')
        .snapshots()
        .map((snapshot) {
      print('Cash Registers fetched: ${snapshot.docs.length}');
      for (var doc in snapshot.docs) {
        print('Cash Register: ${doc.id}, Data: ${doc.data()}');
      }
      return snapshot.docs;
    });

    return Rx.combineLatest2(
      invoiceStream,
      cashStream,
          (List<DocumentSnapshot> invoices, List<DocumentSnapshot> cash) {
        final transactions = [...invoices, ...cash];
        print('Combined transactions: ${transactions.length}');
        return transactions;
      },
    ).onErrorReturnWith((error, stackTrace) {
      print('Error in stream: $error');
      return [];
    });
  }

  Future<ProcessedData> _processTransactions(
      List<DocumentSnapshot> transactions) async {
    double totalCredit = 0.0;
    double totalDebit = 0.0;
    double currentBalance =
    (_selectedCustomerData?['balanceAmount'] ?? 0.0).toDouble();
    Map<String, AccountTotal> accountTotals = {};
    List<ProcessedTransaction> processed = [];

    print('Processing ${transactions.length} transactions...');
    transactions.sort((a, b) {
      DateTime? aDate = _getDate(a);
      DateTime? bDate = _getDate(b);
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });

    for (var doc in transactions) {
      final isInvoice = doc.reference.parent.id == 'invoices';
      final amount = (isInvoice ? doc['total'] : doc['amount'])?.toDouble() ?? 0.0;
      final paid = (isInvoice ? doc['givenAmount'] : 0.0)?.toDouble() ?? 0.0;
      final date = _getDate(doc);

      if (date == null) {
        print('Skipping transaction ${doc.id} due to invalid date: ${doc['date'] ?? doc['created_at']}');
        continue;
      }
      if (_fromDate != null && date.isBefore(_fromDate!)) continue;
      if (_toDate != null && date.isAfter(_toDate!)) continue;

      String type;
      String accountName = 'Unknown Account';
      double credit = 0.0;
      double debit = 0.0;

      if (isInvoice) {
        final transactionType = doc['type'] ?? 'Sale';
        switch (transactionType) {
          case 'Sale':
          case 'Order Booking':
            type = 'Debit';
            debit = amount;
            totalDebit += amount;
            break;
          case 'Return':
            type = 'Credit';
            credit = amount;
            totalCredit += amount;
            break;
          default:
            type = 'Debit';
            debit = amount;
            totalDebit += amount;
        }
        if (paid > 0) {
          credit += paid;
          totalCredit += paid;
        }
        accountName = 'Invoices - $transactionType';
        currentBalance = currentBalance + debit - credit;
        print('Processed Invoice ${doc.id}: Type: $type, Amount: $amount, Paid: $paid, Balance: $currentBalance');
      } else {
        final accountId = doc['account_id'];
        if (accountId == null) {
          print('Cash Register ${doc.id} has no account_id, skipping.');
          continue;
        }
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
          currentBalance -= amount;
        } else {
          debit = amount;
          totalDebit += amount;
          currentBalance += amount;
        }
        print('Processed Cash Transaction ${doc.id}: Type: $type, Amount: $amount, Balance: $currentBalance');
      }

      accountTotals.update(
        accountName,
            (value) => AccountTotal(
          value.credit + credit,
          value.debit + debit,
        ),
        ifAbsent: () => AccountTotal(credit, debit),
      );

      processed.add(ProcessedTransaction(
        doc,
        type,
        credit,
        debit,
        paid,
        currentBalance,
        date,
        accountName: accountName,
      ));
    }

    print(
        'Processed Data: ${processed.length} transactions, Total Credit: $totalCredit, Total Debit: $totalDebit');
    return ProcessedData(
        processed, totalCredit, totalDebit, currentBalance, accountTotals);
  }

  DateTime? _getDate(DocumentSnapshot doc) {
    try {
      if (doc.reference.parent.id == 'invoices') {
        final timestamp = doc['timestamp'];
        if (timestamp is Timestamp) {
          return timestamp.toDate();
        } else if (timestamp is String) {
          print('Parsing invoice timestamp string for ${doc.id}: $timestamp');
          return DateFormat('dd-MM-yyyy').parse(timestamp);
        }
        print('Invalid invoice timestamp for ${doc.id}: $timestamp');
        return null;
      }
      final dateField = doc['date'] ?? doc['created_at'];
      if (dateField is Timestamp) {
        return dateField.toDate();
      } else if (dateField is String) {
        print('Parsing cash register date string for ${doc.id}: $dateField');
        return DateFormat('dd-MM-yyyy').parse(dateField);
      }
      print('Invalid cash register date for ${doc.id}: $dateField');
      return null;
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
    if (_selectedCustomerId == null || _selectedCustomerData == null) {
      print('No customer selected');
      _showSnackBar('Please select a customer to print the ledger', Colors.red);
      return;
    }

    try {
      print('Fetching transactions...');
      final transactions = await _combinedTransactions.first;
      print('Transactions fetched: ${transactions.length}');
      if (transactions.isEmpty) {
        print('No transactions to print');
        _showSnackBar('No transactions found for this customer', Colors.orange);
        return;
      }

      print('Processing transactions...');
      final processedData = await _processTransactions(transactions);
      print('Transactions processed: ${processedData.transactions.length}');

      print('Generating PDF...');
      final pdf = pw.Document();

      // Load the font
      final font = await PdfGoogleFonts.robotoRegular();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header
              pw.Text(
                'Customer Ledger',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue,
                ),
              ),
              pw.SizedBox(height: 16),

              // Customer Details
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Customer Details',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(children: [
                      pw.SizedBox(
                        width: 100,
                        child: pw.Text(
                          'Name',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ),
                      pw.Text(
                        _selectedCustomerData!['name'] ?? 'N/A',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 12,
                          color: PdfColors.black,
                        ),
                      ),
                    ]),
                    pw.SizedBox(height: 4),
                    pw.Row(children: [
                      pw.SizedBox(
                        width: 100,
                        child: pw.Text(
                          'Number',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ),
                      pw.Text(
                        _selectedCustomerData!['number'] ?? 'N/A',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 12,
                          color: PdfColors.black,
                        ),
                      ),
                    ]),
                    pw.SizedBox(height: 4),
                    pw.Row(children: [
                      pw.SizedBox(
                        width: 100,
                        child: pw.Text(
                          'Opening Balance',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ),
                      pw.Text(
                        '${(_selectedCustomerData!['balanceAmount'] ?? 0.0).toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 12,
                          color: PdfColors.black,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Table Header
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.blue,
                  borderRadius: pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(12),
                    topRight: pw.Radius.circular(12),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        'Date',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        'Details',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        'Debit',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        'Credit',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        'Balance',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Table Rows
              ...processedData.transactions.map((pt) {
                final isInvoice = pt.doc.reference.parent.id == 'invoices';
                String details;
                if (isInvoice) {
                  details = '${pt.doc['type']} - Invoice #${pt.doc['invoiceNumber'] ?? 'N/A'}';
                } else {
                  details = pt.accountName ?? 'Unknown Account';
                }

                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey300),
                      left: pw.BorderSide(color: PdfColors.grey300),
                      right: pw.BorderSide(color: PdfColors.grey300),
                    ),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          DateFormat('dd-MM-yyyy').format(pt.date),
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 12,
                            color: PdfColors.black,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          details,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 12,
                            color: PdfColors.blue,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          pt.debitAmount > 0 ? '${pt.debitAmount.toStringAsFixed(0)}/-' : '-',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 12,
                            color: pt.debitAmount > 0 ? PdfColors.red : PdfColors.grey600,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          pt.creditAmount > 0 ? '${pt.creditAmount.toStringAsFixed(0)}/-' : '-',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 12,
                            color: pt.creditAmount > 0 ? PdfColors.green : PdfColors.grey600,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          '${pt.balance.toStringAsFixed(0)}/-',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 12,
                            color: pt.balance >= 0 ? PdfColors.green : PdfColors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ];
          },
        ),
      );

      print('PDF generated, attempting to print...');
      try {
        final printed = await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
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
      final file = File('${dir.path}/customer_ledger.pdf');
      await file.writeAsBytes(bytes);
      print('PDF saved to ${file.path}');

      print('Sharing PDF...');
      await Share.shareXFiles([XFile(file.path)],
          text: 'Customer Ledger PDF',
          subject: 'Customer Ledger');
      print('Share dialog opened');
    } catch (e) {
      print('Error saving/sharing PDF: $e');
      _showSnackBar('Failed to save/share PDF: $e', Colors.red);
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
          _selectedCustomerId = null;
          _selectedCustomerData = null;
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

  Widget _buildCustomerDropdown() {
    if (_isLoadingCustomers) {
      print('Customer dropdown is loading...');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              'Loading customers...',
              style: TextStyle(color: _textColor, fontSize: 14),
            ),
          ],
        ),
      );
    }
    if (_errorMessage != null) {
      print('Error in customer dropdown: $_errorMessage');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
            TextButton(
              onPressed: _loadCustomers,
              child: Text(
                'Retry',
                style: TextStyle(color: _primaryColor, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }
    if (_customersList.isEmpty) {
      print('No customers found in the list');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No customers found',
              style: TextStyle(color: _textColor, fontSize: 14),
            ),
            TextButton(
              onPressed: _loadCustomers,
              child: Text(
                'Retry',
                style: TextStyle(color: _primaryColor, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    print('Building customer dropdown with ${_customersList.length} customers');
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
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search customer...',
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
            hintText: 'Select customer',
            hintStyle: TextStyle(color: _secondaryTextColor, fontSize: 14),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
          baseStyle: TextStyle(color: _textColor, fontSize: 14),
        ),
        dropdownBuilder: (context, selectedItem) {
          return Text(
            selectedItem ?? 'Select customer',
            style: TextStyle(
              color: selectedItem != null ? _textColor : _secondaryTextColor,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          );
        },
        items: _customersList.map((customer) => customer['name'] as String).toList(),
        selectedItem: _selectedCustomerData?['name'],
        onChanged: (String? value) async {
          if (value == null) return;
          final customerData = _customersList.firstWhere((customer) => customer['name'] == value);
          final customerDoc = await _customers.doc(customerData['id']).get();
          print('Selected customer ID: ${customerData['id']}, Name: ${customerDoc['name']}');
          setState(() {
            _selectedCustomerId = customerData['id'];
            _selectedCustomerData = {
              'id': customerDoc.id,
              'name': customerDoc['name'] ?? 'Unnamed Customer',
              'number': customerDoc['number'] ?? '',
              'address': customerDoc['address'] ?? '',
              'balanceAmount': (customerDoc['balanceAmount'] ?? 0.0).toDouble(),
              'balanceType': customerDoc['balanceType'] ?? 'N/A',
            };
            print('Customer data: $_selectedCustomerData');
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
              _selectedCustomerId = null;
              _selectedCustomerData = null;
            });
          },
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

  Widget _buildCustomerDetails() {
    if (_selectedCustomerData == null || _selectedCustomerData!.isEmpty) {
      return Center(
        child: Text(
          'Please select a customer',
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
            'Customer Details',
            style: GoogleFonts.roboto(
              color: _primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          _buildDetailRow('Name', _selectedCustomerData!['name'] ?? 'N/A'),
          _buildDetailRow('Number', _selectedCustomerData!['number'] ?? 'N/A'),
          _buildDetailRow(
            'Opening Balance',
            '${(_selectedCustomerData!['balanceAmount'] ?? 0.0).toStringAsFixed(2)}',
          ),
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
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(child: _HeaderCell('Date')),
            Expanded(child: _HeaderCell('Details')),
            Expanded(child: _HeaderCell('Debit')),
            Expanded(child: _HeaderCell('Credit')),
            Expanded(child: _HeaderCell('Balance')),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionRow(ProcessedTransaction pt) {
    final isInvoice = pt.doc.reference.parent.id == 'invoices';

    print('Rendering row for ${pt.doc.id}: Invoice? $isInvoice, Debit: ${pt.debitAmount}, Credit: ${pt.creditAmount}');
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(child: _DataCell(DateFormat('dd-MM-yyyy').format(pt.date))),
            Expanded(
              child: isInvoice
                  ? GestureDetector(
                onTap: () => _navigateToViewInvoice(pt.doc),
                child: _DataCell(
                  '${pt.doc['type']} - Invoice #${pt.doc['invoiceNumber'] ?? 'N/A'}',
                  color: _primaryColor,
                ),
              )
                  : _DataCell(pt.accountName ?? 'Unknown Account'),
            ),
            Expanded(
              child: _DataCell(
                pt.debitAmount > 0 ? '${pt.debitAmount.toStringAsFixed(0)}/-' : '-',
                color: pt.debitAmount > 0 ? Colors.red : _secondaryTextColor,
              ),
            ),
            Expanded(
              child: _DataCell(
                pt.creditAmount > 0 ? '${pt.creditAmount.toStringAsFixed(0)}/-' : '-',
                color: pt.creditAmount > 0 ? Colors.green : _secondaryTextColor,
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

  Future<void> _navigateToViewInvoice(DocumentSnapshot invoiceDoc) async {
    try {
      final invoiceId = invoiceDoc.id;
      final invoiceSnapshot = await _invoices.doc(invoiceId).get();
      if (!invoiceSnapshot.exists) {
        _showSnackBar('Invoice not found', Colors.red);
        return;
      }

      final invoiceData = invoiceSnapshot.data() as Map<String, dynamic>;
      final invoice = Invoice.fromMap(
        invoiceId,
        invoiceData,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PointOfSalePage(invoice: invoice, isReadOnly: true),
        ),
      );
    } catch (e) {
      print('Error navigating to view invoice: $e');
      _showSnackBar('Failed to view invoice: $e', Colors.red);
    }
  }

  Widget _buildFooter(double totalCredit, double totalDebit,
      double finalBalance, Map<String, AccountTotal> accountTotals) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
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
                        color: _textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${entry.value.debit.toStringAsFixed(0)}/-',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${entry.value.credit.toStringAsFixed(0)}/-',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
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
              _buildFooterColumn('Total Debit', totalDebit, Colors.red),
              _buildFooterColumn('Total Credit', totalCredit, Colors.green),
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
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
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

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _pageFocusNode,
      onKey: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Text('Customer Ledger', style: TextStyle(color: _textColor)),
              const SizedBox(width: 16),
              Expanded(child: _buildCustomerDropdown()),
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
            if (_selectedCustomerId != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: _buildCustomerDetails(),
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
                        child: Text('No transactions found',
                            style: TextStyle(color: _textColor)),
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
                                style: TextStyle(color: _textColor)),
                          );
                        }

                        final data = asyncSnapshot.data!;
                        return Column(
                          children: [
                            _buildTableHeader(),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                itemCount: data.transactions.length,
                                separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                                itemBuilder: (context, index) =>
                                    _buildTransactionRow(data.transactions[index]),
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
}

class _HeaderCell extends StatelessWidget {
  final String text;

  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
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
    final isDarkMode =
    (context.findAncestorWidgetOfExactType<CustomerLedgerPage>()!.isDarkMode);
    return Center(
      child: text is Widget
          ? text
          : Text(
        text.toString(),
        style: TextStyle(
          color: color ??
              (isDarkMode ? Colors.white : const Color(0xFF2D2D2D)),
          fontSize: 14,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}