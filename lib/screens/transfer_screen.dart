import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../currency.dart';
import '../widgets/pin_field.dart';
import '../purchase_result.dart';
import '../services/api_service.dart';
import 'verify_contact_screen.dart';
import 'transfer_limit_request_screen.dart';

/// "Transfer To Katsinasub User" — send wallet money to another customer
/// by their email, phone number, or username. Same rules as the website:
/// the sender must have a verified email, and is capped at their own
/// transfer limit (shown here, with a link to request a higher one).
class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});
  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _api = ApiService();
  final _identifierCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  bool _emailVerified = true;
  double _limit = 50000;
  List<dynamic> _history = [];
  String? _recipientPreview;
  bool? _recipientFound;
  Timer? _lookupDebounce;

  @override
  void initState() {
    super.initState();
    _load();
    _identifierCtrl.addListener(_onIdentifierChanged);
  }

  @override
  void dispose() {
    _lookupDebounce?.cancel();
    _identifierCtrl.removeListener(_onIdentifierChanged);
    super.dispose();
  }

  // Live "who am I sending to" preview — looks up the matching user's
  // name as the sender types, debounced, so they can confirm it's the
  // right person before sending.
  void _onIdentifierChanged() {
    final q = _identifierCtrl.text.trim();
    _lookupDebounce?.cancel();
    if (q.length < 3) {
      setState(() { _recipientPreview = null; _recipientFound = null; });
      return;
    }
    _lookupDebounce = Timer(const Duration(milliseconds: 400), () async {
      final res = await _api.lookupTransferRecipient(q);
      if (!mounted || _identifierCtrl.text.trim() != q) return;
      setState(() {
        if (res['found'] == true) {
          _recipientFound = true;
          _recipientPreview = res['name'];
        } else {
          _recipientFound = false;
          _recipientPreview = 'No user found with that email, phone number, or username.';
        }
      });
    });
  }

  Future<void> _load() async {
    final me = await _api.me();
    final hist = await _api.transferHistory();
    if (!mounted) return;
    setState(() {
      if (me['success'] == true) {
        _emailVerified = me['user']['email_verified'] == true;
        _limit = ((me['user']['transfer_limit'] as num?)?.toDouble()) ?? 50000;
      }
      _history = hist['success'] == true ? hist['transfers'] : [];
      _loading = false;
    });
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    Map<String, dynamic> res;
    try {
      res = await _api.transfer(
        identifier: _identifierCtrl.text.trim(),
        amount: double.tryParse(_amountCtrl.text) ?? 0,
        transactionPin: _pinCtrl.text,
      );
    } catch (e) {
      res = {'success': false, 'message': 'Could not reach the server. Please check your connection.'};
    }
    setState(() => _busy = false);
    if (!mounted) return;
    await showPurchaseResult(context, res);
    if (res['success'] == true) {
      _identifierCtrl.clear();
      _amountCtrl.clear();
      _pinCtrl.clear();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Transfer To Katsinasub User')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!_emailVerified)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: const Color(0xFFFDECEC), borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('You must verify your email before you can send a transfer.', style: TextStyle(color: Color(0xFFB3261E))),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VerifyContactScreen(type: 'email')));
                      _load();
                    },
                    child: const Text('Verify now'),
                  ),
                ],
              ),
            ),
          const Text('Transfers to other KatsinaSub users are free — no charges — and complete instantly.', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.green)),
          const SizedBox(height: 4),
          Text('Your daily limit: ₦${nairaAmount(_limit)}', style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TransferLimitRequestScreen())),
            child: const Text('Request a higher limit'),
          ),
          const SizedBox(height: 8),
          AbsorbPointer(
            absorbing: !_emailVerified,
            child: Opacity(
              opacity: _emailVerified ? 1 : 0.5,
              child: Column(
                children: [
                  TextField(
                    controller: _identifierCtrl,
                    decoration: InputDecoration(labelText: tr('Email, phone number, or username'), border: const OutlineInputBorder()),
                  ),
                  if (_recipientPreview != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          (_recipientFound == true ? '✓ ' : '') + _recipientPreview!,
                          style: TextStyle(fontSize: 12.5, color: _recipientFound == true ? Colors.green : Colors.red),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: tr('Amount (₦)'), border: const OutlineInputBorder()),
                  ),
                  PinField(controller: _pinCtrl),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy ? const CircularProgressIndicator() : const Text('Send Transfer'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Recent Transfers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_history.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('No transfers yet.')),
          ...(_history.map((t) {
            final out = t['direction'] == 'out';
            return Card(
              child: ListTile(
                title: Text(out ? 'To ${t['other_party']}' : 'From ${t['other_party']}'),
                subtitle: Text('${t['created_at']}', style: const TextStyle(fontSize: 12)),
                trailing: Text(
                  '${out ? '-' : '+'}₦${nairaAmount(t['amount'])}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: out ? Colors.red : Colors.green),
                ),
              ),
            );
          })),
        ],
      ),
    );
  }
}
