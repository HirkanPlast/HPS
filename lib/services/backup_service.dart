import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../utils/constants.dart';
import '../utils/persian_date.dart';
import 'telegram_service.dart';

class BackupService {
  static Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyAutoBackup) ?? true;
  }

  static Future<void> setAutoBackup(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyAutoBackup, enabled);
  }

  static Future<String?> getLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyLastBackup);
  }

  /// Create backup JSON and send to Telegram
  static Future<bool> performBackup({bool force = false}) async {
    final enabled = await isAutoBackupEnabled();
    if (!enabled && !force) return false;

    try {
      final data = await DatabaseHelper.instance.exportAllData();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final bytes = utf8.encode(jsonStr);

      final today = PersianDateHelper.today().replaceAll('/', '-');
      final filename = 'HPS_Backup_$today.json';

      final caption = '''
📦 بک‌آپ فروشگاه هیرکان پلاست
📅 تاریخ: ${PersianDateHelper.today()}
📊 تعداد کالا: ${(data['products'] as List).length}
📝 تعداد تراکنش: ${(data['transactions'] as List).length}
💰 تعداد هزینه: ${(data['expenses'] as List).length}
نسخه اپ: ${AppConstants.version}
''';

      final success = await TelegramService.sendDocument(
        bytes: bytes,
        filename: filename,
        caption: caption,
      );

      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          AppConstants.keyLastBackup,
          DateTime.now().toIso8601String(),
        );
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  /// Restore from JSON map (full backup)
  static Future<bool> restoreFromJson(Map<String, dynamic> data, {bool clearFirst = true}) async {
    try {
      await DatabaseHelper.instance.importAllData(data, clearFirst: clearFirst);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Restore from raw JSON string
  static Future<bool> restoreFromJsonString(String jsonStr, {bool clearFirst = true}) async {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      return await restoreFromJson(data, clearFirst: clearFirst);
    } catch (_) {
      return false;
    }
  }

  /// Seed products from the built-in assets/seed_products.json
  static Future<int> seedInitialProducts({bool clearExisting = false}) async {
    try {
      // This will be loaded via rootBundle in the UI layer
      // Here we just provide the DB method wrapper
      return 0; // actual loading done in settings with rootBundle
    } catch (_) {
      return 0;
    }
  }
}
