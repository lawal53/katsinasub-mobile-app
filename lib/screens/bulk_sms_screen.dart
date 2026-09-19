import 'package:flutter/material.dart';
import '../services/api_service.dart';

class BulkSmsScreen extends StatefulWidget {
  const BulkSmsScreen({super.key});
  @override
  State<BulkSmsScreen> createState() => _BulkSmsScreenState();
}

class _BulkSmsScreenState extends State<BulkSmsScreen> {
  final _api = ApiService();
  final _senderCtrl = TextEditingController();
  final _recipientsCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _busy = false;

  int get _recipientCount {
    final parts = _recipientsCtrl.text.trim().split(RegExp(r'[\s,]+'));
    final valid = parts.where((p) => RegExp(r'^0[789][01]\d{8}$').hasMatch(p));
    return valid.toSet().length;
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final res = await _api.buyBulkSms(
      senderId: _senderCtrl.text.trim(),
      message: _messageCtrl.text,
      recipients: _recipientsCtrl.text,
      transactionPin: _pinCtrl.text,
    );
    setState(() => _busy = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Done')));
    if (res['success'] == true) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bulk SMS')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _senderCtrl,
            maxLength: 11,
            decoration: const InputDecoration(labelText: 'Sender ID (optional)', border: OutlineInputBorder()),
          ),
          TextField(
            controller: _recipientsCtrl,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Phone Numbers (comma or newline separated)', hintText: '08012345678, 08087654321', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageCtrl,
            maxLines: 4,
            maxLength: 640,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
          ),
          TextField(
            controller: _pinCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Transaction PIN', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Text('Sending to $_recipientCount valid number(s)'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy ? const CircularProgressIndicator() : const Text('Send SMS'),
          ),
        ],
      ),
    );
  }
}
