import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../currency.dart';
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
  String? _selectedProvider;
  Map<String, dynamic>? _selectedPlan;
  bool _loading = true;
  bool _busy = false;

  static const _providers = ['DSTV', 'GOTV', 'STARTIMES'];

  List<dynamic> get _plansForSelectedProvider =>
      _plans.where((p) => p['provider'] == _selectedProvider).toList();

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
      // Default to whichever provider actually has plans configured,
      // in the usual DSTV/GOTV/STARTIMES order.
      _selectedProvider = _providers.firstWhere(
        (p) => _plans.any((pl) => pl['provider'] == p),
        orElse: () => _providers.first,
      );
      final forProvider = _plans.where((p) => p['provider'] == _selectedProvider).toList();
      _selectedPlan = forProvider.isNotEmpty ? forProvider.first : null;
      _loading = false;
    });
  }

  void _onProviderChanged(String provider) {
    setState(() {
      _selectedProvider = provider;
      final forProvider = _plansForSelectedProvider;
      _selectedPlan = forProvider.isNotEmpty ? forProvider.first : null;
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
            // ---- STEP 1: pick provider, then package + smartcard, then verify ----
            const Text('Provider', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _providers.map((p) {
                final hasPlans = _plans.any((pl) => pl['provider'] == p);
                return ChoiceChip(
                  label: Text(p),
                  selected: _selectedProvider == p,
                  onSelected: hasPlans ? (_) => _onProviderChanged(p) : null,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Package', style: TextStyle(fontWeight: FontWeight.bold)),
            _plansForSelectedProvider.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No packages available for this provider yet.', style: TextStyle(color: Colors.black54)),
                  )
                : DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: _selectedPlan,
                    isExpanded: true,
                    items: _plansForSelectedProvider
                        .map<DropdownMenuItem<Map<String, dynamic>>>((p) => DropdownMenuItem(
                              value: p,
                              child: Text('${p['package_name']} (₦${nairaAmount(p['price'])})'),
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
                    Text('Amount: ₦${nairaAmount(_verification!['price'])}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
              child: _busy ? const CircularProgressIndicator() : Text('Confirm & Pay ₦${nairaAmount(_verification!['price'])}'),
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
