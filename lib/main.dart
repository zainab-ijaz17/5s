import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:five_s_digital_assessment/app.dart';
import 'package:five_s_digital_assessment/src/config/api_config.dart';
import 'package:five_s_digital_assessment/src/services/connectivity_service.dart';
import 'package:five_s_digital_assessment/src/services/sync_service.dart';
import 'package:five_s_digital_assessment/src/state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final appState = AppState();
    await appState.loadInitial();

    ConnectivityService.instance.addListener((online) {
      if (!online) return;
      SyncService.instance.scheduleSync(appState);
    });
    ConnectivityService.instance.startListening();

    debugPrint('API base URL: ${ApiConfig.baseUrl}');
    print('✅ AppState initialized successfully');

    runApp(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const MyApp(),
      ),
    );
  } catch (e, stackTrace) {
    print('❌ App initialization error: $e');
    print('Stack trace: $stackTrace');

    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('App initialization failed: $e'),
          ),
        ),
      ),
    );
  }
}