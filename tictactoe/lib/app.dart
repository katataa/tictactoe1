import 'package:flutter/material.dart';
import 'core/theme.dart';

class MyApp extends StatelessWidget {
  final Widget startScreen;
  const MyApp({super.key, required this.startScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tic Tac Toe',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: startScreen,
    );
  }
}
