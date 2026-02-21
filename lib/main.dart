import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'package:carplay/core/trip_manager.dart';
import 'package:carplay/models/location_point.dart';
import 'package:carplay/models/trip_data.dart';
import 'package:carplay/services/background_service.dart';
import 'package:carplay/ui/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Hive setup ────────────────────────────────────────────────────────────
  await Hive.initFlutter();

  // FIX: Guard adapter registration with isAdapterRegistered checks.
  // Without these guards, if Android restarts the isolate after 5+ hours
  // (low memory, battery saver, etc.) and main() runs again, Hive throws
  // "Adapter already registered" → Hive re-inits to a bad state → data lost.
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(LocationPointAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(TripDataAdapter());
  }

  await Hive.openBox<TripData>('trips');
  await Hive.openBox('settings');

  // FIX: Load persisted settings into TripState at launch.
  // Previously autoStart was never restored after an app restart.
  final settingsBox = Hive.box('settings');
  TripState.instance.autoStart =
      settingsBox.get('autoStart', defaultValue: false) as bool;

  // ── Background service ───────────────────────────────────────────────────
  await BackgroundServiceManager.initialize();

  // ── System UI ────────────────────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    ChangeNotifierProvider.value(
      value: TripState.instance,
      child: const CarPlayApp(),
    ),
  );
}

class CarPlayApp extends StatelessWidget {
  const CarPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarPlay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          surface: Color(0xFF12121E),
        ),
        fontFamily: 'SF Pro Display',
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
