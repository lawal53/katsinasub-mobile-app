import 'dart:io';
import 'package:flutter/material.dart' hide Text;
import 'package:share_plus/share_plus.dart';
import '../l10n.dart';
import '../currency.dart';
import '../services/api_service.dart';
import 'receipt_screen.dart' show ReceiptScreen, statusColor, statusLabel;
import '../services/live_refresh.dart';

/// Transaction History: find any transaction quickly — by type, status, money in / out,
/// time frame or a search — see totals for what you found, and download a statement.
class WalletSummaryScreen extends StatefulWidget {
  const WalletSummaryScreen({super.key});
  @override
  State<WalletSummaryScreen> createState() => _WalletSummaryScreenState();
}

class _WalletSummaryScreenState extends State<WalletSummaryScreen>  with LiveRefresh {
  @override
  void onLiveRefresh() { if (_page <= 1) _load(reset: true, silent: true); }

  final _api = ApiService();
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  static const _quick = <String, String>{
    'all': 'All', 'in': 'Money in', 'out': 'Money out', 'wallet': 'Wallet Funding', 'transfer': 'Transfer', 'withdraw': 'Withdraw', 'refund': 'Refunds',
  };
  static const _bills = <String, String>{
    'data': 'Data', 'airtime': 'Airtime', 'cable': 'Cable TV', 'electricity': 'Electricity', 'exam': 'Exam Pins',
    'sms': 'Bulk SMS', 'rcard': 'Recharge Card', 'dcard': 'Data Card', 'identity': 'NIN/BVN',
  };
  static const _statuses = <String, String>{'all': 'All Status', 'successful': 'Successful', 'pending': 'Pending', 'failed': 'Failed', 'refunded': 'Refunded'};
  static const _ranges = <String, String>{'all': 'All time', 'today': 'Today', 'week': 'Last week', 'twoweeks': 'Last two weeks', 'month': 'Last 30 days'};
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String _category = 'all';
  String _status = 'all';
  String _range = 'all'; // all | today | week | twoweeks | month | custom
  DateTime? _from, _to;
  String _query = '';
  bool _searching = false;

  double _balance = 0, _funded = 0, _spent = 0, _in = 0, _out = 0;
  int _count = 0;
  final List<dynamic> _txns = [];
  int _page = 1, _totalPages = 1;
  bool _loading = true, _loadingMore = false, _downloading = false;
  String? _error;

