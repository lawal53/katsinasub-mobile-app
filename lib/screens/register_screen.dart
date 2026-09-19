import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _api = ApiService();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    final res = await _api.register(
      fullName: _fullName.text.trim(),
      username: _username.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
      confirmPassword: _confirm.text,
    );
    setState(() => _loading = false);
    if (res['success'] == true) {
      try { await NotificationService().initAndRegister(); } catch (e) { /* push is optional */ }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardScreen()));
    } else {
      setState(() => _error = res['message'] ?? 'Registration failed.');
    }
  }

  Widget _field(TextEditingController c, String label, {bool obscure = false, TextInputType? type}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          obscureText: obscure,
          keyboardType: type,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],
            _field(_fullName, 'Full Name'),
            _field(_username, 'Username'),
            _field(_phone, 'Phone Number', type: TextInputType.phone),
            _field(_email, 'Email', type: TextInputType.emailAddress),
            _field(_password, 'Password', obscure: true),
            _field(_confirm, 'Confirm Password', obscure: true),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading ? const CircularProgressIndicator() : const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }
}
