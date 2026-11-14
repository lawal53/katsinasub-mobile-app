import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../format_utils.dart';
import '../services/api_service.dart';
import 'referral_screen.dart';

/// One programme: the rules the admin set, the reward, the time, and — once the
/// customer has joined — their progress and the people they invited.
class ProgramDetailScreen extends StatefulWidget {
  final int programId;
  const ProgramDetailScreen({super.key, required this.programId});
  @override
  State<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends State<ProgramDetailScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _p;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _api.programDetail(widget.programId);
      if (mounted && r['success'] == true) setState(() => _p = Map<String, dynamic>.from(r['program']));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _n(dynamic v) {
    final d = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
    return d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(2);
  }

  Future<void> _join() async {
    final p = _p!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join programme?'),
        content: Text('You will have ${p['task_days']} day(s) from now to finish. The time starts counting as soon as you join.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Join programme')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    Map<String, dynamic> r;
    try {
      r = await _api.joinProgram(widget.programId);
    } catch (_) {
      r = {'success': false, 'message': 'Could not reach the server. Please try again.'};
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${r['message'] ?? ''}')));
    _load();
  }

  Widget _check(Map c) {
    final ok = c['ok'] == true;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked, size: 15, color: ok ? Colors.green : Colors.orange),
          const SizedBox(width: 6),
          Expanded(child: Text('${c['label']}', style: const TextStyle(fontSize: 12.5))),
          Text('${c['text']}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _referee(Map r) {
    final ok = r['qualified'] == true;
    final color = ok ? Colors.green.shade700 : Colors.orange.shade800;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('${r['name']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(ok ? 'Successful ✓' : 'Pending', style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final c in (r['checks'] as List<dynamic>? ?? [])) _check(c as Map),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Programme')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : p == null
              ? const Center(child: Text('This programme is not available.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text('${p['title']}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                      if ((p['description'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('${p['description']}'),
                      ],
                      const SizedBox(height: 14),
                      Card(
                        color: cs.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.card_giftcard, color: cs.primary, size: 30),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('You win', style: TextStyle(fontSize: 12)),
                                    Text('${p['reward_title']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('What you must do', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text('${p['goal_text']}'),
                      if ((p['conditions'] as List<dynamic>? ?? []).isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text('Each person you invite must:', style: TextStyle(fontWeight: FontWeight.w700)),
                        for (final c in p['conditions'] as List<dynamic>)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('•  '), Expanded(child: Text('$c'))]),
                          ),
                      ],
                      const SizedBox(height: 14),
                      const Text('Time', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('• You can join until ${fmtDate(p['join_until'])}.'),
                      Text('• After you join, you have ${p['task_days']} day(s) to finish.'),
                      Text('• If the time runs out, the programme ends for you and you can join again to start from the beginning (while joining is still open).'),
                      const SizedBox(height: 18),
                      if (p['my_status'] == 'active') ...[
                        Builder(builder: (_) {
                          final prog = (p['progress'] as Map?) ?? {};
                          final total = (p['target'] is num) ? (p['target'] as num).toDouble() : 0.0;
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Your progress', style: TextStyle(fontWeight: FontWeight.w800)),
                                      Text(fmtTimeLeft((p['seconds_left'] ?? 0) as num), style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  LinearProgressIndicator(value: ((prog['percent'] ?? 0) as num) / 100, minHeight: 9, borderRadius: BorderRadius.circular(6)),
                                  const SizedBox(height: 6),
                                  Text('${_n(prog['current'])} of ${_n(prog['target'])} done'
                                      '${p['goal_type'] == 'invite_qualified' ? ' · ${p['remaining']} more needed' : ''}'),
                                ],
                              ),
                            ),
                          );
                        }),
                        if (p['goal_type'] == 'invite_qualified' || p['goal_type'] == 'invite_registered') ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReferralScreen())),
                            icon: const Icon(Icons.share),
                            label: const Text('Invite friends'),
                          ),
                        ],
                        if ((p['referees'] as List<dynamic>? ?? []).isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('People you invited (${p['qualified_count']} successful)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          for (final r in p['referees'] as List<dynamic>) _referee(r as Map),
                        ] else if (p['goal_type'] == 'invite_qualified') ...[
                          const SizedBox(height: 14),
                          const Text('Nobody has registered with your code since you joined.', style: TextStyle(color: Colors.grey)),
                        ],
                      ] else if (p['my_status'] == 'completed')
                        const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('🎉 You completed this programme. Your reward is in Rewards → Active.')))
                      else if (p['can_join'] == true)
                        FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                          onPressed: _busy ? null : _join,
                          child: Text(p['my_status'] == 'expired' ? 'Join again' : 'Join programme'),
                        )
                      else
                        const Text('Joining is not open for this programme.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
    );
  }
}
