import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.fundWalletInfo();
    setState(() => _info = res);
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Wallet funded with ₦${verifyRes['credited_amount']}!')));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(verifyRes['message'] ?? 'Payment not confirmed yet.')));
    }
  }

  Future<void> _createVirtualAccount() async {
    setState(() => _busy = true);
    final res = await _api.createVirtualAccount();
    setState(() => _busy = false);
    if (!mounted) return;
    if (res['success'] == true) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Failed')));
    }
  }

  Future<void> _createVirtualAccountBillstack() async {
    setState(() => _busy = true);
    final res = await _api.createVirtualAccountBillstack();
    setState(() => _busy = false);
    if (!mounted) return;
    if (res['success'] == true) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Failed')));
    }
  }

  Future<void> _openWhatsApp(String number, String message) async {
    final uri = Uri.parse('https://wa.me/${number.replaceAll(RegExp(r'[^0-9]'), '')}?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
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
                  if (va != null) ...[
                    _row('Bank', va['bank_name']),
                    _row('Account Number', va['account_number'], copyable: true),
                    _row('Account Name', va['account_name']),
                  ] else
                    FilledButton(onPressed: _busy ? null : _createVirtualAccount, child: const Text('Generate My Account Number')),
                  if (_info!['billstack_enabled'] == true) ...[
                    const Divider(height: 24),
                    const Text('Your Second Account Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    if (va2 != null) ...[
                      _row('Bank', va2['bank_name']),
                      _row('Account Number', va2['account_number'], copyable: true),
                      _row('Account Name', va2['account_name']),
                    ] else
                      OutlinedButton(onPressed: _busy ? null : _createVirtualAccountBillstack, child: const Text('Generate My Second Account Number')),
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
                          'Hello, I just sent money to ${manual['account_name']} (${manual['account_number']}). My username is __ and email is __.',
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
