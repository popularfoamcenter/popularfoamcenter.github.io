import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Dashboard extends StatefulWidget {
  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with SingleTickerProviderStateMixin {
  int _totalInventory = 0;
  int _totalStockValue = 0;
  int _totalQualities = 0;
  int _totalCompanies = 0;
  int _totalVehicles = 0;
  bool _isLoading = true;

  late AnimationController _controller;
  late Animation<int> _inventoryAnimation;
  late Animation<int> _stockValueAnimation;
  late Animation<int> _qualitiesAnimation;
  late Animation<int> _companiesAnimation;
  late Animation<int> _vehiclesAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _initializeAnimations();
    _fetchData();
  }

  void _initializeAnimations() {
    _inventoryAnimation = IntTween(begin: 0, end: 0).animate(_controller);
    _stockValueAnimation = IntTween(begin: 0, end: 0).animate(_controller);
    _qualitiesAnimation = IntTween(begin: 0, end: 0).animate(_controller);
    _companiesAnimation = IntTween(begin: 0, end: 0).animate(_controller);
    _vehiclesAnimation = IntTween(begin: 0, end: 0).animate(_controller);
  }

  Future<void> _fetchData() async {
    try {
      final itemsSnapshot = await FirebaseFirestore.instance.collection('items').get();
      final qualitiesSnapshot = await FirebaseFirestore.instance.collection('qualities').get();
      final companiesSnapshot = await FirebaseFirestore.instance.collection('companies').get();
      final vehiclesSnapshot = await FirebaseFirestore.instance.collection('vehicles').get();

      int totalInventory = 0;
      int totalValue = 0;

      for (var doc in itemsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        int quantity = (data['stockQuantity'] ?? 0) as int;
        int salePrice = (data['salePrice'] ?? 0) as int;

        totalInventory += quantity;
        totalValue += quantity * salePrice;
      }

      setState(() {
        _totalInventory = totalInventory;
        _totalStockValue = totalValue;
        _totalQualities = qualitiesSnapshot.size;
        _totalCompanies = companiesSnapshot.size;
        _totalVehicles = vehiclesSnapshot.size;

        _updateAnimations();
        _controller
          ..reset()
          ..forward();
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _updateAnimations() {
    _inventoryAnimation = IntTween(begin: 0, end: _totalInventory).animate(_controller);
    _stockValueAnimation = IntTween(begin: 0, end: _totalStockValue).animate(_controller);
    _qualitiesAnimation = IntTween(begin: 0, end: _totalQualities).animate(_controller);
    _companiesAnimation = IntTween(begin: 0, end: _totalCompanies).animate(_controller);
    _vehiclesAnimation = IntTween(begin: 0, end: _totalVehicles).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F3460)),
        ),
      )
          : SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05,
          vertical: 24,
        ),
        child: Column(
          children: [
            _buildDashboardHeader(context),
            const SizedBox(height: 32),
            _buildMainMetricsGrid(context),
            const SizedBox(height: 32),
            _buildCategoryGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardHeader(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Overview",
          style: TextStyle(
            fontSize: screenWidth < 600 ? 24 : 28,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1A2F),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Real-time inventory analytics",
          style: TextStyle(
            fontSize: screenWidth < 600 ? 14 : 16,
            color: const Color(0xFF6C757D),
          ),
        ),
      ],
    );
  }

  Widget _buildMainMetricsGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
        final childAspectRatio = constraints.maxWidth > 600 ? 3 : 2.5;

        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio.toDouble(),
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
          ),
          children: [
            _buildMetricCard(
              context,
              title: "Total Inventory",
              animation: _inventoryAnimation,
              icon: Icons.inventory_rounded,
              gradient: const [Color(0xFF4E54C8), Color(0xFF8F94FB)],
            ),
            _buildMetricCard(
              context,
              title: "Stock Value",
              animation: _stockValueAnimation,
              icon: Icons.attach_money_rounded,
              gradient: const [Color(0xFF11998E), Color(0xFF38EF7D)],
              isCurrency: true,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(
      BuildContext context, {
        required String title,
        required Animation<int> animation,
        required IconData icon,
        required List<Color> gradient,
        bool isCurrency = false,
      }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: EdgeInsets.all(screenWidth < 600 ? 16 : 24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: screenWidth < 600 ? 24 : 32,
                color: Colors.white,
              ),
            ),
            SizedBox(width: screenWidth < 600 ? 12 : 20),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: screenWidth < 600 ? 14 : 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isCurrency ? '${animation.value}/-' : animation.value.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: screenWidth < 600 ? 24 : 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 600
            ? 3
            : 2;
        final childAspectRatio = constraints.maxWidth > 600 ? 1.2 : 1.0;

        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          children: [
            _buildCategoryItem(
              context,
              title: "Qualities",
              animation: _qualitiesAnimation,
              icon: Icons.auto_awesome_mosaic_rounded,
              color: const Color(0xFFFF6B6B),
            ),
            _buildCategoryItem(
              context,
              title: "Companies",
              animation: _companiesAnimation,
              icon: Icons.business_rounded,
              color: const Color(0xFF4ECDC4),
            ),
            _buildCategoryItem(
              context,
              title: "Vehicles",
              animation: _vehiclesAnimation,
              icon: Icons.local_shipping_rounded,
              color: const Color(0xFFFF9F43),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryItem(
      BuildContext context, {
        required String title,
        required Animation<int> animation,
        required IconData icon,
        required Color color,
      }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        padding: EdgeInsets.all(screenWidth < 600 ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: screenWidth < 600 ? 24 : 28,
                color: color,
              ),
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                color: const Color(0xFF6C757D),
                fontSize: screenWidth < 600 ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              animation.value.toString(),
              style: TextStyle(
                color: const Color(0xFF1A1A2F),
                fontSize: screenWidth < 600 ? 24 : 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}