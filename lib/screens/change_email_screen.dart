import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../services/api_service.dart';

/// Change email safely: (1) verify the CURRENT email, (2) enter the NEW email,
/// (3) verify the NEW email. Only then does the change happen.
class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});
  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _api = ApiService();
  final _codeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _step = 'start';
  String _current = '';
  String? _newEmail;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await _api.emailChangeState();
      if (mounted && r['success'] == true) {
        setState(() {
          _step = '${r['step']}';
          _current = '${r['email'] ?? ''}';
          _newEmail = r['new_email'] as String?;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _do(String action) async {
    setState(() => _busy = true);
    Map<String, dynamic> r;
    try {
      r = await _api.emailChange(action, code: _codeCtrl.text.trim(), email: _emailCtrl.text.trim());
    } catch (_) {
      r = {'success': false, 'message': 'Could not reach the server. Please check your connection.'};
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${r['message'] ?? ''}')));
    if (r['step'] != null) {
      setState(() {
        _step = '${r['step']}';
        _current = '${r['email'] ?? _current}';
        _newEmail = r['new_email'] as String?;
      });
    }
    _codeCtrl.clear();
    if (action == 'confirm' && r['success'] == true) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: const Text('Email changed'),
          content: Text('${r['message']}', textAlign: TextAlign.center),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    }
  }

  Widget _codeField() => TextField(
        controller: _codeCtrl,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: InputDecoration(labelText: tr('6-digit code'), border: const OutlineInputBorder()),
      );

  Widget _button(String label, VoidCallback onTap) => FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        onPressed: _busy ? null : onTap,
        child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(label),
      );

  Widget _stepBody() {
    switch (_step) {
      case 'verify_old':
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Step 1 of 3 — We sent a code to $_current. Enter it below.'),
          const SizedBox(height: 12),
          _codeField(),
          _button('Verify current email', () => _do('verify_old')),
          TextButton(onPressed: _busy ? null : () => _do('start'), child: const Text('Send a new code')),
        ]);
      case 'new_email':
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Step 2 of 3 — Enter your NEW email address. We will send a code to it.'),
          const SizedBox(height: 12),
          TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: tr('New email'), border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          _button('Send code to new email', () => _do('send_new')),
        ]);
      case 'confirm':
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Step 3 of 3 — We sent a code to $_newEmail. Enter it to finish.'),
          const SizedBox(height: 12),
          _codeField(),
          _button('Confirm new email', () => _do('confirm')),
          TextButton(onPressed: _busy ? null : () => _do('send_new'), child: const Text('Send a new code')),
        ]);
      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Your email is $_current.'),
          const SizedBox(height: 8),
          const Text('For your safety we first verify your current email, then your new one. Nothing changes until both are verified.'),
          const SizedBox(height: 16),
          _button('Send code to current email', () => _do('start')),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Email')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(20), children: [_stepBody()]),
    );
  }
}
