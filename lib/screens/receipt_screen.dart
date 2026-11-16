import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n.dart';
import '../services/api_service.dart';
import 'support_menu.dart';

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
        text: 'KATSINASUB Receipt — $ref',
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

  String? _rowValue(List<dynamic> rows, String label) {
    for (final r in rows) {
      if (r is Map && r['label'] == label) return '${r['value']}';
    }
    return null;
  }

  Widget _dashedDivider(Color notch) {
    return SizedBox(
      height: 22,
      child: Stack(
        alignment: Alignment.center,
        children: [
          LayoutBuilder(builder: (context, c) {
            final n = (c.maxWidth / 9).floor();
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(n, (_) => Container(width: 5, height: 1.5, color: Colors.black26)),
            );
          }),
          Positioned(left: -11, child: Container(width: 22, height: 22, decoration: BoxDecoration(color: notch, shape: BoxShape.circle))),
          Positioned(right: -11, child: Container(width: 22, height: 22, decoration: BoxDecoration(color: notch, shape: BoxShape.circle))),
        ],
      ),
    );
  }

  Widget _buildReceipt() {
    final status = '${_data!['status']}';
    final rows = (_data!['rows'] as List<dynamic>);
    final cs = Theme.of(context).colorScheme;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final amount = _rowValue(rows, 'Amount');
    final before = _rowValue(rows, 'Balance Before');
    final after = _rowValue(rows, 'Balance After');
    final Color sc = status == 'refunded' ? const Color(0xFF2F6FED) : statusColor(status);
    final IconData sIcon = status == 'successful' || status == 'approved'
        ? Icons.check_circle
        : (status == 'failed' || status == 'rejected' ? Icons.cancel : (status == 'refunded' ? Icons.undo_rounded : Icons.hourglass_top_rounded));
    final shown = rows.where((r) => r is Map && !['Amount', 'Balance Before', 'Balance After'].contains(r['label'])).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        RepaintBoundary(
          key: _captureKey,
          child: Container(
            // A plain, solid background is required for the capture.
            color: bg,
            padding: const EdgeInsets.all(4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Container(
                color: cs.surface,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 46),
                      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0A1B36), Color(0xFF0B7D55), Color(0xFF12A06B)])),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                            child: Image.asset('assets/logo.png', width: 46, height: 46, fit: BoxFit.contain),
                          ),
                          const SizedBox(height: 8),
                          const Text('KATSINASUB', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, letterSpacing: 1)),
                          const Text('RC 9716377', style: TextStyle(fontSize: 11.5, color: Colors.white70)),
                        ],
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -34),
                      child: Column(
                        children: [
                          Container(
                            width: 68, height: 68,
                            decoration: BoxDecoration(color: cs.surface, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))]),
                            child: Icon(sIcon, size: 44, color: sc),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                            decoration: BoxDecoration(color: sc.withOpacity(0.13), borderRadius: BorderRadius.circular(20)),
                            child: Text(statusLabel(status).toUpperCase(), style: TextStyle(color: sc, fontWeight: FontWeight.w900, letterSpacing: 0.6, fontSize: 12.5)),
                          ),
                          const SizedBox(height: 10),
                          Text('${_data!['title']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          if (amount != null) ...[
                            const SizedBox(height: 4),
                            Text(amount, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                          ],
                        ],
                      ),
                    ),
                    Transform.translate(offset: const Offset(0, -20), child: _dashedDivider(bg)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                      child: Column(
                        children: [
                          for (final r in shown)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 4, child: Text('${r['label']}', style: const TextStyle(color: Colors.black54, fontSize: 13.5))),
                                  Expanded(
                                    flex: 6,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Flexible(child: SelectableText('${r['value']}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
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
                    if (before != null && after != null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color(0xFF11A06B).withOpacity(0.10), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF11A06B).withOpacity(0.35))),
                        child: Row(
                          children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Balance Before', style: TextStyle(fontSize: 11.5, color: Colors.black54)), const SizedBox(height: 2), FittedBox(fit: BoxFit.scaleDown, child: Text(before, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)))])),
                            const Icon(Icons.arrow_forward_rounded, color: Color(0xFF0B7D55)),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('Balance After', style: TextStyle(fontSize: 11.5, color: Colors.black54)), const SizedBox(height: 2), FittedBox(fit: BoxFit.scaleDown, child: Text(after, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0B7D55))))])),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),
                    const Text('Thank you for using KATSINASUB', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    const Padding(padding: EdgeInsets.fromLTRB(0, 2, 0, 18), child: Text('katsinasub.com', style: TextStyle(fontSize: 11.5, color: Colors.black45))),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _downloading ? null : _downloadReceipt,
          icon: _downloading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.download),
          label: Text(_downloading ? 'Preparing...' : 'Download Receipt'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => showSupportMenu(context),
          icon: const Icon(Icons.support_agent),
          label: const Text('Need help with this transaction?'),
        ),
      ],
    );
  }
}
