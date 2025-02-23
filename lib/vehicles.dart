import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({Key? key}) : super(key: key);

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  final TextEditingController _searchController = TextEditingController();
  final CollectionReference _vehicles = FirebaseFirestore.instance.collection('vehicles');
  final Color _primaryColor = const Color(0xFF0D6EFD);
  final Color _textColor = const Color(0xFF2D2D2D);
  final Color _secondaryTextColor = const Color(0xFF4A4A4A);
  final Color _backgroundColor = const Color(0xFFF8F9FA);
  final Color _surfaceColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicles', style: TextStyle(color: Colors.black)),
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
                _buildAddVehicleButton(),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildTableHeader(),
          const SizedBox(height: 8),
          Expanded(child: _buildVehiclesTable()),
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
          hintText: 'Search vehicles...',
          filled: true,
          fillColor: _surfaceColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          suffixIcon: IconButton(
            onPressed: () {
              _searchController.clear();
              setState(() {});
            },
            icon: Icon(Icons.clear, color: _secondaryTextColor),
          ),
          prefixIcon: Icon(Icons.search, color: _secondaryTextColor),
        ),
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  Widget _buildAddVehicleButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        icon: Icon(Icons.add, size: 20, color: _surfaceColor),
        label: Text('Add Vehicle', style: TextStyle(fontSize: 14, color: _surfaceColor)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        onPressed: () => _showVehicleForm(),
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
            Expanded(child: _HeaderText('Vehicle Name')),
            Expanded(child: _HeaderText('Size')),
            Expanded(child: _HeaderText('Actions')),
          ],
        ),
      ),
    );
  }

  Widget _buildVehiclesTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: _vehicles.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _primaryColor));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No vehicles found.', style: TextStyle(color: _textColor)));
        }

        final filteredDocs = snapshot.data!.docs.where((doc) {
          return doc['name'].toString().toLowerCase().contains(_searchController.text.toLowerCase());
        }).toList();

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 16),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) => _buildVehicleRow(filteredDocs[index]),
        );
      },
    );
  }

  Widget _buildVehicleRow(DocumentSnapshot doc) {
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
                doc['name'],
                style: TextStyle(color: _textColor, fontSize: 14),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Text(
                '${doc['size']} inches',
                style: TextStyle(color: _textColor, fontSize: 14),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: _primaryColor, size: 20),
                    onPressed: () => _showVehicleForm(doc: doc),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _showDeleteConfirmationDialog(doc.id),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVehicleForm({DocumentSnapshot? doc}) {
    final TextEditingController nameController = TextEditingController(text: doc?['name']);
    final TextEditingController sizeController = TextEditingController(text: doc?['size']?.toString() ?? '');

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
              Text(
                doc == null ? 'Add Vehicle' : 'Edit Vehicle',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textColor),
              ),
              const SizedBox(height: 20),
              _buildFormField('Vehicle Name', nameController),
              const SizedBox(height: 16),
              _buildNumberField('Size (inches)', sizeController),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final data = {
                    'name': nameController.text,
                    'size': int.tryParse(sizeController.text) ?? 0,
                    'created': doc?['created'] ?? FieldValue.serverTimestamp(),
                    'updated': FieldValue.serverTimestamp(),
                  };

                  if (doc == null) {
                    _vehicles.add(data);
                  } else {
                    _vehicles.doc(doc.id).update(data);
                  }
                  Navigator.pop(context);
                },
                child: Text(doc == null ? 'SAVE VEHICLE' : 'UPDATE VEHICLE',
                    style: TextStyle(color: _surfaceColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _textColor),
        filled: true,
        fillColor: _surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryColor),
        ),
      ),
      style: TextStyle(color: _textColor),
    );
  }

  Widget _buildNumberField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _textColor),
        filled: true,
        fillColor: _surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryColor),
        ),
      ),
      style: TextStyle(color: _textColor),
    );
  }

  void _showDeleteConfirmationDialog(String id) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _surfaceColor,
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
            children: [
              Text('Delete Vehicle',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textColor)),
              const SizedBox(height: 20),
              Text('Are you sure you want to delete this vehicle?',
                  style: TextStyle(color: _textColor)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('CANCEL', style: TextStyle(color: _textColor)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      _vehicles.doc(id).delete();
                      Navigator.pop(context);
                    },
                    child: Text('DELETE', style: TextStyle(color: _surfaceColor)),
                  ),
                ],
              ),
            ],
          ),
        ),
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
        ),
      ),
    );
  }
}
