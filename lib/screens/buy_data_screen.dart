import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../currency.dart';
import '../purchase_result.dart';
import '../widgets/pin_field.dart';
import '../widgets/service_picker.dart';
import '../services/api_service.dart';

/// Buy Data — step by step, same as the website: pick a network, then a
/// plan type (SME, Gifting, ...), then a plan, and only then the phone
/// number, PIN and Buy button appear.
class BuyDataScreen extends StatefulWidget {
  const BuyDataScreen({super.key});
  @override
  State<BuyDataScreen> createState() => _BuyDataScreenState();
}

class _BuyDataScreenState extends State<BuyDataScreen> {
  final _api = ApiService();
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  List<dynamic> _plans = [];
  bool _loading = true;
  bool _busy = false;
  String? _network;
  String? _type;
  Map<String, dynamic>? _plan;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.dataPlans();
    if (!mounted) return;
    setState(() {
      _plans = res['success'] == true ? res['data_plans'] : [];
      _loading = false;
    });
  }

  List<String> get _networks {
    final seen = <String>[];
    for (final p in _plans) {
      final n = '${p['network']}';
      if (!seen.contains(n)) seen.add(n);
    }
    return seen;
  }

  List<String> get _types {
    final seen = <String>[];
    for (final p in _plans) {
      if ('${p['network']}' != _network) continue;
      final t = '${p['type']}';
      if (!seen.contains(t)) seen.add(t);
    }
    return seen;
  }

  // A network with only one plan type ("General") skips the type step.
  bool get _skipTypeStep {
    final t = _types;
    return t.length == 1 && t.first == 'General';
  }

  List<dynamic> get _visiblePlans =>
      _plans.where((p) => '${p['network']}' == _network && '${p['type']}' == _type).toList();

  void _pickNetwork(String n) {
    setState(() {
      _network = n;
      _plan = null;
      _type = _skipTypeStep ? 'General' : null;
    });
  }

  Future<void> _buy({bool confirmedMismatch = false}) async {
    final plan = _plan;
    if (plan == null) return;
    setState(() => _busy = true);
    Map<String, dynamic> res;
    try {
      res = await _api.buyData(
        planId: plan['id'],
        phone: _phoneCtrl.text.trim(),
        transactionPin: _pinCtrl.text,
        confirmedMismatch: confirmedMismatch,
      );
    } catch (e) {
      res = {'success': false, 'message': 'Could not reach the server. Please check your connection.'};
    }
    if (!mounted) return;
    setState(() => _busy = false);

    // The server replies with confirm_required=true when the phone number
    // looks like it belongs to a different network than the one selected
    // (e.g. a ported number) — same as the website: show the warning and let
    // the customer confirm to continue, or cancel and change the network.
    if (res['confirm_required'] == true) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 44),
          title: const Text('Network mismatch'),
          content: Text('${res['message'] ?? ''}', textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text("Yes, it's $_network")),
          ],
        ),
      );
      if (confirm == true && mounted) await _buy(confirmedMismatch: true);
      return;
    }

    await showPurchaseResult(context, res);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buy Data')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
              ? const Center(child: Text('No plans have been set up yet. Ask the admin to add some.'))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const StepLabel('Select Network'),
                    ServiceGrid(names: _networks, selected: _network, onPick: _pickNetwork),
                    if (_network != null && !_skipTypeStep) ...[
                      const SizedBox(height: 22),
                      const StepLabel('Plan Type'),
                      TypeChips(items: _types, selected: _type, onPick: (t) => setState(() { _type = t; _plan = null; })),
                    ],
                    if (_network != null && _type != null) ...[
                      const SizedBox(height: 22),
                      const StepLabel('Select Data Plan'),
                      for (final p in _visiblePlans)
                        PlanCard(
                          title: '${p['plan_name']} ${p['validity']}',
                          price: '₦${nairaAmount(p['price'])}',
                          selected: _plan != null && _plan!['id'] == p['id'],
                          onTap: () => setState(() => _plan = Map<String, dynamic>.from(p)),
                        ),
                    ],
                    if (_plan != null) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(labelText: tr('Phone Number'), hintText: tr('08012345678'), border: const OutlineInputBorder()),
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
                              Text('₦${nairaAmount(_plan!['price'])}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: _busy ? null : _buy,
                        child: _busy
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Buy Data'),
                      ),
                    ],
                  ],
                ),
    );
  }
}
