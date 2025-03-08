import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
  Map<String, Map<String, dynamic>> _qualityDiscounts = {};
  List<Map<String, dynamic>> _filteredItems = [];
  bool _isPrinting = false; // Added loading state

  // Color Scheme
  Color get _primaryColor => const Color(0xFF0D6EFD);
  Color get _textColor => widget.isDarkMode ? Colors.white : const Color(0xFF2D2D2D);
  Color get _secondaryTextColor => widget.isDarkMode ? const Color(0xFFB0B0C0) : const Color(0xFF4A4A4A);
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
          data: widget.isDarkMode
              ? ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _surfaceColor,
              onSurface: _textColor,
            ),
            dialogBackgroundColor: _backgroundColor,
          )
              : ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _surfaceColor,
              onSurface: _textColor,
            ),
            dialogBackgroundColor: _backgroundColor,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => isFromDate ? _fromDate = picked : _toDate = picked);
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
            color: Colors.black.withOpacity(widget.isDarkMode ? 0.5 : 0.05),
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
            return Center(child: Text('No companies available', style: TextStyle(color: _textColor)));
          }
          final companies = snapshot.data!.docs;
          return DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              dropdownColor: _surfaceColor,
              value: _selectedCompanyName,
              hint: Text('Select Company', style: TextStyle(color: _secondaryTextColor)),
              icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
              items: companies
                  .map((company) => DropdownMenuItem<String>(
                value: company['name'],
                child: Text(company['name'], style: TextStyle(color: _textColor, fontSize: 14)),
              ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedCompanyName = value),
            ),
          );
        },
      ),
    );
  }

  Future<void> _printStockValuationReport(List<Map<String, dynamic>> items, double totalStockValue) async {
    setState(() => _isPrinting = true); // Start loading

    try {
      final pdf = pw.Document();
      final numberFormat = NumberFormat.currency(decimalDigits: 0, symbol: '');
      final Uint8List logoImage = (await rootBundle.load('assets/images/logo1.png')).buffer.asUint8List();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          header: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('STOCK VALUATION REPORT',
                          style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#0D6EFD'))),
                      pw.SizedBox(height: 8),
                      pw.Text('Popular Foam Center',
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                      pw.Text('Zanana Hospital Road, Bahawalpur (63100)',
                          style: pw.TextStyle(fontSize: 10, color: PdfColors.black)),
                    ],
                  ),
                  pw.Image(pw.MemoryImage(logoImage), width: 135, height: 135),
                ],
              ),
              pw.Divider(color: PdfColor.fromHex('#0D6EFD'), height: 40),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Company:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.black)),
                      pw.Text(_selectedCompanyName ?? 'N/A', style: const pw.TextStyle(fontSize: 14, color: PdfColors.black)),
                      pw.SizedBox(height: 8),
                      pw.Text('Date Range:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.black)),
                      pw.Text(
                          '${_fromDate != null ? DateFormat('dd-MM-yyyy').format(_fromDate!) : 'N/A'} - ${_toDate != null ? DateFormat('dd-MM-yyyy').format(_toDate!) : 'N/A'}',
                          style: const pw.TextStyle(fontSize: 12, color: PdfColors.black)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
            ],
          ),
          footer: (_) => pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F8F9FA'),
              border: pw.Border(top: pw.BorderSide(color: PdfColor.fromHex('#0D6EFD'), width: 1)),
            ),
            child: pw.Column(
              children: [
                pw.Text('Thank you for your business with Popular Foam Center',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0D6EFD'))),
                pw.SizedBox(height: 4),
                pw.Text('Contact: 0302-9596046 | Facebook: Popular Foam Center',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.black)),
                pw.Text('Notes: Subject to company terms and conditions',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.black)),
              ],
            ),
          ),
          build: (pw.Context context) => [
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(0.8),
                3: const pw.FlexColumnWidth(0.8),
                4: const pw.FlexColumnWidth(0.8),
                5: const pw.FlexColumnWidth(1.2),
                6: const pw.FlexColumnWidth(1.0),
                7: const pw.FlexColumnWidth(1.2),
              },
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#0D6EFD')),
                  children: [
                    'Quality',
                    'Item',
                    'Cvrd',
                    'Op. Stock',
                    'St. Stock',
                    'Price',
                    'Disc%',
                    'Value',
                  ].map((text) => pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    alignment: pw.Alignment.center,
                    child: pw.Text(text,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  )).toList(),
                ),
                ...items.map((item) {
                  final qualityId = item['qualityId'];
                  final discount = _qualityDiscounts[qualityId]?[item['covered'] == 'Yes' ? 'covered_discount' : 'uncovered_discount'] ?? 0;
                  final effectivePrice = (item['purchasePrice'] * (1 - discount / 100)).toDouble();
                  final stockValue = (item['stockQuantity'] * effectivePrice).toDouble();
                  return pw.TableRow(
                    children: [
                      pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          alignment: pw.Alignment.center,
                          child: pw.Text(item['qualityName'],
                              textAlign: pw.TextAlign.center,
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
                      pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          alignment: pw.Alignment.center,
                          child: pw.Text(item['itemName'],
                              textAlign: pw.TextAlign.center,
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
                      pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          alignment: pw.Alignment.center,
                          child: pw.Text(item['covered'],
                              textAlign: pw.TextAlign.center,
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
                      pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          alignment: pw.Alignment.center,
                          child: pw.Text(item['openingStock'].toString(),
                              textAlign: pw.TextAlign.center,
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
                      pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          alignment: pw.Alignment.center,
                          child: pw.Text(item['stockQuantity'].toString(),
                              textAlign: pw.TextAlign.center,
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
                      pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          alignment: pw.Alignment.center,
                          child: pw.Text(numberFormat.format(item['purchasePrice']),
                              textAlign: pw.TextAlign.center,
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
                      pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          alignment: pw.Alignment.center,
                          child: pw.Text('$discount%',
                              textAlign: pw.TextAlign.center,
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
                      pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          alignment: pw.Alignment.center,
                          child: pw.Text(numberFormat.format(stockValue),
                              textAlign: pw.TextAlign.center,
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.black))),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 25),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                    pw.Text('Total Value:',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                    pw.SizedBox(width: 15),
                    pw.Text(numberFormat.format(totalStockValue),
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
                  ]),
                  pw.SizedBox(height: 15),
                  pw.Container(
                    width: 250,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F8F9FA'),
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: PdfColor.fromHex('#0D6EFD'), width: 1),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('TOTAL ITEMS',
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                        pw.Text(items.length.toString(),
                            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0D6EFD'))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      await Printing.layoutPdf(onLayout: (_) => pdfBytes, name: 'PFC-Stock-Valuation');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to print stock valuation report: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false); // Stop loading
      }
    }
  }

  void _handlePrint() async {
    if (_isPrinting || _selectedCompanyName == null || _filteredItems.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _primaryColor),
            const SizedBox(height: 16),
            Text('Generating PDF...', style: TextStyle(color: _textColor)),
          ],
        ),
      ),
    );

    final totalStockValue = _filteredItems.fold(0.0, (sum, item) {
      final qualityId = item['qualityId'];
      final discount = _qualityDiscounts[qualityId]?[item['covered'] == 'Yes' ? 'covered_discount' : 'uncovered_discount'] ?? 0;
      final effectivePrice = (item['purchasePrice'] * (1 - discount / 100)).toDouble();
      return sum + (item['stockQuantity'] * effectivePrice);
    });

    await _printStockValuationReport(_filteredItems, totalStockValue);

    if (mounted) {
      Navigator.of(context).pop(); // Close loading dialog
    }
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
            _filteredItems = itemSnapshot.data!.docs
                .where((item) => qualityIds.contains(item['qualityId']))
                .map((item) => item.data() as Map<String, dynamic>)
                .toList();

            if (_filteredItems.isEmpty || _selectedCompanyName == null) {
              return Center(child: Text('No items found for this company', style: TextStyle(color: _textColor)));
            }

            double totalStockValue = _filteredItems.fold(0.0, (sum, item) {
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
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) => _buildDesktopRow(_filteredItems[index]),
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
                  _filteredItems = itemSnapshot.data!.docs
                      .where((item) => qualityIds.contains(item['qualityId']))
                      .map((item) => item.data() as Map<String, dynamic>)
                      .toList();

                  if (_filteredItems.isEmpty || _selectedCompanyName == null) {
                    return Center(child: Text('No items found for this company', style: TextStyle(color: _textColor)));
                  }

                  double totalStockValue = _filteredItems.fold(0.0, (sum, item) {
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
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) => _buildMobileRow(_filteredItems[index]),
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
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(widget.isDarkMode ? 0.5 : 0.05), blurRadius: 12, offset: const Offset(0, 4))
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(child: _HeaderCell('Quality')),
            Expanded(flex: 2, child: _HeaderCell('Item')),
            Expanded(child: _HeaderCell('Cvrd')),
            Expanded(child: _HeaderCell('Op. Stock')),
            Expanded(child: _HeaderCell('St. Stock')),
            Expanded(child: _HeaderCell('Price')),
            Expanded(child: _HeaderCell('Disc%')),
            Expanded(child: _HeaderCell('Value')),
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
          BoxShadow(color: Colors.black.withOpacity(widget.isDarkMode ? 0.5 : 0.05), blurRadius: 12, offset: const Offset(0, 4))
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _HeaderCell('Quality', 200),
            _HeaderCell('Item', 300),
            _HeaderCell('Cvrd', 150),
            _HeaderCell('Op. Stock', 150),
            _HeaderCell('St. Stock', 150),
            _HeaderCell('Price', 150),
            _HeaderCell('Disc%', 150),
            _HeaderCell('Value', 200),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopRow(Map<String, dynamic> item) {
    int openingStock = (item['openingStock'] ?? 0).toInt();
    final qualityId = item['qualityId'];
    final discount = _qualityDiscounts[qualityId]?[item['covered'] == 'Yes' ? 'covered_discount' : 'uncovered_discount'] ?? 0;
    final effectivePrice = (item['purchasePrice'] * (1 - discount / 100)).toDouble();
    double stockValue = (item['stockQuantity'] * effectivePrice).toDouble();

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(widget.isDarkMode ? 0.5 : 0.05), blurRadius: 8, offset: const Offset(0, 4))
        ],
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
            Expanded(child: _DataCell('$discount%')),
            Expanded(child: _DataCell(stockValue.toStringAsFixed(0))),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileRow(Map<String, dynamic> item) {
    int openingStock = (item['openingStock'] ?? 0).toInt();
    final qualityId = item['qualityId'];
    final discount = _qualityDiscounts[qualityId]?[item['covered'] == 'Yes' ? 'covered_discount' : 'uncovered_discount'] ?? 0;
    final effectivePrice = (item['purchasePrice'] * (1 - discount / 100)).toDouble();
    double stockValue = (item['stockQuantity'] * effectivePrice).toDouble();

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(widget.isDarkMode ? 0.5 : 0.05), blurRadius: 8, offset: const Offset(0, 4))
        ],
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
            _DataCell('$discount%', 150),
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
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(widget.isDarkMode ? 0.5 : 0.05), blurRadius: 8, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Total Value:', style: TextStyle(color: _textColor, fontSize: 16, fontWeight: FontWeight.w600)),
          Text(totalStockValue.toStringAsFixed(0),
              style: TextStyle(color: _primaryColor, fontSize: 16, fontWeight: FontWeight.w600)),
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
        backgroundColor: _surfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor),
        actions: [
          IconButton(
            icon: _isPrinting
                ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: _primaryColor,
                strokeWidth: 2,
              ),
            )
                : Icon(Icons.print, color: _primaryColor),
            onPressed: _handlePrint,
            tooltip: 'Print Stock Valuation Report',
          ),
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
    final isDarkMode = context.findAncestorWidgetOfExactType<StockValuationReportPage>()!.isDarkMode;
    return SizedBox(
      width: width,
      child: Center(
        child: text is Widget
            ? text
            : Text(
          text.toString(),
          style: TextStyle(color: color ?? (isDarkMode ? Colors.white : const Color(0xFF2D2D2D)), fontSize: 14),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }
}