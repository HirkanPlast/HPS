import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/constants.dart';
import '../services/telegram_service.dart';
import '../services/backup_service.dart';
import '../database/database_helper.dart';
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

  /// Seed the 70 products from assets/seed_products.json
  Future<void> _seedProducts() async {
    final isEmpty = await DatabaseHelper.instance.isProductsEmpty();
    final clear = !isEmpty;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('وارد کردن کالاهای اولیه'),
        content: Text(
          isEmpty
              ? '۷۰ کالای فایل اکسل وارد شود؟'
              : 'دیتابیس خالی نیست.\nآیا می‌خواهید کالاهای فعلی پاک شوند و ۷۰ کالای اولیه جایگزین شوند؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('بله')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      final jsonStr = await rootBundle.loadString('assets/seed_products.json');
      final list = jsonDecode(jsonStr) as List;
      final products = list.cast<Map<String, dynamic>>();
      final count = await DatabaseHelper.instance.seedProducts(
        products,
        clearExisting: clear,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count کالا با موفقیت وارد شد')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در وارد کردن کالاها: $e')),
        );
      }
    }
    setState(() => _busy = false);
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
                  leading: const Icon(Icons.download),
                  title: const Text('وارد کردن ۷۰ کالای اولیه'),
                  subtitle: const Text('از فایل اکسل اصلی'),
                  onTap: _seedProducts,
                ),
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('بازیابی کامل از فایل JSON'),
                  subtitle: const Text('کالا + تراکنش + هزینه'),
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
