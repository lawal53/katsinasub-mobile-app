import 'package:flutter/material.dart';
import '../services/lock_service.dart';
import '../services/api_service.dart';
import '../main.dart' show rootNavigatorKey;
import 'login_screen.dart';

/// Full-screen PIN pad shown whenever [LockService.instance.locked] is
/// true — on cold app start (if the account has a transaction PIN) and
/// after 5 minutes in the background. Same PIN as the website.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  static const navy = Color(0xFF0B1E3D);
  static const emerald = Color(0xFF0F9D6B);

  final _lock = LockService.instance;
  String _pin = '';
  bool _checking = false;
  bool _biometricAvailable = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lock.biometricEnabled.then((enabled) {
      if (enabled && mounted) {
        setState(() => _biometricAvailable = true);
        _tryBiometric();
      }
    });
  }

  Future<void> _tryBiometric() async {
    final result = await _lock.unlockWithBiometric();
    if (!mounted) return;
    switch (result) {
      case BiometricUnlockResult.ok:
        break; // LockService already flipped `locked` to false
      case BiometricUnlockResult.invalidated:
        setState(() {
          _biometricAvailable = false;
          _error = 'An canza fingerprint akan wannan waya. Shigar da PIN, sannan a je Account Settings > Security don sake kunna fingerprint.';
        });
        break;
      case BiometricUnlockResult.canceled:
      case BiometricUnlockResult.error:
        break; // just let them type the PIN
    }
  }

  void _tapDigit(String d) {
    if (_pin.length >= 4 || _checking) return;
    setState(() { _pin += d; _error = null; });
    if (_pin.length == 4) _submit();
  }

  void _backspace() {
    if (_pin.isEmpty || _checking) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _checking = true);
    final ok = await _lock.verifyPin(_pin);
    if (!mounted) return;
    if (ok) {
      _lock.unlock();
    } else {
      setState(() { _checking = false; _pin = ''; _error = 'PIN ba daidai ba, sake gwada.'; });
    }
  }

  Future<void> _logoutInstead() async {
    await ApiService().logout();
    _lock.unlock(); // drop the overlay so the login screen underneath is visible
    rootNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: navy,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, color: emerald, size: 48),
                const SizedBox(height: 12),
                const Text('An kulle app din', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Shigar da PIN dinku don ci gaba', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _pin.length ? emerald : Colors.white24,
                    ),
                  )),
                ),
                if (_error != null) Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5), textAlign: TextAlign.center),
                ),
                const SizedBox(height: 28),
                if (_checking) const CircularProgressIndicator(color: emerald) else _buildKeypad(),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _logoutInstead,
                  child: const Text('Fita (Logout)', style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    final rows = [['1','2','3'], ['4','5','6'], ['7','8','9']];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final d in row) _key(d),
          ]),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _biometricAvailable
              ? _iconKey(Icons.fingerprint, _tryBiometric)
              : const SizedBox(width: 72, height: 72),
          _key('0'),
          _iconKey(Icons.backspace_outlined, _backspace),
        ]),
      ],
    );
  }

  Widget _key(String d) => Padding(
    padding: const EdgeInsets.all(6),
    child: SizedBox(
      width: 72, height: 72,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(shape: const CircleBorder(), backgroundColor: Colors.white10, foregroundColor: Colors.white),
        onPressed: () => _tapDigit(d),
        child: Text(d, style: const TextStyle(fontSize: 22)),
      ),
    ),
  );

  Widget _iconKey(IconData icon, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.all(6),
    child: SizedBox(
      width: 72, height: 72,
      child: IconButton(
        icon: Icon(icon, color: Colors.white70),
        onPressed: onTap,
      ),
    ),
  );
}
