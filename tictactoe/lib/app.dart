import 'package:flutter/material.dart';
import 'core/theme.dart'; // 👈 make sure this exists

class MyApp extends StatelessWidget {
  final Widget startScreen;
  const MyApp({super.key, required this.startScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tic Tac Toe',
      debugShowCheckedModeBanner: false,
      theme: appTheme, // 👈 use shared theme
      home: startScreen,
    );
  }
}
