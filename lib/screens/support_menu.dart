import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

/// The ONE "Support" entry point for the whole app — every "Get Help" /
/// support icon (dashboard drawer, floating action button, etc.) should
/// call this instead of linking to any option directly. Shows everything
/// in one place: Phone, Email, WhatsApp, WhatsApp Group, Live Chat —
/// mirrors the website's contact/support options exactly, pulled live
/// from Admin > Settings so it never goes stale.
Future<void> showSupportMenu(BuildContext context) async {
  final api = ApiService();
  final info = await api.supportInfo();
  if (!context.mounted) return;

  final phone = (info['contact_phone'] as String? ?? '').trim();
  final email = (info['contact_email'] as String? ?? '').trim();
  final whatsapp = (info['whatsapp_number'] as String? ?? '').trim();
  final whatsappGroup = (info['whatsapp_group_link'] as String? ?? '').trim();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Contact Support', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          if (phone.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.call_outlined, color: Colors.blue),
              title: const Text('Call Us'),
              subtitle: Text(phone),
              onTap: () {
                Navigator.pop(ctx);
                launchUrl(Uri.parse('tel:$phone'));
              },
            ),
          if (email.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email Support'),
              subtitle: Text(email),
              onTap: () {
                Navigator.pop(ctx);
                launchUrl(Uri.parse('mailto:$email'));
              },
            ),
          if (whatsapp.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.green),
              title: const Text('WhatsApp Support'),
              onTap: () {
                Navigator.pop(ctx);
                launchUrl(Uri.parse('https://wa.me/$whatsapp'), mode: LaunchMode.externalApplication);
              },
            ),
          if (whatsappGroup.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.groups, color: Colors.green),
              title: const Text('WhatsApp Group'),
              onTap: () {
                Navigator.pop(ctx);
                launchUrl(Uri.parse(whatsappGroup), mode: LaunchMode.externalApplication);
              },
            ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Live Chat'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
