import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../widgets/pin_field.dart';
import '../services/api_service.dart';
import 'identity_history_screen.dart';

class NinVerificationScreen extends StatefulWidget {
  const NinVerificationScreen({super.key});
  @override
  State<NinVerificationScreen> createState() => _NinVerificationScreenState();
}

class _NinVerificationScreenState extends State<NinVerificationScreen> {
  final _api = ApiService();
  final _ninCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  String _method = 'number';
  String _slipType = 'regular';
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    final res = await _api.verifyNin(method: _method, slipType: _slipType, nin: _ninCtrl.text.trim(), transactionPin: _pinCtrl.text);
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
            children: [
              Text('NIN: ${res['nin']}'),
              Text('Name: ${res['full_name'] ?? '-'}'),
              Text('DOB: ${res['dob'] ?? '-'}'),
            ],
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
      appBar: AppBar(title: const Text('NIN Verification'), actions: [
        IconButton(
          icon: const Icon(Icons.history),
          tooltip: tr('Verification History'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IdentityHistoryScreen())),
        ),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
            child: const Text(
              'By Phone Number: a charge still applies even if it fails (only the remainder is refunded). By NIN Number: full refund if it fails.',
              style: TextStyle(fontSize: 12.5),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Method', style: TextStyle(fontWeight: FontWeight.bold)),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'number', label: Text('By NIN')), ButtonSegment(value: 'phone', label: Text('By Phone'))],
            selected: {_method},
            onSelectionChanged: (s) => setState(() => _method = s.first),
          ),
          const SizedBox(height: 12),
          const Text('Slip Type', style: TextStyle(fontWeight: FontWeight.bold)),
          DropdownButtonFormField<String>(
            initialValue: _slipType,
            items: const [
              DropdownMenuItem(value: 'information', child: Text('Information')),
              DropdownMenuItem(value: 'regular', child: Text('Regular Slip')),
              DropdownMenuItem(value: 'standard', child: Text('Standard Slip')),
              DropdownMenuItem(value: 'premium', child: Text('Premium Slip')),
            ],
            onChanged: (v) => setState(() => _slipType = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ninCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: _method == 'phone' ? 'Phone Number' : 'NIN Number (11 digits)', border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          PinField(controller: _pinCtrl),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy ? const CircularProgressIndicator() : const Text('Verify NIN'),
          ),
        ],
      ),
    );
  }
}
