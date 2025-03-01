import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CashRegisterPage extends StatefulWidget {
  const CashRegisterPage({Key? key}) : super(key: key);

  @override
  State<CashRegisterPage> createState() => _CashRegisterPageState();
}

class _CashRegisterPageState extends State<CashRegisterPage> {
  final CollectionReference _cashRegisters = FirebaseFirestore.instance.collection('cash_registers');
  final CollectionReference _companies = FirebaseFirestore.instance.collection('companies');
  final CollectionReference _customers = FirebaseFirestore.instance.collection('customers');
  final CollectionReference _accounts = FirebaseFirestore.instance.collection('accounts');

  final TextEditingController _searchController = TextEditingController();

  final Color _primaryColor = const Color(0xFF0D6EFD);
  final Color _textColor = const Color(0xFF2D2D2D);
  final Color _secondaryTextColor = const Color(0xFF4A4A4A);
  final Color _backgroundColor = const Color(0xFFF8F9FA);
  final Color _surfaceColor = Colors.white;

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addCashRegister(
      DateTime date,
      String entityType,
      String entityId,
      String accountId,
      double amount,
      String comment,
      ) async {
    try {
      final QuerySnapshot snapshot = await _cashRegisters.get();
      final int nextId = snapshot.size;
      final String newId = 'reg$nextId';

      await _cashRegisters.doc(newId).set({
        'id': newId,
        'date': Timestamp.fromDate(date),
        'entity_type': entityType,
        'entity_id': entityId,
        'account_id': accountId,
        'amount': amount.toDouble(),
        'comments': comment.trim(),
        'created_at': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cash register added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error adding cash register')),
      );
    }
  }

  Future<void> _updateCashRegister(
      String docId,
      DateTime date,
      String entityType,
      String entityId,
      String accountId,
      double amount,
      String comment,
      ) async {
    try {
      await _cashRegisters.doc(docId).update({
        'date': Timestamp.fromDate(date),
        'entity_type': entityType,
        'entity_id': entityId,
        'account_id': accountId,
        'amount': amount.toDouble(),
        'comments': comment.trim(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cash register updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating cash register')),
      );
    }
  }

  Future<void> _deleteCashRegister(String id) async {
    await _cashRegisters.doc(id).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cash register deleted successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Register Management', style: TextStyle(color: Colors.black)),
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor),
      ),
      backgroundColor: _backgroundColor,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(child: _buildSearchBar()),
                const SizedBox(width: 16),
                _buildAddButton(),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildTableHeader(),
          const SizedBox(height: 8),
          Expanded(child: _buildCashRegisterList()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search cash registers...',
          filled: true,
          fillColor: _surfaceColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          suffixIcon: IconButton(
            icon: Icon(Icons.clear, color: _secondaryTextColor),
            onPressed: () => setState(() => _searchController.clear()),
          ),
          prefixIcon: Icon(Icons.search, color: _secondaryTextColor),
        ),
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
      ),
    );
  }

  Widget _buildAddButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        icon: Icon(Icons.add, size: 20, color: _surfaceColor),
        label: Text('Add Register', style: TextStyle(fontSize: 14, color: _surfaceColor)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        onPressed: () async {
          final companies = await _companies.get();
          final customers = await _customers.get();
          final accounts = await _accounts.get();

          showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: _surfaceColor,
              insetPadding: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: AddCashRegisterForm(
                companies: companies,
                customers: customers,
                accounts: accounts,
                onSave: _addCashRegister,
                primaryColor: _primaryColor,
                textColor: _textColor,
                surfaceColor: _surfaceColor,
                inputDecoration: _inputDecoration,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(child: _HeaderText('ID')),
            Expanded(child: _HeaderText('Date')),
            Expanded(child: _HeaderText('Name')),
            Expanded(child: _HeaderText('Account')),
            Expanded(child: _HeaderText('Amount')),
            Expanded(child: _HeaderText('Actions')),
          ],
        ),
      ),
    );
  }

  Widget _buildCashRegisterList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _cashRegisters.orderBy('date', descending: true).snapshots(), // Sort by 'date' descending
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _primaryColor));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: _textColor)));
        }

        final registers = snapshot.data?.docs.where((doc) {
          final entity = doc['entity_type'].toString().toLowerCase();
          final account = doc['account_id'].toString().toLowerCase();
          return entity.contains(_searchQuery) || account.contains(_searchQuery);
        }).toList();

        if (registers == null || registers.isEmpty) {
          return Center(child: Text('No cash registers found', style: TextStyle(color: _textColor)));
        }

        return HorizontalMargin(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 16),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: registers.length,
            itemBuilder: (context, index) => _buildRegisterRow(registers[index]),
          ),
        );
      },
    );
  }

  Widget _buildRegisterRow(DocumentSnapshot register) {
    final date = (register['date'] as Timestamp?)?.toDate();
    final formattedDate = date != null ? DateFormat('dd-MM-yyyy').format(date) : 'N/A';
    final entityType = register['entity_type'] as String?;
    final entityId = register['entity_id'] as String?;
    final accountId = register['account_id'] as String?;
    final registerId = register['id'] as String?;

    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                registerId ?? 'N/A',
                style: TextStyle(color: _textColor, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Text(
                formattedDate,
                style: TextStyle(color: _textColor, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: FutureBuilder<DocumentSnapshot>(
                future: entityType == 'Company'
                    ? _companies.doc(entityId).get()
                    : _customers.doc(entityId).get(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final entity = snapshot.data!.data() as Map<String, dynamic>;
                    return Text(
                      entity['name'] ?? 'N/A',
                      style: TextStyle(color: _textColor, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    );
                  }
                  return Text(
                    'Loading...',
                    style: TextStyle(color: _textColor, fontSize: 14),
                    textAlign: TextAlign.center,
                  );
                },
              ),
            ),
            Expanded(
              child: FutureBuilder<DocumentSnapshot>(
                future: _accounts.doc(accountId).get(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final account = snapshot.data!.data() as Map<String, dynamic>;
                    return Text(
                      account['name'] ?? 'N/A',
                      style: TextStyle(color: _textColor, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    );
                  }
                  return Text(
                    'Loading...',
                    style: TextStyle(color: _textColor, fontSize: 14),
                    textAlign: TextAlign.center,
                  );
                },
              ),
            ),
            Expanded(
              child: Text(
                '${(register['amount'] as num?)?.toStringAsFixed(0) ?? ''}/-',
                style: TextStyle(color: _textColor, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: _primaryColor, size: 20),
                    onPressed: () => _showEditDialog(register),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _deleteCashRegister(register.id),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _secondaryTextColor),
      filled: true,
      fillColor: _surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _primaryColor),
      ),
    );
  }

  void _showEditDialog(DocumentSnapshot register) async {
    final companies = await _companies.get();
    final customers = await _customers.get();
    final accounts = await _accounts.get();

    final date = (register['date'] as Timestamp?)?.toDate();
    final entityType = register['entity_type'] as String?;
    final entityId = register['entity_id'] as String?;
    final accountId = register['account_id'] as String?;
    final initialAmount = (register['amount'] as double?)?.toString() ?? '';
    final comments = register['comments'] as String? ?? '';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _surfaceColor,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: EditCashRegisterForm(
          register: register,
          companies: companies,
          customers: customers,
          accounts: accounts,
          initialDate: date,
          initialEntityType: entityType,
          initialEntityId: entityId,
          initialAccountId: accountId,
          initialAmount: initialAmount,
          initialComment: comments,
          onSave: (date, entityType, entityId, accountId, amount, comment) {
            _updateCashRegister(
              register.id,
              date,
              entityType,
              entityId,
              accountId,
              amount,
              comment,
            );
          },
          primaryColor: _primaryColor,
          textColor: _textColor,
          surfaceColor: _surfaceColor,
          inputDecoration: _inputDecoration,
        ),
      ),
    );
  }
}

