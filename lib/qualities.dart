import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _primaryColor = Color(0xFF0D6EFD);
const Color _textColor = Color(0xFF2D2D2D);
const Color _secondaryTextColor = Color(0xFF4A4A4A);
const Color _backgroundColor = Color(0xFFF8F9FA);
const Color _surfaceColor = Colors.white;

class QualityPage extends StatefulWidget {
  const QualityPage({Key? key}) : super(key: key);

  @override
  State<QualityPage> createState() => _QualityPageState();
}

class _QualityPageState extends State<QualityPage> {
  final CollectionReference _qualities = FirebaseFirestore.instance.collection('qualities');
  final CollectionReference _companies = FirebaseFirestore.instance.collection('companies');
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _coveredController = TextEditingController();
  final TextEditingController _uncoveredController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  final double _mobileTableWidth = 1200;

  String _searchQuery = '';
  String? _selectedCompany;

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _coveredController.dispose();
    _uncoveredController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _addQuality() async {
    if (_nameController.text.isEmpty || _selectedCompany == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fields are required')),
      );
      return;
    }

    try {
      await _qualities.add({
        'name': _nameController.text.trim(),
        'company_name': _selectedCompany,
        'covered_discount': double.parse(_coveredController.text.trim()),
        'uncovered_discount': double.parse(_uncoveredController.text.trim()),
        'created_at': FieldValue.serverTimestamp(),
      });
      _resetForm();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quality added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error adding quality')),
      );
    }
  }

  void _resetForm() {
    _nameController.clear();
    _coveredController.clear();
    _uncoveredController.clear();
    setState(() => _selectedCompany = null);
  }

  Future<void> _deleteQuality(String id) async {
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textColor),
              ),
              const SizedBox(height: 20),
              const Text(
                'Are you sure you want to delete this quality?',
                style: TextStyle(fontSize: 14, color: _secondaryTextColor),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(color: _secondaryTextColor, fontSize: 14)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Delete',
                        style: TextStyle(color: _surfaceColor, fontSize: 14)),
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
        await _qualities.doc(id).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quality deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error deleting quality')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 1200;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quality Management', style: TextStyle(color: _textColor)),
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
          Expanded(child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout()),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        _buildDesktopHeader(),
        const SizedBox(height: 8),
        Expanded(child: _buildQualityList(true)),
      ],
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
              Expanded(child: _buildQualityList(false)),
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
            Expanded(child: _HeaderCell('Quality Name')),
            Expanded(child: _HeaderCell('Company')),
            Expanded(child: _HeaderCell('Covered (%)')),
            Expanded(child: _HeaderCell('Uncovered (%)')),
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
            _HeaderCell('Quality Name', 200),
            _HeaderCell('Company', 150),
            _HeaderCell('Covered (%)', 100),
            _HeaderCell('Uncovered (%)', 100),
            _HeaderCell('Actions', 150),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityList(bool isDesktop) {
    return StreamBuilder<QuerySnapshot>(
      stream: _qualities.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _primaryColor));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: _textColor)));
        }

        final qualities = snapshot.data?.docs.where((doc) {
          final name = doc['name'].toString().toLowerCase();
          final company = doc['company_name'].toString().toLowerCase();
          return name.contains(_searchQuery) || company.contains(_searchQuery);
        }).toList();

        if (qualities == null || qualities.isEmpty) {
          return Center(child: Text('No qualities found', style: const TextStyle(color: _textColor)));
        }

        // Sort qualities alphabetically by name (case-insensitive)
        qualities.sort((a, b) {
          final aName = a['name'].toString().toLowerCase();
          final bName = b['name'].toString().toLowerCase();
          return aName.compareTo(bName);
        });

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: qualities.length,
          itemBuilder: (context, index) => isDesktop
              ? _buildDesktopRow(qualities[index])
              : _buildMobileRow(qualities[index]),
        );
      },
    );
  }

  Widget _buildDesktopRow(DocumentSnapshot quality) {
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
            Expanded(child: _DataCell(quality['name'])),
            Expanded(child: _DataCell(quality['company_name'])),
            Expanded(child: _DataCell('${quality['covered_discount']}%')),
            Expanded(child: _DataCell('${quality['uncovered_discount']}%')),
            Expanded(
                child: _ActionCell(
                  quality,
                  onEdit: _showEditDialog,
                  onDelete: _deleteQuality,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileRow(DocumentSnapshot quality) {
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
            _DataCell(quality['name'], 200),
            _DataCell(quality['company_name'], 150),
            _DataCell('${quality['covered_discount']}%', 100),
            _DataCell('${quality['uncovered_discount']}%', 100),
            _ActionCell(
              quality,
              width: 150,
              onEdit: _showEditDialog,
              onDelete: _deleteQuality,
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
          hintText: 'Search qualities...',
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
        label: const Text('Add Quality', style: TextStyle(fontSize: 14, color: _surfaceColor)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        onPressed: () => _showAddForm(),
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
              const Text('Add Quality',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textColor)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('Quality Name'),
                style: const TextStyle(color: _textColor),
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: _companies.snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  final companies = snapshot.data!.docs.map((doc) => doc['name'].toString()).toList();
                  return DropdownButtonFormField<String>(
                    value: _selectedCompany,
                    decoration: _inputDecoration('Company'),
                    dropdownColor: _surfaceColor,
                    items: companies
                        .map((company) => DropdownMenuItem(
                      value: company,
                      child: Text(company, style: const TextStyle(color: _textColor)),
                    ))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedCompany = value),
                    style: const TextStyle(color: _textColor),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _coveredController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('Covered Discount (%)'),
                style: const TextStyle(color: _textColor),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _uncoveredController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('Uncovered Discount (%)'),
                style: const TextStyle(color: _textColor),
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
                  _addQuality();
                },
                child: const Text('SAVE QUALITY', style: TextStyle(color: _surfaceColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(DocumentSnapshot quality) {
    final nameController = TextEditingController(text: quality['name']);
    final coveredController = TextEditingController(text: quality['covered_discount'].toString());
    final uncoveredController = TextEditingController(text: quality['uncovered_discount'].toString());
    String? selectedCompany = quality['company_name'];

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
              const Text('Edit Quality',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textColor)),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                decoration: _inputDecoration('Quality Name'),
                style: const TextStyle(color: _textColor),
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: _companies.snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  final companies = snapshot.data!.docs.map((doc) => doc['name'].toString()).toList();
                  return DropdownButtonFormField<String>(
                    value: selectedCompany,
                    decoration: _inputDecoration('Company'),
                    dropdownColor: _surfaceColor,
                    items: companies
                        .map((company) => DropdownMenuItem(
                      value: company,
                      child: Text(company, style: const TextStyle(color: _textColor)),
                    ))
                        .toList(),
                    onChanged: (value) => selectedCompany = value,
                    style: const TextStyle(color: _textColor),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: coveredController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('Covered Discount (%)'),
                style: const TextStyle(color: _textColor),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: uncoveredController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('Uncovered Discount (%)'),
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
                  await _qualities.doc(quality.id).update({
                    'name': nameController.text,
                    'company_name': selectedCompany,
                    'covered_discount': double.parse(coveredController.text),
                    'uncovered_discount': double.parse(uncoveredController.text),
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Quality updated successfully')),
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
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
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
  final DocumentSnapshot quality;
  final double? width;
  final Function(DocumentSnapshot) onEdit;
  final Function(String) onDelete;

  const _ActionCell(this.quality, {this.width, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, color: _primaryColor, size: 20),
            onPressed: () => onEdit(quality),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            onPressed: () => onDelete(quality.id),
          ),
        ],
      ),
    );
  }
}