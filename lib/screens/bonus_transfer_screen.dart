import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../currency.dart';
import '../services/api_service.dart';

class BonusTransferScreen extends StatefulWidget {
  const BonusTransferScreen({super.key});
  @override
  State<BonusTransferScreen> createState() => _BonusTransferScreenState();
}

class _BonusTransferScreenState extends State<BonusTransferScreen> {
  final _api = ApiService();
  final _amountCtrl = TextEditingController();
  double _bonusBalance = 0;
  double _minTransfer = 100;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.me();
    setState(() {
      _bonusBalance = res['success'] == true ? (res['user']['bonus_balance'] as num).toDouble() : 0;
      _minTransfer = res['success'] == true ? ((res['user']['bonus_transfer_min'] as num?)?.toDouble() ?? 100) : 100;
      _amountCtrl.text = _bonusBalance.toString();
      _loading = false;
    });
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final res = await _api.bonusTransfer(amount: double.tryParse(_amountCtrl.text) ?? 0);
    setState(() => _busy = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Done')));
    if (res['success'] == true) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Bonus Transfer')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bonus Balance'),
                  Text('₦${nairaAmount(_bonusBalance)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Bonuses credited by the admin (promos, rewards, etc.) show up here. Move them into your wallet to use for purchases.', style: TextStyle(fontSize: 12.5)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_bonusBalance >= _minTransfer) ...[
            Text('Minimum: ₦${nairaAmount(_minTransfer)}', style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
            const SizedBox(height: 6),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr('Amount'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy ? const CircularProgressIndicator() : const Text('Transfer to Wallet'),
            ),
          ] else if (_bonusBalance > 0)
            Text('The minimum you can move to your wallet is ₦${nairaAmount(_minTransfer)} — your bonus balance is below that.')
          else
            const Text("You don't have any bonus balance yet."),
        ],
      ),
    );
  }
}
