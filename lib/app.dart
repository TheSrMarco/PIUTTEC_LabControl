import 'package:flutter/material.dart';

import 'features/auth/presentation/auth_gate.dart';

class LabControlApp extends StatelessWidget {
  const LabControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PIUTTEC LabControl',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF078964)),
      ),
      home: const AuthGate(),
    );
  }
}
