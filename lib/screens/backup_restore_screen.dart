import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import '../services/backup_service.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});
  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _busy = false;

  Future<void> _shareBackup() async {
    setState(() => _busy = true);
    try {
      final jsonStr = jsonEncode(await DatabaseHelper.instance.exportAllData());
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      await Share.shareXFiles([
        XFile.fromData(Uint8List.fromList(utf8.encode(jsonStr)),
          mimeType: 'application/json', name: 'hpleila_backup_$stamp.json'),
      ], text: 'نسخه پشتیبان اطلاعات HPLeila', subject: 'نسخه پشتیبان HPLeila');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا در آماده‌سازی نسخه پشتیبان: $e')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _restore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('بازیابی از فایل پشتیبان'),
        content: const Text('اطلاعات فعلی با محتوای فایل جایگزین می‌شود. پیش از ادامه مطمئن شوید نسخهٔ پشتیبان فعلی را دارید. ادامه می‌دهید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('ادامه')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.first.bytes;
      if (bytes == null) throw Exception('فایل قابل خواندن نیست');
      setState(() => _busy = true);
      final ok = await BackupService.restoreFromJsonString(utf8.decode(bytes), clearFirst: true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'بازیابی با موفقیت انجام شد' : 'بازیابی انجام نشد؛ فرمت فایل را بررسی کنید')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا در بازیابی: $e')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('پشتیبان‌گیری و بازیابی')),
    body: _busy ? const Center(child: CircularProgressIndicator()) : ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Icon(Icons.cloud_sync_outlined, size: 56),
        const SizedBox(height: 12),
        Text('از اطلاعات فروشگاه محافظت کنید', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('فایل پشتیبان شامل اطلاعات ذخیره‌شدهٔ برنامه است. آن را در جای امن نگه دارید و پیش از بازیابی، از اطلاعات فعلی نیز پشتیبان بگیرید.'),
        const SizedBox(height: 24),
        FilledButton.icon(onPressed: _shareBackup, icon: const Icon(Icons.backup_outlined), label: const Text('ساخت و اشتراک‌گذاری نسخه پشتیبان')),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: _restore, icon: const Icon(Icons.restore), label: const Text('بازیابی از فایل JSON')),
      ],
    ),
  );
}