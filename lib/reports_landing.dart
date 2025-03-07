import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Color Scheme
const Color _primaryColor = Color(0xFF0D6EFD);
const Color _textColor = Color(0xFF2D2D2D);
const Color _secondaryTextColor = Color(0xFF4A4A4A);
const Color _backgroundColor = Color(0xFFF8F9FA);
const Color _surfaceColor = Colors.white;

class StockValuationReportPage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback toggleDarkMode;

  const StockValuationReportPage({
    super.key,
    required this.isDarkMode,
    required this.toggleDarkMode,
  });

  @override
  _StockValuationReportPageState createState() => _StockValuationReportPageState();
}

class _StockValuationReportPageState extends State<StockValuationReportPage> {
  final ScrollController _horizontalScrollController = ScrollController();
  String? _selectedCompanyName;
  final double _mobileTableWidth = 1400;
  DateTime? _fromDate;
  DateTime? _toDate;
  Map<String, Map<String, dynamic>> _qualityDiscounts = {}; // Map qualityId to discounts

  Color get _primaryColor => const Color(0xFF0D6EFD);
  Color get _textColor => widget.isDarkMode ? Colors.white : const Color(0xFF2D2D2D);
  Color get _secondaryTextColor => widget.isDarkMode ? Colors.white70 : const Color(0xFF4A4A4A);
  Color get _backgroundColor => widget.isDarkMode ? const Color(0xFF1A1A2F) : const Color(0xFFF8F9FA);
  Color get _surfaceColor => widget.isDarkMode ? const Color(0xFF252541) : Colors.white;

  @override
  void initState() {
    super.initState();
    _loadQualityDiscounts();
  }

