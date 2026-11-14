import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../currency.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'checkout_webview_screen.dart';
import 'manual_fund_screen.dart';

class FundWalletScreen extends StatefulWidget {
  const FundWalletScreen({super.key});
  @override
  State<FundWalletScreen> createState() => _FundWalletScreenState();
}

class _FundWalletScreenState extends State<FundWalletScreen> {
  final _api = ApiService();
  final _amountCtrl = TextEditingController();
  Map<String, dynamic>? _info;
  Map<String, dynamic>? _user;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadUser();
  }

  Future<void> _load() async {
    final res = await _api.fundWalletInfo();
    setState(() => _info = res);
  }

  // So the WhatsApp receipt message can include the customer's own
  // username/email automatically, the same way the website's manual-fund
  // page already knows who's logged in — instead of leaving blanks for
  // the customer to fill in by hand.
  Future<void> _loadUser() async {
    final res = await _api.me();
    if (res['success'] == true && mounted) setState(() => _user = res['user']);
  }

  Future<void> _pay(String method) async {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount < 100) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum amount is ₦100.')));
      return;
    }
    setState(() => _busy = true);
    final initRes = await _api.fundWalletInit(method: method, amount: amount);
    setState(() => _busy = false);

    if (initRes['success'] != true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(initRes['message'] ?? 'Could not start payment')));
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CheckoutWebViewScreen(url: initRes['checkout_url']),
    ));

    // Whether the WebView closed on its own or the user tapped close,
    // always confirm with the server — never trust the client alone.
    setState(() => _busy = true);
    final verifyRes = await _api.verifyTransaction(reference: initRes['reference']);
    setState(() => _busy = false);
    if (!mounted) return;

    if (verifyRes['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Wallet funded with ₦${nairaAmount(verifyRes['credited_amount'])}!')));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(verifyRes['message'] ?? 'Payment not confirmed yet.')));
    }
  }

  // Generates a virtual account number. For PaymentPoint ("second" =
  // false / primary account), a BVN/NIN is ALWAYS required, so tapping
  // Generate opens the ID dialog first — no round trip is wasted on a
  // request we already know needs it. BillStack ("second" = true)
  // doesn't need this up front; it only asks if the provider's response
  // says so (kyc_required).
  Future<void> _generateAccount({required bool second}) async {
    String? kycType;
    String? kycNumber;
    while (true) {
      setState(() => _busy = true);
      Map<String, dynamic> res;
      try {
        res = second
            ? await _api.createVirtualAccountBillstack(kycType: kycType, kycNumber: kycNumber)
            : await _api.createVirtualAccount(kycType: kycType, kycNumber: kycNumber);
      } catch (e) {
        res = {'success': false, 'message': 'Could not reach the server. Please check your connection.'};
      }
      if (mounted) setState(() => _busy = false);
      if (!mounted) return;

      if (res['success'] == true) {
        _load();
        return;
      }
      if (res['kyc_required'] == true) {
        final entered = await _askForKyc('${res['message'] ?? ''}');
        if (entered == null) return; // customer cancelled
        kycType = entered.$1;
        kycNumber = entered.$2;
        continue;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Failed')));
      return;
    }
  }

  Future<(String, String)?> _askForKyc(String message) {
    final numberCtrl = TextEditingController();
    String type = 'bvn';
    return showDialog<(String, String)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Verify your ID'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.isEmpty ? 'Your bank partner needs your BVN or NIN to create this account number.' : message),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(label: const Text('BVN'), selected: type == 'bvn', onSelected: (_) => setD(() => type = 'bvn')),
                  ChoiceChip(label: const Text('NIN'), selected: type == 'nin', onSelected: (_) => setD(() => type = 'nin')),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: numberCtrl,
                keyboardType: TextInputType.number,
                maxLength: 11,
                decoration: InputDecoration(labelText: tr('11-digit BVN or NIN'), border: const OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (numberCtrl.text.trim().length != 11) return;
                Navigator.pop(ctx, (type, numberCtrl.text.trim()));
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWhatsApp(String number, String message) async {
    // Do NOT gate on canLaunchUrl(): on Android 11+ it returns false for
    // https links unless the manifest declares <queries>, which made this
    // button always say "Could not open WhatsApp" even with WhatsApp installed.
    final uri = Uri.parse('https://wa.me/${number.replaceAll(RegExp(r'[^0-9]'), '')}?text=${Uri.encodeComponent(message)}');
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
  }

  @override
  Widget build(BuildContext context) {
    if (_info == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final va = _info!['virtual_account'];
    final va2 = _info!['virtual_account_2'];
    final manual = _info!['manual_fund'];

    return Scaffold(
      appBar: AppBar(title: const Text('Fund Wallet')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_info!['monnify_enabled'] == true) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Pay with Debit/ATM Card', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    // The server already sends this (card_charge_label) — it
                    // just was never displayed here, unlike the two bank
                    // transfer sections below and the website.
                    if (_info!['card_charge_label'] != null) ...[
                      _row('Charges', _info!['card_charge_label']),
                      const SizedBox(height: 10),
                    ],
                    TextField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: tr('Amount (₦)'), border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    if (_info!['monnify_enabled'] == true)
                      FilledButton(onPressed: _busy ? null : () => _pay('monnify'), child: const Text('Pay with Card (Monnify)')),
                    if (_busy) const Padding(padding: EdgeInsets.only(top: 10), child: Center(child: CircularProgressIndicator())),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text('Bank Transfer (Instant)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text('Get your own account number: any transfer to it funds your wallet automatically.', style: TextStyle(fontSize: 12.5)),
          ),
          // Two separate account numbers, each with its own card and colours.
          _accountCard(
            title: 'Your Account Number',
            badge: 'Account 1',
            colors: const [Color(0xFF0F7B5F), Color(0xFF1FB57F)],
            account: va,
            chargeLabel: _info!['virtual_account_charge_label'],
            canGenerate: true,
            generateLabel: 'Generate My Account Number',
            onGenerate: () => _generateAccount(second: false),
          ),
          if (va2 != null || _info!['billstack_enabled'] == true) ...[
            const SizedBox(height: 18),
            _accountCard(
              title: 'Your Second Account Number',
              badge: 'Account 2',
              colors: const [Color(0xFF14315E), Color(0xFF2F6FB5)],
              account: va2,
              chargeLabel: _info!['virtual_account_2_charge_label'],
              canGenerate: _info!['billstack_enabled'] == true,
              generateLabel: 'Generate My Second Account Number',
              onGenerate: () => _generateAccount(second: true),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Manual Fund', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  if (manual['account_number'] != null && manual['account_number'] != '') ...[
                    const Text('Manually send money to a bank account, then send the receipt via WhatsApp.', style: TextStyle(fontSize: 12.5)),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ManualFundScreen(manual: Map<String, dynamic>.from(manual as Map), user: _user),
                      )),
                      child: const Text('View Bank Details'),
                    ),
                  ] else
                    const Text('Admin has not configured Manual Fund details yet.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountCard({
    required String title,
    required String badge,
    required List<Color> colors,
    required dynamic account,
    required dynamic chargeLabel,
    required bool canGenerate,
    required String generateLabel,
    required VoidCallback onGenerate,
  }) {
    const white = TextStyle(color: Colors.white);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        boxShadow: [BoxShadow(color: colors.first.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: white.copyWith(fontWeight: FontWeight.w800, fontSize: 16))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: Text(badge, style: white.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (account != null) ...[
            Text('${account['bank_name'] ?? ''}', style: white.copyWith(fontSize: 13, color: Colors.white70)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Text('${account['account_number'] ?? ''}', style: white.copyWith(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 2))),
                IconButton(
                  style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2)),
                  icon: const Icon(Icons.copy, color: Colors.white, size: 20),
                  onPressed: () => _copy('${account['account_number']}'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${account['account_name'] ?? ''}', style: white.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
          ] else ...[
            Text('You do not have this account number yet.', style: white.copyWith(fontSize: 13.5)),
            const SizedBox(height: 14),
            if (canGenerate)
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: colors.first, minimumSize: const Size.fromHeight(48)),
                onPressed: _busy ? null : onGenerate,
                child: Text(generateLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
          ],
          if (chargeLabel != null && '$chargeLabel'.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Flexible(child: Text('Charges: $chargeLabel', style: white.copyWith(fontSize: 12.5))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String? value, {bool copyable = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (copyable && value != null)
                    IconButton(icon: const Icon(Icons.copy, size: 16), onPressed: () => _copy(value)),
                ],
              ),
            ),
          ],
        ),
      );
}
