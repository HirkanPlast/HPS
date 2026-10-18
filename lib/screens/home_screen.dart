import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'transactions_screen.dart';
import 'inventory_screen.dart';
import 'expenses_screen.dart';
import 'products_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final String role; // 'seller' or 'manager'

  const HomeScreen({super.key, required this.role});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages;
  late final List<BottomNavigationBarItem> _items;

  @override
  void initState() {
    super.initState();
    final isManager = widget.role == 'manager';

    _pages = [
      const DashboardScreen(),
      const TransactionsScreen(),
      const InventoryScreen(),
      const ExpensesScreen(),
      if (isManager) const ProductsScreen(),
      SettingsScreen(role: widget.role),
    ];

    _items = [
      const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'در یک نگاه'),
      const BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: 'تراکنش'),
      const BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'موجودی'),
      const BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'هزینه‌ها'),
      if (isManager) const BottomNavigationBarItem(icon: Icon(Icons.category), label: 'کالاها'),
      const BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'تنظیمات'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        items: _items,
      ),
    );
  }
}
