import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';

import 'Home.dart'; // Assuming Home.dart contains the HomePage class

// Color Scheme for Light Mode
const Color _primaryColor = Color(0xFF0D6EFD);
const Color _textColor = Color(0xFF2D2D2D);
const Color _secondaryTextColor = Color(0xFF4A4A4A);
const Color _backgroundColor = Color(0xFFF8F9FA);
const Color _surfaceColor = Colors.white;

// Color Scheme for Dark Mode
const Color _darkBackgroundColor = Color(0xFF1A1A2F);
const Color _darkSurfaceColor = Color(0xFF252541);
const Color _darkTextColor = Colors.white;
const Color _darkSecondaryTextColor = Color(0xFFB0B0C0);

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
      home: HomePage(), // Changed to HomePage as the entry point
    );
  }
}

class AddItems extends StatefulWidget {
  final bool isDarkMode;

  const AddItems({required this.isDarkMode, super.key});

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
  final TextEditingController _openingStockController = TextEditingController();

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
        title: Text('Add Item', style: TextStyle(color: widget.isDarkMode ? _darkTextColor : _textColor)),
        backgroundColor: widget.isDarkMode ? _darkSurfaceColor : _surfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(color: widget.isDarkMode ? _darkTextColor : _textColor),
      ),
      backgroundColor: widget.isDarkMode ? _darkBackgroundColor : _backgroundColor,
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
                _buildTextFormField('OP. Stock', _openingStockController, isNumeric: true),
                _buildTextFormField('C. Stock', _stockController, isNumeric: true),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? _darkSurfaceColor : _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
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
        Text(
          label,
          style: TextStyle(
            color: widget.isDarkMode ? _darkTextColor : _textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: TextStyle(
            color: widget.isDarkMode ? _darkTextColor : _textColor,
            fontSize: 14,
          ),
          decoration: _inputDecoration(),
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          validator: (value) => value!.isEmpty ? 'Required field' : null,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDimensionField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: widget.isDarkMode ? _darkTextColor : _textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: _inputDecoration(),
          style: TextStyle(
            color: widget.isDarkMode ? _darkTextColor : _textColor,
            fontSize: 14,
          ),
          validator: (value) => value!.isEmpty ? 'Required field' : null,
        ),
      ],
    );
  }

  Widget _buildPackagingUnitDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Packaging Unit',
          style: TextStyle(
            color: widget.isDarkMode ? _darkTextColor : _textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedPackagingUnit,
          decoration: _inputDecoration(),
          dropdownColor: widget.isDarkMode ? _darkSurfaceColor : _surfaceColor,
          items: const [
            DropdownMenuItem(value: 'Pieces', child: Text('Pieces')),
            DropdownMenuItem(value: 'Mètres', child: Text('Mètres')),
            DropdownMenuItem(value: 'Kilograms', child: Text('Kilograms')),
            DropdownMenuItem(value: 'Dozen', child: Text('Dozen')),
            DropdownMenuItem(value: 'Grams', child: Text('Grams')),
          ],
          onChanged: (value) => setState(() => _selectedPackagingUnit = value),
          style: TextStyle(color: widget.isDarkMode ? _darkTextColor : _textColor),
          validator: (value) => value == null ? 'Please select a unit' : null,
        ),
      ],
    );
  }

  Widget _buildCoveredDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Covered Option',
          style: TextStyle(
            color: widget.isDarkMode ? _darkTextColor : _textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _coveredOption,
          decoration: _inputDecoration(),
          dropdownColor: widget.isDarkMode ? _darkSurfaceColor : _surfaceColor,
          items: const [
            DropdownMenuItem(value: "Yes", child: Text("Covered")),
            DropdownMenuItem(value: "-", child: Text("Uncovered")),
          ],
          onChanged: (value) => setState(() => _coveredOption = value),
          style: TextStyle(color: widget.isDarkMode ? _darkTextColor : _textColor),
          validator: (value) => value == null ? 'Please select an option' : null,
        ),
      ],
    );
  }

  Widget _buildQualityDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quality',
          style: TextStyle(
            color: widget.isDarkMode ? _darkTextColor : _textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: _qualities.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator(color: _primaryColor);
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Text(
                'No qualities available',
                style: TextStyle(color: widget.isDarkMode ? _darkTextColor : _textColor),
              );
            }

            final qualities = snapshot.data!.docs;
            return DropdownButtonFormField<String>(
              value: _selectedQualityId,
              decoration: _inputDecoration(),
              dropdownColor: widget.isDarkMode ? _darkSurfaceColor : _surfaceColor,
              items: qualities.map((quality) {
                return DropdownMenuItem<String>(
                  value: quality.id,
                  child: Text(
                    quality['name'],
                    style: TextStyle(color: widget.isDarkMode ? _darkTextColor : _textColor),
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() {
                _selectedQualityId = value;
                _selectedQualityName = qualities.firstWhere((q) => q.id == value)['name'];
              }),
              style: TextStyle(color: widget.isDarkMode ? _darkTextColor : _textColor),
              validator: (value) => value == null ? 'Please select a quality' : null,
            );
          },
        ),
      ],
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: widget.isDarkMode ? _darkBackgroundColor.withOpacity(0.8) : _backgroundColor.withOpacity(0.8),
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
        int openingStock = int.parse(_openingStockController.text);
        await _items.add({
          'itemName': _itemNameController.text.trim(),
          'purchasePrice': double.parse(_purchasePriceController.text),
          'salePrice': double.parse(_salePriceController.text),
          'length': double.parse(_lengthController.text),
          'width': double.parse(_widthController.text),
          'height': double.parse(_heightController.text),
          'openingStock': openingStock,
          'stockQuantity': openingStock,
          'covered': _coveredOption,
          'qualityId': _selectedQualityId,
          'qualityName': _selectedQualityName,
          'packagingUnit': _selectedPackagingUnit,
          'dateCreated': FieldValue.serverTimestamp(),
          'dateModified': FieldValue.serverTimestamp(),
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

  @override
  void dispose() {
    _itemNameController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _stockController.dispose();
    _openingStockController.dispose();
    super.dispose();
  }
}

class InventoryPage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback toggleDarkMode;

  const InventoryPage({required this.isDarkMode, required this.toggleDarkMode, super.key});

  @override
  _InventoryPageState createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  String _searchQuery = '';
  final double _mobileTableWidth = 1620; // Increased to accommodate wider Item Name and gap

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _deleteItem(String id) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: widget.isDarkMode ? _darkSurfaceColor : _surfaceColor,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: widget.isDarkMode ? _darkSurfaceColor : _surfaceColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Delete Item',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: widget.isDarkMode ? _darkTextColor : _textColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to delete this item? This action cannot be undone.',
                style: TextStyle(
                  color: widget.isDarkMode ? _darkSecondaryTextColor : _secondaryTextColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'CANCEL',
                      style: TextStyle(
                        color: widget.isDarkMode ? _darkSecondaryTextColor : _secondaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('DELETE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
    final TextEditingController openingStockController = TextEditingController(text: item['openingStock'].toString());
    final TextEditingController lengthController = TextEditingController(text: item['length'].toString());
    final TextEditingController widthController = TextEditingController(text: item['width'].toString());
    final TextEditingController heightController = TextEditingController(text: item['height'].toString());

    String? selectedCovered = item['covered'];
    String? selectedPackagingUnit = item['packagingUnit'];
    String? selectedQualityId = item['qualityId'];
    String? selectedQualityName = item['qualityName'];

    final _formKey = GlobalKey<FormState>();
    final int initialStockQuantity = item['stockQuantity'];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: widget.isDarkMode ? _darkSurfaceColor : _surfaceColor,
            insetPadding: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? _darkSurfaceColor : _surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: widget.isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Edit Item',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: widget.isDarkMode ? _darkTextColor : _textColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Covered Option',
                            style: TextStyle(
                              color: widget.isDarkMode ? _darkTextColor : _textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedCovered,
                            decoration: _inputDecoration(),
                            dropdownColor: widget.isDarkMode ? _darkSurfaceColor : _surfaceColor,
                            items: const [
                              DropdownMenuItem(value: "Yes", child: Text("Covered")),
                              DropdownMenuItem(value: "-", child: Text("Uncovered")),
                            ],
                            onChanged: (value) => setState(() => selectedCovered = value),
                            style: TextStyle(color: widget.isDarkMode ? _darkTextColor : _textColor),
                            validator: (value) => value == null ? 'Required field' : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quality',
                            style: TextStyle(
                              color: widget.isDarkMode ? _darkTextColor : _textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('qualities').snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const CircularProgressIndicator(color: _primaryColor);
                              }
                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return Text(
                                  'No qualities available',
                                  style: TextStyle(color: widget.isDarkMode ? _darkTextColor : _textColor),
                                );
                              }
                              final qualities = snapshot.data!.docs;
                              return DropdownButtonFormField<String>(
                                value: selectedQualityId,
                                decoration: _inputDecoration(),
                                dropdownColor: widget.isDarkMode ? _darkSurfaceColor : _surfaceColor,
                                items: qualities.map((quality) {
                                  return DropdownMenuItem<String>(
                                    value: quality.id,
                                    child: Text(
                                      quality['name'],
                                      style: TextStyle(color: widget.isDarkMode ? _darkTextColor : _textColor),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) => setState(() {
                                  selectedQualityId = value;
                                  selectedQualityName = qualities.firstWhere((q) => q.id == value)['name'];
                                }),
                                style: TextStyle(color: widget.isDarkMode ? _darkTextColor : _textColor),
                                validator: (value) => value == null ? 'Required field' : null,
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Packaging Unit',
                            style: TextStyle(
                              color: widget.isDarkMode ? _darkTextColor : _textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedPackagingUnit,
                            decoration: _inputDecoration(),
                            dropdownColor: widget.isDarkMode ? _darkSurfaceColor : _surfaceColor,
                            items: const [
                              DropdownMenuItem(value: 'Pieces', child: Text('Pieces')),
                              DropdownMenuItem(value: 'Mètres', child: Text('Mètres')),
                              DropdownMenuItem(value: 'Kilograms', child: Text('Kilograms')),
                              DropdownMenuItem(value: 'Dozen', child: Text('Dozen')),
                              DropdownMenuItem(value: 'Grams', child: Text('Grams')),
                            ],
                            onChanged: (value) => setState(() => selectedPackagingUnit = value),
                            style: TextStyle(color: widget.isDarkMode ? _darkTextColor : _textColor),
                            validator: (value) => value == null ? 'Required field' : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextFormField('Item Name', nameController),
                      _buildTextFormField('Purchase Price', purchaseController, isNumeric: true),
                      _buildTextFormField('Sale Price', saleController, isNumeric: true),
                      _buildTextFormField('OP. Stock', openingStockController, isNumeric: true),
                      _buildTextFormField('C. Stock', stockController, isNumeric: true),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildDimensionField('Length', lengthController)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildDimensionField('Width', widthController)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildDimensionField('Height', heightController)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            int newOpeningStock = int.parse(openingStockController.text);
                            int currentStock = item['stockQuantity'];
                            int currentOpeningStock = item['openingStock'];
                            int newStockQuantity = int.parse(stockController.text);

                            int stockAdjustment = newOpeningStock - currentOpeningStock;
                            int calculatedStock = currentStock + stockAdjustment;
                            int updatedStock = (newStockQuantity != initialStockQuantity)
                                ? newStockQuantity
                                : calculatedStock;

                            await FirebaseFirestore.instance.collection('items').doc(item.id).update({
                              'itemName': nameController.text.trim(),
                              'purchasePrice': double.parse(purchaseController.text),
                              'salePrice': double.parse(saleController.text),
                              'openingStock': newOpeningStock,
                              'stockQuantity': updatedStock,
                              'length': double.parse(lengthController.text),
                              'width': double.parse(widthController.text),
                              'height': double.parse(heightController.text),
                              'covered': selectedCovered,
                              'qualityId': selectedQualityId,
                              'qualityName': selectedQualityName,
                              'packagingUnit': selectedPackagingUnit,
                              'dateModified': FieldValue.serverTimestamp(),
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Item updated successfully')),
                            );
                          }
                        },
                        child: const Text('UPDATE', style: TextStyle(color: _surfaceColor)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    nameController.dispose();
    purchaseController.dispose();
    saleController.dispose();
    stockController.dispose();
    openingStockController.dispose();
    lengthController.dispose();
    widthController.dispose();
    heightController.dispose();
  }

  Widget _buildTextFormField(String label, TextEditingController controller, {bool isNumeric = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: widget.isDarkMode ? _darkTextColor : _textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: TextStyle(
            color: widget.isDarkMode ? _darkTextColor : _textColor,
            fontSize: 14,
          ),
          decoration: _inputDecoration(),
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          validator: (value) => value!.isEmpty ? 'Required field' : null,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDimensionField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: widget.isDarkMode ? _darkTextColor : _textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: _inputDecoration(),
          style: TextStyle(
            color: widget.isDarkMode ? _darkTextColor : _textColor,
            fontSize: 14,
          ),
          validator: (value) => value!.isEmpty ? 'Required field' : null,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: widget.isDarkMode ? _darkBackgroundColor.withOpacity(0.8) : _backgroundColor.withOpacity(0.8),
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

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 1200;

    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory', style: TextStyle(color: widget.isDarkMode ? _darkTextColor : _textColor)),
        backgroundColor: widget.isDarkMode ? _darkSurfaceColor : _surfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(color: widget.isDarkMode ? _darkTextColor : _textColor),
      ),
      backgroundColor: widget.isDarkMode ? _darkBackgroundColor : _backgroundColor,
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
          return Center(
              child: Text('Error: ${snapshot.error}',
                  style: TextStyle(color: widget.isDarkMode ? _darkTextColor : _textColor)));
        }

        final items = snapshot.data?.docs.where((doc) {
          final name = doc['itemName'].toString().toLowerCase();
          final quality = doc['qualityName'].toString().toLowerCase();
          return name.contains(_searchQuery) || quality.contains(_searchQuery);
        }).toList();

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
          return Center(
              child: Text('No items found', style: TextStyle(color: widget.isDarkMode ? _darkTextColor : _textColor)));
        }

        return Column(
          children: [
            _buildDesktopHeader(),
            SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 16),
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
                      return Center(
                          child: Text('Error: ${snapshot.error}',
                              style: TextStyle(color: widget.isDarkMode ? _darkTextColor : _textColor)));
                    }

                    final items = snapshot.data?.docs.where((doc) {
                      final name = doc['itemName'].toString().toLowerCase();
                      final quality = doc['qualityName'].toString().toLowerCase();
                      return name.contains(_searchQuery) || quality.contains(_searchQuery);
                    }).toList();

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
                      return Center(
                          child: Text('No items found',
                              style: TextStyle(color: widget.isDarkMode ? _darkTextColor : _textColor)));
                    }

                    return ListView.separated(
                      physics: BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 16),
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
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(flex: 2, child: _HeaderCell('Item Name')), // Increased flex for more space
            SizedBox(width: 20), // Gap after Item Name
            Expanded(child: _HeaderCell('Purchase')),
            Expanded(child: _HeaderCell('Sale')),
            Expanded(child: _HeaderCell('OP. Stock')),
            Expanded(child: _HeaderCell('C. Stock')),
            Expanded(child: _HeaderCell('Unit')),
            Expanded(child: _HeaderCell('Covered')),
            Expanded(child: _HeaderCell('Modified')),
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
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _HeaderCell('Item Name', 400), // Increased width to 400
            SizedBox(width: 20), // Gap after Item Name
            _HeaderCell('Purchase', 100),
            _HeaderCell('Sale', 100),
            _HeaderCell('OP. Stock', 100),
            _HeaderCell('C. Stock', 100),
            _HeaderCell('Unit', 100),
            _HeaderCell('Covered', 100),
            _HeaderCell('Modified', 150),
            _HeaderCell('Actions', 150),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopRow(DocumentSnapshot item) {
    final dateModified = item['dateModified'] != null
        ? DateFormat('dd-MM-yyyy').format((item['dateModified'] as Timestamp).toDate())
        : 'N/A';
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? _darkSurfaceColor : _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(flex: 2, child: _DataCell('${item['qualityName']}: ${item['itemName']}')),
            SizedBox(width: 20), // Gap after Item Name
            Expanded(child: _DataCell(item['purchasePrice'].toInt().toString())),
            Expanded(child: _DataCell(item['salePrice'].toInt().toString())),
            Expanded(child: _DataCell(item['openingStock'].toString())),
            Expanded(child: _DataCell(item['stockQuantity'].toString())),
            Expanded(child: _DataCell(item['packagingUnit'] ?? 'N/A')),
            Expanded(child: _DataCell(item['covered'])),
            Expanded(child: _DataCell(dateModified)),
            Expanded(
              child: _ActionCell(
                item,
                150,
                onEdit: (item) => _showEditDialog(item),
                onDelete: (id) => _deleteItem(id),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileRow(DocumentSnapshot item) {
    final dateModified = item['dateModified'] != null
        ? DateFormat('dd-MM-yyyy').format((item['dateModified'] as Timestamp).toDate())
        : 'N/A';
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? _darkSurfaceColor : _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _DataCell('${item['qualityName']}: ${item['itemName']}', 400), // Increased width to 400
            SizedBox(width: 20), // Gap after Item Name
            _DataCell(item['purchasePrice'].toInt().toString(), 100),
            _DataCell(item['salePrice'].toInt().toString(), 100),
            _DataCell(item['openingStock'].toString(), 100),
            _DataCell(item['stockQuantity'].toString(), 100),
            _DataCell(item['packagingUnit'] ?? 'N/A', 100),
            _DataCell(item['covered'], 100),
            _DataCell(dateModified, 150),
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
        color: widget.isDarkMode ? _darkSurfaceColor : _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search inventory...',
          hintStyle: TextStyle(color: widget.isDarkMode ? _darkSecondaryTextColor : _secondaryTextColor),
          filled: true,
          fillColor: widget.isDarkMode ? _darkSurfaceColor : _surfaceColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          suffixIcon: IconButton(
            icon: Icon(Icons.clear, color: widget.isDarkMode ? _darkSecondaryTextColor : _secondaryTextColor),
            onPressed: () => setState(() => _searchController.clear()),
          ),
          prefixIcon: Icon(Icons.search, color: widget.isDarkMode ? _darkSecondaryTextColor : _secondaryTextColor),
        ),
        style: TextStyle(color: widget.isDarkMode ? _darkTextColor : _textColor),
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
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => AddItems(
                  isDarkMode: widget.isDarkMode,
                ))),
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
    final isDarkMode = (context.findAncestorWidgetOfExactType<InventoryPage>() as InventoryPage?)?.isDarkMode ?? false;
    // Check if this is the Item Name column by width or context
    bool isItemName = width == 400 || (width == null && context.findAncestorWidgetOfExactType<Expanded>()?.flex == 2);
    return SizedBox(
      width: width,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: isDarkMode ? _darkTextColor : _textColor,
            fontSize: 14,
          ),
          overflow: isItemName ? TextOverflow.visible : TextOverflow.ellipsis,
          softWrap: isItemName ? false : true,
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