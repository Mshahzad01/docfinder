import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/database/app_database.dart';
import 'domain/services/settings_service.dart';
import 'presentation/providers/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final db = await AppDatabase.open();
    final settings = await SettingsService.load();
    runApp(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        settingsServiceProvider.overrideWithValue(settings),
      ],
      child: const DocVaultApp(),
    ));
  } catch (e) {
    // Never crash silently: show what went wrong.
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(child: Text('DocVault could not start:\n$e', textAlign: TextAlign.center)),
      ),
    ));
  }
}
