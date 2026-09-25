import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../services/api_service.dart';
import 'receipt_screen.dart' show statusColor, statusLabel;

/// Airtime-to-Cash — same per-network discount, destination number and
/// live "you'll receive ₦X" hint as the website, plus the same request
/// history with status and admin notes.
class AirtimeToCashScreen extends StatefulWidget {
  const AirtimeToCashScreen({super.key});
  @override
  State<AirtimeToCashScreen> createState() => _AirtimeToCashScreenState();
}

class _AirtimeToCashScreenState extends State<AirtimeToCashScreen> {
  final _api = ApiService();
  final _amountCtrl = TextEditingController();
  final _senderPhoneCtrl = TextEditingController();

  Map<String, dynamic>? _data;
  String? _network;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    _amountCtrl.addListener(() => setState(() {}));
  }

  Future<void> _load() async {
    final res = await _api.airtimeToCash();
    if (!mounted) return;
    setState(() {
      _data = res;
      final nets = res['success'] == true ? (res['networks'] as List) : [];
      _network = nets.isNotEmpty ? nets.first as String : null;
    });
  }

  Map<String, dynamic>? get _networkCfg {
    final detail = (_data?['networks_detail'] as List<dynamic>?) ?? [];
    for (final n in detail) {
      if (n['network'] == _network) return Map<String, dynamic>.from(n);
    }
    return null;
  }

  double get _discountPercent => (_networkCfg?['discount_percent'] as num?)?.toDouble() ?? 0;
  String get _destination => '${_networkCfg?['destination_number'] ?? '-'}';

  double get _payout {
    final amt = double.tryParse(_amountCtrl.text) ?? 0;
    return amt > 0 ? amt * (1 - _discountPercent / 100) : 0;
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    Map<String, dynamic> res;
    try {
      res = await _api.submitAirtimeToCash(
        network: _network!,
        amountSent: double.tryParse(_amountCtrl.text) ?? 0,
        senderPhone: _senderPhoneCtrl.text.trim(),
      );
    } catch (e) {
      res = {'success': false, 'message': 'Could not reach the server. Please check your connection.'};
    }
    setState(() => _busy = false);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(res['success'] == true ? Icons.hourglass_top : Icons.error, color: res['success'] == true ? Colors.orange : Colors.red, size: 44),
        title: Text(res['success'] == true ? 'Request Received' : 'Failed'),
        content: Text('${res['message'] ?? ''}'),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
    if (res['success'] == true) {
      _amountCtrl.clear();
      _senderPhoneCtrl.clear();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_data!['success'] != true) {
      return Scaffold(appBar: AppBar(title: const Text('Airtime to Cash')), body: Center(child: Text('${_data!['message'] ?? 'Could not load.'}')));
    }
    final networks = (_data!['networks'] as List).cast<String>();
    final requests = _data!['requests'] as List<dynamic>;

    if (networks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Airtime to Cash')),
        body: const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Airtime to Cash is not available right now.'))),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Airtime to Cash')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Convert Airtime to Cash', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Send airtime to the number shown below and get paid to your wallet, minus the network\'s discount.', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 16),
          const Text('Network', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: networks.map<Widget>((n) => ChoiceChip(
                  label: Text(n),
                  selected: _network == n,
                  onSelected: (_) => setState(() => _network = n),
                )).toList(),
          ),
          const SizedBox(height: 12),
          if (_network != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4), borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Discount: ${_discountPercent.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Send to: $_destination', style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: tr("Amount You'll Send (₦)"), border: const OutlineInputBorder()),
          ),
          if (_amountCtrl.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text("You'll receive: ₦${_payout.toStringAsFixed(2)}", style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _senderPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: tr("Number You'll Send From"), hintText: '08012345678', border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy || _network == null ? null : _submit,
            child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Submit Request'),
          ),
          const SizedBox(height: 24),
          const Text('Previous Requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (requests.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('No requests yet.')),
          ...requests.map((r) {
            final status = '${r['status']}';
            return Card(
              child: ListTile(
                title: Text('${r['network']} — ₦${r['amount_sent']}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payout: ₦${r['payout_amount']} • Sent to: ${r['send_to_number'] ?? '-'}', style: const TextStyle(fontSize: 12)),
                    Text('${r['created_at']}', style: const TextStyle(fontSize: 11, color: Colors.black45)),
                    if (r['admin_note'] != null && '${r['admin_note']}'.isNotEmpty)
                      Text('${r['admin_note']}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                  ],
                ),
                isThreeLine: true,
                trailing: Text(statusLabel(status), style: TextStyle(fontWeight: FontWeight.bold, color: statusColor(status), fontSize: 12)),
              ),
            );
          }),
        ],
      ),
    );
  }
}
