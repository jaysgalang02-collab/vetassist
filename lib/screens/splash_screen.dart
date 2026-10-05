import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/vet_theme.dart';
import '../widgets/brand_widgets.dart';

class SplashScreen extends StatefulWidget {
  static const route = '/splash';
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) Navigator.pushReplacementNamed(context, '/auth');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: VetTheme.forest,
        body: DecoratedBox(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [VetTheme.forest, Color(0xFF286A51)],
          )),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Entrance(
                  milliseconds: 700,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const BrandLogo(size: 108),
                    const SizedBox(height: 28),
                    Text('VetAssist',
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(color: Colors.white)),
                    const SizedBox(height: 10),
                    const Text('Care for every paw.',
                        style:
                            TextStyle(color: Color(0xFFD5EDDF), fontSize: 16)),
                    const SizedBox(height: 36),
                    const Icon(Icons.favorite_rounded,
                        color: Color(0xFFB7D7B6), size: 20),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}
