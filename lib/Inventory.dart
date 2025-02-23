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
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory Management',
      theme: ThemeData(
        primaryColor: _primaryColor,
        scaffoldBackgroundColor: _backgroundColor,
      ),
      home: InventoryPage(),
    );
  }
}

class AddItems extends StatefulWidget {
  @override
  _AddItemsState createState() => _AddItemsState();
}

class _AddItemsState extends State<AddItems> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _purchasePriceController = TextEditingController();
  final TextEditingController _salePriceController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();

  String? _coveredOption;
  String? _selectedQualityId;
  String? _selectedQualityName;
  String? _selectedPackagingUnit;

  final CollectionReference _qualities = FirebaseFirestore.instance.collection('qualities');
  final CollectionReference _items = FirebaseFirestore.instance.collection('items');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Item', style: TextStyle(color: _textColor)),
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _textColor),
      ),
      backgroundColor: _backgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildFormSection('Item Details', [
                _buildCoveredDropdown(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildQualityDropdown()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildPackagingUnitDropdown()),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextFormField('Item Name', _itemNameController),
                _buildTextFormField('Purchase Price', _purchasePriceController, isNumeric: true),
                _buildTextFormField('Sale Price', _salePriceController, isNumeric: true),
                _buildTextFormField('Stock Quantity', _stockController, isNumeric: true),
              ]),
              const SizedBox(height: 24),
              _buildFormSection('Dimensions', [
                Row(
                  children: [
                    Expanded(child: _buildDimensionField('Length', _lengthController)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildDimensionField('Width', _widthController)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildDimensionField('Height', _heightController)),
                  ],
                ),
              ]),
              const SizedBox(height: 24),
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
          validator: (value) => value!.isEmpty ? 'Required field' : null,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDimensionField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: _inputDecoration(label),
      style: const TextStyle(color: _textColor, fontSize: 14),
      validator: (value) => value!.isEmpty ? 'Required field' : null,
    );
  }

  Widget _buildPackagingUnitDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedPackagingUnit,
      decoration: _inputDecoration('Packaging Unit'),
      dropdownColor: _surfaceColor,
      items: const [
        DropdownMenuItem(value: 'Pieces', child: Text('Pieces')),
        DropdownMenuItem(value: 'Mètres', child: Text('Mètres')),
        DropdownMenuItem(value: 'Kilograms', child: Text('Kilograms')),
        DropdownMenuItem(value: 'Dozen', child: Text('Dozen')),
        DropdownMenuItem(value: 'Grams', child: Text('Grams')),
      ],
      onChanged: (value) => setState(() => _selectedPackagingUnit = value),
      style: const TextStyle(color: _textColor),
      validator: (value) => value == null ? 'Please select a unit' : null,
    );
  }

  Widget _buildCoveredDropdown() {
    return DropdownButtonFormField<String>(
      value: _coveredOption,
      decoration: _inputDecoration('Covered Option'),
      dropdownColor: _surfaceColor,
      items: const [
        DropdownMenuItem(value: "Yes", child: Text("Covered")),
        DropdownMenuItem(value: "-", child: Text("Uncovered")),
      ],
      onChanged: (value) => setState(() => _coveredOption = value),
      style: const TextStyle(color: _textColor),
      validator: (value) => value == null ? 'Please select an option' : null,
    );
  }

  Widget _buildQualityDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _qualities.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator(color: _primaryColor);
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text('No qualities available', style: TextStyle(color: _textColor));
        }

        final qualities = snapshot.data!.docs;
        return DropdownButtonFormField<String>(
          value: _selectedQualityId,
          decoration: _inputDecoration('Quality'),
          dropdownColor: _surfaceColor,
          items: qualities.map((quality) {
            return DropdownMenuItem<String>(
              value: quality.id,
              child: Text(quality['name'], style: const TextStyle(color: _textColor)),
            );
          }).toList(),
          onChanged: (value) => setState(() {
            _selectedQualityId = value;
            _selectedQualityName = qualities.firstWhere((q) => q.id == value)['name'];
          }),
          style: const TextStyle(color: _textColor),
          validator: (value) => value == null ? 'Please select a quality' : null,
        );
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

  Widget _buildSaveButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.save, size: 20, color: _surfaceColor),
        label: const Text('SAVE ITEM', style: TextStyle(fontSize: 14, color: _surfaceColor)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        onPressed: _addItem,
      ),
    );
  }

  Future<void> _addItem() async {
    if (_formKey.currentState!.validate()) {
      try {
        await _items.add({
          'itemName': _itemNameController.text,
          'purchasePrice': double.parse(_purchasePriceController.text),
          'salePrice': double.parse(_salePriceController.text),
          'length': double.parse(_lengthController.text),
          'width': double.parse(_widthController.text),
          'height': double.parse(_heightController.text),
          'stockQuantity': int.parse(_stockController.text),
          'covered': _coveredOption,
          'qualityId': _selectedQualityId,
          'qualityName': _selectedQualityName,
          'packagingUnit': _selectedPackagingUnit,
          'timestamp': FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item added successfully')),
        );
        _formKey.currentState!.reset();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding item: $e')),
        );
      }
    }
  }
}

