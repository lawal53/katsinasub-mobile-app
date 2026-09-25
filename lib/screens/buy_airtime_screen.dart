import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../widgets/pin_field.dart';
import '../purchase_result.dart';
import '../services/api_service.dart';

class BuyAirtimeScreen extends StatefulWidget {
  const BuyAirtimeScreen({super.key});
  @override
  State<BuyAirtimeScreen> createState() => _BuyAirtimeScreenState();
}

class _BuyAirtimeScreenState extends State<BuyAirtimeScreen> {
  final _api = ApiService();
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  List<dynamic> _networks = [];
  String? _selectedNetwork;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
    _amountCtrl.addListener(() => setState(() {}));
  }

  Future<void> _load() async {
    final res = await _api.networks();
    setState(() {
      _networks = res['success'] == true ? res['networks'] : [];
      _selectedNetwork = _networks.isNotEmpty ? _networks.first['name'] : null;
      _loading = false;
    });
  }

  double get _ratePer100 {
    final n = _networks.firstWhere((n) => n['name'] == _selectedNetwork, orElse: () => null);
    return n == null ? 100.0 : (n['rate_per_100'] as num).toDouble();
  }

  double get _charge {
    final face = double.tryParse(_amountCtrl.text) ?? 0;
    return (face * _ratePer100 / 100);
  }

  Future<void> _submit({bool confirmedMismatch = false}) async {
    setState(() => _submitting = true);
    final res = await _api.buyAirtime(
      network: _selectedNetwork!,
      phone: _phoneCtrl.text.trim(),
      amount: double.tryParse(_amountCtrl.text) ?? 0,
      transactionPin: _pinCtrl.text,
      confirmedMismatch: confirmedMismatch,
    );
    setState(() => _submitting = false);
    if (!mounted) return;

    // The API replies with confirm_required=true when the phone number's
    // detected network doesn't match what was selected (e.g. a ported
    // number). Show a confirm dialog and, if accepted, resend with
    // confirmedMismatch: true — same behaviour as the website.
    if (res['confirm_required'] == true) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Network mismatch'),
          content: Text(res['message'] ?? ''),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, it\'s correct')),
          ],
        ),
      );
      if (confirm == true) {
        await _submit(confirmedMismatch: true);
      }
      return;
    }

    await showPurchaseResult(context, res);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Buy Airtime')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Network', style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 8,
            children: _networks.map<Widget>((n) => ChoiceChip(
                  label: Text(n['name']),
                  selected: _selectedNetwork == n['name'],
                  onSelected: (_) => setState(() => _selectedNetwork = n['name']),
                )).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: tr('Phone Number'), hintText: tr('08012345678'), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: tr('Airtime Amount (₦)'), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          PinField(controller: _pinCtrl),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Amount to be deducted'),
                  Text('₦${_charge.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting || _selectedNetwork == null ? null : () => _submit(),
            child: _submitting ? const CircularProgressIndicator() : const Text('Buy Airtime'),
          ),
        ],
      ),
    );
  }
}
