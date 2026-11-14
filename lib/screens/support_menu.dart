import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'support_screen.dart';

/// The ONE "Support" entry point for the whole app — every "Get Help" /
/// support icon (dashboard drawer, floating action button, etc.) should
/// call this instead of linking to any option directly. Shows everything
/// in one place: Phone, Email, WhatsApp, WhatsApp Group, Live Chat —
/// mirrors the website's contact/support options exactly, pulled live
/// from Admin > Settings so it never goes stale.
Future<void> showSupportMenu(BuildContext context) async {
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupportScreen(asPage: true)));
}
