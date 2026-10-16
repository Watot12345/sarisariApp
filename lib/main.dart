import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'data/db/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce portrait orientation for one-handed store counter usage (mobile)
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (_) {}

  // Run app immediately so the UI renders without blocking
  runApp(const TindahanApp());

  // Warm up SQLite database asynchronously in background
  AppDatabase.instance.database.then((_) {
    debugPrint('SQLite database initialized successfully');
  }).catchError((e) {
    debugPrint('Database initialization note (e.g. running on Web/Desktop): $e');
  });
}
