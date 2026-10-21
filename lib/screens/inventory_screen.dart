import 'package:flutter/material.dart';
import '../utils/home_navigation.dart';
import '../database/database_helper.dart';
import '../models/product.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  String _filter = 'all'; // all, low, out

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await DatabaseHelper.instance.getInventory();
    if (mounted) {
      setState(() {
        _list = list;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'low') {
      return _list.where((e) => e['status'] == 'کمبود').toList();
    } else if (_filter == 'out') {
      return _list.where((e) => e['status'] == 'بدون موجودی').toList();
    }
    return _list;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'تأمین':
        return Colors.green;
      case 'کمبود':
        return Colors.orange;
      case 'بدون موجودی':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'منوی اصلی', icon: const Icon(Icons.menu), onPressed: openHomeDrawer),
        title: const Text('موجودی انبار'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'all', child: Text('همه')),
              PopupMenuItem(value: 'low', child: Text('کمبود')),
              PopupMenuItem(value: 'out', child: Text('بدون موجودی')),
            ],
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _filtered.isEmpty
                  ? const Center(child: Text('موردی یافت نشد'))
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final item = _filtered[i];
                        final p = item['product'] as Product;
                        final stock = item['current_stock'] as double;
                        final status = item['status'] as String;
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _statusColor(status).withOpacity(0.15),
                              child: Text(
                                status == 'تأمین'
                                    ? '🟢'
                                    : status == 'کمبود'
                                        ? '🟡'
                                        : '🔴',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${p.code} • ${p.category}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${stock.toStringAsFixed(stock == stock.roundToDouble() ? 0 : 2)} ${p.unit}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _statusColor(status),
                                  ),
                                ),
                                Text(
                                  status,
                                  style: TextStyle(fontSize: 11, color: _statusColor(status)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
