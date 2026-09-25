import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import '../l10n.dart';
import '../services/api_service.dart';

/// Colour + label for a transaction status, shared by history and receipt.
Color statusColor(String status) {
  switch (status) {
    case 'successful': return Colors.green;
    case 'failed': return Colors.red;
    default: return Colors.orange;
  }
}

String statusLabel(String status) {
  switch (status) {
    case 'successful': return 'Successful';
    case 'failed': return 'Failed';
    case 'refunded': return 'Refunded';
    case 'processing': return 'Processing';
    default: return 'Pending';
  }
}

/// Same information as the website's receipt page for one transaction.
class ReceiptScreen extends StatefulWidget {
  final String reference;
  const ReceiptScreen({super.key, required this.reference});
  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _api.receipt(widget.reference).then((res) {
      if (!mounted) return;
      setState(() { _data = res; _loading = false; });
    }).catchError((_) {
      if (!mounted) return;
      setState(() { _data = {'success': false, 'message': 'Could not load the receipt.'}; _loading = false; });
    });
  }

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_data!['success'] != true)
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('${_data!['message'] ?? 'Transaction not found.'}')))
              : _buildReceipt(),
    );
  }

  Widget _buildReceipt() {
    final status = '${_data!['status']}';
    final rows = (_data!['rows'] as List<dynamic>);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(color: statusColor(status).withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(statusLabel(status).toUpperCase(), style: TextStyle(color: statusColor(status), fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 8),
        Center(child: Text('${_data!['title']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 4, child: Text('${r['label']}', style: const TextStyle(color: Colors.black54))),
                        Expanded(
                          flex: 6,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(child: SelectableText('${r['value']}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
                              if (r['copy'] == true)
                                InkWell(
                                  onTap: () => _copy('${r['value']}'),
                                  child: const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.copy, size: 16)),
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
        const SizedBox(height: 12),
        const Center(child: Text('Thank you for using Katsinasub', style: TextStyle(fontSize: 12, color: Colors.black54))),
      ],
    );
  }
}
