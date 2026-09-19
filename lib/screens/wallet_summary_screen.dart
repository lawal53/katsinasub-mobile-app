import 'package:flutter/material.dart';
import '../services/api_service.dart';

class WalletSummaryScreen extends StatefulWidget {
  const WalletSummaryScreen({super.key});
  @override
  State<WalletSummaryScreen> createState() => _WalletSummaryScreenState();
}

class _WalletSummaryScreenState extends State<WalletSummaryScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _api.walletSummary().then((res) => setState(() => _data = res));
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final txns = _data!['transactions'] as List<dynamic>;

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet Summary')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _statCard('Balance', _data!['wallet_balance'])),
              const SizedBox(width: 8),
              Expanded(child: _statCard('Funded', _data!['total_funded'])),
              const SizedBox(width: 8),
              Expanded(child: _statCard('Spent', _data!['total_spent'])),
            ],
          ),
          const SizedBox(height: 20),
          const Text('History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ...txns.map((t) => Card(
                child: ListTile(
                  title: Text(t['description']),
                  subtitle: Text(t['created_at']),
                  trailing: Text(
                    '${t['type'] == 'credit' ? '+' : '-'}₦${t['amount']}',
                    style: TextStyle(color: t['type'] == 'credit' ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _statCard(String label, dynamic value) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Text('₦$value', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
