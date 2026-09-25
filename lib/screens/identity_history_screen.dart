import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../services/api_service.dart';

class IdentityHistoryScreen extends StatefulWidget {
  const IdentityHistoryScreen({super.key});
  @override
  State<IdentityHistoryScreen> createState() => _IdentityHistoryScreenState();
}

class _IdentityHistoryScreenState extends State<IdentityHistoryScreen> {
  final _api = ApiService();
  List<dynamic>? _history;

  @override
  void initState() {
    super.initState();
    _api.identityHistory().then((res) => setState(() => _history = res['success'] == true ? res['history'] : []));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification History')),
      body: _history == null
          ? const Center(child: CircularProgressIndicator())
          : _history!.isEmpty
              ? const Center(child: Text("You haven't run any NIN or BVN verifications yet."))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history!.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (ctx, i) {
                    final h = _history![i];
                    final ok = h['status'] == 'successful';
                    return ListTile(
                      leading: Icon(ok ? Icons.check_circle : Icons.error, color: ok ? Colors.green : Colors.red),
                      title: Text('${h['type'].toString().toUpperCase()} — ${h['input_number']}'),
                      subtitle: Text('${h['full_name'] ?? '-'} • ₦${h['amount']} • ${h['created_at']}'),
                    );
                  },
                ),
    );
  }
}