class InventoryPage extends StatefulWidget {
  @override
  _InventoryPageState createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
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
  Future<void> _deleteItem(String id) async {
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
              const Text(
                'Delete Item',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Are you sure you want to delete this item? This action cannot be undone.',
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
                    child: const Text(
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
      await FirebaseFirestore.instance.collection('items').doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted successfully')),
        );
      }
    }
  }

  Future<void> _showEditDialog(DocumentSnapshot item) async {
    final TextEditingController nameController = TextEditingController(text: item['itemName']);
    final TextEditingController purchaseController = TextEditingController(text: item['purchasePrice'].toString());
    final TextEditingController saleController = TextEditingController(text: item['salePrice'].toString());
    final TextEditingController stockController = TextEditingController(text: item['stockQuantity'].toString());

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
              const Text('Edit Item',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textColor)),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                decoration: _inputDecoration('Item Name'),
                style: const TextStyle(color: _textColor),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: purchaseController,
                decoration: _inputDecoration('Purchase Price'),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: _textColor),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: saleController,
                decoration: _inputDecoration('Sale Price'),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: _textColor),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: stockController,
                decoration: _inputDecoration('Stock Quantity'),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: _textColor),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('items')
                      .doc(item.id)
                      .update({
                    'itemName': nameController.text,
                    'purchasePrice': double.parse(purchaseController.text),
                    'salePrice': double.parse(saleController.text),
                    'stockQuantity': int.parse(stockController.text),
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item updated successfully')),
                  );
                },
                child: const Text('UPDATE', style: TextStyle(color: _surfaceColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 1200;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory', style: TextStyle(color: _textColor)),
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
      stream: FirebaseFirestore.instance.collection('items').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _primaryColor));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: _textColor)));
        }

        final items = snapshot.data?.docs.where((doc) {
          final name = doc['itemName'].toString().toLowerCase();
          final quality = doc['qualityName'].toString().toLowerCase();
          return name.contains(_searchQuery) || quality.contains(_searchQuery);
        }).toList();

        // Two-level sorting: Quality Name -> Item Name
        if (items != null) {
          items.sort((a, b) {
            // Primary sort by Quality Name
            String aQuality = a['qualityName']?.toLowerCase() ?? '';
            String bQuality = b['qualityName']?.toLowerCase() ?? '';
            int qualityCompare = aQuality.compareTo(bQuality);

            // Secondary sort by Item Name if qualities are equal
            if (qualityCompare == 0) {
              String aItem = a['itemName']?.toLowerCase() ?? '';
              String bItem = b['itemName']?.toLowerCase() ?? '';
              return aItem.compareTo(bItem);
            }

            return qualityCompare;
          });
        }

        if (items == null || items.isEmpty) {
          return Center(child: Text('No items found', style: TextStyle(color: _textColor)));
        }

        return Column(
          children: [
            _buildDesktopHeader(),
            SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.only(bottom: 16),
                separatorBuilder: (_, __) => SizedBox(height: 8),
                itemCount: items.length,
                itemBuilder: (context, index) => _buildDesktopRow(items[index]),
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
                  stream: FirebaseFirestore.instance.collection('items').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: _primaryColor));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: _textColor)));
                    }

                    final items = snapshot.data?.docs.where((doc) {
                      final name = doc['itemName'].toString().toLowerCase();
                      final quality = doc['qualityName'].toString().toLowerCase();
                      return name.contains(_searchQuery) || quality.contains(_searchQuery);
                    }).toList();

                    // Two-level sorting: Quality Name -> Item Name
                    if (items != null) {
                      items.sort((a, b) {
                        String aQuality = a['qualityName']?.toLowerCase() ?? '';
                        String bQuality = b['qualityName']?.toLowerCase() ?? '';
                        int qualityCompare = aQuality.compareTo(bQuality);

                        if (qualityCompare == 0) {
                          String aItem = a['itemName']?.toLowerCase() ?? '';
                          String bItem = b['itemName']?.toLowerCase() ?? '';
                          return aItem.compareTo(bItem);
                        }

                        return qualityCompare;
                      });
                    }

                    if (items == null || items.isEmpty) {
                      return Center(child: Text('No items found', style: TextStyle(color: _textColor)));
                    }

                    return ListView.separated(
                      physics: BouncingScrollPhysics(),
                      padding: EdgeInsets.only(bottom: 16),
                      separatorBuilder: (_, __) => SizedBox(height: 8),
                      itemCount: items.length,
                      itemBuilder: (context, index) => _buildMobileRow(items[index]),
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
            Expanded(child: _HeaderCell('Item Name')),
            Expanded(child: _HeaderCell('Purchase')),
            Expanded(child: _HeaderCell('Sale')),
            Expanded(child: _HeaderCell('Stock')),
            Expanded(child: _HeaderCell('Unit')),
            Expanded(child: _HeaderCell('Covered')),
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
            _HeaderCell('Item Name', 200),
            _HeaderCell('Purchase', 100),
            _HeaderCell('Sale', 100),
            _HeaderCell('Stock', 100),
            _HeaderCell('Unit', 100),
            _HeaderCell('Covered', 100),
            _HeaderCell('Actions', 150),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopRow(DocumentSnapshot item) {
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
            Expanded(child: _DataCell('${item['qualityName']}: ${item['itemName']}')),
            Expanded(child: _DataCell(item['purchasePrice'].toInt().toString())), // Purchase Price
            Expanded(child: _DataCell(item['salePrice'].toInt().toString())),    // Sale Price
            Expanded(child: _DataCell(item['stockQuantity'].toString())),
            Expanded(child: _DataCell(item['packagingUnit'] ?? 'N/A')),
            Expanded(child: _DataCell(item['covered'])),
            Expanded(child: _ActionCell(
              item,
              150,
              onEdit: (item) => _showEditDialog(item),
              onDelete: (id) => _deleteItem(id),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileRow(DocumentSnapshot item) {
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
            _DataCell('${item['qualityName']}: ${item['itemName']}', 200),
            _DataCell(item['purchasePrice'].toInt().toString(), 100), // Purchase Price
            _DataCell(item['salePrice'].toInt().toString(), 100),    // Sale Price
            _DataCell(item['stockQuantity'].toString(), 100),
            _DataCell(item['packagingUnit'] ?? 'N/A', 100),
            _DataCell(item['covered'], 100),
            _ActionCell(
              item,
              150,
              onEdit: (item) => _showEditDialog(item),
              onDelete: (id) => _deleteItem(id),
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
          hintText: 'Search inventory...',
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
        label: const Text('Add Item', style: TextStyle(fontSize: 14, color: _surfaceColor)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddItems())),
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
  final DocumentSnapshot item;
  final double? width;
  final Function(DocumentSnapshot) onEdit;
  final Function(String) onDelete;

  const _ActionCell(
      this.item,
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
            onPressed: () => onEdit(item),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            onPressed: () => onDelete(item.id),
          ),
        ],
      ),
    );
  }
}