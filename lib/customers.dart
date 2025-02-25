import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

// Color Scheme
const Color _primaryColor = Color(0xFF0D6EFD);
const Color _textColor = Color(0xFF2D2D2D);
const Color _secondaryTextColor = Color(0xFF4A4A4A);
const Color _backgroundColor = Color(0xFFF8F9FA);
const Color _surfaceColor = Colors.white;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Customer Management',
      theme: ThemeData(
        primaryColor: _primaryColor,
        scaffoldBackgroundColor: _backgroundColor,
      ),
      home: const CustomerListPage(),
    );
  }
}

class CustomerListPage extends StatefulWidget {
  const CustomerListPage({super.key});

  @override
  _CustomerListPageState createState() => _CustomerListPageState();
}
class _CustomerListPageState extends State<CustomerListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool get isDesktop => MediaQuery.of(context).size.width >= 1200;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers', style: TextStyle(color: Colors.black)),
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
                _buildAddCustomerButton(),
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
    return Column(
      children: [
        _buildTableHeader(),
        const SizedBox(height: 8),
        Expanded(child: _buildCustomerList(isDesktop: true)),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          width: 1200,
          child: Column(
            children: [
              _buildMobileTableHeader(),
              const SizedBox(height: 8),
              Expanded(child: _buildCustomerList(isDesktop: false)),
            ],
          ),
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
          hintText: 'Search customers...',
          filled: true,
          fillColor: _surfaceColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          suffixIcon: Icon(Icons.search, color: _secondaryTextColor),
        ),
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
      ),
    );
  }

  Widget _buildAddCustomerButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Add Customer', style: TextStyle(fontSize: 14)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddCustomerPage())),
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
            Expanded(child: _HeaderText('Name')),
            Expanded(child: _HeaderText('Number')),
            Expanded(child: _HeaderText('Address')),
            Expanded(child: _HeaderText('Balance Type')),
            Expanded(child: _HeaderText('Balance')),
            Expanded(child: _HeaderText('Actions')),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTableHeader() {
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
            _HeaderText('Name', 200),
            _HeaderText('Number', 150),
            _HeaderText('Address', 250),
            _HeaderText('Balance Type', 150),
            _HeaderText('Balance', 150),
            _HeaderText('Actions', 200),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerList({required bool isDesktop}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('customers').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _primaryColor));

        final customers = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['name'].toString().toLowerCase().contains(_searchQuery);
        }).toList();

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 16),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: customers.length,
          itemBuilder: (context, index) => _buildCustomerItem(customers[index], isDesktop: isDesktop),
        );
      },
    );
  }

  Widget _buildCustomerItem(DocumentSnapshot document, {required bool isDesktop}) {
    final data = document.data() as Map<String, dynamic>;
    return isDesktop
        ? _buildDesktopCustomerItem(data, document)
        : _buildMobileCustomerItem(data, document);
  }

  Widget _buildDesktopCustomerItem(Map<String, dynamic> data, DocumentSnapshot document) {
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _DataCell(data['name'] ?? '')),
            Expanded(child: _DataCell(data['number'] ?? '')),
            Expanded(child: _DataCell(data['address'] ?? '')),
            Expanded(child: _DataCell(data['balanceType'] ?? '')),
            Expanded(child: _DataCell(data['balanceAmount']?.toStringAsFixed(0) ?? '0')),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: _primaryColor, size: 20),
                    onPressed: () => _showEditCustomerDialog(document),
                  ),
                  IconButton(
                    icon: Icon(Icons.visibility_rounded, color: _primaryColor, size: 20),
                    onPressed: () => _navigateToDiscounts(context, document),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _deleteCustomer(document.id),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCustomerItem(Map<String, dynamic> data, DocumentSnapshot document) {
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
            _DataCell(data['name'] ?? '', 200),
            _DataCell(data['number'] ?? '', 150),
            _DataCell(data['address'] ?? '', 250),
            _DataCell(data['balanceType'] ?? '', 150),
            _DataCell(data['balanceAmount']?.toStringAsFixed(0) ?? '0', 150),
            SizedBox(
              width: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: _primaryColor, size: 20),
                    onPressed: () => _showEditCustomerDialog(document),
                  ),
                  IconButton(
                    icon: Icon(Icons.visibility_rounded, color: _primaryColor, size: 20),
                    onPressed: () => _navigateToDiscounts(context, document),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _deleteCustomer(document.id),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDiscounts(BuildContext context, DocumentSnapshot customerDoc) {
    final data = customerDoc.data() as Map<String, dynamic>;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerDiscountsPage(
          customerId: customerDoc.id,
          customerName: data['name'],
        ),
      ),
    );
  }

  void _showEditCustomerDialog(DocumentSnapshot customerDoc) {
    final data = customerDoc.data() as Map<String, dynamic>;
    final TextEditingController nameController = TextEditingController(text: data['name']);
    final TextEditingController numberController = TextEditingController(text: data['number']);
    final TextEditingController addressController = TextEditingController(text: data['address'] ?? '');
    final TextEditingController balanceController = TextEditingController(
      text: data['balanceAmount']?.toStringAsFixed(0) ?? '0',
    );
    String balanceType = data['balanceType'] ?? 'Credit';

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Edit Customer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 20),
                // Customer Name
                Text(
                  'Customer Name',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nameController,
                  decoration: _inputDecoration('Enter customer name'),
                  style: TextStyle(color: _textColor, fontSize: 14),
                  validator: (value) => value!.isEmpty ? 'Required field' : null,
                ),
                const SizedBox(height: 16),
                // Contact Number
                Text(
                  'Contact Number',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: numberController,
                  decoration: _inputDecoration('Enter contact number'),
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: _textColor, fontSize: 14),
                  validator: (value) => value!.isEmpty ? 'Required field' : null,
                ),
                const SizedBox(height: 16),
                // Address
                Text(
                  'Address (Optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: addressController,
                  decoration: _inputDecoration('Enter address'),
                  style: TextStyle(color: _textColor, fontSize: 14),
                ),
                const SizedBox(height: 16),
                // Balance Type
                Text(
                  'Balance Type',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: balanceType,
                  decoration: _inputDecoration('Select balance type'),
                  dropdownColor: _surfaceColor,
                  style: TextStyle(color: _textColor, fontSize: 14),
                  items: ['Credit', 'Debit'].map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type, style: TextStyle(color: _textColor)),
                    );
                  }).toList(),
                  onChanged: (value) => balanceType = value!,
                ),
                const SizedBox(height: 16),
                // Balance Amount
                Text(
                  'Balance Amount',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: balanceController,
                  decoration: _inputDecoration('Enter balance amount'),
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: _textColor, fontSize: 14),
                  validator: (value) => value!.isEmpty ? 'Required field' : null,
                ),
                const SizedBox(height: 24),
                // Save Button
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isNotEmpty &&
                        numberController.text.isNotEmpty &&
                        balanceController.text.isNotEmpty) {
                      await _updateCustomer(
                        customerDoc.id,
                        nameController.text,
                        numberController.text,
                        addressController.text,
                        balanceType,
                        double.parse(balanceController.text),
                      );
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'SAVE',
                    style: TextStyle(fontSize: 14, color: _surfaceColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateCustomer(
      String id,
      String name,
      String number,
      String address,
      String balanceType,
      double balanceAmount,
      ) async {
    try {
      await _firestore.collection('customers').doc(id).update({
        'name': name,
        'number': number,
        'address': address,
        'balanceType': balanceType,
        'balanceAmount': balanceAmount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating customer: $e')),
      );
    }
  }

  Future<void> _deleteCustomer(String id) async {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Delete Customer',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _textColor)),
              const SizedBox(height: 16),
              Text('Are you sure you want to delete this customer? This action cannot be undone.',
                  style: TextStyle(
                      fontSize: 14,
                      color: _secondaryTextColor)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                    child: Text('CANCEL',
                        style: TextStyle(
                            color: _secondaryTextColor,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: const Text('DELETE',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
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
        await _firestore.collection('customers').doc(id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer deleted successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting customer: $e')),
          );
        }
      }
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      filled: true,
      fillColor: _surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      labelText: label,
      labelStyle: TextStyle(color: _secondaryTextColor, fontSize: 14),
      floatingLabelBehavior: FloatingLabelBehavior.never,
    );
  }
}

class CustomerDiscountsPage extends StatefulWidget {
  final String customerId;
  final String customerName;

  const CustomerDiscountsPage({super.key, required this.customerId, required this.customerName});

  @override
  _CustomerDiscountsPageState createState() => _CustomerDiscountsPageState();
}

class _CustomerDiscountsPageState extends State<CustomerDiscountsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool get isDesktop => MediaQuery.of(context).size.width >= 1200;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.customerName} Discounts', style: TextStyle(color: _textColor)),
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
                _buildAddDiscountButton(),
              ],
            ),
          ),
          Expanded(
            child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        _buildTableHeader(),
        const SizedBox(height: 8),
        Expanded(child: _buildDiscountList(isDesktop: true)),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          width: 1200,
          child: Column(
            children: [
              _buildMobileTableHeader(),
              const SizedBox(height: 8),
              Expanded(child: _buildDiscountList(isDesktop: false)),
            ],
          ),
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
          hintText: 'Search discounts...',
          filled: true,
          fillColor: _surfaceColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          suffixIcon: Icon(Icons.search, color: _secondaryTextColor),
        ),
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
      ),
    );
  }

  Widget _buildAddDiscountButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        icon: Icon(Icons.add, size: 20, color: _surfaceColor),
        label: Text('Add Discount', style: TextStyle(fontSize: 14, color: _surfaceColor)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        onPressed: () => _showDiscountDialog(context),
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
            Expanded(child: _HeaderText('Quality')),
            Expanded(child: _HeaderText('Item')),
            Expanded(child: _HeaderText('Type')),
            Expanded(child: _HeaderText('Covered/Unc')),
            Expanded(child: _HeaderText('Amount')),
            Expanded(child: _HeaderText('Actions')),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTableHeader() {
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
            _HeaderText('Quality', 200),
            _HeaderText('Item', 150),
            _HeaderText('Type', 150),
            _HeaderText('Covered/Unc', 200),
            _HeaderText('Amount', 150),
            _HeaderText('Actions', 200),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountList({required bool isDesktop}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('customer_discounts')
          .where('customerId', isEqualTo: widget.customerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _primaryColor));

        final discounts = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['qualityName'].toString().toLowerCase().contains(_searchQuery) ||
              data['item'].toString().toLowerCase().contains(_searchQuery);
        }).toList();

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 16),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: discounts.length,
          itemBuilder: (context, index) => _buildDiscountItem(
            discounts[index].data() as Map<String, dynamic>,
            discounts[index].id,
            isDesktop: isDesktop,
          ),
        );
      },
    );
  }

  Widget _buildDiscountItem(Map<String, dynamic> discount, String docId, {required bool isDesktop}) {
    return isDesktop
        ? _buildDesktopDiscountItem(discount, docId)
        : _buildMobileDiscountItem(discount, docId);
  }

  Widget _buildDesktopDiscountItem(Map<String, dynamic> discount, String docId) {
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
            Expanded(child: _DataCell(discount['qualityName'] ?? '')),
            Expanded(child: _DataCell(discount['item'] ?? '')),
            Expanded(child: _DataCell(discount['type'] ?? '')),
            Expanded(child: _DataCell(
              discount['type'] == 'Discount'
                  ? '${discount['covered']}% / ${discount['uncovered']}%'
                  : '-',
            )),
            Expanded(child: _DataCell(
              discount['type'] == 'Price' ? '${discount['amount']}' : '-',
            )),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: _primaryColor, size: 20),
                    onPressed: () => _showDiscountDialog(context, discount: discount, docId: docId),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _deleteDiscount(docId),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileDiscountItem(Map<String, dynamic> discount, String docId) {
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
            _DataCell(discount['qualityName'] ?? '', 200),
            _DataCell(discount['item'] ?? '', 150),
            _DataCell(discount['type'] ?? '', 150),
            _DataCell(
                discount['type'] == 'Discount'
                    ? '${discount['covered']}% / ${discount['uncovered']}%'
                    : '-',
                200
            ),
            _DataCell(
                discount['type'] == 'Price' ? '${discount['amount']}' : '-',
                150
            ),
            SizedBox(
              width: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: _primaryColor, size: 20),
                    onPressed: () => _showDiscountDialog(context, discount: discount, docId: docId),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _deleteDiscount(docId),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDiscountDialog(BuildContext context, {Map<String, dynamic>? discount, String? docId}) {
    showDialog(
      context: context,
      builder: (context) => DiscountFormDialog(
        customerId: widget.customerId,
        customerName: widget.customerName,
        initialDiscount: discount,
        docId: docId,
        primaryColor: _primaryColor,
        surfaceColor: _surfaceColor,
        textColor: _textColor,
      ),
    );
  }

  void _deleteDiscount(String docId) {
    _firestore.collection('customer_discounts').doc(docId).delete();
  }
}

