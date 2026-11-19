import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import '../services/pin_guard.dart';
import '../l10n.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _api = ApiService();
  final _loginIdCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  Future<void> _showSuccessAndEnter() async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF0F9D6B), size: 54),
            SizedBox(height: 12),
            Text('Login Successful', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text('Opening your account...', textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const DashboardScreen()), (r) => false);
    PinGuard.reset();
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    final res = await _api.login(loginId: _loginIdCtrl.text.trim(), password: _passwordCtrl.text);
    setState(() => _loading = false);
    if (res['success'] == true) {
      try { await NotificationService().initAndRegister(); } catch (e) { /* push is optional */ }
      await _showSuccessAndEnter();
    } else {
      setState(() => _error = res['message'] ?? 'Login failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0A1B36), Color(0xFF0B5A4A)]),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Welcome back', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                    SizedBox(height: 6),
                    Text('Log in with the same account you use on the website.', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFDECEC), borderRadius: BorderRadius.circular(14)),
                  child: Text(_error!, style: const TextStyle(color: Color(0xFFB3261E), fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _loginIdCtrl,
                decoration: InputDecoration(labelText: tr('Email, Username or Phone Number'), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: tr('Password'),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading ? const CircularProgressIndicator() : const Text('Login'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                child: const Text('Forgot password?'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: const Text("Don't have an account? Create one"),
              ),
              TextButton.icon(
                onPressed: () async { await showLanguagePicker(context); if (mounted) setState(() {}); },
                icon: const Icon(Icons.language),
                label: const Text('Language'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
