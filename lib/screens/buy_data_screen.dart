import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../currency.dart';
import '../purchase_result.dart';
import '../widgets/pin_field.dart';
import '../services/api_service.dart';

/// Buy Data — same flow as the website: pick a network, then a plan
/// type (SME, Gifting, ...), then one of the plans under that type.
class BuyDataScreen extends StatefulWidget {
  const BuyDataScreen({super.key});
  @override
  State<BuyDataScreen> createState() => _BuyDataScreenState();
}

class _BuyDataScreenState extends State<BuyDataScreen> {
  final _api = ApiService();
  List<dynamic> _plans = [];
  bool _loading = true;
  String? _network;
  String? _type;

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
      final nets = _networks;
      _network = nets.isNotEmpty ? nets.first : null;
      _type = null;
      _selectFirstType();
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

  void _selectFirstType() {
    final t = _types;
    _type = t.isNotEmpty ? t.first : null;
  }

  List<dynamic> get _visiblePlans =>
      _plans.where((p) => '${p['network']}' == _network && '${p['type']}' == _type).toList();

  void _openBuySheet(Map<String, dynamic> plan) {
    final phoneCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    bool busy = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${plan['network']} — ${plan['plan_name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('₦${nairaAmount(plan['price'])} • ${plan['validity']}'),
              const SizedBox(height: 16),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: tr('Recipient phone'), border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              PinField(controller: pinCtrl),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        setSheet(() => busy = true);
                        Map<String, dynamic> res;
                        try {
                          res = await _api.buyData(planId: plan['id'], phone: phoneCtrl.text.trim(), transactionPin: pinCtrl.text);
                        } catch (e) {
                          res = {'success': false, 'message': 'Could not reach the server. Please check your connection.'};
                        }
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        await showPurchaseResult(context, res);
                      },
                child: busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Confirm Purchase'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chips(List<String> items, String? selected, void Function(String) onPick) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final it in items)
          ChoiceChip(
            label: Text(it),
            selected: it == selected,
            onSelected: (_) => onPick(it),
          ),
      ],
    );
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
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text('Network', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _chips(_networks, _network, (n) => setState(() { _network = n; _selectFirstType(); })),
                    const SizedBox(height: 16),
                    const Text('Plan Type', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _chips(_types, _type, (t) => setState(() => _type = t)),
                    const SizedBox(height: 16),
                    const Text('Plans', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    for (final p in _visiblePlans)
                      Card(
                        child: ListTile(
                          title: Text('${p['plan_name']}'),
                          subtitle: Text('${p['validity']}'),
                          trailing: Text('₦${nairaAmount(p['price'])}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          onTap: () => _openBuySheet(Map<String, dynamic>.from(p)),
                        ),
                      ),
                  ],
                ),
    );
  }
}
