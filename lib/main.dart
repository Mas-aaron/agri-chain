import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agri_chain/home_screen.dart';
import 'package:agri_chain/services/tflite_service.dart';
import 'package:agri_chain/providers/scan_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize TFLite service
  final tfliteService = TFLiteService();
  await tfliteService.initialize();
  
  runApp(
    MultiProvider(
      providers: [
        Provider<TFLiteService>(create: (_) => tfliteService),
        ChangeNotifierProvider(create: (_) => ScanProvider()),
      ],
      child: const MaizeDetectorApp(),
    ),
  );
}

class MaizeDetectorApp extends StatelessWidget {
  const MaizeDetectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '🌽 Maize Disease Detector',
      theme: ThemeData(
        primaryColor: Colors.green,
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