class HorizontalMargin extends StatelessWidget {
  final Widget child;

  const HorizontalMargin({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
  }
}

class AddCashRegisterForm extends StatefulWidget {
  final QuerySnapshot companies;
  final QuerySnapshot customers;
  final QuerySnapshot accounts;
  final Function(
      DateTime date,
      String entityType,
      String entityId,
      String accountId,
      double amount,
      String comment,
      ) onSave;
  final Color primaryColor;
  final Color textColor;
  final Color surfaceColor;
  final InputDecoration Function(String) inputDecoration;

  const AddCashRegisterForm({
    Key? key,
    required this.companies,
    required this.customers,
    required this.accounts,
    required this.onSave,
    required this.primaryColor,
    required this.textColor,
    required this.surfaceColor,
    required this.inputDecoration,
  }) : super(key: key);

  @override
  _AddCashRegisterFormState createState() => _AddCashRegisterFormState();
}

class _AddCashRegisterFormState extends State<AddCashRegisterForm> {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  String? _selectedEntityType;
  String? _selectedEntityId;
  String? _selectedAccountId;
  DateTime? _selectedDate;

  @override
  void dispose() {
    _dateController.dispose();
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add Cash Register',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: widget.textColor)),
          const SizedBox(height: 20),
          TextFormField(
            controller: _dateController,
            readOnly: true,
            decoration: widget.inputDecoration('Date*'),
            onTap: () async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (pickedDate != null) {
                setState(() {
                  _selectedDate = pickedDate;
                  _dateController.text = DateFormat('dd-MM-yyyy').format(pickedDate);
                });
              }
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            dropdownColor: Colors.white,
            value: _selectedEntityType,
            decoration: widget.inputDecoration('Entity Type*'),
            items: ['Company', 'Customer'].map((type) => DropdownMenuItem(
              value: type,
              child: Text(type, style: TextStyle(color: widget.textColor)),
            )).toList(),
            onChanged: (value) => setState(() {
              _selectedEntityType = value;
              _selectedEntityId = null;
            }),
          ),
          const SizedBox(height: 16),
          if (_selectedEntityType != null)
            DropdownButtonFormField<String>(
              dropdownColor: Colors.white,
              value: _selectedEntityId,
              decoration: widget.inputDecoration('Select ${_selectedEntityType!}*'),
              items: (_selectedEntityType == 'Company'
                  ? widget.companies.docs
                  : widget.customers.docs
              ).map((doc) => DropdownMenuItem(
                value: doc.id,
                child: Text(doc['name'], style: TextStyle(color: widget.textColor)),
              )).toList(),
              onChanged: (value) => setState(() => _selectedEntityId = value),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            dropdownColor: Colors.white,
            value: _selectedAccountId,
            decoration: widget.inputDecoration('Account*'),
            items: widget.accounts.docs.map((doc) => DropdownMenuItem(
              value: doc.id,
              child: Text(doc['name'], style: TextStyle(color: widget.textColor)),
            )).toList(),
            onChanged: (value) => setState(() => _selectedAccountId = value),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amountController,
            decoration: widget.inputDecoration('Amount*'),
            keyboardType: TextInputType.number,
            style: TextStyle(color: widget.textColor),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _commentController,
            decoration: widget.inputDecoration('Comments (optional)'),
            style: TextStyle(color: widget.textColor),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (_selectedDate == null ||
                  _selectedEntityType == null ||
                  _selectedEntityId == null ||
                  _selectedAccountId == null ||
                  _amountController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All required fields must be filled')),
                );
                return;
              }

              final parsedAmount = double.tryParse(_amountController.text) ?? 0.0;

              widget.onSave(
                _selectedDate!,
                _selectedEntityType!,
                _selectedEntityId!,
                _selectedAccountId!,
                parsedAmount,
                _commentController.text,
              );
              Navigator.pop(context);
            },
            child: Text('SAVE REGISTER', style: TextStyle(color: widget.surfaceColor)),
          ),
        ],
      ),
    );
  }
}

