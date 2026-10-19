import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/constants.dart';
import '../services/telegram_service.dart';
import '../services/backup_service.dart';
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
  final _tokenCtrl = TextEditingController();
  final _chatCtrl = TextEditingController();
  bool _autoBackup = true;
  String? _lastBackup;
  bool _saving = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await TelegramService.getBotToken();
    final chat = await TelegramService.getChatId();
    final auto = await BackupService.isAutoBackupEnabled();
    final last = await BackupService.getLastBackupTime();
    setState(() {
      _tokenCtrl.text = token ?? '';
      _chatCtrl.text = chat ?? '';
      _autoBackup = auto;
      _lastBackup = last;
    });
  }

  Future<void> _saveTelegram() async {
    setState(() => _saving = true);
    await TelegramService.saveCredentials(_tokenCtrl.text, _chatCtrl.text);
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تنظیمات تلگرام ذخیره شد')),
      );
    }
  }

  Future<void> _testTelegram() async {
    final ok = await TelegramService.sendMessage(
      '✅ تست اتصال از اپ فروشگاه هیرکان پلاست\nنسخه ${AppConstants.version}',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'پیام تست ارسال شد'
              : 'خطا در ارسال. توکن و چت‌آیدی را بررسی کنید'),
        ),
      );
    }
  }

  Future<void> _manualBackup() async {
    setState(() => _busy = true);
    final ok = await BackupService.performBackup(force: true);
    await _load();
    setState(() => _busy = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'بک‌آپ با موفقیت ارسال شد' : 'خطا در ارسال بک‌آپ')),
      );
    }
  }

  /// Export all app data to a local JSON file (separate from Telegram backup).
  Future<void> _localBackup() async {
    setState(() => _busy = true);
    try {
      final jsonStr = jsonEncode(await DatabaseHelper.instance.exportAllData());
      final bytes = utf8.encode(jsonStr);
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'ذخیره نسخه پشتیبان HPLeila',
        fileName: 'hpleila_backup_$stamp.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فایل پشتیبان ذخیره شد')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در تهیه نسخه پشتیبان: $e')),
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

  Future<void> _importProductCsv() async {
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
      if (rows.length < 2) throw Exception('فایل خالی است یا سرستون ندارد');

      final headers = rows.first.map((v) => v.trim().toLowerCase()).toList();
      final required = ['type', 'code', 'name', 'category', 'unit'];
      if (!required.every(headers.contains)) {
        throw Exception('سرستون‌های فایل با قالب مورد انتظار سازگار نیست');
      }
      final records = <Map<String, String>>[];
      for (final values in rows.skip(1)) {
        final map = <String, String>{};
        for (var i = 0; i < headers.length; i++) {
          map[headers[i]] = i < values.length ? values[i].trim() : '';
        }
        if (map['type']?.toLowerCase() == 'product' &&
            (map['code'] ?? '').isNotEmpty &&
            (map['name'] ?? '').isNotEmpty) {
          records.add(map);
        }
      }
      if (records.isEmpty) throw Exception('هیچ ردیف کالا در فایل پیدا نشد');

      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('وارد کردن کالاها'),
          content: Text(
            '${records.length} ردیف کالا شناسایی شد. کالاهای هم‌کد به‌روزرسانی می‌شوند و کالاهای جدید اضافه می‌شوند؛ اطلاعات فعلی حذف نمی‌شود.\n\nتراکنش‌های فایل فعلاً وارد نمی‌شوند، چون کد کالای مرتبط در ردیف‌ها وجود ندارد.\nادامه می‌دهید؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('وارد کردن'),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      setState(() => _busy = true);
      var added = 0;
      var updated = 0;
      var failed = 0;
      for (final row in records) {
        try {
          final code = row['code']!.trim();
          final existing = await DatabaseHelper.instance.getProductByCode(code);
          final product = Product(
            id: existing?.id,
            code: code,
            name: row['name']!.trim(),
            category: (row['category'] ?? '').trim(),
            unit: (row['unit'] ?? '').trim().isEmpty
                ? 'تعدادی'
                : row['unit']!.trim(),
            initialStock: _csvNumber(row, 'initial_stock'),
            minStock: _csvNumber(row, 'min_stock'),
            buyPrice: _csvNumber(row, 'purchase_price',
                fallback: _csvNumber(row, 'buy_price')),
            sellPrice: _csvNumber(row, 'sale_price',
                fallback: _csvNumber(row, 'sell_price')),
            isActive: true,
            notes: (row['notes'] ?? '').trim().isEmpty
                ? existing?.notes
                : row['notes']!.trim(),
          );
          if (existing == null) {
            await DatabaseHelper.instance.insertProduct(product);
            added++;
          } else {
            await DatabaseHelper.instance.updateProduct(product);
            updated++;
          }
        } catch (_) {
          failed++;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'واردات تمام شد: $added کالای جدید، $updated کالای به‌روزشده، $failed خطا. تراکنش‌ها وارد نشدند.',
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

                // Telegram
                Text('بک‌آپ تلگرام', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _tokenCtrl,
                  decoration: const InputDecoration(
                    labelText: 'توکن ربات تلگرام',
                    hintText: '123456:ABC-DEF...',
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _chatCtrl,
                  decoration: const InputDecoration(
                    labelText: 'شناسه چت (Chat ID)',
                    hintText: '-1001234567890 یا عددی',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveTelegram,
                        child: const Text('ذخیره'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _testTelegram,
                        child: const Text('تست ارسال'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('بک‌آپ روزانه خودکار'),
                  subtitle: Text(
                    _lastBackup != null
                        ? 'آخرین بک‌آپ: $_lastBackup'
                        : 'هنوز بک‌آپی گرفته نشده',
                  ),
                  value: _autoBackup,
                  onChanged: (v) async {
                    await BackupService.setAutoBackup(v);
                    setState(() => _autoBackup = v);
                  },
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _manualBackup,
                  icon: const Icon(Icons.backup),
                  label: const Text('بک‌آپ دستی الان'),
                ),
                const SizedBox(height: 24),

                // Data tools (available to both roles, but restore more careful)
                Text('داده و بازیابی', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined),
                  title: const Text('وارد کردن کالاها از CSV'),
                  subtitle: const Text('افزودن کالاهای جدید و به‌روزرسانی کدهای موجود'),
                  onTap: _importProductCsv,
                ),
                ListTile(
                  leading: const Icon(Icons.save_alt),
                  title: const Text('تهیه نسخه پشتیبان در گوشی'),
                  subtitle: const Text('ذخیره کالاها، تراکنش‌ها و هزینه‌ها در فایل JSON'),
                  onTap: _localBackup,
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
