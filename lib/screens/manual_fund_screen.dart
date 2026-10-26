import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n.dart';

/// Bank details for Manual Fund, shown on their own page exactly like the
/// website's manual-fund page: "Send Money To", then "After You Send Money"
/// with the WhatsApp receipt button and the fake-receipt warning.
class ManualFundScreen extends StatelessWidget {
  final Map<String, dynamic> manual;
  final Map<String, dynamic>? user;
  const ManualFundScreen({super.key, required this.manual, this.user});

  Future<void> _openWhatsApp(BuildContext context, String number, String message) async {
    // Do not gate on canLaunchUrl(): on Android 11+ it returns false for
    // https links unless the manifest declares <queries>.
    final uri = Uri.parse('https://wa.me/${number.replaceAll(RegExp(r'[^0-9]'), '')}?text=${Uri.encodeComponent(message)}');
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
    }
  }

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
  }

  Widget _row(BuildContext context, String label, String? value, {bool copyable = false}) => Padding(
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
                    ),
                  ),
                  if (copyable && value != null)
                    IconButton(icon: const Icon(Icons.copy, size: 16), onPressed: () => _copy(context, value)),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final accountNumber = '${manual['account_number'] ?? ''}';
    final accountName = '${manual['account_name'] ?? ''}';
    final waNumber = '${manual['whatsapp_number'] ?? ''}';

    return Scaffold(
      appBar: AppBar(title: const Text('Manual Fund (Bank Transfer)')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (accountNumber.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Admin has not configured Manual Fund details yet.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Send Money To', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    _row(context, 'Bank', manual['bank_name']?.toString()),
                    _row(context, 'Account Number', accountNumber, copyable: true),
                    _row(context, 'Account Name', accountName),
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
                    const Text('After You Send Money', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text(
                      'Click the button below to send your receipt via WhatsApp — admin will review and fund your wallet manually.',
                      style: TextStyle(fontSize: 13.5),
                    ),
                    const SizedBox(height: 12),
                    if (waNumber.isNotEmpty)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                        onPressed: () => _openWhatsApp(
                          context,
                          waNumber,
                          'Hello, I just sent money to $accountName ($accountNumber). '
                          'My username is ${user?['username'] ?? '-'} and email is ${user?['email'] ?? '-'}.',
                        ),
                        icon: const Icon(Icons.chat),
                        label: const Text('Send Receipt via WhatsApp'),
                      ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF2C4C4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFB3261E), size: 22),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Warning', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB3261E))),
                                SizedBox(height: 2),
                                Text(
                                  'If you send a fake receipt without actually sending the money, your account will be suspended immediately, and further legal action may be taken.',
                                  style: TextStyle(color: Color(0xFFB3261E), fontSize: 13.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
