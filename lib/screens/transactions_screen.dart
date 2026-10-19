import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/transaction.dart';
import '../models/product.dart';
import '../utils/persian_date.dart';
import '../utils/constants.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<InventoryTransaction> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await DatabaseHelper.instance.getTransactions(limit: 200);
    if (mounted) {
      setState(() {
        _list = list;
        _loading = false;
      });
    }
  }

  Future<void> _showAddDialog() async {
    final products = await DatabaseHelper.instance.getAllProducts();
    if (!mounted) return;

    String type = 'فروش';
    Product? selectedProduct;
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final date = PersianDateHelper.today();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('ثبت تراکنش جدید', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: const InputDecoration(labelText: 'نوع تراکنش'),
                      items: AppConstants.transactionTypes
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setModalState(() => type = v!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Product>(
                      value: selectedProduct,
                      decoration: const InputDecoration(labelText: 'کالا'),
                      isExpanded: true,
                      items: products
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text('${p.code} — ${p.name}', overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setModalState(() {
                          selectedProduct = v;
                          if (v != null && type == 'فروش') {
                            priceCtrl.text = v.sellPrice > 0 ? v.sellPrice.toStringAsFixed(0) : '';
                          } else if (v != null && type == 'ورود') {
                            priceCtrl.text = v.buyPrice > 0 ? v.buyPrice.toStringAsFixed(0) : '';
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: type == 'تعدیل' ? 'تعداد (مثبت یا منفی)' : 'تعداد',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'قیمت واحد (ریال)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'توضیحات (اختیاری)'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        if (selectedProduct == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('کالا را انتخاب کنید')),
                          );
                          return;
                        }
                        final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '')) ?? 0;
                        final price = double.tryParse(priceCtrl.text.replaceAll(',', '')) ?? 0;
                        if (qty == 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تعداد را وارد کنید')),
                          );
                          return;
                        }

                        // Warning for low stock on sale
                        if (type == 'فروش') {
                          final current = await DatabaseHelper.instance.getCurrentStock(selectedProduct!.code);
                          if (current < qty && mounted) {
                            final proceed = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('هشدار موجودی'),
                                content: Text(
                                  'موجودی فعلی ${current.toStringAsFixed(2)} ${selectedProduct!.unit} است.\n'
                                  'آیا ادامه می‌دهید؟',
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')),
                                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('ادامه')),
                                ],
                              ),
                            );
                            if (proceed != true) return;
                          }
                        }

                        final t = InventoryTransaction(
                          date: date,
                          type: type,
                          productCode: selectedProduct!.code,
                          quantity: qty,
                          unitPrice: price,
                          notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                          createdBy: 'user',
                        );
                        await DatabaseHelper.instance.insertTransaction(t);
                        if (mounted) {
                          Navigator.pop(context);
                          _load();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تراکنش ثبت شد')),
                          );
                        }
                      },
                      child: const Text('ثبت'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'ورود':
        return Colors.blue;
      case 'فروش':
        return Colors.green;
      case 'برگشت':
        return Colors.orange;
      case 'تعدیل':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تراکنش‌ها')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('ثبت تراکنش'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list.isEmpty
              ? const Center(child: Text('هنوز تراکنشی ثبت نشده'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _list.length,
                    itemBuilder: (ctx, i) {
                      final t = _list[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _typeColor(t.type).withOpacity(0.15),
                            child: Text(
                              t.type[0],
                              style: TextStyle(color: _typeColor(t.type), fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            t.productName ?? t.productCode,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('${t.date} • ${t.type} • ${t.quantity} ${t.unit ?? ''}'),
                          trailing: Text(
                            '${t.totalAmount.toStringAsFixed(0)} ریال',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onLongPress: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('حذف تراکنش'),
                                content: const Text('آیا مطمئن هستید؟'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('خیر')),
                                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('بله')),
                                ],
                              ),
                            );
                            if (confirm == true && t.id != null) {
                              await DatabaseHelper.instance.deleteTransaction(t.id!);
                              _load();
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