class EditCashRegisterForm extends StatefulWidget {
  final DocumentSnapshot register;
  final QuerySnapshot companies;
  final QuerySnapshot customers;
  final QuerySnapshot accounts;
  final DateTime? initialDate;
  final String? initialEntityType;
  final String? initialEntityId;
  final String? initialAccountId;
  final String initialAmount;
  final String initialComment;
  final Function(
      DateTime date,
      String entityType,
      String entityId,
      String accountId,
      double amount,
      String comment,
      ) onSave;
  final Color primaryColor;
  final Color textColor;
  final Color surfaceColor;
  final InputDecoration Function(String) inputDecoration;

  const EditCashRegisterForm({
    Key? key,
    required this.register,
    required this.companies,
    required this.customers,
    required this.accounts,
    required this.initialDate,
    required this.initialEntityType,
    required this.initialEntityId,
    required this.initialAccountId,
    required this.initialAmount,
    required this.initialComment,
    required this.onSave,
    required this.primaryColor,
    required this.textColor,
    required this.surfaceColor,
    required this.inputDecoration,
  }) : super(key: key);

  @override
  _EditCashRegisterFormState createState() => _EditCashRegisterFormState();
}

class _EditCashRegisterFormState extends State<EditCashRegisterForm> {
  late TextEditingController _dateController;
  late TextEditingController _amountController;
  late TextEditingController _commentController;

