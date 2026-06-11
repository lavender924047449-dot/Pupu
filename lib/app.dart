import 'package:flutter/material.dart';
import 'package:pupu/core/theme.dart';
import 'package:pupu/features/home/home_screen.dart';

class PupuApp extends StatelessWidget {
  const PupuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pupu',
      theme: AppTheme.night,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
