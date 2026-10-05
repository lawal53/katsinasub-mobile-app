import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../currency.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'checkout_webview_screen.dart';

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
    if (!second) {
      final entered = await _askForKyc('Your bank partner (PaymentPoint) requires your BVN or NIN to create this account number.');
      if (entered == null) return; // customer cancelled
      kycType = entered.$1;
      kycNumber = entered.$2;
    }
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Bank Transfer (Instant)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text('Get your own account number — any transfer to it funds your wallet automatically.', style: TextStyle(fontSize: 12.5)),
                  const SizedBox(height: 12),
                  // "Your Account Number" is PaymentPoint (second: false);
                  // BillStack (second: true) is shown below as "Your
                  // Second Account Number" — this order matches the
                  // website's dashboard.
                  if (va != null) ...[
                    _row('Bank', va['bank_name']),
                    _row('Account Number', va['account_number'], copyable: true),
                    _row('Account Name', va['account_name']),
                    _row('Charges', _info!['virtual_account_charge_label']),
                  ] else ...[
                    _row('Charges', _info!['virtual_account_charge_label']),
                    const SizedBox(height: 8),
                    FilledButton(onPressed: _busy ? null : () => _generateAccount(second: false), child: const Text('Generate My Account Number')),
                  ],
                  const Divider(height: 24),
                  const Text('Your Second Account Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (va2 != null) ...[
                    _row('Bank', va2['bank_name']),
                    _row('Account Number', va2['account_number'], copyable: true),
                    _row('Account Name', va2['account_name']),
                    _row('Charges', _info!['virtual_account_2_charge_label']),
                  ] else if (_info!['billstack_enabled'] == true) ...[
                    _row('Charges', _info!['virtual_account_2_charge_label']),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: _busy ? null : () => _generateAccount(second: true), child: const Text('Generate My Second Account Number')),
                  ],
                ],
              ),
            ),
          ),
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
                    _row('Bank', manual['bank_name']),
                    _row('Account Number', manual['account_number'], copyable: true),
                    _row('Account Name', manual['account_name']),
                    const SizedBox(height: 10),
                    const Text('After sending, contact support via WhatsApp with your receipt.', style: TextStyle(fontSize: 12.5)),
                    if (manual['whatsapp_number'] != null && '${manual['whatsapp_number']}'.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                        onPressed: () => _openWhatsApp(
                          '${manual['whatsapp_number']}',
                          'Hello, I just sent money to ${manual['account_name']} (${manual['account_number']}). '
                          'My username is ${_user?['username'] ?? '-'} and email is ${_user?['email'] ?? '-'}.',
                        ),
                        icon: const Icon(Icons.chat),
                        label: const Text('Send Receipt via WhatsApp'),
                      ),
                    ],
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
