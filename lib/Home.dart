import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pfc/Dashboard.dart';
import 'package:pfc/Inventory.dart';
import 'package:pfc/accounts.dart';
import 'package:pfc/cashregister.dart';
import 'package:pfc/customers.dart';
import 'package:pfc/ledger.dart';
import 'package:pfc/pointofsale.dart';
import 'package:pfc/purchaseinvoice.dart';
import 'package:pfc/qualities.dart';
import 'package:pfc/purchaseorder.dart';
import 'package:pfc/transactionspage.dart';
import 'package:pfc/vehicles.dart';
import 'package:pfc/company.dart';
import 'package:pfc/main.dart';
import 'package:pfc/productledger.dart';
import 'package:provider/provider.dart';
import 'customerLedger.dart';
import 'reports_landing.dart';
import 'profit&loss.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Widget _currentPage;
  String _selectedButton = "Dashboard";
  late int _darkModeState; // 0: Full light, 1: Sidebar dark, 2: Full dark
  final double _sidebarWidth = 200; // Reduced from 280 to minimize space

  // Color Scheme
  static const Color primaryBlue = Color(0xFF0D6EFD);
  static const Color backgroundGray = Color(0xFFF8F9FA);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF212529);
  static const Color textSecondary = Color(0xFF495057);
  static const Color iconActive = Color(0xFF0D6EFD);
  static const Color iconInactive = Color(0xFFADB5BD);

  late List<Map<String, dynamic>> _navigationItems;

  @override
  void initState() {
    super.initState();
    final themeProvider = Provider.of<ThemeModeProvider>(context, listen: false);
    _darkModeState = themeProvider.themeMode == ThemeMode.dark ? 2 : 0;
    _navigationItems = [
      {'icon': Icons.dashboard, 'label': 'Dashboard', 'page': Dashboard(isDarkMode: _darkModeState == 2, toggleDarkMode: _toggleDarkMode)},
      {'icon': Icons.inventory_2, 'label': 'Inventory', 'page': InventoryPage(isDarkMode: _darkModeState == 2, toggleDarkMode: _toggleDarkMode)},
      {'icon': Icons.point_of_sale, 'label': 'Point of Sale', 'page': const PointOfSalePage()},
      {'icon': Icons.receipt_rounded, 'label': 'Invoices', 'page': TransactionsPage()},
      {'icon': Icons.people_alt, 'label': 'Customers', 'page': const CustomerListPage()},
      {'icon': Icons.directions_bus, 'label': 'Vehicles', 'page': const VehiclesPage()},
      {'icon': Icons.grade, 'label': 'Quality', 'page': const QualityPage()},
      {'icon': Icons.business, 'label': 'Company', 'page': CompanyListPage()},
      {'icon': Icons.account_balance_sharp, 'label': 'Accounts', 'page': const AccountsPage()},
      {'icon': Icons.edit_note_rounded, 'label': 'Company Ledger', 'page': CompanyLedgerPage(isDarkMode: _darkModeState == 2, toggleDarkMode: _toggleDarkMode)},
      {'icon': Icons.people_alt_outlined, 'label': 'Customer Ledger', 'page': CustomerLedgerPage(isDarkMode: _darkModeState == 2, toggleDarkMode: _toggleDarkMode)},
      {'icon': Icons.book, 'label': 'Product Ledger', 'page': ProductLedgerPage(isDarkMode: _darkModeState == 2, toggleDarkMode: _toggleDarkMode)},
      {'icon': Icons.attach_money, 'label': 'Cash Register', 'page': const CashRegisterPage()},
      {'icon': Icons.auto_graph, 'label': 'Stock Valuation Report', 'page': StockValuationReportPage(isDarkMode: _darkModeState == 2, toggleDarkMode: _toggleDarkMode)},
      {'icon': Icons.shopping_cart, 'label': 'Purchase Order', 'page': PurchaseOrdersPage(isDarkMode: _darkModeState == 2)},
      {'icon': Icons.add_shopping_cart, 'label': 'Purchase Invoice', 'page': const InvoiceListScreen()},
      {'icon': Icons.bar_chart, 'label': 'Profit and Loss', 'page': ProfitAndLossPage(isDarkMode: _darkModeState == 2, toggleDarkMode: _toggleDarkMode)},
    ];
    _currentPage = _navigationItems[0]['page'] as Widget; // Default to Dashboard
  }

  void _setPage(Widget page, String label) {
    setState(() {
      _currentPage = page;
      _selectedButton = label;
    });
  }

  void _toggleDarkMode() {
    setState(() {
      _darkModeState = (_darkModeState + 1) % 3;
      final themeProvider = Provider.of<ThemeModeProvider>(context, listen: false);
      themeProvider.setThemeMode(_darkModeState == 2 ? ThemeMode.dark : ThemeMode.light);
      _navigationItems = _navigationItems.map((item) {
        if (item['label'] == 'Dashboard') {
          return {'icon': item['icon'], 'label': item['label'], 'page': Dashboard(isDarkMode: _darkModeState == 2, toggleDarkMode: _toggleDarkMode)};
        } else if (item['label'] == 'Inventory') {
          return {'icon': item['icon'], 'label': item['label'], 'page': InventoryPage(isDarkMode: _darkModeState == 2, toggleDarkMode: _toggleDarkMode)};
        } else if (item['label'] == 'Purchase Order') {
          return {'icon': item['icon'], 'label': item['label'], 'page': PurchaseOrdersPage(isDarkMode: _darkModeState == 2)};
        } else if (item['label'] == 'Company Ledger') {
          return {'icon': item['icon'], 'label': item['label'], 'page': CompanyLedgerPage(isDarkMode: _darkModeState == 2, toggleDarkMode: _toggleDarkMode)};
        } else if (item['label'] == 'Customer Ledger') {
          return {'icon': item['icon'], 'label': item['label'], 'page': CustomerLedgerPage(isDarkMode: _darkModeState == 2, toggleDarkMode: _toggleDarkMode)};
        } else if (item['label'] == 'Product Ledger') {
          return {'icon': item['icon'], 'label': item['label'], 'page': ProductLedgerPage(isDarkMode: _darkModeState == 2, toggleDarkMode: _toggleDarkMode)};
        } else if (item['label'] == 'Stock Valuation Report') {
          return {'icon': item['icon'], 'label': item['label'], 'page': StockValuationReportPage(isDarkMode: _darkModeState == 2, toggleDarkMode: _toggleDarkMode)};
        } else if (item['label'] == 'Profit and Loss') {
          return {'icon': item['icon'], 'label': item['label'], 'page': ProfitAndLossPage(isDarkMode: _darkModeState == 2, toggleDarkMode: _toggleDarkMode)};
        }
        return item;
      }).toList();

      if (_selectedButton == "Dashboard") {
        _currentPage = Dashboard(isDarkMode: _darkModeState == 2, toggleDarkMode: _toggleDarkMode);
      } else if (_selectedButton == "Inventory") {
        _currentPage = InventoryPage(isDarkMode: _darkModeState == 2, toggleDarkMode: _toggleDarkMode);
      } else if (_selectedButton == "Purchase Order") {
        _currentPage = PurchaseOrdersPage(isDarkMode: _darkModeState == 2);
      } else if (_selectedButton == "Company Ledger") {
        _currentPage = CompanyLedgerPage(isDarkMode: _darkModeState == 2, toggleDarkMode: _toggleDarkMode);
      } else if (_selectedButton == "Customer Ledger") {
        _currentPage = CustomerLedgerPage(isDarkMode: _darkModeState == 2, toggleDarkMode: _toggleDarkMode);
      } else if (_selectedButton == "Product Ledger") {
        _currentPage = ProductLedgerPage(isDarkMode: _darkModeState == 2, toggleDarkMode: _toggleDarkMode);
      } else if (_selectedButton == "Stock Valuation Report") {
        _currentPage = StockValuationReportPage(isDarkMode: _darkModeState == 2, toggleDarkMode: _toggleDarkMode);
      } else if (_selectedButton == "Profit and Loss") {
        _currentPage = ProfitAndLossPage(isDarkMode: _darkModeState == 2, toggleDarkMode: _toggleDarkMode);
      }
    });
  }

  Future<void> _showLogoutConfirmationDialog() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Theme(
        data: _darkModeState == 2 ? _darkTheme() : _lightTheme(),
        child: Dialog(
          backgroundColor: _darkModeState >= 1 ? const Color(0xFF252541) : surfaceWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _darkModeState >= 1 ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Confirm Logout',
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _darkModeState >= 1 ? Colors.white : textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Are you sure you want to log out?',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: _darkModeState >= 1 ? const Color(0xFFB0B0C0) : textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.roboto(
                          color: _darkModeState >= 1 ? const Color(0xFFB0B0C0) : textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Logout',
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
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
      ),
    );

    if (confirmed == true) {
      final themeProvider = Provider.of<ThemeModeProvider>(context, listen: false);
      themeProvider.setThemeMode(_darkModeState == 2 ? ThemeMode.dark : ThemeMode.light);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    return isMobile ? _buildMobileLayout() : _buildDesktopLayout();
  }

  Widget _buildMobileLayout() {
    final textScale = MediaQuery.of(context).textScaleFactor;
    final screenWidth = MediaQuery.of(context).size.width;

    return Theme(
      data: _darkModeState == 2 ? _darkTheme() : _lightTheme(),
      child: Scaffold(
        appBar: AppBar(
          systemOverlayStyle: _darkModeState == 2 ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          title: Text(
            _selectedButton,
            style: GoogleFonts.roboto(
              color: _darkModeState >= 1 ? Colors.white : textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 20 * textScale,
            ),
          ),
          backgroundColor: _darkModeState >= 1 ? const Color(0xFF252541) : surfaceWhite,
          iconTheme: IconThemeData(color: _darkModeState >= 1 ? Colors.white : textPrimary),
          elevation: 0,
          centerTitle: true,
        ),
        drawer: Drawer(
          backgroundColor: _darkModeState >= 1 ? const Color(0xFF252541) : surfaceWhite,
          width: screenWidth * 0.8,
          child: SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: 120,
                  child: DrawerHeader(
                    decoration: BoxDecoration(
                      color: _darkModeState >= 1 ? const Color(0xFF252541) : surfaceWhite,
                      border: Border(
                        bottom: BorderSide(color: _darkModeState >= 1 ? Colors.grey[800]!.withOpacity(0.5) : backgroundGray.withOpacity(0.5)),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8),
                        _MobileNavItem(
                          icon: _darkModeState == 0 ? Icons.dark_mode : Icons.light_mode,
                          label: 'Dark Mode',
                          isSelected: false,
                          onTap: _toggleDarkMode,
                          isDarkMode: _darkModeState >= 1,
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _navigationItems.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: _darkModeState >= 1 ? Colors.grey[800]!.withOpacity(0.3) : backgroundGray.withOpacity(0.3),
                    ),
                    itemBuilder: (context, index) => _MobileNavItem(
                      icon: _navigationItems[index]['icon'] as IconData,
                      label: _navigationItems[index]['label'] as String,
                      isSelected: _selectedButton == _navigationItems[index]['label'],
                      onTap: () => _setPage(
                        _navigationItems[index]['page'] as Widget,
                        _navigationItems[index]['label'] as String,
                      ),
                      isDarkMode: _darkModeState >= 1,
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  color: _darkModeState >= 1 ? Colors.grey[800]!.withOpacity(0.3) : backgroundGray.withOpacity(0.3),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: _MobileNavItem(
                    icon: Icons.logout,
                    label: 'Logout',
                    isSelected: false,
                    onTap: _showLogoutConfirmationDialog,
                    isDarkMode: _darkModeState >= 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.1, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
          child: Container(
            key: ValueKey<Widget>(_currentPage),
            child: _currentPage,
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Theme(
      data: _darkModeState == 2 ? _darkTheme() : _lightTheme(),
      child: Scaffold(
        backgroundColor: _darkModeState == 2 ? const Color(0xFF1A1A2F) : backgroundGray,
        body: Row(
          children: [
            SizedBox(
              width: _sidebarWidth,
              child: _buildNavigationRail(),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey<Widget>(_currentPage),
                  decoration: BoxDecoration(
                    color: _darkModeState == 2 ? const Color(0xFF252541) : surfaceWhite,
                    boxShadow: [
                      BoxShadow(
                        color: _darkModeState >= 1 ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: const Offset(4, 0),
                      ),
                    ],
                  ),
                  child: _currentPage,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationRail() {
    return Material(
      elevation: 4,
      child: Container(
        width: _sidebarWidth,
        decoration: BoxDecoration(
          color: _darkModeState >= 1 ? const Color(0xFF252541) : surfaceWhite,
          boxShadow: [
            BoxShadow(
              color: _darkModeState >= 1 ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.1),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(4, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12), // Reduced padding
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: _darkModeState >= 1 ? Colors.grey[800]!.withOpacity(0.5) : backgroundGray.withOpacity(0.5)),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12), // Reduced spacing
                  _NavigationItem(
                    icon: _darkModeState == 0 ? Icons.dark_mode : Icons.light_mode,
                    label: 'Dark Mode',
                    isSelected: false,
                    onTap: _toggleDarkMode,
                    isDarkMode: _darkModeState >= 1,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), // Reduced padding
                itemCount: _navigationItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6), // Reduced separator height
                itemBuilder: (context, index) => _NavigationItem(
                  icon: _navigationItems[index]['icon'] as IconData,
                  label: _navigationItems[index]['label'] as String,
                  isSelected: _selectedButton == _navigationItems[index]['label'],
                  onTap: () => _setPage(
                    _navigationItems[index]['page'] as Widget,
                    _navigationItems[index]['label'] as String,
                  ),
                  isDarkMode: _darkModeState >= 1,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16), // Reduced padding
              child: _NavigationItem(
                icon: Icons.logout,
                label: 'Logout',
                isSelected: false,
                onTap: _showLogoutConfirmationDialog,
                isDarkMode: _darkModeState >= 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  ThemeData _lightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundGray,
      cardColor: surfaceWhite,
      textTheme: TextTheme(
        headlineMedium: GoogleFonts.roboto(color: textPrimary, fontWeight: FontWeight.w600),
        bodyMedium: GoogleFonts.roboto(color: textSecondary),
      ),
      iconTheme: const IconThemeData(color: iconInactive),
    );
  }

  ThemeData _darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF1A1A2F),
      cardColor: const Color(0xFF252541),
      textTheme: TextTheme(
        headlineMedium: GoogleFonts.roboto(color: Colors.white, fontWeight: FontWeight.w600),
        bodyMedium: GoogleFonts.roboto(color: const Color(0xFFB0B0C0)),
      ),
      iconTheme: const IconThemeData(color: Colors.white70),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDarkMode;

  const _MobileNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? _HomePageState.primaryBlue.withOpacity(0.1) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: _HomePageState.primaryBlue.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected
                    ? _HomePageState.primaryBlue
                    : (isDarkMode ? Colors.white70 : _HomePageState.iconInactive),
              ),
              const SizedBox(width: 20),
              Text(
                label,
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  color: isSelected
                      ? (isDarkMode ? Colors.white : _HomePageState.textPrimary)
                      : (isDarkMode ? Colors.white70 : _HomePageState.textSecondary),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavIconItem extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDarkMode;

  const _MobileNavIconItem({
    required this.icon,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: _HomePageState.primaryBlue.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
          ),
          child: Icon(
            icon,
            size: 24,
            color: isDarkMode ? Colors.white70 : _HomePageState.iconInactive,
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDarkMode;

  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8), // Reduced horizontal padding
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected ? _HomePageState.primaryBlue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: _HomePageState.primaryBlue, width: 1.5) : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            hoverColor: _HomePageState.primaryBlue.withOpacity(0.05),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), // Reduced padding
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20, // Slightly smaller icon
                    color: isSelected
                        ? _HomePageState.primaryBlue
                        : (isDarkMode ? Colors.white70 : _HomePageState.iconInactive),
                  ),
                  const SizedBox(width: 12), // Reduced spacing
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        color: isSelected
                            ? (isDarkMode ? Colors.white : _HomePageState.textPrimary)
                            : (isDarkMode ? Colors.white70 : _HomePageState.textSecondary),
                        fontSize: 13, // Slightly smaller font
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationIconItem extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDarkMode;

  const _NavigationIconItem({
    required this.icon,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: _HomePageState.primaryBlue.withOpacity(0.05),
        splashColor: _HomePageState.primaryBlue.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.all(10), // Reduced padding
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
          ),
          child: Icon(
            icon,
            size: 20, // Slightly smaller icon
            color: isDarkMode ? Colors.white70 : _HomePageState.iconInactive,
          ),
        ),
      ),
    );
  }
}