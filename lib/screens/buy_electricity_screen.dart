import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../currency.dart';
import '../widgets/pin_field.dart';
import '../widgets/service_picker.dart';
import '../purchase_result.dart';
import '../services/api_service.dart';

class BuyElectricityScreen extends StatefulWidget {
  const BuyElectricityScreen({super.key});
  @override
  State<BuyElectricityScreen> createState() => _BuyElectricityScreenState();
}

class _BuyElectricityScreenState extends State<BuyElectricityScreen> {
  final _api = ApiService();
  final _meterCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  List<dynamic> _discos = [];
  Map<String, dynamic> _charges = {};
  String? _selectedDisco;
  String _meterType = 'prepaid';
  bool _loading = true;
  bool _busy = false;

  Map<String, dynamic>? _verification;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.electricityDiscos();
    setState(() {
      _discos = res['success'] == true ? res['discos'] : [];
      _charges = res['success'] == true && res['charges'] is Map ? Map<String, dynamic>.from(res['charges']) : {};
      _loading = false;
    });
  }

  double _chargeFor(double amount) {
    final c = _charges[_verification?['disco'] ?? _selectedDisco];
    if (c == null) return 0;
    final pct = (c['percent'] as num?)?.toDouble() ?? 0;
    final cap = (c['cap'] as num?)?.toDouble() ?? 0;
    var fee = amount * pct / 100;
    if (cap > 0 && fee > cap) fee = cap;
    return fee;
  }

  String _chargeNote(double amount) {
    final c = _charges[_verification?['disco'] ?? _selectedDisco];
    final pct = (c?['percent'] as num?)?.toDouble() ?? 0;
    if (pct <= 0) return '';
    final cap = (c['cap'] as num?)?.toDouble() ?? 0;
    final fee = _chargeFor(amount);
    return 'Service charge: $pct%${cap > 0 ? ' (max ₦${cap.toStringAsFixed(0)})' : ''}'
        '${amount > 0 ? ' = ₦${nairaAmount(fee)} — Total ₦${nairaAmount(amount + fee)}' : ''}';
  }

  Future<void> _verify() async {
    if (_selectedDisco == null || _meterCtrl.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final res = await _api.verifyElectricity(
      disco: _selectedDisco!,
      meterType: _meterType,
      meterNumber: _meterCtrl.text.trim(),
    );
    setState(() => _busy = false);
    if (res['success'] == true) {
      setState(() => _verification = res);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Verification failed')));
    }
  }

  Future<void> _pay() async {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount < 500) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum electricity payment is ₦500.')));
      return;
    }
    setState(() => _busy = true);
    final res = await _api.buyElectricity(
      disco: _verification!['disco'],
      meterType: _verification!['meter_type'],
      meterNumber: _verification!['meter_number'],
      phone: _phoneCtrl.text.trim(),
      amount: amount,
      transactionPin: _pinCtrl.text,
    );
    setState(() => _busy = false);
    if (!mounted) return;
    await showPurchaseResult(context, res);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Electricity Bill')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_verification == null) ...[
            // ---- STEP 1: pick disco + meter, then verify ----
            const StepLabel('Select Disco'),
            ServiceGrid(
              names: _discos.map<String>((d) => '$d').toList(),
              selected: _selectedDisco,
              onPick: (d) => setState(() => _selectedDisco = d),
            ),
            if (_selectedDisco != null) ...[
            const SizedBox(height: 22),
            const StepLabel('Meter Type'),
            TypeChips(
              items: const ['prepaid', 'postpaid'],
              selected: _meterType,
              onPick: (t) => setState(() => _meterType = t),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _meterCtrl,
              decoration: InputDecoration(labelText: tr('Meter Number'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _verify,
              child: _busy ? const CircularProgressIndicator() : const Text('Verify Name & Continue'),
            ),
            ],
          ] else ...[
            // ---- STEP 2: confirm name, enter phone/amount/PIN, pay ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Confirm Before Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    if ((_verification!['verified_name'] as String).isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text('Customer Name: ${_verification!['verified_name']}'),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                        child: const Text('Could not verify name automatically — double check the meter number before paying.'),
                      ),
                    const SizedBox(height: 10),
                    Text('${_verification!['disco']} — ${_verification!['meter_type']}'),
                    Text('Meter: ${_verification!['meter_number']}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: tr('Amount (₦, min 500)'),
                helperText: _chargeNote(double.tryParse(_amountCtrl.text) ?? 0),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: tr('Phone Number'), hintText: tr('08012345678'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            PinField(controller: _pinCtrl),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _pay,
              child: _busy ? const CircularProgressIndicator() : const Text('Confirm & Pay'),
            ),
            TextButton(
              onPressed: () => setState(() => _verification = null),
              child: const Text('Go back'),
            ),
          ],
        ],
      ),
    );
  }
}
