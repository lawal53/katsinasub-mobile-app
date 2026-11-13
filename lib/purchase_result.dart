import 'package:flutter/material.dart' hide Text;
import 'l10n.dart';
import 'screens/receipt_screen.dart';
import 'screens/account_settings_screen.dart';

/// Shows the outcome of a purchase INSIDE the page the customer bought
/// from (same behaviour as the website): a clear success / processing /
/// failed message with a "View Receipt" button, and "OK" to simply stay
/// on the same page.
Future<void> showPurchaseResult(BuildContext context, Map<String, dynamic> res, {VoidCallback? onOk}) async {
  final success = res['success'] == true;
  final status = '${res['status'] ?? (success ? 'successful' : 'failed')}';
  final processing = success && (status == 'processing' || status == 'pending');
  final ok = success && !processing;
  final reference = '${res['reference'] ?? ''}';
  final message = '${res['message'] ?? (ok ? 'Done' : 'Something went wrong.')}';
  final color = ok ? Colors.green : (processing ? Colors.orange : Colors.red);
  final icon = ok ? Icons.check_circle : (processing ? Icons.hourglass_top : Icons.error);
  final title = ok ? 'Successful' : (processing ? 'Processing' : 'Failed');
  // The server says this exact thing when the account has no transaction
  // PIN yet — send the customer straight to where they can set one,
  // instead of a plain "OK" that just leaves them stuck on this page.
  final needsPin = !success && message.toLowerCase().contains('set a transaction pin');

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: Icon(icon, color: color, size: 48),
      title: Text(title),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        if (reference.isNotEmpty && reference != 'null')
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptScreen(reference: reference)));
            },
            child: const Text('View Receipt'),
          ),
        if (needsPin)
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountSettingsScreen()));
            },
            child: const Text('Set PIN'),
          )
        else
          FilledButton(
            onPressed: () { Navigator.pop(ctx); if (onOk != null) onOk(); },
            child: const Text('OK'),
          ),
      ],
    ),
  );
}
