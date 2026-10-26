import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// The first page a logged-out customer sees. Introduces the company,
/// then lets the customer pick Register or Login.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  static const navy = Color(0xFF0B1E3D);
  static const emerald = Color(0xFF0F9D6B);
  static const mint = Color(0xFF7EF0C3);

  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _point(IconData icon, String title, String sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.14)),
            ),
            child: Icon(icon, color: mint, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.68), fontSize: 12.5, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B1E3D), Color(0xFF0A3A47), Color(0xFF0B5A4A)],
          ),
        ),
        child: Stack(
          children: [
            // Soft decorative glows
            Positioned(
              top: -90, right: -70,
              child: Container(
                width: 260, height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: emerald.withOpacity(0.22),
                ),
              ),
            ),
            Positioned(
              bottom: -110, left: -80,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mint.withOpacity(0.10),
                ),
              ),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Align(
                                alignment: Alignment.center,
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                                  ),
                                  child: Image.asset(
                                    'assets/logo.png',
                                    width: 96, height: 96, fit: BoxFit.contain,
                                    errorBuilder: (c, e, s) => const SizedBox(
                                      width: 96, height: 96,
                                      child: Center(child: Text('KS', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold))),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              const Text(
                                'WELLCOME TO KATSINASUB',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 31,
                                  fontWeight: FontWeight.w900,
                                  height: 1.15,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: Container(
                                  width: 56, height: 4,
                                  decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Airtime, data, and bills — sorted in seconds.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 15, height: 1.35),
                              ),
                              const SizedBox(height: 22),
                              Container(
                                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                                ),
                                child: Column(
                                  children: [
                                    _point(Icons.verified_rounded, 'Registered company', 'RC 9716377 — a registered Nigerian company.'),
                                    _point(Icons.bolt_rounded, 'Fast & automatic', 'Airtime, data, cable TV, electricity, exam pins and more.'),
                                    _point(Icons.lock_rounded, 'Safe & secure', 'Your wallet is protected with your PIN and fingerprint.'),
                                    _point(Icons.support_agent_rounded, 'Real support', 'Reach a real support team, not a bot.'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 26),
                              SizedBox(
                                height: 54,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: mint,
                                    foregroundColor: navy,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                  ),
                                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                                  child: const Text('Register'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 54,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(color: Colors.white.withOpacity(0.7), width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                  ),
                                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                                  child: const Text('Login'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                                onPressed: () async { await showLanguagePicker(context); if (mounted) setState(() {}); },
                                icon: const Icon(Icons.language, size: 18),
                                label: const Text('Language'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
