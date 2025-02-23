import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({Key? key}) : super(key: key);

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final CollectionReference _accounts = FirebaseFirestore.instance.collection('accounts');
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  final Color _primaryColor = const Color(0xFF0D6EFD);
  final Color _textColor = const Color(0xFF2D2D2D);
  final Color _secondaryTextColor = const Color(0xFF4A4A4A);
  final Color _backgroundColor = const Color(0xFFF8F9FA);
  final Color _surfaceColor = Colors.white;

  String _searchQuery = '';
  String? _selectedType;

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _addAccount() async {
    if (_nameController.text.isEmpty || _selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account name and type are required')),
      );
      return;
    }

    try {
      await _accounts.add({
        'name': _nameController.text.trim(),
        'type': _selectedType,
        'comments': _commentController.text.trim(),
        'created_at': FieldValue.serverTimestamp(),
      });
      _resetForm();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error adding account')),
      );
    }
  }

  void _resetForm() {
    _nameController.clear();
    _commentController.clear();
    setState(() => _selectedType = null);
  }

  Future<void> _deleteAccount(String id) async {
    // Show confirmation dialog before deleting
    bool? confirmDelete = await showDialog<bool>(
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
              Text(
                'Delete Account',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to delete this account? This action cannot be undone.',
                style: TextStyle(
                  color: _secondaryTextColor,
                  fontSize: 14,
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
                    child: Text(
                      'CANCEL',
                      style: TextStyle(
                        color: _secondaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                      'DELETE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
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
      await _accounts.doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Management', style: TextStyle(color: Colors.black)),
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
          Expanded(child: _buildAccountList()),
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
          hintText: 'Search accounts...',
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
        label: Text('Add Account', style: TextStyle(fontSize: 14, color: _surfaceColor)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        onPressed: () => _showAddForm(),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(child: _HeaderText('Account Name')),
            Expanded(child: _HeaderText('Type')),
            Expanded(child: _HeaderText('Date Created')),
            Expanded(child: _HeaderText('Actions')),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _accounts.orderBy('created_at', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _primaryColor));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: _textColor)));
        }

        final accounts = snapshot.data?.docs.where((doc) {
          final name = doc['name'].toString().toLowerCase();
          final type = doc['type'].toString().toLowerCase();
          return name.contains(_searchQuery) || type.contains(_searchQuery);
        }).toList();

        if (accounts == null || accounts.isEmpty) {
          return Center(child: Text('No accounts found', style: TextStyle(color: _textColor)));
        }

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 16),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: accounts.length,
          itemBuilder: (context, index) => _buildAccountRow(accounts[index]),
        );
      },
    );
  }

  Widget _buildAccountRow(DocumentSnapshot account) {
    final date = (account['created_at'] as Timestamp?)?.toDate();
    final formattedDate = date != null
        ? DateFormat('MMM dd, yyyy ').format(date)
        : 'N/A';

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
            Expanded(
              child: Text(
                account['name'],
                style: TextStyle(color: _textColor, fontSize: 14),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Text(
                account['type'],
                style: TextStyle(color: _textColor, fontSize: 14),
                overflow: TextOverflow.ellipsis,
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: _primaryColor, size: 20),
                    onPressed: () => _showEditDialog(account),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _deleteAccount(account.id),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddForm() {
    showDialog(
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
              Text('Add Account',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textColor)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('Account Name*'),
                style: TextStyle(color: _textColor),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: _inputDecoration('Account Type*'),
                dropdownColor: _surfaceColor,
                items: ['Credit', 'Debit'].map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type, style: TextStyle(color: _textColor)),
                )).toList(),
                onChanged: (value) => setState(() => _selectedType = value),
                style: TextStyle(color: _textColor),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _commentController,
                decoration: _inputDecoration('Comments (optional)'),
                style: TextStyle(color: _textColor),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _addAccount();
                },
                child: Text('SAVE ACCOUNT', style: TextStyle(color: _surfaceColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(DocumentSnapshot account) {
    final nameController = TextEditingController(text: account['name']);
    final commentController = TextEditingController(text: account['comments']);
    String? selectedType = account['type'];

    showDialog(
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
              Text('Edit Account',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textColor)),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                decoration: _inputDecoration('Account Name*'),
                style: TextStyle(color: _textColor),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: _inputDecoration('Account Type*'),
                dropdownColor: _surfaceColor,
                items: ['Credit', 'Debit'].map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type, style: TextStyle(color: _textColor)),
                )).toList(),
                onChanged: (value) => selectedType = value,
                style: TextStyle(color: _textColor),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: commentController,
                decoration: _inputDecoration('Comments (optional)'),
                style: TextStyle(color: _textColor),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  await _accounts.doc(account.id).update({
                    'name': nameController.text,
                    'type': selectedType,
                    'comments': commentController.text,
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account updated successfully')),
                  );
                },
                child: Text('UPDATE', style: TextStyle(color: _surfaceColor)),
              ),
            ],
          ),
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