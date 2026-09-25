import 'package:flutter/material.dart' hide Text;
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

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    final res = await _api.login(loginId: _loginIdCtrl.text.trim(), password: _passwordCtrl.text);
    setState(() => _loading = false);
    if (res['success'] == true) {
      try { await NotificationService().initAndRegister(); } catch (e) { /* push is optional */ }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardScreen()));
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
              const Text('Welcome back', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Log in with the same account you use on the website.'),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _loginIdCtrl,
                decoration: InputDecoration(labelText: tr('Email or Username'), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: tr('Password'), border: OutlineInputBorder()),
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
