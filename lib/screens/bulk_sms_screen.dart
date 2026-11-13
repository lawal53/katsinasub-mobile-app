import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../currency.dart';
import '../widgets/pin_field.dart';
import '../purchase_result.dart';
import '../services/api_service.dart';

class BulkSmsScreen extends StatefulWidget {
  const BulkSmsScreen({super.key});
  @override
  State<BulkSmsScreen> createState() => _BulkSmsScreenState();
}

class _BulkSmsScreenState extends State<BulkSmsScreen> {
  final _api = ApiService();
  final _senderCtrl = TextEditingController();
  final _recipientsCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _busy = false;
  double _pricePerUnit = 3.5; // sensible default until _loadInfo() returns

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final res = await _api.bulkSmsInfo();
    if (res['success'] == true && mounted) {
      setState(() => _pricePerUnit = (res['price_per_unit'] as num).toDouble());
      if (_senderCtrl.text.isEmpty && res['sender_id'] != null) {
        _senderCtrl.text = '${res['sender_id']}';
      }
    }
  }

  int get _recipientCount {
    final parts = _recipientsCtrl.text.trim().split(RegExp(r'[\s,]+'));
    final valid = parts.where((p) => RegExp(r'^0[789][01]\d{8}$').hasMatch(p));
    return valid.toSet().length;
  }

  // Same formula as the website: one "page" per 160 characters, and the
  // amount deducted is pages × recipients × price-per-unit.
  int get _pages => (_messageCtrl.text.length / 160).ceil().clamp(1, 1000000);

  double get _amount => _pages * _recipientCount * _pricePerUnit;

  Future<void> _submit() async {
    setState(() => _busy = true);
    final res = await _api.buyBulkSms(
      senderId: _senderCtrl.text.trim(),
      message: _messageCtrl.text,
      recipients: _recipientsCtrl.text,
      transactionPin: _pinCtrl.text,
    );
    setState(() => _busy = false);
    if (!mounted) return;
    await showPurchaseResult(context, res);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bulk SMS')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Price: ₦${nairaAmount(_pricePerUnit)} per SMS page, per recipient', style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
          const SizedBox(height: 8),
          TextField(
            controller: _senderCtrl,
            maxLength: 11,
            decoration: InputDecoration(labelText: tr('Sender ID (optional)'), border: OutlineInputBorder()),
          ),
          TextField(
            controller: _recipientsCtrl,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: tr('Phone Numbers (comma or newline separated)'), hintText: tr('08012345678, 08087654321'), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageCtrl,
            maxLines: 4,
            maxLength: 640,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: tr('Message'), border: OutlineInputBorder()),
          ),
          PinField(controller: _pinCtrl),
          const SizedBox(height: 8),
          Text('Sending to $_recipientCount valid number(s)'),
          const SizedBox(height: 12),
          // Same live "Amount to be deducted" summary the website shows,
          // updating as the customer types recipients/message.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFFE4F5E9), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Amount to be deducted'),
                Text('₦${nairaAmount(_amount)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy ? const CircularProgressIndicator() : const Text('Send SMS'),
          ),
        ],
      ),
    );
  }
}
