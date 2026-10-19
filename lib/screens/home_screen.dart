import 'package:flutter/material.dart';
import '../utils/home_navigation.dart';
import 'invoice_screen.dart';
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

  void _selectPage(BuildContext context, int index) {
    Navigator.pop(context);
    setState(() => _currentIndex = index);
  }

  ListTile _drawerItem(BuildContext context, int index, IconData icon, String label) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    selected: _currentIndex == index,
    onTap: () => _selectPage(context, index),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: homeScaffoldKey,
      drawer: Drawer(
        child: SafeArea(child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF1565C0)),
              child: Align(alignment: Alignment.bottomRight, child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.storefront, size: 38, color: Colors.white),
                  SizedBox(height: 8),
                  Text('HPLeila', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('مدیریت فروشگاه هیرکان پلاست', style: TextStyle(color: Colors.white)),
                ],
              )),
            ),
            _drawerItem(context, 0, Icons.dashboard_outlined, 'در یک نگاه'),
            _drawerItem(context, 1, Icons.swap_horiz, 'تراکنش‌ها'),
            _drawerItem(context, 2, Icons.inventory_2_outlined, 'موجودی انبار'),
            _drawerItem(context, 3, Icons.money_off_outlined, 'هزینه‌ها'),
            _drawerItem(context, 4, Icons.category_outlined, 'مدیریت کالاها'),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('فاکتورهای فروش'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InvoicesScreen()));
              },
            ),
            _drawerItem(context, 5, Icons.settings_outlined, 'تنظیمات'),
          ],
        )),
      ),
      floatingActionButton: _currentIndex == 0 ? FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InvoicesScreen())),
        icon: const Icon(Icons.receipt_long),
        label: const Text('فاکتور فروش'),
      ) : null,
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
