import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
  }

  Future<void> _load() async {
    final res = await _api.airtimeToCash();
    setState(() {
      _data = res;
      _network = res['success'] == true ? (res['networks'] as List).first : null;
    });
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final res = await _api.submitAirtimeToCash(
      network: _network!,
      amountSent: double.tryParse(_amountCtrl.text) ?? 0,
      senderPhone: _senderPhoneCtrl.text.trim(),
    );
    setState(() => _busy = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Done')));
    if (res['success'] == true) {
      _amountCtrl.clear();
      _senderPhoneCtrl.clear();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final requests = _data!['requests'] as List<dynamic>;

    return Scaffold(
      appBar: AppBar(title: const Text('Airtime to Cash')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('A ${_data!['discount_percent']}% discount applies. Send airtime to: ${_data!['send_to_number'] ?? '-'}'),
          const SizedBox(height: 16),
          const Text('Network', style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 8,
            children: (_data!['networks'] as List).map<Widget>((n) => ChoiceChip(
                  label: Text(n),
                  selected: _network == n,
                  onSelected: (_) => setState(() => _network = n),
                )).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Amount You'll Send (₦)", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _senderPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: "Number You'll Send From", hintText: '08012345678', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy || _network == null ? null : _submit,
            child: _busy ? const CircularProgressIndicator() : const Text('Submit Request'),
          ),
          const SizedBox(height: 24),
          const Text('Previous Requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ...requests.map((r) => Card(
                child: ListTile(
                  title: Text('${r['network']} — ₦${r['amount_sent']}'),
                  subtitle: Text('Payout: ₦${r['payout_amount']} • ${r['created_at']}'),
                  trailing: Text(r['status'], style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              )),
        ],
      ),
    );
  }
}
