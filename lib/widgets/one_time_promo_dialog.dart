import 'package:flutter/material.dart' hide Text;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../l10n.dart';
import '../screens/checkout_webview_screen.dart';
import '../screens/program_detail_screen.dart';

class OneTimePromoManager {
  OneTimePromoManager._();
  static const _storage = FlutterSecureStorage();
  static const _seenKey = 'last_seen_promo_id';
  static bool _showing = false;

  static Future<void> maybeShow(BuildContext context, Map<String, dynamic>? popup) async {
    if (_showing || popup == null) return;
    final id = int.tryParse('${popup['id'] ?? ''}');
    if (id == null || id <= 0) return;

    final seenRaw = await _storage.read(key: _seenKey);
    final seenId = int.tryParse(seenRaw ?? '');
    if (seenId == id) return; // Customer has already seen this exact update once.

    if (!context.mounted) return;
    _showing = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _PromoCardDialog(
          popup: popup,
          onMarkSeen: () async {
            await _storage.write(key: _seenKey, value: '$id');
          },
        ),
      );
    } finally {
      _showing = false;
    }
  }
}

class _PromoCardDialog extends StatelessWidget {
  final Map<String, dynamic> popup;
  final Future<void> Function() onMarkSeen;

  const _PromoCardDialog({required this.popup, required this.onMarkSeen});

  Future<void> _dismiss(BuildContext context) async {
    await onMarkSeen();
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _handleAction(BuildContext context) async {
    final actionType = '${popup['action_type'] ?? 'none'}';
    final actionValue = '${popup['action_value'] ?? ''}'.trim();
    await onMarkSeen();
    if (!context.mounted) return;
    Navigator.of(context).pop();

    if (actionType == 'program') {
      final progId = int.tryParse(actionValue);
      if (progId != null && progId > 0) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProgramDetailScreen(programId: progId)),
        );
      }
    } else if (actionType == 'link' && actionValue.isNotEmpty) {
      final uri = Uri.tryParse(actionValue);
      if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CheckoutWebViewScreen(
              url: uri.toString(),
              title: '${popup['title'] ?? 'Update'}',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = '${popup['title'] ?? 'Update'}';
    final message = '${popup['message'] ?? ''}';
    final highlight = '${popup['highlight_text'] ?? ''}'.trim();
    final buttonText = '${popup['button_text'] ?? 'Continue'}';
    final actionType = '${popup['action_type'] ?? 'none'}';
    final actionValue = '${popup['action_value'] ?? ''}'.trim();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primaryContainer, cs.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.primary.withOpacity(0.25)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                if (highlight.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    highlight,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: cs.primary,
                    ),
                  ),
                ],
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ],
                if (actionType == 'link' && actionValue.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => _handleAction(context),
                    child: Text(
                      actionValue,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: cs.primary,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _handleAction(context),
                    child: Text(buttonText),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          IconButton.filledTonal(
            onPressed: () => _dismiss(context),
            icon: const Icon(Icons.close, size: 24),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}
