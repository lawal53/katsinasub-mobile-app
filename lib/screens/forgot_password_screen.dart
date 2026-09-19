import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _api = ApiService();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _message;

  Future<void> _sendCode() async {
    setState(() => _busy = true);
    final res = await _api.forgotPassword(email: _emailCtrl.text.trim());
    setState(() {
      _busy = false;
      _codeSent = true; // always advance — the API never reveals whether the email exists
      _message = res['message'];
    });
  }

  Future<void> _reset() async {
    setState(() => _busy = true);
    final res = await _api.resetPassword(
      email: _emailCtrl.text.trim(),
      code: _codeCtrl.text.trim(),
      password: _passwordCtrl.text,
      confirmPassword: _confirmCtrl.text,
    );
    setState(() { _busy = false; _message = res['message']; });
    if (res['success'] == true && mounted) {
      Future.delayed(const Duration(seconds: 1), () => Navigator.pop(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_message != null) ...[
              Text(_message!, style: TextStyle(color: _message!.contains('reset') || _message!.contains('sent') ? Colors.green : Colors.red)),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _emailCtrl,
              enabled: !_codeSent,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            if (!_codeSent)
              FilledButton(
                onPressed: _busy ? null : _sendCode,
                child: _busy ? const CircularProgressIndicator() : const Text('Send Reset Code'),
              )
            else ...[
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Code from email', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm New Password', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _reset,
                child: _busy ? const CircularProgressIndicator() : const Text('Reset Password'),
              ),
              TextButton(onPressed: () => setState(() => _codeSent = false), child: const Text('Use a different email')),
            ],
          ],
        ),
      ),
    );
  }
}
