import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../currency.dart';
import '../widgets/pin_field.dart';
import '../widgets/service_picker.dart';
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
  double _minAmount = 50;
  double _maxAmount = 0; // 0 = no maximum
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
      if (res['success'] == true) {
        _minAmount = (res['min_amount'] as num?)?.toDouble() ?? 50;
        _maxAmount = (res['max_amount'] as num?)?.toDouble() ?? 0;
      }
      _loading = false;
    });
  }

  double get _ratePer100 {
    final n = _networks.firstWhere((n) => n['name'] == _selectedNetwork, orElse: () => null);
    return n == null ? 100.0 : (n['rate_per_100'] as num).toDouble();
  }

  bool get _amountInRange {
    final face = double.tryParse(_amountCtrl.text) ?? 0;
    if (face < _minAmount) return false;
    if (_maxAmount > 0 && face > _maxAmount) return false;
    return true;
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
          const StepLabel('Select Network'),
          ServiceGrid(
            names: _networks.map<String>((n) => '${n['name']}').toList(),
            selected: _selectedNetwork,
            onPick: (n) => setState(() => _selectedNetwork = n),
          ),
          if (_selectedNetwork != null) ...[
          const SizedBox(height: 22),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: tr('Phone Number'), hintText: tr('08012345678'), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: tr('Airtime Amount (₦)'),
              helperText: 'Min ₦${_minAmount.toStringAsFixed(0)}' + (_maxAmount > 0 ? ' — Max ₦${_maxAmount.toStringAsFixed(0)}' : ''),
              border: const OutlineInputBorder(),
            ),
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
                  Text('₦${nairaAmount(_charge)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting || _selectedNetwork == null || !_amountInRange ? null : () => _submit(),
            child: _submitting ? const CircularProgressIndicator() : const Text('Buy Airtime'),
          ),
          ],
        ],
      ),
    );
  }
}
