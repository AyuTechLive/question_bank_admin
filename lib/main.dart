import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:question_bank/admin_dashboard.dart';

import 'package:question_bank/service/local_db.dart';
import 'package:window_manager/window_manager.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for Windows
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    //  size: Size(1400, 900), // Increased size for better layout
    center: true,
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.normal,
    title: 'Question Bank Admin Dashboard',
    minimumSize: Size(1200, 800),
  );

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Local Database
  try {
    final localDb = LocalDatabaseService();
    await localDb.database; // This initializes the database
    debugPrint('Local database initialized successfully');

    // Cleanup old records on startup
    await localDb.cleanupOldRecords();
  } catch (e) {
    debugPrint('Error initializing local database: $e');
  }

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Question Bank Admin',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        // Enhanced theme for better UI
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const AdminDashboard(),
    );
  }
}
