import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

// Color Scheme
const Color _primaryColor = Color(0xFF0D6EFD);
const Color _textColor = Color(0xFF2D2D2D);
const Color _secondaryTextColor = Color(0xFF4A4A4A);
const Color _backgroundColor = Color(0xFFF8F9FA);
const Color _surfaceColor = Colors.white;

class CompanyPage extends StatefulWidget {
  @override
  _CompanyPageState createState() => _CompanyPageState();
}

class _CompanyPageState extends State<CompanyPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _partyIdController = TextEditingController();
  final TextEditingController _partyNameController = TextEditingController();
  final TextEditingController _balanceAmountController = TextEditingController();
  final TextEditingController _balanceLimitController = TextEditingController();
  final TextEditingController _balanceDateController = TextEditingController();
  String? _balanceType;

  @override
  void dispose() {
    _nameController.dispose();
    _partyIdController.dispose();
    _partyNameController.dispose();
    _balanceAmountController.dispose();
    _balanceLimitController.dispose();
    _balanceDateController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        await FirebaseFirestore.instance.collection('companies').add({
          'name': _nameController.text,
          'party_id': _partyIdController.text,
          'party_name': _partyNameController.text,
          'balance_type': _balanceType,
          'balance_amount': int.tryParse(_balanceAmountController.text) ?? 0,
          'balance_limit': int.tryParse(_balanceLimitController.text) ?? 0,
          'balance_date': _balanceDateController.text,
          'created_at': Timestamp.now(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company saved successfully!')),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving company: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Add Company', style: TextStyle(color: _textColor)),
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _textColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
            _buildFormSection('Company Details', [
            _buildTextFormField('Company Name', _nameController),
            _buildTextFormField('Party ID', _partyIdController),
            _buildTextFormField('Party Name', _partyNameController),
            const SizedBox(height: 16),
              isDesktop
                  ? Row(
                children: [
                  Expanded(
                    child: _buildBalanceTypeDropdown(
                      _balanceType,
                          (value) => setState(() => _balanceType = value),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDatePicker('Balance Date', _balanceDateController, context),
                  ),
                ],
              )
                  : Column(
                children: [
                  _buildBalanceTypeDropdown(
                    _balanceType,
                        (value) => setState(() => _balanceType = value),
                  ),
                  const SizedBox(height: 16),
                  _buildDatePicker('Balance Date', _balanceDateController, context),
                ],
              ),
                  _buildTextFormField('Balance Amount', _balanceAmountController, isNumeric: true),
                  _buildTextFormField('Balance Limit', _balanceLimitController, isNumeric: true),
                ]),
            const SizedBox(height: 24),
            _buildSaveButton(_submitForm),
          ],
          ),
        ),
      ),
    );
  }


  Widget _buildFormSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(
              color: _primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w600
          )),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextFormField(String label, TextEditingController controller, {bool isNumeric = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
            color: _textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500
        )),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: _textColor, fontSize: 14),
          decoration: _inputDecoration(label),
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          inputFormatters: isNumeric ? [FilteringTextInputFormatter.digitsOnly] : null,
          validator: (value) => value!.isEmpty ? 'Required field' : null,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBalanceTypeDropdown(String? value, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: _inputDecoration('Balance Type'),
      dropdownColor: _surfaceColor,
      items: const [
        DropdownMenuItem(value: 'Credit', child: Text('Credit')),
        DropdownMenuItem(value: 'Debit', child: Text('Debit')),
      ],
      onChanged: onChanged,
      style: const TextStyle(color: _textColor),
      validator: (value) => value == null ? 'Please select a type' : null,
    );
  }

  Widget _buildDatePicker(String label, TextEditingController controller, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
            color: _textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500
        )),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true,
          onTap: () async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2101),
            );
            if (pickedDate != null) {
              controller.text = '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
            }
          },
          decoration: _inputDecoration(label).copyWith(
            suffixIcon: const Icon(Icons.calendar_today, color: _secondaryTextColor),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(Function onPressed) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.save, size: 20, color: _surfaceColor),
        label: const Text('SAVE COMPANY', style: TextStyle(fontSize: 14, color: _surfaceColor)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        onPressed: () => onPressed(),
      ),
    );
  }


  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _secondaryTextColor),
      filled: true,
      fillColor: _surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryColor),
      ),
    );
  }
}

