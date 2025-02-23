import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

class ProcessedTransaction {
  final DocumentSnapshot doc;
  final String type;
  final double creditAmount;
  final double debitAmount;
  final double balance;
  final DateTime date;

  ProcessedTransaction(this.doc, this.type, this.creditAmount, this.debitAmount, this.balance, this.date);
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

  ProcessedData(this.transactions, this.totalCredit, this.totalDebit, this.finalBalance, this.accountTotals);
}

class CompanyLedgerPage extends StatefulWidget {
  const CompanyLedgerPage({Key? key}) : super(key: key);

  @override
  State<CompanyLedgerPage> createState() => _CompanyLedgerPageState();
}

class _CompanyLedgerPageState extends State<CompanyLedgerPage> {
  final CollectionReference _companies = FirebaseFirestore.instance.collection('companies');
  final CollectionReference _purchaseInvoices = FirebaseFirestore.instance.collection('purchaseinvoices');
  final CollectionReference _cashRegisters = FirebaseFirestore.instance.collection('cash_registers');
  final CollectionReference _accounts = FirebaseFirestore.instance.collection('accounts');

  final Color _primaryColor = const Color(0xFF0D6EFD);
  final Color _textColor = const Color(0xFF2D2D2D);
  final Color _backgroundColor = const Color(0xFFF8F9FA);
  final Color _surfaceColor = Colors.white;

  String? _selectedCompanyId;
  String? _selectedCompanyName;
  String? _openingType;
  String? _openingDate;
  double _balanceLimit = 0.0;
  double _balanceAmount = 0.0;
  double _currentBalance = 0.0;
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _showSummary = false;

