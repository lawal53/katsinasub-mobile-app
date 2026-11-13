import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../currency.dart';
import '../services/api_service.dart';

class TransferLimitRequestScreen extends StatefulWidget {
  const TransferLimitRequestScreen({super.key});
  @override
  State<TransferLimitRequestScreen> createState() => _TransferLimitRequestScreenState();
}

class _TransferLimitRequestScreenState extends State<TransferLimitRequestScreen> {
  final _api = ApiService();
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  double _currentLimit = 0;
  List<dynamic> _requests = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.transferLimitRequests();
    if (!mounted) return;
    setState(() {
      if (res['success'] == true) {
        _currentLimit = (res['current_limit'] as num).toDouble();
        _requests = res['requests'];
      }
      _loading = false;
    });
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final res = await _api.requestTransferLimit(
      requestedLimit: double.tryParse(_amountCtrl.text) ?? 0,
      reason: _reasonCtrl.text.trim(),
    );
    setState(() => _busy = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${res['message'] ?? ''}')));
    if (res['success'] == true) {
      _amountCtrl.clear();
      _reasonCtrl.clear();
      _load();
    }
  }

  Color _statusColor(String s) => s == 'approved' ? Colors.green : (s == 'rejected' ? Colors.red : Colors.orange);

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Request Transfer Limit Increase')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Your current daily limit: ₦${nairaAmount(_currentLimit)}', style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: tr('Requested Limit (₦)'), border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            decoration: InputDecoration(labelText: tr('Reason (optional)'), border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy ? const CircularProgressIndicator() : const Text('Send Request'),
          ),
          const SizedBox(height: 24),
          const Text('Your Requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_requests.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('No requests yet.')),
          ...(_requests.map((r) => Card(
                child: ListTile(
                  title: Text('₦${nairaAmount(r['requested_limit'])}'),
                  subtitle: Text('${r['created_at']}' + (r['admin_note'] != null && '${r['admin_note']}'.isNotEmpty ? '\n${r['admin_note']}' : ''), style: const TextStyle(fontSize: 12)),
                  isThreeLine: r['admin_note'] != null && '${r['admin_note']}'.isNotEmpty,
                  trailing: Text('${r['status']}'.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _statusColor('${r['status']}'))),
                ),
              ))),
        ],
      ),
    );
  }
}
