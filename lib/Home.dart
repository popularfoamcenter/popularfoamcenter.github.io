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
import 'package:pfc/saleinvoices.dart';
import 'package:pfc/vehicles.dart';
import 'package:pfc/company.dart';
import 'package:pfc/main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Widget _currentPage = Dashboard();
  String _selectedButton = "Dashboard";
  bool _isSidebarOpen = true;
  final double _sidebarWidth = 280;

  // Color Scheme
  static const Color primaryBlue = Color(0xFF0D6EFD);
  static const Color backgroundGray = Color(0xFFF8F9FA);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF212529);
  static const Color textSecondary = Color(0xFF495057);
  static const Color iconActive = Color(0xFF0D6EFD);
  static const Color iconInactive = Color(0xFFADB5BD);

  final List<Map<String, dynamic>> _navigationItems = [
    {'icon': Icons.dashboard, 'label': 'Dashboard', 'page': Dashboard()},
    {'icon': Icons.point_of_sale, 'label': 'Point of Sale', 'page': PointOfSalePage()},
    {'icon': Icons.inventory_2, 'label': 'Inventory', 'page': InventoryPage()},
    {'icon': Icons.people_alt, 'label': 'Customers', 'page': CustomerListPage()},
    {'icon': Icons.directions_bus, 'label': 'Vehicles', 'page': const VehiclesPage()},
    {'icon': Icons.grade, 'label': 'Quality', 'page': const QualityPage()},
    {'icon': Icons.business, 'label': 'Company', 'page': CompanyListPage()},
    {'icon': Icons.account_balance_sharp, 'label': 'Accounts', 'page': const AccountsPage()},
    {'icon': Icons.receipt_rounded, 'label': 'Sale Invoices', 'page': InvoiceListPage()},
    {'icon': Icons.edit_note_rounded, 'label': 'Ledger', 'page': const CompanyLedgerPage()},
    {'icon': Icons.attach_money, 'label': 'Cash Register', 'page': const CashRegisterPage()},
    {'icon': Icons.shopping_cart, 'label': 'Purchase Order', 'page': PurchaseOrdersPage()},
    {'icon': Icons.add_shopping_cart, 'label': 'Purchase Invoice', 'page': const InvoiceListScreen()},
  ];

  void _setPage(Widget page, String label) {
    setState(() {
      _currentPage = page;
      _selectedButton = label;
    });
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    return isMobile ? _buildMobileLayout() : _buildDesktopLayout();
  }

  Widget _buildMobileLayout() {
    final textScale = MediaQuery.of(context).textScaleFactor;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: Text(
          _selectedButton,
          style: GoogleFonts.roboto(
            color: textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 20 * textScale,
          ),
        ),
        backgroundColor: surfaceWhite,
        iconTheme: const IconThemeData(color: textPrimary),
        elevation: 0,
        centerTitle: true,
      ),
      drawer: Drawer(
        backgroundColor: surfaceWhite,
        width: screenWidth * 0.8,
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 120,
                child: DrawerHeader(
                  decoration: BoxDecoration(
                    color: surfaceWhite,
                    border: Border(
                      bottom: BorderSide(color: backgroundGray.withOpacity(0.5)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: "Popular Foam ",
                                style: GoogleFonts.montserrat(
                                  color: textPrimary,
                                  fontSize: screenWidth < 400 ? 16 : 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: "Centre",
                                style: GoogleFonts.montserrat(
                                  color: primaryBlue,
                                  fontSize: screenWidth < 400 ? 16 : 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                    color: backgroundGray.withOpacity(0.3),
                  ),
                  itemBuilder: (context, index) => _MobileNavItem(
                    icon: _navigationItems[index]['icon'] as IconData,
                    label: _navigationItems[index]['label'] as String,
                    isSelected: _selectedButton == _navigationItems[index]['label'],
                    onTap: () => _setPage(
                      _navigationItems[index]['page'] as Widget,
                      _navigationItems[index]['label'] as String,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _MobileNavItem(
                  icon: Icons.logout,
                  label: 'Logout',
                  isSelected: false,
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  ),
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
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: backgroundGray,
      body: Stack(
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                width: _isSidebarOpen ? _sidebarWidth : 0,
                child: OverflowBox(
                  maxWidth: _sidebarWidth,
                  alignment: Alignment.centerLeft,
                  child: _buildNavigationRail(),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey<Widget>(_currentPage),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      boxShadow: _isSidebarOpen
                          ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 16,
                          spreadRadius: 2,
                          offset: const Offset(4, 0),
                        )
                      ]
                          : null,
                    ),
                    child: _currentPage,
                  ),
                ),
              ),
            ],
          ),
          if (!_isSidebarOpen)
            Positioned(
              left: 0,
              top: MediaQuery.of(context).size.height / 2 - 24,
              child: GestureDetector(
                onTap: _toggleSidebar,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: surfaceWhite,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    color: textPrimary,
                    size: 24,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavigationRail() {
    return Material(
      elevation: 4,
      child: Container(
        width: _sidebarWidth,
        decoration: BoxDecoration(
          color: surfaceWhite,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(4, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: backgroundGray.withOpacity(0.5)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: RichText(
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: "Popular Foam ",
                            style: GoogleFonts.montserrat(
                              color: textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: "Centre",
                            style: GoogleFonts.montserrat(
                              color: primaryBlue,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isSidebarOpen ? Icons.chevron_left : Icons.chevron_right),
                    onPressed: _toggleSidebar,
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                itemCount: _navigationItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _NavigationItem(
                  icon: _navigationItems[index]['icon'] as IconData,
                  label: _navigationItems[index]['label'] as String,
                  isSelected: _selectedButton == _navigationItems[index]['label'],
                  onTap: () => _setPage(
                    _navigationItems[index]['page'] as Widget,
                    _navigationItems[index]['label'] as String,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: _NavigationItem(
                icon: Icons.logout,
                label: 'Logout',
                isSelected: false,
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MobileNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
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
                color: isSelected ? _HomePageState.primaryBlue : _HomePageState.iconInactive,
              ),
              const SizedBox(width: 20),
              Text(
                label,
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  color: isSelected ? _HomePageState.textPrimary : _HomePageState.textSecondary,
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

class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected
              ? _HomePageState.primaryBlue.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: _HomePageState.primaryBlue, width: 1.5)
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            hoverColor: _HomePageState.primaryBlue.withOpacity(0.05),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              child: Row(
                children: [
                  Icon(icon,
                      size: 22,
                      color: isSelected
                          ? _HomePageState.primaryBlue
                          : _HomePageState.iconInactive),
                  const SizedBox(width: 16),
                  Text(
                    label,
                    style: GoogleFonts.roboto(
                      color: isSelected
                          ? _HomePageState.textPrimary
                          : _HomePageState.textSecondary,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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