  String? _selectedEntityType;
  String? _selectedEntityId;
  String? _selectedAccountId;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(
        text: widget.initialDate != null
            ? DateFormat('dd-MM-yyyy').format(widget.initialDate!)
            : ''
    );
    final amountValue = (widget.register['amount'] as num?)?.toDouble() ?? 0.0;
    _amountController = TextEditingController(text: amountValue.toString());
    _commentController = TextEditingController(text: widget.initialComment);

    _selectedEntityType = widget.initialEntityType;
    _selectedEntityId = widget.initialEntityId;
    _selectedAccountId = widget.initialAccountId;
    _selectedDate = widget.initialDate;
  }

  @override
  void dispose() {
    _dateController.dispose();
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit Cash Register',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: widget.textColor)),
          const SizedBox(height: 20),
          TextFormField(
            initialValue: widget.register['id'],
            readOnly: true,
            decoration: widget.inputDecoration('ID'),
            style: TextStyle(color: widget.textColor),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _dateController,
            readOnly: true,
            decoration: widget.inputDecoration('Date*'),
            onTap: () async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (pickedDate != null) {
                setState(() {
                  _selectedDate = pickedDate;
                  _dateController.text = DateFormat('dd-MM-yyyy').format(pickedDate);
                });
              }
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedEntityType,
            decoration: widget.inputDecoration('Entity Type*'),
            items: ['Company', 'Customer'].map((type) => DropdownMenuItem(
              value: type,
              child: Text(type, style: TextStyle(color: widget.textColor)),
            )).toList(),
            onChanged: (value) => setState(() {
              _selectedEntityType = value;
              _selectedEntityId = null;
            }),
          ),
          const SizedBox(height: 16),
          if (_selectedEntityType != null)
            DropdownButtonFormField<String>(
              value: _selectedEntityId,
              decoration: widget.inputDecoration('Select ${_selectedEntityType!}*'),
              items: (_selectedEntityType == 'Company'
                  ? widget.companies.docs
                  : widget.customers.docs
              ).map((doc) => DropdownMenuItem(
                value: doc.id,
                child: Text(doc['name'], style: TextStyle(color: widget.textColor)),
              )).toList(),
              onChanged: (value) => setState(() => _selectedEntityId = value),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedAccountId,
            decoration: widget.inputDecoration('Account*'),
            items: widget.accounts.docs.map((doc) => DropdownMenuItem(
              value: doc.id,
              child: Text(doc['name'], style: TextStyle(color: widget.textColor)),
            )).toList(),
            onChanged: (value) => setState(() => _selectedAccountId = value),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amountController,
            decoration: widget.inputDecoration('Amount*'),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: widget.textColor),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _commentController,
            decoration: widget.inputDecoration('Comments (optional)'),
            style: TextStyle(color: widget.textColor),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (_selectedDate == null ||
                  _selectedEntityType == null ||
                  _selectedEntityId == null ||
                  _selectedAccountId == null ||
                  _amountController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All required fields must be filled')),
                );
                return;
              }

              final parsedAmount = double.tryParse(_amountController.text) ?? 0.0;

              widget.onSave(
                _selectedDate!,
                _selectedEntityType!,
                _selectedEntityId!,
                _selectedAccountId!,
                parsedAmount,
                _commentController.text,
              );
              Navigator.pop(context);
            },
            child: Text('UPDATE', style: TextStyle(color: widget.surfaceColor)),
          ),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;

  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}