import 'package:flutter/material.dart' hide Text;
import 'l10n.dart';
import 'screens/receipt_screen.dart';

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
  final color = ok ? Colors.green : (processing ? Colors.orange : Colors.red);
  final icon = ok ? Icons.check_circle : (processing ? Icons.hourglass_top : Icons.error);
  final title = ok ? 'Successful' : (processing ? 'Processing' : 'Failed');

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: Icon(icon, color: color, size: 48),
      title: Text(title),
      content: Text('${res['message'] ?? (ok ? 'Done' : 'Something went wrong.')}', textAlign: TextAlign.center),
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
        FilledButton(
          onPressed: () { Navigator.pop(ctx); if (onOk != null) onOk(); },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
