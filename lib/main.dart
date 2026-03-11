import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:five_s_digital_assessment/app.dart';
import 'package:five_s_digital_assessment/src/state/app_state.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase FIRST
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Activate Firebase App Check
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
    );

    print('✅ Firebase initialized successfully');
    print('✅ App Check debug provider enabled');
  } catch (e, stackTrace) {
    print('Firebase initialization error: $e');
    print('Stack trace: $stackTrace');
  }

  try {
    final appState = AppState();
    await appState.loadInitial();

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