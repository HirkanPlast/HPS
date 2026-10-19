import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import '../utils/constants.dart';
import '../database/database_helper.dart';
import '../models/product.dart';
import '../app.dart';

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


  /// Import the ledger CSV exported from the user's accounting sheet.
  /// Product records are kept; only transactions and expenses are replaced.
  Future<void> _importLedgerCsv(List<List<String>> rows, List<String> headers) async {
    final transactions = <Map<String, dynamic>>[];
    final expenses = <Map<String, dynamic>>[];
    var productCodes = (await DatabaseHelper.instance.getAllProducts(activeOnly: false))
        .map((p) => p.code).toSet();
    if (productCodes.isEmpty) {
      final seedJson = await rootBundle.loadString('assets/seed_products.json');
      final seedRows = jsonDecode(seedJson) as List<dynamic>;
      await DatabaseHelper.instance.seedProducts(
        seedRows.map((item) => Map<String, dynamic>.from(item as Map)).toList(),
      );
      productCodes = (await DatabaseHelper.instance.getAllProducts(activeOnly: false))
          .map((p) => p.code).toSet();
    }
    final now = DateTime.now().toIso8601String();
    var salesCount = 0;
    var purchasesCount = 0;

    for (final values in rows.skip(1)) {
      final row = <String, String>{};
      for (var i = 0; i < headers.length; i++) {
        row[headers[i]] = i < values.length ? values[i].trim() : '';
      }
      final kind = (row['type'] ?? '').trim();
      final date = (row['date'] ?? '').trim();
      if (!RegExp(r'^\d{4}/\d{2}/\d{2}
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
      if (headers.contains('rowid') && headers.contains('totalrial') &&
          headers.contains('productcode') && headers.contains('unitpricerial')) {
        await _importLedgerCsv(rows, headers);
        return;
      }
      final required = ['type', 'code', 'name', 'category', 'unit',
        'initial_stock', 'min_stock', 'purchase_price', 'sale_price'];
      if (!required.every(headers.contains)) {
        throw Exception('سرستون‌های فایل با قالب کامل کالاها سازگار نیست');
      }

      final products = <Map<String, dynamic>>[];
      final transactions = <Map<String, dynamic>>[];
      final productCodes = <String>{};
      final transactionIds = <String>{};
      final now = DateTime.now().toIso8601String();

      for (final values in rows.skip(1)) {
        if (values.isEmpty) continue;
        final kind = values[0].trim().toLowerCase();
        if (kind == 'product') {
          final row = <String, String>{};
          for (var i = 0; i < headers.length; i++) {
            row[headers[i]] = i < values.length ? values[i].trim() : '';
          }
          final code = row['code'] ?? '';
          final name = row['name'] ?? '';
          if (code.isEmpty || name.isEmpty) {
            throw Exception('ردیف کالا بدون کد یا نام پیدا شد');
          }
          if (!productCodes.add(code)) {
            throw Exception('کد کالای تکراری در فایل: $code');
          }
          products.add({
            'code': code,
            'name': name,
            'category': row['category'] ?? '',
            'unit': (row['unit'] ?? '').isEmpty ? 'تعدادی' : row['unit'],
            'initial_stock': _csvNumber(row, 'initial_stock'),
            'min_stock': _csvNumber(row, 'min_stock'),
            'buy_price': _csvNumber(row, 'purchase_price'),
            'sell_price': _csvNumber(row, 'sale_price'),
            'is_active': 1,
            'notes': (row['notes'] ?? '').isEmpty ? null : row['notes'],
          });
        } else if (kind == 'transaction') {
          // Compact layout: transaction,source_id,,,Shamsi_date,type,quantity,unit_price,notes,product_code
          if (values.length < 10) {
            throw Exception('ردیف تراکنش ناقص است: ${values.join(',')}');
          }
          final sourceId = values[1].trim();
          final date = values[4].trim();
          final type = values[5].trim();
          final quantityText = values[6].trim();
          final priceText = values[7].trim();
          final notes = values[8].trim();
          final productCode = values[9].trim();
          if (sourceId.isEmpty || date.isEmpty || type.isEmpty ||
              quantityText.isEmpty || priceText.isEmpty || productCode.isEmpty) {
            throw Exception('اطلاعات ضروری تراکنش ناقص است: ${values.join(',')}');
          }
          if (!RegExp(r'^\d{4}/\d{2}/\d{2}$').hasMatch(date)) {
            throw Exception('تاریخ شمسی نامعتبر است: $date');
          }
          if (!{'ورود', 'فروش', 'برگشت', 'تعدیل'}.contains(type)) {
            throw Exception('نوع تراکنش ناشناخته است: $type');
          }
          final quantity = double.tryParse(quantityText.replaceAll(',', ''));
          final price = double.tryParse(priceText.replaceAll(',', ''));
          if (quantity == null || price == null || quantity < 0 || price < 0) {
            throw Exception('مقدار یا قیمت تراکنش نامعتبر است: ${values.join(',')}');
          }
          if (!transactionIds.add(sourceId)) {
            throw Exception('شناسه تراکنش تکراری در فایل: $sourceId');
          }
          transactions.add({
            'date': date,
            'type': type,
            'product_code': productCode,
            'quantity': quantity,
            'unit_price': price,
            'notes': notes.isEmpty ? null : notes,
            'created_by': null,
            'created_at': now,
          });
        }
      }

      if (products.isEmpty) throw Exception('هیچ کالایی در فایل پیدا نشد');
      if (transactions.isEmpty) throw Exception('هیچ تراکنشی در فایل پیدا نشد');
      final missingCodes = transactions
          .map((t) => t['product_code'] as String)
          .where((code) => !productCodes.contains(code))
          .toSet();
      if (missingCodes.isNotEmpty) {
        throw Exception('کد کالا برای این تراکنش‌ها در فایل وجود ندارد: ${missingCodes.join(', ')}');
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('جایگزینی کامل اطلاعات'),
          content: Text(
            '${products.length} کالا و ${transactions.length} تراکنش شناسایی شد.\n\n'
            'با تأیید، تمام کالاها، تراکنش‌ها و هزینه‌های فعلی برنامه پاک می‌شوند و فقط اطلاعات همین فایل باقی می‌ماند. '
            'این فایل ردیف هزینه ندارد؛ بنابراین هزینه‌های قبلی نیز حذف می‌شوند.\n\n'
            'تاریخ‌های شمسی و مقادیر اعشاری حفظ می‌شوند. ادامه می‌دهید؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('پاک‌کردن و جایگزینی'),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      setState(() => _busy = true);
      await DatabaseHelper.instance.importAllData({
        'products': products,
        'transactions': transactions,
        'expenses': <Map<String, dynamic>>[],
      }, clearFirst: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'جایگزینی موفق بود: ${products.length} کالا و ${transactions.length} تراکنش وارد شد؛ داده‌های قبلی و هزینه‌ها پاک شدند.',
            ),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در وارد کردن فایل: $e')),
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
                // Role info
                Card(
                  child: ListTile(
                    leading: Icon(
                      isManager ? Icons.admin_panel_settings : Icons.point_of_sale,
                    ),
                    title: Text(isManager ? 'نقش: مدیر' : 'نقش: فروشنده'),
                    subtitle: const Text('برای تغییر نقش دکمه زیر را بزنید'),
                    trailing: TextButton(
                      child: const Text('تغییر نقش'),
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove(AppConstants.keyRole);
                        if (mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const SplashWrapper()),
                            (_) => false,
                          );
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

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