  Stream<List<DocumentSnapshot>> get _combinedTransactions {
    if (_selectedCompanyId == null || _selectedCompanyName == null) {
      return Stream.value([]);
    }

    return CombineLatestStream.combine2(
      _purchaseInvoices.where('company', isEqualTo: _selectedCompanyName).snapshots(),
      _cashRegisters.where('entity_id', isEqualTo: _selectedCompanyId).snapshots(),
          (QuerySnapshot purchases, QuerySnapshot cash) {
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

    // Sort and filter transactions by date
    transactions.sort((a, b) {
      DateTime? aDate = _getDate(a);
      DateTime? bDate = _getDate(b);
      return aDate?.compareTo(bDate ?? DateTime(0)) ?? 0;
    });

    for (var doc in transactions) {
      final isPurchase = doc.reference.parent.id == 'purchaseinvoices';
      final amount = (isPurchase ? doc['total'] : doc['amount'])?.toDouble() ?? 0.0;
      final date = _getDate(doc);

      // Date filtering
      if (date == null) continue;
      if (_fromDate != null && date.isBefore(_fromDate!)) continue;
      if (_toDate != null && date.isAfter(_toDate!)) continue;

      String type;

      if (isPurchase) {
        type = 'Credit';
        totalCredit += amount;
        currentBalance += amount;

        accountTotals.update(
          'Purchase Invoices',
              (value) => AccountTotal(value.credit + amount, value.debit),
          ifAbsent: () => AccountTotal(amount, 0),
        );
      } else {
        final accountId = doc['account_id'];
        final account = await _accounts.doc(accountId).get();
        final accountName = account['name'] ?? 'Unknown Account';
        type = account['type'] == 'Credit' ? 'Credit' : 'Debit';

        if (type == 'Credit') {
          totalCredit += amount;
          currentBalance += amount;
          accountTotals.update(
            accountName,
                (value) => AccountTotal(value.credit + amount, value.debit),
            ifAbsent: () => AccountTotal(amount, 0),
          );
        } else {
          totalDebit += amount;
          currentBalance -= amount;
          accountTotals.update(
            accountName,
                (value) => AccountTotal(value.credit, value.debit + amount),
            ifAbsent: () => AccountTotal(0, amount),
          );
        }
      }

      processed.add(ProcessedTransaction(
        doc,
        type,
        type == 'Credit' ? amount : 0.0,
        type == 'Debit' ? amount : 0.0,
        currentBalance,
        date,
      ));
    }

    return ProcessedData(processed, totalCredit, totalDebit, currentBalance, accountTotals);
  }

  DateTime? _getDate(DocumentSnapshot doc) {
    try {
      if (doc.reference.parent.id == 'purchaseinvoices') {
        return DateFormat('yyyy-MM-dd').parse(doc['invoiceDate']);
      }
      return (doc['created_at'] as Timestamp?)?.toDate();
    } catch (e) {
      return null;
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Ledger', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(child: _buildCompanyDropdown()),
            const SizedBox(width: 10),
            _buildDateFilterChip('From', _fromDate, true),
            const SizedBox(width: 10),
            _buildDateFilterChip('To', _toDate, false),
          ],
        ),
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor),
        actions: [
          IconButton(
            icon: Icon(_showSummary ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _showSummary = !_showSummary),
          ),
        ],
      ),
      backgroundColor: _backgroundColor,
      body: Column(
        children: [
          if (_selectedCompanyId != null) ...[
            _buildOpeningBalanceCard(),
            const SizedBox(height: 16),
            _buildTableHeader(),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<DocumentSnapshot>>(
                stream: _combinedTransactions,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: _primaryColor));
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        children: [
                          Text('No transactions found', style: TextStyle(color: _textColor)),
                          if (_showSummary) _buildFooter(0, 0, _balanceAmount, {}),
                        ],
                      ),
                    );
                  }

                  return FutureBuilder<ProcessedData>(
                    future: _processTransactions(snapshot.data!),
                    builder: (context, asyncSnapshot) {
                      if (asyncSnapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: _primaryColor));
                      }

                      if (asyncSnapshot.hasError) {
                        return Center(child: Text('Error loading transactions'));
                      }

                      final data = asyncSnapshot.data!;
                      return Column(
                        children: [
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: data.transactions.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final pt = data.transactions[index];
                                return _buildTransactionRow(pt);
                              },
                            ),
                          ),
                          if (_showSummary) _buildFooter(data.totalCredit, data.totalDebit, data.finalBalance, data.accountTotals),
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

  Widget _buildDateFilterChip(String label, DateTime? date, bool isFromDate) {
    return InputChip(
      label: Text(
        date != null ? DateFormat('MMM dd').format(date) : label,
        style: TextStyle(
          color: date != null ? _primaryColor : _textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: _surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
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

        return Container(
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _primaryColor.withOpacity(0.3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              dropdownColor: _surfaceColor,
              value: _selectedCompanyId,
              hint: Text(
                'Select company',
                style: TextStyle(
                  color: _textColor.withOpacity(0.6),
                  fontSize: 16,
                ),
              ),
              icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
              items: snapshot.data?.docs.map((company) {
                return DropdownMenuItem<String>(
                  value: company.id,
                  child: Text(
                    company['name'] ?? 'Unnamed',
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 16,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) async {
                final company = await _companies.doc(value).get();
                setState(() {
                  _selectedCompanyId = value;
                  _selectedCompanyName = company['name'];
                  _openingType = company['balance_type'] ?? 'N/A';
                  _openingDate = company['balance_date'] ?? 'N/A';
                  _balanceLimit = (company['balance_limit'] ?? 0).toDouble();
                  _balanceAmount = (company['balance_amount'] ?? 0).toDouble();
                  _currentBalance = _balanceAmount;
                });
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildOpeningBalanceCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
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
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBalanceInfo('Balance Limit', '${_balanceLimit.toStringAsFixed(2)}/-'),
              _buildBalanceInfo('Account Type', _openingType!),
              _buildBalanceInfo('Opening Date', _formatDate(_openingDate)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceInfo(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _textColor.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: _textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Color(0xFF0D6EFD),
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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Row(
          children: [
            Expanded(child: _HeaderText('Details')),
            Expanded(child: _HeaderText('Date')),
            Expanded(child: _HeaderText('Credit')),
            Expanded(child: _HeaderText('Debit')),
            Expanded(child: _HeaderText('Balance')),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionRow(ProcessedTransaction pt) {
    final isPurchase = pt.doc.reference.parent.id == 'purchaseinvoices';

    return Container(
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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Row(
          children: [
            Expanded(
              child: isPurchase
                  ? _buildTransactionText('Invoice ${pt.doc['invoiceId']}')
                  : FutureBuilder<DocumentSnapshot>(
                future: _accounts.doc(pt.doc['account_id']).get(),
                builder: (context, snapshot) {
                  return _buildTransactionText(snapshot.data?['name'] ?? 'Unknown Account');
                },
              ),
            ),
            Expanded(child: _buildTransactionText(DateFormat('MMM dd').format(pt.date))),
            Expanded(
              child: _buildTransactionText(
                pt.creditAmount > 0 ? '${pt.creditAmount.toStringAsFixed(2)}/-' : '-',
                color: pt.creditAmount > 0 ? Colors.green : _textColor.withOpacity(0.6),
              ),
            ),
            Expanded(
              child: _buildTransactionText(
                pt.debitAmount > 0 ? '${pt.debitAmount.toStringAsFixed(2)}/-' : '-',
                color: pt.debitAmount > 0 ? Colors.red : _textColor.withOpacity(0.6),
              ),
            ),
            Expanded(
              child: _buildTransactionText(
                '${pt.balance.toStringAsFixed(2)}/-',
                color: pt.balance >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionText(String text, {Color? color}) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color ?? _textColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildFooter(double totalCredit, double totalDebit, double finalBalance, Map<String, AccountTotal> accountTotals) {
    return Visibility(
      visible: _showSummary,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
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
                padding: const EdgeInsets.symmetric(vertical: 4.0),
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
                        '${entry.value.credit.toStringAsFixed(2)}/-',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${entry.value.debit.toStringAsFixed(2)}/-',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
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
      ),
    );
  }

  Widget _buildFooterColumn(String label, double value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _textColor.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(2)}/-',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return 'Invalid Date';
    }
  }
}

class _HeaderText extends StatelessWidget {
  final String text;

  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
      textAlign: TextAlign.center,
    );
  }
}