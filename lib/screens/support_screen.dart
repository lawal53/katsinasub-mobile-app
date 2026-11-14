import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';
import 'checkout_webview_screen.dart';

/// Support: every option is a big button. Used as the "Support" tab and
/// as a normal page when opened from the menu.
class SupportScreen extends StatefulWidget {
  final bool asPage;
  const SupportScreen({super.key, this.asPage = false});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _api = ApiService();
  Map<String, dynamic> _info = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _api.supportInfo();
      if (mounted) setState(() => _info = r);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _v(String k) => ('${_info[k] ?? ''}').trim();

  Widget _big(IconData icon, Color color, String title, String? sub, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withOpacity(0.35))),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                      if (sub != null && sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phone = _v('contact_phone'), email = _v('contact_email'), wa = _v('whatsapp_number'), group = _v('whatsapp_group_link');
    return Scaffold(
      appBar: AppBar(title: const Text('Support'), automaticallyImplyLeading: widget.asPage),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: Text('How can we help you?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  _big(Icons.chat_bubble_outline, const Color(0xFF2E7D5B), 'Live Chat', 'Talk to our support team', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatScreen()))),
                  if (wa.isNotEmpty)
                    _big(Icons.chat, const Color(0xFF25D366), 'WhatsApp Support', 'Message us on WhatsApp', () => launchUrl(Uri.parse('https://wa.me/${wa.replaceAll(RegExp(r'[^0-9]'), '')}'), mode: LaunchMode.externalApplication)),
                  if (group.isNotEmpty)
                    _big(Icons.groups, const Color(0xFF1B8F4B), 'WhatsApp Group', 'Join our community', () => launchUrl(Uri.parse(group), mode: LaunchMode.externalApplication)),
                  if (phone.isNotEmpty) _big(Icons.call_outlined, const Color(0xFF1E6FD9), 'Call Us', phone, () => launchUrl(Uri.parse('tel:$phone'))),
                  if (email.isNotEmpty) _big(Icons.email_outlined, const Color(0xFF8E5BD0), 'Email Support', email, () => launchUrl(Uri.parse('mailto:$email'))),
                  _big(Icons.language, const Color(0xFF0F7B5F), 'VISIT OUR WEBSITE', 'katsinasub.com', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckoutWebViewScreen(url: 'https://katsinasub.com', title: 'KATSINASUB', lockHosts: ['katsinasub.com', 'www.katsinasub.com'])))),
                ],
              ),
            ),
    );
  }
}
