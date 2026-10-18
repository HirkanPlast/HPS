import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'فروشگاه هیرکان پلاست',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
        fontFamily: 'Vazirmatn', // Standard Persian font if available
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fa', 'IR')],
      locale: const Locale('fa', 'IR'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سیستم انبارداری هیرکان پلاست'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          DashboardTab(),
          InventoryTab(),
          TransactionsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'داشبورد'),
          NavigationDestination(icon: Icon(Icons.inventory), label: 'موجودی'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'تراکنش‌ها'),
        ],
      ),
    );
  }
}

// --- DASHBOARD TAB ---
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    double totalValue = 0;
    for (var p in appProducts) {
      // Calculate current stock roughly
      double stock = p.initialStock;
      for (var t in appTransactions) {
        if (t.productCode == p.code) {
          if (t.type == "ورود") stock += t.quantity;
          if (t.type == "فروش") stock -= t.quantity;
        }
      }
      totalValue += (stock > 0 ? stock : 0) * p.purchasePrice;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.green[100],
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const Text('ارزش کل انبار (خرید)', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text(
                  '${totalValue.toStringAsFixed(0)} تومان',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('کل کالاها'),
                      const SizedBox(height: 8),
                      Text('${appProducts.length}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('کل تراکنش‌ها'),
                      const SizedBox(height: 8),
                      Text('${appTransactions.length}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// --- INVENTORY TAB ---
class InventoryTab extends StatelessWidget {
  const InventoryTab({super.key});

  double getCurrentStock(String code, double initial) {
    double stock = initial;
    for (var t in appTransactions) {
      if (t.productCode == code) {
        if (t.type == "ورود") stock += t.quantity;
        if (t.type == "فروش") stock -= t.quantity;
      }
    }
    return stock;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: appProducts.length,
      itemBuilder: (context, index) {
        final p = appProducts[index];
        final currentStock = getCurrentStock(p.code, p.initialStock);
        final isLow = currentStock <= p.minStock;
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isLow ? Colors.red[100] : Colors.green[100],
              child: Icon(Icons.inventory_2, color: isLow ? Colors.red : Colors.green),
            ),
            title: Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: Text('کد: ${p.code} | ${p.unit}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(currentStock.toStringAsFixed(2), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isLow ? Colors.red : Colors.black)),
                Text(isLow ? 'کمبود' : 'تأمین', style: TextStyle(fontSize: 12, color: isLow ? Colors.red : Colors.green)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- TRANSACTIONS TAB ---
class TransactionsTab extends StatelessWidget {
  const TransactionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: appTransactions.length,
      itemBuilder: (context, index) {
        final t = appTransactions[index];
        final isSale = t.type == "فروش";
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: Icon(
              isSale ? Icons.arrow_upward : Icons.arrow_downward,
              color: isSale ? Colors.red : Colors.green,
            ),
            title: Text('کد: ${t.productCode} | ${t.type}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('تاریخ: ${t.date}\n${t.notes.isNotEmpty ? 'توضیح: ${t.notes}' : ''}'),
            isThreeLine: t.notes.isNotEmpty,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${t.quantity} عدد', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('${t.unitPrice.toStringAsFixed(0)} تومان', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }
}
