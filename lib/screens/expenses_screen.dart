import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/expense.dart';
import '../utils/persian_date.dart';
import '../utils/constants.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Expense> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await DatabaseHelper.instance.getExpenses();
    if (mounted) {
      setState(() {
        _list = list;
        _loading = false;
      });
    }
  }

  Future<void> _showAddDialog() async {
    String category = AppConstants.expenseCategories.first;
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
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
                    const Text('ثبت هزینه جدید', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(labelText: 'دسته‌بندی'),
                      items: AppConstants.expenseCategories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setModalState(() => category = v!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'عنوان'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'مبلغ (ریال)'),
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
                        final amount = double.tryParse(amountCtrl.text.replaceAll(',', '')) ?? 0;
                        if (titleCtrl.text.isEmpty || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('عنوان و مبلغ را وارد کنید')),
                          );
                          return;
                        }
                        final e = Expense(
                          date: date,
                          category: category,
                          title: titleCtrl.text,
                          amount: amount,
                          notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                        );
                        await DatabaseHelper.instance.insertExpense(e);
                        if (mounted) {
                          Navigator.pop(context);
                          _load();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('هزینه ثبت شد')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('هزینه‌های جانبی')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('ثبت هزینه'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list.isEmpty
              ? const Center(child: Text('هنوز هزینه‌ای ثبت نشده'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _list.length,
                    itemBuilder: (ctx, i) {
                      final e = _list[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.receipt, size: 20),
                          ),
                          title: Text(e.title),
                          subtitle: Text('${e.date} • ${e.category}'),
                          trailing: Text(
                            '${e.amount.toStringAsFixed(0)} ریال',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                          onLongPress: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('حذف هزینه'),
                                content: const Text('آیا مطمئن هستید؟'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('خیر')),
                                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('بله')),
                                ],
                              ),
                            );
                            if (confirm == true && e.id != null) {
                              await DatabaseHelper.instance.deleteExpense(e.id!);
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
