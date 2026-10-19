import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/backup_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import '../utils/constants.dart';
import '../database/database_helper.dart';
import '../models/product.dart';

class SettingsScreen extends StatefulWidget {
  final String role;

  const SettingsScreen({super.key, required this.role});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  /// Share a JSON backup through Android's native share sheet.
  Future<void> _shareBackup() async {
    setState(() => _busy = true);
    try {
      final jsonStr = jsonEncode(await DatabaseHelper.instance.exportAllData());
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      await Share.shareXFiles(
        [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(jsonStr)),
            mimeType: 'application/json',
            name: 'hpleila_backup_$stamp.json',
          ),
        ],
        text: 'نسخه پشتیبان اطلاعات HPLeila',
        subject: 'نسخه پشتیبان HPLeila',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در آماده‌سازی نسخه پشتیبان: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }


  List<List<String>> _parseCsv(String input) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      if (ch == '"') {
        if (quoted && i + 1 < input.length && input[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (ch == ',' && !quoted) {
        row.add(field.toString());
        field = StringBuffer();
      } else if ((ch == '\n' || ch == '\r') && !quoted) {
        if (ch == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
        row.add(field.toString());
        if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
        row = <String>[];
        field = StringBuffer();
      } else {
        field.write(ch);
      }
    }
    row.add(field.toString());
    if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
    return rows;
  }

  double _csvNumber(Map<String, String> row, String key, {double fallback = 0}) {
    final value = (row[key] ?? '').trim().replaceAll(',', '');
    return double.tryParse(value) ?? fallback;
  }


  /// Import a ledger CSV while preserving the product catalogue.
  Future<void> _importLedgerCsv() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final bytes = picked.files.first.bytes;
      if (bytes == null) throw Exception('فایل قابل خواندن نیست');

      var csv = utf8.decode(bytes, allowMalformed: true);
      if (csv.startsWith('\uFEFF')) csv = csv.substring(1);
      final rows = _parseCsv(csv);
      if (rows.length < 2) throw Exception('فایل خالی است');

      final headers = rows.first.map((v) => v.trim().toLowerCase()).toList();
      final required = ['type', 'date'];
      if (!required.every(headers.contains)) {
        throw Exception('سرستون‌های فایل دفتر حسابداری قابل شناسایی نیست');
      }

      final products = await DatabaseHelper.instance.getAllProducts(activeOnly: false);
      var productCodes = products.map((p) => p.code).toSet();
      if (productCodes.isEmpty) {
        final seedJson = await rootBundle.loadString('assets/seed_products.json');
        final seedRows = jsonDecode(seedJson) as List<dynamic>;
        await DatabaseHelper.instance.seedProducts(
          seedRows.map((item) => Map<String, dynamic>.from(item as Map)).toList(),
        );
        productCodes = (await DatabaseHelper.instance.getAllProducts(activeOnly: false))
            .map((p) => p.code).toSet();
      }

      final transactions = <Map<String, dynamic>>[];
      final expenses = <Map<String, dynamic>>[];
      final seenLedgerRows = <String>{};
      final now = DateTime.now().toIso8601String();
      String value(Map<String, String> row, List<String> keys) {
        for (final key in keys) {
          final v = row[key];
          if (v != null && v.trim().isNotEmpty) return v.trim();
        }
        return '';
      }
      double number(String input) =>
          double.tryParse(input.replaceAll(',', '').replaceAll(' ', '')) ?? 0;

      for (final values in rows.skip(1)) {
        // Ignore exact duplicate CSV rows so repeated export lines are not counted twice.
        final rowSignature = values.map((v) => v.trim()).join('\\u001f');
        if (!seenLedgerRows.add(rowSignature)) continue;
        final row = <String, String>{};
        for (var i = 0; i < headers.length; i++) {
          row[headers[i]] = i < values.length ? values[i].trim() : '';
        }
        final kind = value(row, ['type', 'نوع', 'نوع تراکنش']);
        final date = value(row, ['date', 'تاریخ']);
        if (date.isEmpty) continue;
        if (!RegExp(r'^\d{4}/\d{2}/\d{2}$').hasMatch(date)) {
          throw Exception('تاریخ نامعتبر است: $date');
        }

        final code = value(row, ['productcode', 'product_code', 'code', 'کد کالا', 'کدکالا']);
        final qty = number(value(row, ['quantity', 'qty', 'تعداد', 'مقدار']));
        final unitPrice = number(value(row, ['unitpricerial', 'unit_price', 'unit price', 'قیمت واحد']));
        final total = number(value(row, ['totalrial', 'total', 'amount', 'مبلغ', 'مبلغ کل']));
        final name = value(row, ['title', 'name', 'شرح', 'عنوان', 'دسته', 'category']) ;
        final notes = value(row, ['notes', 'توضیحات', 'شرح']);

        // ADJ-1489 is a one-off invoice adjustment, not a stock product.
        // Import it as an expense so it never requires a matching product code.
        if (code.toUpperCase() == 'ADJ-1489') {
          expenses.add({
            'date': date,
            'category': 'تعدیل فاکتور خرید',
            'title': name.isEmpty ? 'تعدیل فاکتور ۱۴۸۹' : name,
            'amount': total != 0 ? total : unitPrice,
            'notes': notes.isEmpty ? null : notes,
            'created_at': now,
          });
          continue;
        }

        if (kind.toLowerCase() == 'expense' || kind == 'هزینه') {
          expenses.add({
            'date': date,
            'category': value(row, ['category', 'دسته', 'دسته‌بندی']).isEmpty ? 'سایر' : value(row, ['category', 'دسته', 'دسته‌بندی']),
            'title': name.isEmpty ? 'هزینه واردشده' : name,
            'amount': total != 0 ? total : unitPrice,
            'notes': notes.isEmpty ? null : notes,
            'created_at': now,
          });
          continue;
        }

        String type;
        if (kind.toLowerCase() == 'sale' || kind == 'فروش') {
          type = 'فروش';
        } else if (kind.toLowerCase() == 'purchase' || kind == 'خرید' || kind == 'ورود') {
          type = 'ورود';
        } else if (kind == 'برگشت' || kind.toLowerCase() == 'return') {
          type = 'برگشت';
        } else if (kind == 'تعدیل' || kind.toLowerCase() == 'adjustment') {
          type = 'تعدیل';
        } else {
          continue;
        }
        if (code.isEmpty || !productCodes.contains(code)) {
          throw Exception('کد کالای موجود در برنامه پیدا نشد: ${code.isEmpty ? '(خالی)' : code}');
        }
        transactions.add({
          'date': date,
          'type': type,
          'product_code': code,
          'quantity': qty,
          'unit_price': unitPrice != 0 ? unitPrice : (qty == 0 ? 0 : total / qty),
          'notes': notes.isEmpty ? null : notes,
          'created_by': null,
          'created_at': now,
        });
      }

      if (transactions.isEmpty && expenses.isEmpty) {
        throw Exception('هیچ خرید، فروشی یا هزینه قابل واردکردن پیدا نشد');
      }
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('واردکردن دفتر حسابداری'),
          content: Text(
            '${transactions.length} تراکنش و ${expenses.length} هزینه پس از حذف ردیف‌های تکراری پیدا شد. '
            'تراکنش‌ها و هزینه‌های فعلی جایگزین می‌شوند؛ فهرست کالاها حفظ می‌شود. '
            'برای جلوگیری از دوباره‌شماری، موجودی اولیهٔ پیش‌فرض کالاها صفر می‌شود؛ اگر موجودی افتتاحیهٔ دستی دارید، پیش از ادامه نسخهٔ پشتیبان بگیرید. ادامه می‌دهید؟',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
            TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('ادامه')),
          ],
        ),
      );
      if (confirm != true) return;

      setState(() => _busy = true);
      await DatabaseHelper.instance.importOperationalData(
        transactions: transactions,
        expenses: expenses,
        resetInitialStock: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('وارد شد: ${transactions.length} تراکنش و ${expenses.length} هزینه')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در واردکردن فایل: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Restore full backup from a JSON file picked by user
  Future<void> _restoreFromFile() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('بازیابی از فایل JSON'),
        content: const Text(
          'تمام داده‌های فعلی (کالاها، تراکنش‌ها و هزینه‌ها) پاک می‌شوند و با محتوای فایل جایگزین می‌شوند.\n\nآیا ادامه می‌دهید؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('بازیابی'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('نتوانستم فایل را بخوانم')),
          );
        }
        return;
      }

      setState(() => _busy = true);
      final jsonStr = utf8.decode(file.bytes!);
      final ok = await BackupService.restoreFromJsonString(jsonStr, clearFirst: true);
      setState(() => _busy = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? 'بازیابی با موفقیت انجام شد'
                : 'خطا در بازیابی. فرمت فایل را بررسی کنید'),
          ),
        );
      }
    } catch (e) {
      setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isManager = widget.role == 'manager';

    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 8),
                Text('نسخه پشتیبان', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  'فایل پشتیبان را با منوی اشتراک‌گذاری اندروید از طریق تلگرام، واتساپ، ایمیل یا برنامه‌های دیگر ارسال کنید.',
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _shareBackup,
                  icon: const Icon(Icons.share),
                  label: const Text('اشتراک‌گذاری نسخه پشتیبان'),
                ),
                const SizedBox(height: 24),

                // Data tools (available to both roles, but restore more careful)
                Text('داده و بازیابی', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined),
                  title: const Text('جایگزینی کامل اطلاعات از فایل CSV/TXT'),
                  subtitle: const Text('پاک‌کردن اطلاعات فعلی و واردکردن کالاها و تراکنش‌های فایل'),
                  onTap: _importLedgerCsv,
                ),
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: const Text('بازیابی از فایل پشتیبان'),
                  subtitle: const Text('جایگزینی داده‌های فعلی با فایل JSON'),
                  onTap: _restoreFromFile,
                ),
                if (isManager) ...[
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('درباره اپ'),
                    subtitle: Text(
                      'نسخه ${AppConstants.version}\nفروشگاه هیرکان پلاست (HPS)',
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                Text(
                  'ساخته شده برای هیرکان پلاست ❤️\nنسخه ${AppConstants.version}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
    );
  }
}
