import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../currency.dart';
import '../services/api_service.dart';
import 'receipt_screen.dart';

/// Wallet Summary + Transaction History — same numbers, category filter
/// and paging as the website. Tap any transaction to open its receipt.
class WalletSummaryScreen extends StatefulWidget {
  const WalletSummaryScreen({super.key});
  @override
  State<WalletSummaryScreen> createState() => _WalletSummaryScreenState();
}

class _WalletSummaryScreenState extends State<WalletSummaryScreen> {
  final _api = ApiService();
  static const _categories = <String, String>{
    'all': 'All',
    'data': 'Data',
    'airtime': 'Airtime',
    'electricity': 'Electricity',
    'cable': 'Cable TV',
    'sms': 'Bulk SMS',
    'exam': 'Exam Pins',
    'rcard': 'Recharge Card',
    'dcard': 'Data Card',
    'identity': 'NIN/BVN',
    'wallet': 'Wallet Funding',
  };

  String _category = 'all';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  double _balance = 0, _funded = 0, _spent = 0;
  final List<dynamic> _txns = [];
  int _page = 1;
  int _totalPages = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() { _loading = true; _error = null; _page = 1; _txns.clear(); });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final res = await _api.walletSummary(page: reset ? 1 : _page + 1, category: _category, q: _searchQuery);
      if (!mounted) return;
      if (res['success'] != true) {
        setState(() { _error = '${res['message'] ?? 'Could not load history.'}'; _loading = false; _loadingMore = false; });
        return;
      }
      setState(() {
        _balance = (res['wallet_balance'] as num).toDouble();
        _funded = (res['total_funded'] as num).toDouble();
        _spent = (res['total_spent'] as num).toDouble();
        _page = res['page'] as int;
        _totalPages = res['total_pages'] as int;
        _txns.addAll(res['transactions'] as List<dynamic>);
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Could not load history.'; _loading = false; _loadingMore = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet Summary')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(child: _statCard('Balance', _balance)),
                      const SizedBox(width: 8),
                      Expanded(child: _statCard('Funded', _funded)),
                      const SizedBox(width: 8),
                      Expanded(child: _statCard('Spent', _spent)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Transaction History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: tr('Search by description, phone number, reference...'),
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                _searchQuery = '';
                                _load(reset: true);
                              },
                            ),
                    ),
                    onSubmitted: (v) {
                      _searchQuery = v.trim();
                      _load(reset: true);
                    },
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final e in _categories.entries)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(e.value),
                              selected: _category == e.key,
                              onSelected: (_) {
                                if (_category == e.key) return;
                                _category = e.key;
                                _load(reset: true);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_error != null) Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
                  if (_error == null && _txns.isEmpty)
                    const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No transactions yet.'))),
                  for (final t in _txns) _txnCard(t),
                  if (_page < _totalPages)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: OutlinedButton(
                        onPressed: _loadingMore ? null : () => _load(),
                        child: _loadingMore
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Load more'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _txnCard(dynamic t) {
    final isCredit = t['type'] == 'credit';
    final status = '${t['status']}';
    return Card(
      child: ListTile(
        onTap: () {
          final ref = '${t['reference'] ?? ''}';
          if (ref.isEmpty || ref == 'null') return;
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptScreen(reference: ref)));
        },
        title: Text('${t['description']}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${t['created_at']}', style: const TextStyle(fontSize: 12)),
            Text('₦${nairaAmount(t['balance_before'])} → ₦${nairaAmount(t['balance_after'])}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            Text(statusLabel(status), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor(status))),
          ],
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isCredit ? '+' : '-'}₦${nairaAmount(t['amount'])}',
              style: TextStyle(color: isCredit ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            const Icon(Icons.receipt_long, size: 16, color: Colors.black45),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, double value) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Text('₦${nairaAmount(value)}', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