  Future<void> _loadQualityDiscounts() async {
    final snapshot = await FirebaseFirestore.instance.collection('qualities').get();
    setState(() {
      _qualityDiscounts = {
        for (var doc in snapshot.docs)
          doc.id: {
            'covered_discount': doc['covered_discount'] ?? 0,
            'uncovered_discount': doc['uncovered_discount'] ?? 0,
          }
      };
    });
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
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('companies').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _primaryColor));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text('No companies available', style: TextStyle(color: _textColor)),
            );
          }

          final companies = snapshot.data!.docs;
          return DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              dropdownColor: _surfaceColor,
              value: _selectedCompanyName,
              hint: Text('Select Company', style: TextStyle(color: _secondaryTextColor)),
              icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
              items: [
                ...companies.map((company) => DropdownMenuItem<String>(
                  value: company['name'],
                  child: Text(
                    company['name'],
                    style: TextStyle(color: _textColor, fontSize: 14),
                  ),
                )),
              ],
              onChanged: (value) => setState(() => _selectedCompanyName = value),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('items').snapshots(),
      builder: (context, itemSnapshot) {
        if (itemSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _primaryColor));
        }
        if (itemSnapshot.hasError) {
          return Center(child: Text('Error: ${itemSnapshot.error}', style: TextStyle(color: _textColor)));
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('qualities').snapshots(),
          builder: (context, qualitySnapshot) {
            if (qualitySnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: _primaryColor));
            }
            if (qualitySnapshot.hasError) {
              return Center(child: Text('Error: ${qualitySnapshot.error}', style: TextStyle(color: _textColor)));
            }

            final qualityDocs = qualitySnapshot.data!.docs
                .where((doc) => doc['company_name'] == _selectedCompanyName)
                .toList();
            final qualityIds = qualityDocs.map((doc) => doc.id).toList();
            final items = itemSnapshot.data!.docs
                .where((item) => qualityIds.contains(item['qualityId']))
                .toList();

            if (items.isEmpty || _selectedCompanyName == null) {
              return Center(child: Text('No items found for this company', style: TextStyle(color: _textColor)));
            }

            double totalStockValue = items.fold(
                0.0, (sum, item) {
              final qualityId = item['qualityId'];
              final discount = _qualityDiscounts[qualityId]?[item['covered'] == 'Yes' ? 'covered_discount' : 'uncovered_discount'] ?? 0;
              final effectivePrice = (item['purchasePrice'] * (1 - discount / 100)).toDouble();
              return sum + (item['stockQuantity'] * effectivePrice);
            });

            return Column(
              children: [
                _buildDesktopHeader(),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 16),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: items.length,
                    itemBuilder: (context, index) => _buildDesktopRow(items[index]),
                  ),
                ),
                _buildTotalStockValue(totalStockValue),
              ],
            );
          },
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
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('items').snapshots(),
            builder: (context, itemSnapshot) {
              if (itemSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: _primaryColor));
              }
              if (itemSnapshot.hasError) {
                return Center(child: Text('Error: ${itemSnapshot.error}', style: TextStyle(color: _textColor)));
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('qualities').snapshots(),
                builder: (context, qualitySnapshot) {
                  if (qualitySnapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: _primaryColor));
                  }
                  if (qualitySnapshot.hasError) {
                    return Center(child: Text('Error: ${qualitySnapshot.error}', style: TextStyle(color: _textColor)));
                  }

                  final qualityDocs = qualitySnapshot.data!.docs
                      .where((doc) => doc['company_name'] == _selectedCompanyName)
                      .toList();
                  final qualityIds = qualityDocs.map((doc) => doc.id).toList();
                  final items = itemSnapshot.data!.docs
                      .where((item) => qualityIds.contains(item['qualityId']))
                      .toList();

                  if (items.isEmpty || _selectedCompanyName == null) {
                    return Center(child: Text('No items found for this company', style: TextStyle(color: _textColor)));
                  }

                  double totalStockValue = items.fold(
                      0.0, (sum, item) {
                    final qualityId = item['qualityId'];
                    final discount = _qualityDiscounts[qualityId]?[item['covered'] == 'Yes' ? 'covered_discount' : 'uncovered_discount'] ?? 0;
                    final effectivePrice = (item['purchasePrice'] * (1 - discount / 100)).toDouble();
                    return sum + (item['stockQuantity'] * effectivePrice);
                  });

                  return Column(
                    children: [
                      _buildMobileHeader(),
                      Expanded(
                        child: ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 16),
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemCount: items.length,
                          itemBuilder: (context, index) => _buildMobileRow(items[index]),
                        ),
                      ),
                      _buildTotalStockValue(totalStockValue),
                    ],
                  );
                },
              );
            },
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
            Expanded(child: _HeaderCell('Quality')),
            Expanded(flex: 2, child: _HeaderCell('Item Name')),
            Expanded(child: _HeaderCell('Covered')),
            Expanded(child: _HeaderCell('Opening Stock')),
            Expanded(child: _HeaderCell('C. Stock')),
            Expanded(child: _HeaderCell('Purchase Price')),
            Expanded(child: _HeaderCell('Discount')),
            Expanded(child: _HeaderCell('Stock Value')),
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
            _HeaderCell('Quality', 200),
            _HeaderCell('Item Name', 300),
            _HeaderCell('Covered', 150),
            _HeaderCell('Opening Stock', 150),
            _HeaderCell('C. Stock', 150),
            _HeaderCell('Purchase', 150),
            _HeaderCell('Discount', 150),
            _HeaderCell('Stock Value', 200),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopRow(DocumentSnapshot item) {
    int openingStock = (item['openingStock'] ?? 0).toInt();
    final qualityId = item['qualityId'];
    final discount = _qualityDiscounts[qualityId]?[item['covered'] == 'Yes' ? 'covered_discount' : 'uncovered_discount'] ?? 0;
    final effectivePrice = (item['purchasePrice'] * (1 - discount / 100)).toDouble();
    double stockValue = (item['stockQuantity'] * effectivePrice).toDouble();

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
            Expanded(child: _DataCell(item['qualityName'])),
            Expanded(flex: 2, child: _DataCell(item['itemName'])),
            Expanded(child: _DataCell(item['covered'])),
            Expanded(child: _DataCell(openingStock.toString())),
            Expanded(child: _DataCell(item['stockQuantity'].toStringAsFixed(0))),
            Expanded(child: _DataCell(item['purchasePrice'].toStringAsFixed(0))),
            Expanded(child: _DataCell(discount.toString())),
            Expanded(child: _DataCell(stockValue.toStringAsFixed(0))),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileRow(DocumentSnapshot item) {
    int openingStock = (item['openingStock'] ?? 0).toInt();
    final qualityId = item['qualityId'];
    final discount = _qualityDiscounts[qualityId]?[item['covered'] == 'Yes' ? 'covered_discount' : 'uncovered_discount'] ?? 0;
    final effectivePrice = (item['purchasePrice'] * (1 - discount / 100)).toDouble();
    double stockValue = (item['stockQuantity'] * effectivePrice).toDouble();

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
            _DataCell(item['qualityName'], 200),
            _DataCell(item['itemName'], 300),
            _DataCell(item['covered'], 150),
            _DataCell(openingStock.toString(), 150),
            _DataCell(item['stockQuantity'].toStringAsFixed(0), 150),
            _DataCell(item['purchasePrice'].toStringAsFixed(0), 150),
            _DataCell(discount.toString(), 150),
            _DataCell(stockValue.toStringAsFixed(0), 200),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalStockValue(double totalStockValue) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total Stock Value:',
            style: TextStyle(color: _textColor, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(
            totalStockValue.toStringAsFixed(0),
            style: TextStyle(color: _primaryColor, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 1200;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('Stock Valuation Report', style: TextStyle(color: _textColor)),
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
      body: _selectedCompanyName == null
          ? Center(child: Text('Please select a company', style: TextStyle(color: _textColor)))
          : isDesktop
          ? _buildDesktopLayout()
          : _buildMobileLayout(),
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
  final dynamic text;
  final double? width;
  final Color? color;

  const _DataCell(this.text, [this.width, this.color]);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = (context.findAncestorWidgetOfExactType<StockValuationReportPage>()!.isDarkMode);
    return SizedBox(
      width: width,
      child: Center(
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
      ),
    );
  }
}