class CompanyListPage extends StatefulWidget {
  @override
  _CompanyListPageState createState() => _CompanyListPageState();
}

class _CompanyListPageState extends State<CompanyListPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  String _searchQuery = '';
  final double _mobileTableWidth = 1200;

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _deleteCompany(String id) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _surfaceColor,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Confirm Delete',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Are you sure you want to delete this company?',
                style: TextStyle(
                  fontSize: 14,
                  color: _secondaryTextColor,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: _secondaryTextColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        color: _surfaceColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance.collection('companies').doc(id).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company deleted successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting company: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 1200;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Companies', style: TextStyle(color: _textColor)),
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _textColor),
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
          Expanded(
            child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('companies').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _primaryColor));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: _textColor)));
        }

        final companies = snapshot.data?.docs.where((doc) {
          final name = doc['name'].toString().toLowerCase();
          final partyName = doc['party_name'].toString().toLowerCase();
          return name.contains(_searchQuery) || partyName.contains(_searchQuery);
        }).toList();

        if (companies == null || companies.isEmpty) {
          return Center(child: Text('No companies found', style: const TextStyle(color: _textColor)));
        }

        return Column(
          children: [
            _buildDesktopHeader(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 16),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: companies.length,
                itemBuilder: (context, index) => _buildDesktopRow(companies[index]),
              ),
            ),
          ],
        );
      },
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
          child: Column(
            children: [
              _buildMobileHeader(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('companies').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: _primaryColor));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: _textColor)));
                    }

                    final companies = snapshot.data?.docs.where((doc) {
                      final name = doc['name'].toString().toLowerCase();
                      final partyName = doc['party_name'].toString().toLowerCase();
                      return name.contains(_searchQuery) || partyName.contains(_searchQuery);
                    }).toList();

                    if (companies == null || companies.isEmpty) {
                      return Center(child: Text('No companies found', style: const TextStyle(color: _textColor)));
                    }

                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 16),
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemCount: companies.length,
                      itemBuilder: (context, index) => _buildMobileRow(companies[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Container(
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
            Expanded(child: _HeaderCell('Company')),
            Expanded(child: _HeaderCell('Party ID')),
            Expanded(child: _HeaderCell('Balance Type')),
            Expanded(child: _HeaderCell('Amount')),
            Expanded(child: _HeaderCell('Limit')),
            Expanded(child: _HeaderCell('Actions')),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Container(
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
            _HeaderCell('Company', 200),
            _HeaderCell('Party ID', 150),
            _HeaderCell('Balance Type', 150),
            _HeaderCell('Amount', 100),
            _HeaderCell('Limit', 100),
            _HeaderCell('Actions', 150),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopRow(DocumentSnapshot company) {
    return Container(
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
            Expanded(child: _DataCell(company['name'])),
            Expanded(child: _DataCell(company['party_id'])),
            Expanded(child: _DataCell(company['balance_type'] ?? 'N/A')),
            Expanded(child: _DataCell(company['balance_amount'].toString())),
            Expanded(child: _DataCell(company['balance_limit'].toString())),
            Expanded(child: _ActionCell(
              company,
              150,
              onEdit: (company) => _showEditDialog(company),
              onDelete: (id) => _deleteCompany(id),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileRow(DocumentSnapshot company) {
    return Container(
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
            _DataCell(company['name'], 200),
            _DataCell(company['party_id'], 150),
            _DataCell(company['balance_type'] ?? 'N/A', 150),
            _DataCell(company['balance_amount'].toString(), 100),
            _DataCell(company['balance_limit'].toString(), 100),
            _ActionCell(
              company,
              150,
              onEdit: (company) => _showEditDialog(company),
              onDelete: (id) => _deleteCompany(id),
            ),
          ],
        ),
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
          hintText: 'Search companies...',
          filled: true,
          fillColor: _surfaceColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear, color: _secondaryTextColor),
            onPressed: () => setState(() => _searchController.clear()),
          ),
          prefixIcon: const Icon(Icons.search, color: _secondaryTextColor),
        ),
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
      ),
    );
  }

  Widget _buildAddButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add, size: 20, color: _surfaceColor),
        label: const Text('Add Company', style: TextStyle(fontSize: 14, color: _surfaceColor)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CompanyPage())),
      ),
    );
  }

  Future<void> _showEditDialog(DocumentSnapshot company) async {
    final bool isDesktop = MediaQuery.of(context).size.width >= 768;
    final TextEditingController nameController = TextEditingController(text: company['name']);
    final TextEditingController partyIdController = TextEditingController(text: company['party_id']);
    final TextEditingController partyNameController = TextEditingController(text: company['party_name']);
    final TextEditingController balanceAmountController =
    TextEditingController(text: (company['balance_amount']?.toInt() ?? 0).toString());
    final TextEditingController balanceLimitController =
    TextEditingController(text: (company['balance_limit']?.toInt() ?? 0).toString());
    final TextEditingController balanceDateController = TextEditingController(text: company['balance_date']);

    String? balanceType = company['balance_type'];

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _surfaceColor,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Edit Company',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textColor)),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                decoration: _inputDecoration('Company Name'),
                style: const TextStyle(color: _textColor),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: partyIdController,
                decoration: _inputDecoration('Party ID'),
                style: const TextStyle(color: _textColor),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: partyNameController,
                decoration: _inputDecoration('Party Name'),
                style: const TextStyle(color: _textColor),
              ),
              const SizedBox(height: 16),
              isDesktop
                  ? Row(
                children: [
                  Expanded(child: _buildEditBalanceTypeDropdown(balanceType, (value) => balanceType = value)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildEditDatePicker(balanceDateController)),
                ],
              )
                  : Column(
                children: [
                  _buildEditBalanceTypeDropdown(balanceType, (value) => balanceType = value),
                  const SizedBox(height: 16),
                  _buildEditDatePicker(balanceDateController),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: balanceAmountController,
                decoration: _inputDecoration('Balance Amount*'),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: _textColor),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: balanceLimitController,
                decoration: _inputDecoration('Balance Limit*'),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: _textColor),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (balanceType == null ||
                      balanceAmountController.text.isEmpty ||
                      balanceLimitController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill all required fields')),
                    );
                    return;
                  }

                  try {
                    await FirebaseFirestore.instance
                        .collection('companies')
                        .doc(company.id)
                        .update({
                      'name': nameController.text,
                      'party_id': partyIdController.text,
                      'party_name': partyNameController.text,
                      'balance_type': balanceType,
                      'balance_amount': int.parse(balanceAmountController.text),
                      'balance_limit': int.parse(balanceLimitController.text),
                      'balance_date': balanceDateController.text,
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Company updated successfully')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating company: $e')),
                    );
                  }
                },
                child: const Text('UPDATE', style: TextStyle(color: _surfaceColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditBalanceTypeDropdown(String? value, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: _surfaceColor,
      decoration: _inputDecoration('Balance Type*'),
      items: const [
        DropdownMenuItem(value: 'Credit', child: Text('Credit', style: TextStyle(color: _textColor))),
        DropdownMenuItem(value: 'Debit', child: Text('Debit', style: TextStyle(color: _textColor))),
      ],
      onChanged: onChanged,
      validator: (value) => value == null ? 'Required' : null,
    );
  }

  Widget _buildEditDatePicker(TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: _inputDecoration('Balance Date'),
      readOnly: true,
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
        );
        if (pickedDate != null) {
          controller.text =
          '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
        }
      },
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _secondaryTextColor),
      filled: true,
      fillColor: _surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryColor),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double? width;

  const _HeaderCell(this.text, [this.width]);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final String text;
  final double? width;

  const _DataCell(this.text, [this.width]);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Center(
        child: Text(
          text,
          style: const TextStyle(color: _textColor, fontSize: 14),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }
}

class _ActionCell extends StatelessWidget {
  final DocumentSnapshot company;
  final double? width;
  final Function(DocumentSnapshot) onEdit;
  final Function(String) onDelete;

  const _ActionCell(
      this.company,
      this.width, {
        required this.onEdit,
        required this.onDelete,
      });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, color: _primaryColor, size: 20),
            onPressed: () => onEdit(company),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            onPressed: () => onDelete(company.id),
          ),
        ],
      ),
    );
  }
}