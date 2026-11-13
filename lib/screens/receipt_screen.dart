import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n.dart';
import '../services/api_service.dart';

/// Colour + label for a transaction status, shared by history and receipt.
Color statusColor(String status) {
  switch (status) {
    case 'successful':
    case 'approved':
      return Colors.green;
    case 'failed':
    case 'rejected':
      return Colors.red;
    default: return Colors.orange;
  }
}

String statusLabel(String status) {
  switch (status) {
    case 'successful': return 'Successful';
    case 'failed': return 'Failed';
    case 'refunded': return 'Refunded';
    case 'processing': return 'Processing';
    case 'approved': return 'Approved';
    case 'rejected': return 'Rejected';
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
  // Wraps just the printable receipt card so the download button itself
  // (and the app bar) never end up captured in the saved image.
  final GlobalKey _captureKey = GlobalKey();
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _downloading = false;

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

  // Renders the receipt card (via the RepaintBoundary wrapped around it)
  // to a PNG image, then hands it to the OS share sheet — from there the
  // customer can pick "Save to device / Files", send it on WhatsApp, etc.
  // No storage permission is needed since nothing is written to disk by
  // the app itself; the OS share target handles saving.
  Future<void> _downloadReceipt() async {
    setState(() => _downloading = true);
    try {
      final boundary = _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // pixelRatio 3.0: a crisp, readable image on any screen size.
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final ref = widget.reference.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: 'katsinasub-receipt-$ref.png', mimeType: 'image/png')],
        text: 'KatsinaSub Receipt — $ref',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not download the receipt. Please try again.')));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
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
        RepaintBoundary(
          key: _captureKey,
          child: Container(
            // A plain, solid background is required for the capture — a
            // transparent background would turn black in some share targets.
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              children: [
                // Same brand header as the website's printable receipt: logo,
                // site name, and the company's RC (registration) number.
                Center(
                  child: Column(
                    children: [
                      Image.asset('assets/logo.png', width: 56, height: 56, fit: BoxFit.contain),
                      const SizedBox(height: 6),
                      const Text('KatsinaSub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Text('RC 9716377', style: TextStyle(fontSize: 11.5, color: Colors.black54)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
            ),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _downloading ? null : _downloadReceipt,
          icon: _downloading
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download),
          label: Text(_downloading ? 'Preparing...' : 'Download Receipt'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ],
    );
  }
}