  String _ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _nice(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
  String get _catArg => (_category == 'in' || _category == 'out') ? 'all' : _category;
  String get _dirArg => (_category == 'in' || _category == 'out') ? _category : '';
  String get _fromArg => _from == null ? '' : _ymd(_from!);
  String get _toArg => _to == null ? '' : _ymd(_to!);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 300 && !_loading && !_loadingMore && _page < _totalPages) {
        _load();
      }
    });
    // The unfiltered first page is shown at once from the last visit, then refreshed quietly.
    final cached = _api.peekHistory();
    var haveCache = false;
    if (cached != null && cached['success'] == true) {
      try { _ingest(cached, replace: true); haveCache = true; } catch (_) {}
    }
    _load(reset: true, silent: haveCache);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Puts one answer from the server on the screen.
  void _ingest(Map res, {required bool replace}) {
    final sum = res['summary'];
    _balance = (res['wallet_balance'] as num).toDouble();
    _funded = (res['total_funded'] as num).toDouble();
    _spent = (res['total_spent'] as num).toDouble();
    if (sum is Map) {
      // Totals come with the first page only; scrolling keeps the totals already shown.
      _in = ((sum['in'] ?? 0) as num).toDouble();
      _out = ((sum['out'] ?? 0) as num).toDouble();
      _count = ((sum['count'] ?? 0) as num).toInt();
    }
    _page = res['page'] as int;
    _totalPages = res['total_pages'] as int;
    if (replace) _txns.clear();
    _txns.addAll(res['transactions'] as List<dynamic>);
    _loading = false;
    _loadingMore = false;
  }

  Future<void> _load({bool reset = false, bool silent = false}) async {
    if (reset) {
      if (!silent) setState(() { _loading = true; _error = null; _page = 1; _txns.clear(); });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final res = await _api.walletSummary(
        page: reset ? 1 : _page + 1, category: _catArg, q: _query, status: _status, direction: _dirArg, from: _fromArg, to: _toArg,
      );
      if (!mounted) return;
      if (res['success'] != true) {
        setState(() { if (!silent) _error = '${res['message'] ?? 'Could not load history.'}'; _loading = false; _loadingMore = false; });
        return;
      }
      setState(() => _ingest(res, replace: reset));
    } catch (e) {
      if (!mounted) return;
      setState(() { if (!silent) _error = 'Could not load history.'; _loading = false; _loadingMore = false; });
    }
  }

  // ---------------- filters ----------------
  void _applyRange(String r) {
    final now = DateTime.now();
    _range = r;
    switch (r) {
      case 'today': _from = now; _to = now; break;
      case 'week': _from = now.subtract(const Duration(days: 7)); _to = now; break;
      case 'twoweeks': _from = now.subtract(const Duration(days: 14)); _to = now; break;
      case 'month': _from = now.subtract(const Duration(days: 30)); _to = now; break;
      default: _from = null; _to = null;
    }
  }

  String get _rangeLabel {
    if (_range == 'custom') {
      if (_from != null && _to != null) return '${_nice(_from!)} – ${_nice(_to!)}';
      if (_from != null) return 'From ${_nice(_from!)}';
      if (_to != null) return 'Until ${_nice(_to!)}';
    }
    return _ranges[_range] ?? 'All time';
  }

  String get _categoryLabel => _quick[_category] ?? _bills[_category] ?? 'All';

  Future<void> _pickCategory() async {
    Widget chips(Map<String, String> m, BuildContext ctx) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in m.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: _category == e.key,
                onSelected: (_) {
                  Navigator.pop(ctx);
                  setState(() => _category = e.key);
                  _load(reset: true);
                },
              ),
          ],
        );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Quick Select', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              chips(_quick, ctx),
              const SizedBox(height: 18),
              const Text('Bills & Services', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              chips(_bills, ctx),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickStatus() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Status', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in _statuses.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: _status == e.key,
                      onSelected: (_) {
                        Navigator.pop(ctx);
                        setState(() => _status = e.key);
                        _load(reset: true);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickRange() async {
    var tmpRange = _range;
    var tmpFrom = _from, tmpTo = _to;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> pickDate(bool isFrom) async {
            final now = DateTime.now();
            final d = await showDatePicker(
              context: ctx,
              initialDate: (isFrom ? tmpFrom : tmpTo) ?? now,
              firstDate: now.subtract(const Duration(days: 365)),
              lastDate: now,
            );
            if (d != null) setSheet(() { if (isFrom) { tmpFrom = d; } else { tmpTo = d; } tmpRange = 'custom'; });
          }

          Widget dateTile(String label, DateTime? v, bool isFrom) => InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => pickDate(isFrom),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withOpacity(0.5), borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Expanded(child: Text(v == null ? label : _nice(v), style: TextStyle(color: v == null ? Colors.grey : null, fontWeight: FontWeight.w600))),
                      const Icon(Icons.calendar_month_outlined, size: 20),
                    ],
                  ),
                ),
              );

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Time Frame', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  const SizedBox(height: 14),
                  const Text('Duration', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in _ranges.entries)
                        ChoiceChip(
                          label: Text(e.value),
                          selected: tmpRange == e.key,
                          onSelected: (_) => setSheet(() {
                            tmpRange = e.key;
                            tmpFrom = null;
                            tmpTo = null;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Padding(padding: EdgeInsets.only(top: 6), child: Text('Records from the last 12 months can be shown.', style: TextStyle(fontSize: 12, color: Colors.grey))),
                  const SizedBox(height: 14),
                  const Text('Start Date', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  dateTile('Start Date', tmpFrom, true),
                  const SizedBox(height: 12),
                  const Text('End Date', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  dateTile('End Date', tmpTo, false),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        if (tmpRange == 'custom') {
                          _range = 'custom';
                          _from = tmpFrom;
                          _to = tmpTo;
                        } else {
                          _applyRange(tmpRange);
                        }
                      });
                      _load(reset: true);
                    },
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final body = await _api.walletStatementCsv(category: _catArg, q: _query, status: _status, direction: _dirArg, from: _fromArg, to: _toArg);
      if (body == null) throw Exception('failed');
      final f = File('${Directory.systemTemp.path}/katsinasub-statement-${_ymd(DateTime.now())}.csv');
      await f.writeAsString(body);
      await Share.shareXFiles([XFile(f.path)], text: 'KATSINASUB transaction statement');
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not prepare the statement. Please try again.')));
    }
    if (mounted) setState(() => _downloading = false);
  }

  // ---------------- look ----------------
  (IconData, Color) _look(String desc, bool credit) {
    final d = desc.toLowerCase();
    if (d.contains('refund')) return (Icons.undo_rounded, const Color(0xFF1B9E55));
    if (d.contains('data card') || d.contains('recharge card')) return (Icons.print_outlined, const Color(0xFF8E5BD0));
    if (d.contains('data')) return (Icons.wifi, const Color(0xFF2F6FED));
    if (d.contains('airtime')) return (Icons.phone_android, const Color(0xFFE67E22));
    if (d.contains('electric')) return (Icons.bolt, const Color(0xFFF2B01E));
    if (d.contains('cable')) return (Icons.tv, const Color(0xFF0FA3B1));
    if (d.contains('exam')) return (Icons.school_outlined, const Color(0xFF7C5CE0));
    if (d.contains('sms')) return (Icons.sms_outlined, const Color(0xFF4C5BD4));
    if (d.contains('verification')) return (Icons.badge_outlined, const Color(0xFFE5486A));
    if (d.contains('fund')) return (Icons.account_balance_wallet_outlined, const Color(0xFF11A06B));
    if (d.contains('transfer')) return (Icons.swap_horiz, const Color(0xFF2F6FED));
    if (d.contains('withdraw')) return (Icons.account_balance, const Color(0xFF14315E));
    return (credit ? Icons.south_west : Icons.north_east, credit ? const Color(0xFF1B9E55) : const Color(0xFFD64545));
  }

  String _dayLabel(String key) {
    final now = DateTime.now();
    if (key == _ymd(now)) return 'Today';
    if (key == _ymd(now.subtract(const Duration(days: 1)))) return 'Yesterday';
    final d = DateTime.tryParse(key);
    return d == null ? key : _nice(d);
  }

  Widget _statusPill(String status) {
    final s = status.toLowerCase();
    // Same colours and words as the receipt: Successful, Pending, Processing, Failed, Refunded.
    final Color c = s == 'refunded' ? const Color(0xFF2F6FED) : statusColor(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.withOpacity(0.13), borderRadius: BorderRadius.circular(8)),
      child: Text(statusLabel(s), style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _row(Map t) {
    final desc = '${t['description']}';
    final credit = t['type'] == 'credit';
    final look = _look(desc, credit);
    final amount = (t['amount'] as num).toDouble();
    final created = '${t['created_at']}';
    final time = created.length >= 16 ? created.substring(11, 16) : '';
    final phone = '${t['recipient_phone'] ?? ''}'.trim();
    final network = '${t['network'] ?? ''}'.trim();
    final extra = phone.isNotEmpty ? phone : network;
    final ref = '${t['reference'] ?? ''}';
    return InkWell(
      onTap: ref.isEmpty || ref == 'null' ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptScreen(reference: ref))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(color: look.$2.withOpacity(0.13), borderRadius: BorderRadius.circular(15)),
              child: Icon(look.$1, color: look.$2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(extra.isEmpty ? time : '$time • $extra', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (t['balance_before'] != null && t['balance_after'] != null) ...[
                    const SizedBox(height: 2),
                    Text('Before ₦${nairaAmount(t['balance_before'])}  →  After ₦${nairaAmount(t['balance_after'])}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${credit ? '+' : '-'}₦${nairaAmount(amount)}',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: credit ? const Color(0xFF1B9E55) : null)),
                const SizedBox(height: 4),
                _statusPill('${t['status']}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterButton(String label, IconData icon, VoidCallback onTap, {bool active = false}) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? cs.primaryContainer : cs.surfaceContainerHighest.withOpacity(0.55),
            borderRadius: BorderRadius.circular(16),
            border: active ? Border.all(color: cs.primary.withOpacity(0.5)) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: active ? cs.primary : null))),
              const SizedBox(width: 4),
              Icon(icon, size: 20, color: active ? cs.primary : null),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [cs.primary, const Color(0xFF0B7D55)]),
        boxShadow: [BoxShadow(color: cs.primary.withOpacity(0.28), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_note_outlined, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(_rangeLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
              Text('$_count', style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
              const Text(' records', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _flow('In', _in, Icons.south_west)),
              const SizedBox(width: 10),
              Expanded(child: _flow('Out', _out, Icons.north_east)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Wallet balance ₦${nairaAmount(_balance)}  •  Funded ₦${nairaAmount(_funded)}  •  Spent ₦${nairaAmount(_spent)}',
              style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
        ],
      ),
    );
  }

  Widget _flow(String label, double v, IconData icon) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            CircleAvatar(radius: 14, backgroundColor: Colors.white24, child: Icon(icon, size: 16, color: Colors.white)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                  FittedBox(fit: BoxFit.scaleDown, child: Text('₦${nairaAmount(v)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
                ],
              ),
            ),
          ],
        ),
      );

  List<Widget> _groups() {
    final groups = <String, List<Map>>{};
    for (final t in _txns) {
      final key = '${(t as Map)['created_at']}'.length >= 10 ? '${t['created_at']}'.substring(0, 10) : '';
      groups.putIfAbsent(key, () => []).add(t);
    }
    final out = <Widget>[];
    groups.forEach((key, list) {
      out.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Text(_dayLabel(key), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
      ));
      out.add(Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < list.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 72),
              _row(list[i]),
            ],
          ],
        ),
      ));
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final filtersOn = _category != 'all' || _status != 'all' || _range != 'all' || _query.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(hintText: tr('Search by description, phone number, reference...'), border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
                onSubmitted: (v) { _query = v.trim(); _load(reset: true); },
              )
            : const Text('Transaction History'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: 'Search',
            onPressed: () {
              setState(() => _searching = !_searching);
              if (!_searching && _query.isNotEmpty) { _searchCtrl.clear(); _query = ''; _load(reset: true); }
            },
          ),
          _downloading
              ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(icon: const Icon(Icons.download_outlined), tooltip: 'Download statement', onPressed: _download),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async { await _api.refreshAll(); await _load(reset: true); },
              child: ListView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  Row(
                    children: [
                      _filterButton(_categoryLabel, Icons.arrow_drop_down, _pickCategory, active: _category != 'all'),
                      const SizedBox(width: 8),
                      _filterButton(_status == 'all' ? 'Status' : (_statuses[_status] ?? 'Status'), Icons.arrow_drop_down, _pickStatus, active: _status != 'all'),
                      const SizedBox(width: 8),
                      _filterButton('Time', Icons.calendar_month_outlined, _pickRange, active: _range != 'all'),
                    ],
                  ),
                  if (filtersOn)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() { _category = 'all'; _status = 'all'; _applyRange('all'); _query = ''; _searchCtrl.clear(); _searching = false; });
                          _load(reset: true);
                        },
                        icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                        label: const Text('Clear filters'),
                      ),
                    )
                  else
                    const SizedBox(height: 12),
                  _summaryCard(),
                  if (_error != null) Padding(padding: const EdgeInsets.all(20), child: Text(_error!, style: const TextStyle(color: Colors.red))),
                  if (_error == null && _txns.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 50),
                      child: Column(
                        children: const [
                          Icon(Icons.receipt_long_outlined, size: 54, color: Colors.grey),
                          SizedBox(height: 10),
                          Text('No transactions found for these filters.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ..._groups(),
                  if (_loadingMore) const Padding(padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator())),
                ],
              ),
            ),
    );
  }
}
