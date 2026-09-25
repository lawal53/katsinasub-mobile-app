import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../widgets/pin_field.dart';
import '../purchase_result.dart';
import '../services/api_service.dart';

class CardPrintingScreen extends StatefulWidget {
  final String cardType; // 'recharge' or 'data'
  const CardPrintingScreen({super.key, required this.cardType});

  @override
  State<CardPrintingScreen> createState() => _CardPrintingScreenState();
}

class _CardPrintingScreenState extends State<CardPrintingScreen> {
  final _api = ApiService();
  final _qtyCtrl = TextEditingController(text: '1');
  final _pinCtrl = TextEditingController();

  List<dynamic> _plans = [];
  Map<String, dynamic>? _selectedPlan;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.cardPlans(cardType: widget.cardType);
    setState(() {
      _plans = res['success'] == true ? res['card_plans'] : [];
      _selectedPlan = _plans.isNotEmpty ? _plans.first : null;
      _loading = false;
    });
  }

  double get _total {
    if (_selectedPlan == null) return 0;
    return (_selectedPlan!['price'] as num).toDouble() * (int.tryParse(_qtyCtrl.text) ?? 1);
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final res = await _api.buyCard(
      cardType: widget.cardType,
      planId: _selectedPlan!['id'],
      quantity: int.tryParse(_qtyCtrl.text) ?? 1,
      transactionPin: _pinCtrl.text,
    );
    setState(() => _busy = false);
    if (!mounted) return;

    final pin = res['pin'];
    final shown = Map<String, dynamic>.from(res);
    if (pin is String && pin.isNotEmpty) {
      shown['message'] = '${res['message'] ?? 'Successful'}\nPIN(s): $pin';
    }
    await showPurchaseResult(context, shown);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.cardType == 'data' ? 'Data Card Printing' : 'Recharge Card Printing';
    if (_loading) return Scaffold(appBar: AppBar(title: Text(title)), body: const Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_plans.isEmpty)
            const Text('No plans have been set up yet. Ask the admin to add some.')
          else ...[
            const Text('Plan', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<Map<String, dynamic>>(
              initialValue: _selectedPlan,
              isExpanded: true,
              items: _plans.map<DropdownMenuItem<Map<String, dynamic>>>((p) => DropdownMenuItem(
                    value: p,
                    child: Text('${p['network']} - ${p['denomination']} (₦${p['price']})'),
                  )).toList(),
              onChanged: (v) => setState(() => _selectedPlan = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: tr('Quantity (how many cards)'), border: OutlineInputBorder()),
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
                  children: [const Text('Total'), Text('₦${_total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy ? const CircularProgressIndicator() : Text('Print ${widget.cardType == 'data' ? 'Data' : 'Recharge'} Card(s)'),
            ),
          ],
        ],
      ),
    );
  }
}
