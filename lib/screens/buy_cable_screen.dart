import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../widgets/pin_field.dart';
import '../purchase_result.dart';
import '../services/api_service.dart';

class BuyCableScreen extends StatefulWidget {
  const BuyCableScreen({super.key});
  @override
  State<BuyCableScreen> createState() => _BuyCableScreenState();
}

class _BuyCableScreenState extends State<BuyCableScreen> {
  final _api = ApiService();
  final _smartcardCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  List<dynamic> _plans = [];
  Map<String, dynamic>? _selectedPlan;
  bool _loading = true;
  bool _busy = false;

  // Set once verify-cable.php responds — this is what unlocks step 2.
  Map<String, dynamic>? _verification;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.cablePlans();
    setState(() {
      _plans = res['success'] == true ? res['cable_plans'] : [];
      _selectedPlan = _plans.isNotEmpty ? _plans.first : null;
      _loading = false;
    });
  }

  Future<void> _verify() async {
    if (_selectedPlan == null || _smartcardCtrl.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final res = await _api.verifyCable(planId: _selectedPlan!['id'], smartcard: _smartcardCtrl.text.trim());
    setState(() => _busy = false);
    if (res['success'] == true) {
      setState(() => _verification = res);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Verification failed')));
    }
  }

  Future<void> _pay() async {
    setState(() => _busy = true);
    final res = await _api.buyCable(
      planId: _verification!['plan_id'],
      smartcard: _smartcardCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
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
      appBar: AppBar(title: const Text('Cable TV')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_verification == null) ...[
            // ---- STEP 1: pick package + smartcard, then verify ----
            const Text('Package', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<Map<String, dynamic>>(
              initialValue: _selectedPlan,
              isExpanded: true,
              items: _plans
                  .map<DropdownMenuItem<Map<String, dynamic>>>((p) => DropdownMenuItem(
                        value: p,
                        child: Text('${p['provider']} — ${p['package_name']} (₦${p['price']})'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedPlan = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _smartcardCtrl,
              decoration: InputDecoration(labelText: tr('Smartcard/IUC Number'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _verify,
              child: _busy ? const CircularProgressIndicator() : const Text('Verify Name & Continue'),
            ),
          ] else ...[
            // ---- STEP 2: confirm name + amount, enter phone/PIN, pay ----
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
                        child: const Text('Could not verify name automatically — double check the smartcard number before paying.'),
                      ),
                    const SizedBox(height: 10),
                    Text('${_verification!['provider']} — ${_verification!['package_name']}'),
                    Text('Smartcard: ${_smartcardCtrl.text}'),
                    Text('Amount: ₦${_verification!['price']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
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
              child: _busy ? const CircularProgressIndicator() : Text('Confirm & Pay ₦${_verification!['price']}'),
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
