import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../services/api_service.dart';

/// Handles both Email and Phone verification — same two-step flow
/// (send code, then confirm it), just pointed at different endpoints.
class VerifyContactScreen extends StatefulWidget {
  final String type; // 'email' or 'phone'
  const VerifyContactScreen({super.key, required this.type});

  @override
  State<VerifyContactScreen> createState() => _VerifyContactScreenState();
}

class _VerifyContactScreenState extends State<VerifyContactScreen> {
  final _api = ApiService();
  final _codeCtrl = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _message;

  bool get _isEmail => widget.type == 'email';

  Future<void> _send() async {
    setState(() => _busy = true);
    final res = _isEmail ? await _api.sendEmailVerification() : await _api.sendPhoneVerification();
    setState(() {
      _busy = false;
      _message = res['message'];
      if (res['success'] == true && res['already_verified'] != true) _codeSent = true;
    });
    if (res['already_verified'] == true && mounted) {
      Future.delayed(const Duration(seconds: 1), () => Navigator.pop(context));
    }
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    final res = _isEmail
        ? await _api.confirmEmailVerification(_codeCtrl.text.trim())
        : await _api.confirmPhoneVerification(_codeCtrl.text.trim());
    setState(() { _busy = false; _message = res['message']; });
    if (res['success'] == true && mounted) {
      Future.delayed(const Duration(seconds: 1), () => Navigator.pop(context, true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _isEmail ? 'Email' : 'Phone';
    return Scaffold(
      appBar: AppBar(title: Text('Verify $label')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_message != null) ...[
              Text(_message!, style: TextStyle(color: _message!.toLowerCase().contains('success') || _message!.toLowerCase().contains('sent') || _message!.toLowerCase().contains('already') ? Colors.green : Colors.red)),
              const SizedBox(height: 16),
            ],
            if (!_codeSent)
              FilledButton(
                onPressed: _busy ? null : _send,
                child: _busy ? const CircularProgressIndicator() : Text('Send Verification Code to $label'),
              )
            else ...[
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: tr('Enter code'), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _confirm,
                child: _busy ? const CircularProgressIndicator() : const Text('Confirm Code'),
              ),
              TextButton(onPressed: _busy ? null : _send, child: const Text('Resend code')),
            ],
          ],
        ),
      ),
    );
  }
}