class DiscountFormDialog extends StatefulWidget {
  final String customerId;
  final String customerName;
  final Map<String, dynamic>? initialDiscount;
  final String? docId;
  final Color primaryColor;
  final Color surfaceColor;
  final Color textColor;

  const DiscountFormDialog({
    super.key,
    required this.customerId,
    required this.customerName,
    this.initialDiscount,
    this.docId,
    required this.primaryColor,
    required this.surfaceColor,
    required this.textColor,
  });

  @override
  _DiscountFormDialogState createState() => _DiscountFormDialogState();
}

class _DiscountFormDialogState extends State<DiscountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedQuality;
  String? _selectedItem;
  String _discountType = 'Discount';
  String _itemSelection = 'All';
  double? _covered;
  double? _uncovered;
  double? _amount;
  List<Map<String, dynamic>> _items = [];
  List<String> _qualities = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialDiscount != null) {
      _selectedQuality = widget.initialDiscount!['qualityName'];
      _itemSelection = widget.initialDiscount!['item'] == 'All' ? 'All' : 'Specific';
      _selectedItem = widget.initialDiscount!['item'];
      _discountType = widget.initialDiscount!['type'];
      _covered = widget.initialDiscount!['covered']?.toDouble();
      _uncovered = widget.initialDiscount!['uncovered']?.toDouble();
      _amount = widget.initialDiscount!['amount']?.toDouble();
    }
    _loadQualities();
  }

  void _loadQualities() async {
    final snapshot = await _firestore.collection('items').get();
    setState(() {
      _qualities = snapshot.docs
          .map((doc) => doc['qualityName'].toString())
          .toSet()
          .toList();
    });
  }

  void _loadItems(String quality) async {
    final snapshot = await _firestore
        .collection('items')
        .where('qualityName', isEqualTo: quality)
        .get();
    setState(() => _items = snapshot.docs.map((doc) => doc.data()).toList());
  }

  void _saveDiscount() {
    if (_formKey.currentState!.validate()) {
      final discountData = {
        'customerId': widget.customerId,
        'customerName': widget.customerName,
        'qualityName': _selectedQuality,
        'item': _itemSelection == 'All' ? 'All' : _selectedItem,
        'type': _discountType,
        'covered': _covered,
        'uncovered': _uncovered,
        'amount': _amount,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (widget.docId != null) {
        _firestore.collection('customer_discounts').doc(widget.docId).update(discountData);
      } else {
        _firestore.collection('customer_discounts').add(discountData);
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: widget.surfaceColor,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: widget.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Discount for ${widget.customerName}',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: widget.textColor)),
                  const SizedBox(height: 20),
                  _buildQualityDropdown(),
                  const SizedBox(height: 16),
                  _buildItemSelection(),
                  const SizedBox(height: 16),
                  _buildDiscountTypeSelector(),
                  const SizedBox(height: 16),
                  _buildDiscountFields(),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _saveDiscount,
                    child: Text('SAVE DISCOUNT', style: TextStyle(color: widget.surfaceColor)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildQualityDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedQuality,
      decoration: _inputDecoration('Quality'),
      dropdownColor: Colors.white,
      items: _qualities.map((quality) => DropdownMenuItem<String>(
        value: quality,
        child: Text(quality, style: TextStyle(fontSize: 14, color: widget.textColor)),
      )).toList(),
      onChanged: (value) {
        setState(() {
          _selectedQuality = value;
          _selectedItem = null;
        });
        if (value != null) _loadItems(value);
      },
      validator: (value) => value == null ? 'Select quality' : null,
    );
  }

  Widget _buildDiscountTypeSelector() {
    final bool isDesktop = MediaQuery.of(context).size.width >= 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Discount Type',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: widget.textColor)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: widget.surfaceColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: isDesktop
              ? Row(
            children: [
              Expanded(child: _buildPercentageRadio()), // Add Expanded
              Expanded(child: _buildFixedRadio()), // Add Expanded
            ],
          )
              : Column(
            children: [
              _buildPercentageRadio(),
              _buildFixedRadio(),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildPercentageRadio() {
    return RadioListTile<String>(
      title: Text('Percentage',
          style: TextStyle(fontSize: 14, color: widget.textColor)),
      value: 'Discount',
      groupValue: _discountType,
      activeColor: widget.primaryColor,
      onChanged: (value) => setState(() => _discountType = value!),
    );
  }

  Widget _buildFixedRadio() {
    return RadioListTile<String>(
      title: Text('Fixed Amount',
          style: TextStyle(fontSize: 14, color: widget.textColor)),
      value: 'Price',
      groupValue: _discountType,
      activeColor: widget.primaryColor,
      onChanged: (value) => setState(() => _discountType = value!),
    );
  }
  Widget _buildItemSelection() {
    final bool isDesktop = MediaQuery.of(context).size.width >= 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Item Selection',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: widget.textColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: widget.surfaceColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: isDesktop
              ? Row(
            children: [
              Expanded(child: _buildAllRadio()), // Add Expanded
              Expanded(child: _buildSpecificRadio()), // Add Expanded
            ],
          )
              : Column(
            children: [
              _buildAllRadio(),
              _buildSpecificRadio(),
            ],
          ),
        ),
        if (_itemSelection == 'Specific' && _selectedQuality != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: DropdownButtonFormField<String>(
              value: _selectedItem,
              decoration: _inputDecoration('Select Item'),
              dropdownColor: Colors.white,
              items: _items.map((item) {
                return DropdownMenuItem<String>(
                  value: item['itemName'],
                  child: Text(
                    item['itemName'],
                    style: TextStyle(fontSize: 14, color: widget.textColor),
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedItem = value),
              validator: (value) => _itemSelection == 'Specific' && value == null
                  ? 'Select item'
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _buildAllRadio() {
    return RadioListTile<String>(
      title: Text('All Items',
          style: TextStyle(fontSize: 14, color: widget.textColor)),
      value: 'All',
      groupValue: _itemSelection,
      activeColor: widget.primaryColor,
      onChanged: (value) => setState(() => _itemSelection = value!),
    );
  }

  Widget _buildSpecificRadio() {
    return RadioListTile<String>(
      title: Text('Specific Item',
          style: TextStyle(fontSize: 14, color: widget.textColor)),
      value: 'Specific',
      groupValue: _itemSelection,
      activeColor: widget.primaryColor,
      onChanged: (value) => setState(() => _itemSelection = value!),
    );
  }


  Widget _buildDiscountFields() {
    return _discountType == 'Discount'
        ? Column(
      children: [
        _buildNumberField('Covered Percentage', (value) => _covered = double.tryParse(value)),
        const SizedBox(height: 16),
        _buildNumberField('Uncovered Percentage', (value) => _uncovered = double.tryParse(value)),
      ],
    )
        : _buildNumberField('Discount Amount', (value) => _amount = double.tryParse(value));
  }

  Widget _buildNumberField(String label, Function(String) onChanged) {
    return TextFormField(
      decoration: _inputDecoration(label),
      keyboardType: TextInputType.number,
      style: TextStyle(color: widget.textColor),
      validator: (value) => value!.isEmpty ? 'Enter $label' : null,
      onChanged: (value) => onChanged(value),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: widget.textColor),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: widget.primaryColor),
      ),
    );
  }
}

class AddCustomerPage extends StatefulWidget {
  const AddCustomerPage({super.key});

  @override
  _AddCustomerPageState createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends State<AddCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();
  String _balanceType = 'Credit';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Customer', style: TextStyle(color: Colors.black)),
        backgroundColor: _backgroundColor,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: _backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    _buildFormSection('Customer Details', [
                      _buildTextFormField('Customer Name', _nameController),
                      _buildNumberFormField('Contact Number', _numberController),
                      _buildTextFormField('Address (Optional)', _addressController, optional: true),
                    ]),
                    _buildFormSection('Balance Information', [
                      _buildDropdownFormField(
                        label: 'Balance Type',
                        value: _balanceType,
                        items: ['Credit', 'Debit'],
                        onChanged: (value) => setState(() => _balanceType = value!),
                      ),
                      _buildNumberFormField('Balance Amount', _balanceController),
                    ]),
                  ],
                ),
              ),
              _buildSaveButton(),
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
          Text(title,
              style: TextStyle(
                  color: _primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextFormField(String label, TextEditingController controller, {bool optional = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: _textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: TextStyle(color: _textColor, fontSize: 14),
          decoration: _inputDecoration(label),
          validator: optional ? null : (value) => value!.isEmpty ? 'Required field' : null,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildNumberFormField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: _textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: TextStyle(color: _textColor, fontSize: 14),
          decoration: _inputDecoration(label),
          validator: (value) => value!.isEmpty ? 'Required field' : null,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDropdownFormField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: _textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          decoration: _inputDecoration('Select $label'),
          dropdownColor: _surfaceColor,
          style: TextStyle(color: _textColor, fontSize: 14),
          items: items.map((item) => DropdownMenuItem<String>(
            value: item,
            child: Text(item, style: TextStyle(color: _textColor)),
          )).toList(),
          onChanged: onChanged,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      filled: true,
      fillColor: _surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      labelText: label,
      labelStyle: TextStyle(color: _secondaryTextColor, fontSize: 14),
      floatingLabelBehavior: FloatingLabelBehavior.never,
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        icon: Icon(Icons.save, size: 20, color: _surfaceColor),
        label: Text('SAVE CUSTOMER', style: TextStyle(fontSize: 14, color: _surfaceColor)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        onPressed: _saveCustomerDetails,
      ),
    );
  }

  Future<void> _saveCustomerDetails() async {
    if (_formKey.currentState!.validate()) {
      try {
        await _firestore.collection('customers').add({
          'name': _nameController.text.trim(),
          'number': _numberController.text.trim(),
          'address': _addressController.text.trim(),
          'balanceType': _balanceType,
          'balanceAmount': double.parse(_balanceController.text.trim()),
          'createdAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer saved successfully!')),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving customer: $e')),
        );
      }
    }
  }
}

class _HeaderText extends StatelessWidget {
  final String text;
  final double width;

  const _HeaderText(this.text, [this.width = double.infinity]);

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
  final double width;

  const _DataCell(this.text, [this.width = double.infinity]);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Center(
        child: Text(
          text,
          style: const TextStyle(color: _textColor, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}