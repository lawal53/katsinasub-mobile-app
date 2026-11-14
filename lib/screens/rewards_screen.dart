import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../format_utils.dart';
import '../services/api_service.dart';
import 'redeem_reward_screen.dart';
import 'program_detail_screen.dart';

/// Rewards: ongoing programmes + the customer's own rewards in three tabs
/// (Active, Used, Expired).
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});
  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  final _api = ApiService();
  Map<String, dynamic> _data = {};
  List<dynamic> _programs = [];
  bool _loading = true;
  String _tab = 'active';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([_api.rewards(), _api.programs()]);
      if (!mounted) return;
      setState(() {
        _data = r[0]['success'] == true ? r[0] : {};
        _programs = r[1]['success'] == true ? (r[1]['programs'] as List<dynamic>? ?? []) : [];
      });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<dynamic> _list(String k) => (_data[k] as List<dynamic>?) ?? [];

  IconData _icon(String type) => type == 'data' ? Icons.wifi : (type == 'airtime' ? Icons.phone_android : Icons.payments_outlined);

  Future<void> _claim(Map r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Claim reward'),
        content: Text('Add ${r['title']} to your bonus balance?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Claim')),
        ],
      ),
    );
    if (ok != true) return;
    final res = await _api.claimReward(r['id'] as int);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${res['message'] ?? ''}')));
    _load();
  }

  Future<void> _use(Map r) async {
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => RedeemRewardScreen(reward: Map<String, dynamic>.from(r), networks: (_data['networks'] as List<dynamic>? ?? []).map((e) => '$e').toList()),
    ));
    if (done == true) _load();
  }

  Widget _tabButton(String key, String label) {
    final selected = _tab == key;
    final count = _list(key).length;
    final child = Text('$label ($count)', style: const TextStyle(fontWeight: FontWeight.w700));
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(
          height: 46,
          child: selected
              ? FilledButton(onPressed: () => setState(() => _tab = key), child: child)
              : OutlinedButton(onPressed: () => setState(() => _tab = key), child: child),
        ),
      ),
    );
  }

  Widget _programCard(Map p) {
    final cs = Theme.of(context).colorScheme;
    final st = p['my_status'];
    final prog = p['progress'] as Map?;
    String badge;
    Color color;
    if (st == 'active') {
      badge = 'In progress';
      color = Colors.orange.shade700;
    } else if (st == 'completed') {
      badge = 'Completed';
      color = Colors.green.shade700;
    } else if (st == 'expired') {
      badge = p['can_join'] == true ? 'Join again' : 'Expired';
      color = Colors.red.shade700;
    } else {
      badge = 'Tap to join';
      color = cs.primary;
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProgramDetailScreen(programId: p['id'] as int)));
          _load();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events_outlined),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${p['title']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(badge, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Reward: ${p['reward_title']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              if (st == 'active' && prog != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: ((prog['percent'] ?? 0) as num) / 100, minHeight: 7, borderRadius: BorderRadius.circular(6)),
                const SizedBox(height: 4),
                Text('${_n(prog['current'])} of ${_n(prog['target'])} · ${fmtTimeLeft((p['seconds_left'] ?? 0) as num)}', style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _n(dynamic v) {
    final d = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
    return d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(2);
  }

  Widget _rewardCard(Map r) {
    final cs = Theme.of(context).colorScheme;
    final type = '${r['type']}';
    final isActive = _tab == 'active';
    String sub;
    if (_tab == 'used') {
      sub = 'Used ${fmtDate(r['used_at'])}${(r['used_phone'] ?? '').toString().isNotEmpty ? ' · ${r['used_phone']}' : ''}';
    } else if (_tab == 'expired') {
      sub = 'Expired ${fmtDate(r['expires_at'])}';
    } else {
      sub = 'Use before ${fmtDate(r['expires_at'])}';
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(14)),
                  child: Icon(_icon(type), color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${r['title']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(sub, style: const TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
              ],
            ),
            if (isActive) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => type == 'cash' ? _claim(r) : _use(r),
                icon: Icon(type == 'cash' ? Icons.account_balance_wallet_outlined : Icons.card_giftcard, size: 18),
                label: Text(type == 'cash' ? 'Claim to Bonus' : 'Use Reward'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _list(_tab);
    return Scaffold(
      appBar: AppBar(title: const Text('Rewards'), automaticallyImplyLeading: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_programs.isNotEmpty) ...[
                    const Text('Ongoing Programmes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    for (final p in _programs) _programCard(p as Map),
                    const SizedBox(height: 14),
                  ],
                  const Text('My Rewards', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Row(children: [_tabButton('active', 'Active'), _tabButton('used', 'Used'), _tabButton('expired', 'Expired')]),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          const Icon(Icons.card_giftcard, size: 48, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(_tab == 'active' ? 'No active rewards right now.' : (_tab == 'used' ? 'You have not used any reward yet.' : 'No expired rewards.'), style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  for (final r in items) _rewardCard(r as Map),
                ],
              ),
            ),
    );
  }
}
