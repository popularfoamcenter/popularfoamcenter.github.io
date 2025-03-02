import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'pointofsale.dart'; // Import PointOfSalePage from the provided code

class ProcessedTransaction {
  final DocumentSnapshot doc;
  final String type;
  final double creditAmount;
  final double debitAmount;
  final double paidAmount; // New field for paid amount
  final double balance;
  final DateTime date;

  ProcessedTransaction(this.doc, this.type, this.creditAmount, this.debitAmount, this.paidAmount, this.balance, this.date);
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
  final double totalPaid; // New field for total paid
  final double finalBalance;
  final Map<String, AccountTotal> accountTotals;

  ProcessedData(this.transactions, this.totalCredit, this.totalDebit, this.totalPaid, this.finalBalance, this.accountTotals);
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
  final CollectionReference _customers = FirebaseFirestore.instance.collection('customers');
  final CollectionReference _invoices = FirebaseFirestore.instance.collection('invoices');
  final CollectionReference _cashRegisters = FirebaseFirestore.instance.collection('cash_registers');

  String? _selectedCustomerId;
  Map<String, dynamic>? _selectedCustomerData;
  List<Map<String, dynamic>> _customersList = [];
  bool _isLoadingCustomers = false;
  String? _errorMessage;
  DateTime? _fromDate;
  DateTime? _toDate;

  // Adjusted Color Scheme
  Color get _primaryColor => const Color(0xFF0D6EFD);
  Color get _textColor => widget.isDarkMode ? Colors.white : const Color(0xFF2D2D2D);
  Color get _secondaryTextColor => widget.isDarkMode ? Colors.white70 : const Color(0xFF4A4A4A);
  Color get _backgroundColor => widget.isDarkMode ? const Color(0xFF1A1A2F) : const Color(0xFFF8F9FA);
  Color get _surfaceColor => widget.isDarkMode ? const Color(0xFF252541) : Colors.white;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
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
        _isLoadingCustomers = false;
        print('Customers loaded: ${_customersList.length}');
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
    return CombineLatestStream.combine2(
      _invoices.where('customer.id', isEqualTo: _selectedCustomerId).snapshots(),
      _cashRegisters.where('entity_id', isEqualTo: _selectedCustomerId).where('entity_type', isEqualTo: 'Customer').snapshots(),
          (QuerySnapshot invoices, QuerySnapshot cash) {
        print('Invoices fetched: ${invoices.docs.length}');
        for (var doc in invoices.docs) {
          print('Invoice: ${doc.id}, Data: ${doc.data()}');
        }
        print('Cash Registers fetched: ${cash.docs.length}');
        for (var doc in cash.docs) {
          print('Cash Register: ${doc.id}, Data: ${doc.data()}');
        }
        List<DocumentSnapshot> transactions = [];
        transactions.addAll(invoices.docs);
        transactions.addAll(cash.docs);
        return transactions;
      },
    );
  }

  Future<ProcessedData> _processTransactions(List<DocumentSnapshot> transactions) async {
    double totalCredit = 0.0;
    double totalDebit = 0.0;
    double totalPaid = 0.0;
    double currentBalance = (_selectedCustomerData?['balanceAmount'] ?? 0.0).toDouble();
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
      final paid = (isInvoice ? doc['givenAmount'] : 0.0)?.toDouble() ?? 0.0; // From Invoice class
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
        // Add paid amount as credit
        if (paid > 0) {
          credit += paid;
          totalPaid += paid;
          totalCredit += paid;
        }
        accountName = 'Invoices - $transactionType';

        // Update balance: debit increases it, credit and paid decreases it
        currentBalance = currentBalance + debit - credit;
      } else {
        // Cash Registers (Customer entity_type)
        final accountId = doc['account_id'];
        final account = await _firestore.collection('accounts').doc(accountId).get();
        accountName = account['name'] ?? 'Unknown Account';
        type = account['type'] == 'Credit' ? 'Credit' : 'Debit';

        if (type == 'Credit') {
          credit = amount;
          totalCredit += amount;
          currentBalance -= amount;
        } else {
          debit = amount;
          totalDebit += amount;
          currentBalance += amount;
        }
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
      ));
    }

    print('Processed Data: ${processed.length} transactions, Total Credit: $totalCredit, Total Debit: $totalDebit, Total Paid: $totalPaid');
    return ProcessedData(processed, totalCredit, totalDebit, totalPaid, currentBalance, accountTotals);
  }

  DateTime? _getDate(DocumentSnapshot doc) {
    try {
      final timestamp = doc['timestamp'];
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is String) {
        return DateFormat('dd-MM-yyyy').parse(timestamp);
      }
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
                      data.totalPaid,
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
              style: TextStyle(color: Colors.red, fontSize: 14),
            ),
            TextButton(
              onPressed: _loadCustomers, // Retry loading
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
              onPressed: _loadCustomers, // Retry loading
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
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          dropdownColor: _surfaceColor,
          value: _selectedCustomerId,
          hint: Text('Select Customer', style: TextStyle(color: _secondaryTextColor, fontSize: 14)),
          icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
          items: _customersList.map((customer) {
            return DropdownMenuItem<String>(
              value: customer['id'],
              child: Text(
                customer['name'] ?? 'Unnamed Customer',
                style: TextStyle(color: _textColor, fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: (value) async {
            final customer = await _customers.doc(value).get();
            print('Selected customer ID: $value, Name: ${customer['name']}');
            setState(() {
              _selectedCustomerId = value;
              _selectedCustomerData = {
                'id': customer.id,
                'name': customer['name'] ?? 'Unnamed Customer',
                'number': customer['number'] ?? '',
                'address': customer['address'] ?? '',
                'balanceAmount': (customer['balanceAmount'] ?? 0.0).toDouble(),
                'balanceType': customer['balanceType'] ?? 'N/A',
              };
              print('Customer data: $_selectedCustomerData');
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
            Expanded(child: _HeaderCell('Debit')), // Debit first
            Expanded(child: _HeaderCell('Credit')), // Credit second
            Expanded(child: _HeaderCell('Balance')),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionRow(ProcessedTransaction pt) {
    final isInvoice = pt.doc.reference.parent.id == 'invoices';

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
                  : _DataCell('Cash Transaction - ${pt.doc['description'] ?? 'N/A'}'),
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

  Widget _buildFooter(double totalCredit, double totalDebit, double totalPaid, double finalBalance, Map<String, AccountTotal> accountTotals) {
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
                      style: TextStyle(
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
                      style: TextStyle(
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
              _buildFooterColumn('Total Paid', totalPaid, Colors.blue),
              _buildFooterColumn('Final Balance', finalBalance, finalBalance >= 0 ? Colors.green : Colors.red),
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
    return Scaffold(
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSummaryBottomSheet(context),
        backgroundColor: _primaryColor,
        child: const Icon(Icons.info_outline, color: Colors.white),
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
                          child: Text('Error loading transactions', style: TextStyle(color: _textColor)),
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
                              separatorBuilder: (context, index) => const SizedBox(height: 8),
                              itemBuilder: (context, index) => _buildTransactionRow(data.transactions[index]),
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
    final isDarkMode = (context.findAncestorWidgetOfExactType<CustomerLedgerPage>()!.isDarkMode);
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