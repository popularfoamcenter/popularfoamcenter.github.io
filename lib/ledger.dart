import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For RawKeyboard
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'package:dropdown_search/dropdown_search.dart';

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

  ProcessedTransaction(
      this.doc, this.type, this.creditAmount, this.debitAmount, this.balance, this.date);
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

  ProcessedData(this.transactions, this.totalCredit, this.totalDebit, this.finalBalance,
      this.accountTotals);
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

      if (isPurchase) {
        type = 'Credit';
        accountName = 'Purchase Invoices';
        totalCredit += amount;
        currentBalance += amount;
        print('Processed Purchase Invoice ${doc.id}: Amount: $amount, Balance: $currentBalance');
      } else {
        final accountId = doc['account_id'];
        final account = await _accounts.doc(accountId).get();
        accountName = account['name'] ?? 'Unknown Account';
        type = account['type'] == 'Credit' ? 'Credit' : 'Debit';

        if (type == 'Credit') {
          totalCredit += amount;
          currentBalance += amount;
        } else {
          totalDebit += amount;
          currentBalance -= amount;
        }
        print('Processed Cash Transaction ${doc.id}: Type: $type, Amount: $amount, Balance: $currentBalance');
      }

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
      ));
    }

    print('Processed Data: ${processed.length} transactions, Total Credit: $totalCredit, Total Debit: $totalDebit');
    return ProcessedData(processed, totalCredit, totalDebit, currentBalance, accountTotals);
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
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showSummaryBottomSheet(context),
          backgroundColor: _primaryColor,
          child: const Icon(Icons.info_outline, color: Colors.white),
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
                        return Column(
                          children: [
                            _buildTableHeader(),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                itemCount: data.transactions.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 8),
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

        final companyList = snapshot.data!.docs;

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
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              baseStyle: TextStyle(color: _textColor, fontSize: 14),
            ),
            dropdownBuilder: (context, selectedItem) {
              return GestureDetector(
                onTap: () {
                  // Request focus on the dropdown field when clicked
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _dropdownFocusNode.requestFocus();
                  });
                },
                child: Text(
                  selectedItem ?? 'Select company',
                  style: TextStyle(
                    color: selectedItem != null ? _textColor : _secondaryTextColor,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
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
                  : FutureBuilder<DocumentSnapshot>(
                future: _accounts.doc(pt.doc['account_id']).get(),
                builder: (context, snapshot) {
                  return _DataCell(snapshot.data?['name'] ?? 'Unknown Account');
                },
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