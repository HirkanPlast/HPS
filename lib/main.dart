import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'app.dart';
import 'services/backup_service.dart';
import 'utils/constants.dart';
import 'utils/theme_controller.dart';

/// Background callback for daily backup
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await BackupService.performBackup();
      return true;
    } catch (_) {
      return false;
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Init WorkManager for daily backup
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  // Register daily backup task (runs approximately once a day)
  await Workmanager().registerPeriodicTask(
    'hps_daily_backup',
    'dailyBackup',
    frequency: const Duration(hours: 24),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );

  await AppThemeController.load();
  runApp(const HpsApp());
}
