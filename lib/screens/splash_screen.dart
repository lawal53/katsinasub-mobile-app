import 'package:flutter/material.dart';

/// The first thing anyone sees when opening the app. Shows for a
/// couple of seconds with the brand mark, then calls [onFinished] to
/// move on to the real startup logic (checking if already logged in).
class SplashScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const SplashScreen({super.key, required this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const navy = Color(0xFF0B1E3D);
  static const emerald = Color(0xFF0F9D6B);

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), widget.onFinished);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            // Uses assets/logo.png if you've added it (see pubspec.yaml
            // "assets:" section and README) — falls back to a plain
            // "KS" mark automatically if that file isn't there yet, so
            // the app never crashes over a missing image.
            // fit: BoxFit.contain (not cover) + no corner rounding on the
            // image itself, so the full logo artwork always shows —
            // cover + a large border radius was clipping the design's
            // corner details.
            Image.asset(
              'assets/logo.png',
              width: 110, height: 110, fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 110, height: 110,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                alignment: Alignment.center,
                child: const Text('KS', style: TextStyle(color: navy, fontSize: 34, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Katsinasub', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const Spacer(flex: 4),
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text('Dev. By Ks. D. S. Ltd', style: TextStyle(color: Colors.white54, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
