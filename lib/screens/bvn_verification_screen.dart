import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../widgets/pin_field.dart';
import '../services/api_service.dart';
import 'identity_history_screen.dart';

class BvnVerificationScreen extends StatefulWidget {
  const BvnVerificationScreen({super.key});
  @override
  State<BvnVerificationScreen> createState() => _BvnVerificationScreenState();
}

class _BvnVerificationScreenState extends State<BvnVerificationScreen> {
  final _api = ApiService();
  final _bvnCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    final res = await _api.verifyBvn(bvn: _bvnCtrl.text.trim(), transactionPin: _pinCtrl.text);
    setState(() => _busy = false);
    if (!mounted) return;

    if (res['success'] == true) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Verification Result'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text('BVN: ${res['bvn']}'), Text('Name: ${res['full_name'] ?? '-'}'), Text('DOB: ${res['dob'] ?? '-'}')],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Verification failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BVN Verification'), actions: [
        IconButton(
          icon: const Icon(Icons.history),
          tooltip: tr('Verification History'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IdentityHistoryScreen())),
        ),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _bvnCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: tr('BVN Number (11 digits)'), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          PinField(controller: _pinCtrl),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy ? const CircularProgressIndicator() : const Text('Verify BVN'),
          ),
        ],
      ),
    );
  }
}
