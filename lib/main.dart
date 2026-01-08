import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:agri_chain/app_shell.dart';
import 'package:agri_chain/services/tflite_service.dart';
import 'package:agri_chain/providers/scan_provider.dart';
import 'package:agri_chain/providers/alerts_provider.dart';
import 'package:agri_chain/providers/fields_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    // Firebase initialized (optional for Hosting-only flows)
  } catch (e) {
    // Continue without Firebase if not configured
    // print('Firebase init failed: $e');
  }
  
  // Initialize TFLite service (do not block app startup on failure)
  final tfliteService = TFLiteService();
  try {
    await tfliteService.initialize();
  } catch (e) {
    // Continue to app UI; service can retry later when needed
  }
  
  runApp(
    MultiProvider(
      providers: [
        Provider<TFLiteService>(create: (_) => tfliteService),
        ChangeNotifierProvider(create: (_) => ScanProvider()),
        ChangeNotifierProvider(create: (_) => FieldsProvider()),
        ChangeNotifierProvider(create: (_) => AlertsProvider()),
      ],
      child: const MaizeDetectorApp(),
    ),
  );
}

class MaizeDetectorApp extends StatelessWidget {
  const MaizeDetectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2E7D32);
    const primaryLight = Color(0xFF4CAF50);
    const primaryDark = Color(0xFF1B5E20);
    const background = Color(0xFFF8F9FA);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: const Color(0xFF8BC34A),
      surface: Colors.white,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'AgriChain',
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: primary,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        fontFamily: 'Inter',
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primaryLight, width: 2),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: primary,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
        ),
        iconTheme: const IconThemeData(color: primaryDark),
      ),
      home: const AppShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}
