import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';

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
        // SizedBox(width: infinity) makes the Column span the full screen
        // width — without it the Column shrinks to its widest child and
        // sits at the left side instead of the centre.
        child: SizedBox(
          width: double.infinity,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
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
            Center(
              child: Image.asset(
                'assets/logo.png',
                width: 240, height: 240, fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 240, height: 240,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                  alignment: Alignment.center,
                  child: const Text('KS', style: TextStyle(color: navy, fontSize: 48, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Katsinasub', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const Spacer(flex: 4),
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text('Dev. By Ks. D. S. Ltd', style: TextStyle(color: Colors.white54, fontSize: 13), textAlign: TextAlign.center),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
