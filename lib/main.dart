import 'package:flutter/material.dart';
import 'theme/nautune_theme.dart';

void main() => runApp(const NautuneApp());

class NautuneApp extends StatelessWidget {
  const NautuneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nautune – Poseidon’s Music Player',
      theme: NautuneTheme.build(),
      debugShowCheckedModeBanner: false,
      home: const Scaffold(
        body: Center(
          child: Text('🌊 Nautune Booted Up!', style: TextStyle(fontSize: 26)),
        ),
      ),
    );
  }
}
