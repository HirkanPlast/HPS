import 'package:flutter/material.dart';
import '../utils/home_navigation.dart';
import '../database/database_helper.dart';
import '../models/product.dart';
import '../utils/constants.dart';
import '../utils/number_format.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await DatabaseHelper.instance.getAllProducts(activeOnly: false);
    if (mounted) {
      setState(() {
        _list = list;
        _loading = false;
      });
    }
  }

  Future<void> _showEditDialog([Product? existing]) async {
    final isEdit = existing != null;
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final unitCtrl = TextEditingController(text: existing?.unit ?? 'تعدادی');
    final initCtrl = TextEditingController(text: existing?.initialStock.toString() ?? '0');
    final minCtrl = TextEditingController(text: existing?.minStock.toString() ?? '0');
    final buyCtrl = TextEditingController(text: existing == null ? '0' : NumberFormatHelper.integer(existing.buyPrice));
    final sellCtrl = TextEditingController(text: existing == null ? '0' : NumberFormatHelper.integer(existing.sellPrice));
    String category = existing?.category ?? AppConstants.productCategories.last;

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
                    Text(isEdit ? 'ویرایش کالا' : 'افزودن کالای جدید',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(labelText: 'کد کالا (یکتا)'),
                      enabled: !isEdit,
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'نام کالا')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(labelText: 'دسته‌بندی'),
                      items: AppConstants.productCategories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setModalState(() => category = v!),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'واحد')),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: initCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'موجودی اولیه'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: minCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'حداقل موجودی'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: buyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'قیمت خرید (ریال)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: sellCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'قیمت فروش (ریال)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        if (codeCtrl.text.isEmpty || nameCtrl.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('کد و نام کالا الزامی است')),
                          );
                          return;
                        }
                        final p = Product(
                          id: existing?.id,
                          code: codeCtrl.text.trim(),
                          name: nameCtrl.text.trim(),
                          category: category,
                          unit: unitCtrl.text.trim().isEmpty ? 'تعدادی' : unitCtrl.text.trim(),
                          initialStock: double.tryParse(initCtrl.text) ?? 0,
                          minStock: double.tryParse(minCtrl.text) ?? 0,
                          buyPrice: double.tryParse(buyCtrl.text.replaceAll(',', '')) ?? 0,
                          sellPrice: double.tryParse(sellCtrl.text.replaceAll(',', '')) ?? 0,
                          isActive: existing?.isActive ?? true,
                        );
                        if (isEdit) {
                          await DatabaseHelper.instance.updateProduct(p);
                        } else {
                          await DatabaseHelper.instance.insertProduct(p);
                        }
                        if (mounted) {
                          Navigator.pop(context);
                          _load();
                        }
                      },
                      child: Text(isEdit ? 'ذخیره' : 'افزودن'),
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
      appBar: AppBar(leading: IconButton(tooltip: 'منوی اصلی', icon: const Icon(Icons.menu), onPressed: openHomeDrawer), title: const Text('مدیریت کالاها')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('کالای جدید'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: _list.length,
                itemBuilder: (ctx, i) {
                  final p = _list[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${p.code} • ${p.category} • ${p.unit}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _showEditDialog(p),
                      ),
                      onLongPress: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('حذف کالا'),
                            content: Text('کالای «${p.name}» حذف شود؟'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('خیر')),
                              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('بله')),
                            ],
                          ),
                        );
                        if (confirm == true && p.id != null) {
                          await DatabaseHelper.instance.deleteProduct(p.id!);
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
