import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/program_detail_screen.dart';

/// Shows the admin's one-time popup (App Popups page) once per popup ID.
/// A new popup gets a new ID, so customers see each update exactly once.
class OneTimePromoManager {
  static const _storage = FlutterSecureStorage();
  static const _kSeenKey = 'seen_promo_popup_id';
  static bool _showing = false;

  static Future<void> maybeShow(BuildContext context, Map<String, dynamic> popup) async {
    if (_showing) return;
    final id = int.tryParse('${popup['id'] ?? ''}') ?? 0;
    if (id <= 0) return;
    try {
      final seen = int.tryParse(await _storage.read(key: _kSeenKey) ?? '') ?? 0;
      if (seen >= id) return;
    } catch (_) {}
    if (!context.mounted) return;
    _showing = true;
    // Mark as seen first so a crash or a quick close never makes it repeat.
    try { await _storage.write(key: _kSeenKey, value: '$id'); } catch (_) {}
    if (!context.mounted) { _showing = false; return; }

    final title = '${popup['title'] ?? ''}'.trim();
    final message = '${popup['message'] ?? ''}'.trim();
    final highlight = '${popup['highlight_text'] ?? ''}'.trim();
    final buttonText = '${popup['button_text'] ?? ''}'.trim();
    final actionType = '${popup['action_type'] ?? 'none'}';
    final actionValue = '${popup['action_value'] ?? ''}'.trim();
    final hasAction = actionType == 'link' || actionType == 'program';

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (highlight.isNotEmpty)
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(20)),
                      child: Text(highlight, style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary)),
                    ),
                  ),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.4)),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    if (!hasAction) return;
                    if (actionType == 'program') {
                      final pid = int.tryParse(actionValue) ?? 0;
                      if (pid > 0) {
                        rootContextPush(context, pid);
                      }
                    } else {
                      // Only ordinary web links are ever opened from a popup.
                      final uri = Uri.tryParse(actionValue);
                      if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    }
                  },
                  child: Text(buttonText.isNotEmpty ? buttonText : (hasAction ? 'Open' : 'Got it')),
                ),
                if (hasAction)
                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
              ],
            ),
          ),
        );
      },
    );
    _showing = false;
  }

  static void rootContextPush(BuildContext context, int programId) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => ProgramDetailScreen(programId: programId)),
    );
  }
}
