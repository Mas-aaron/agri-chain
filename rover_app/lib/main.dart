import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'rover/providers/rover_provider.dart';
import 'splash_screen.dart';

void main() {
  runApp(const MyApp());
  //  = false;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RoverProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ESP32 Rover',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
// Connect (initial + reconnect)
// Control (main driving + camera)
// Sensors (telemetry dashboard)
// Map/Nav (GPS-focused)
// Settings (gear icon, or extra tab)