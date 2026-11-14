import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../purchase_result.dart';
import '../services/api_service.dart';
import '../widgets/phone_field.dart';
import '../widgets/pin_field.dart';

/// Data / airtime reward: the customer types (or picks) a phone number, enters
/// the PIN, and the reward is sent. Nothing is taken from their wallet.
class RedeemRewardScreen extends StatefulWidget {
  final Map<String, dynamic> reward;
  final List<String> networks;
  const RedeemRewardScreen({super.key, required this.reward, required this.networks});
  @override
  State<RedeemRewardScreen> createState() => _RedeemRewardScreenState();
}

class _RedeemRewardScreenState extends State<RedeemRewardScreen> {
  final _api = ApiService();
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  String? _network;
  bool _busy = false;

  bool get _isAirtime => widget.reward['type'] == 'airtime';

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _send({bool confirm = false}) async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 11) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid phone number (e.g. 08012345678).')));
      return;
    }
    if (_isAirtime && _network == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please choose a network.')));
      return;
    }
    if (_pinCtrl.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your 4-digit transaction PIN.')));
      return;
    }
    setState(() => _busy = true);
    Map<String, dynamic> res;
    try {
      res = await _api.redeemReward(id: widget.reward['id'] as int, phone: phone, network: _network ?? '', pin: _pinCtrl.text, confirmMismatch: confirm);
    } catch (_) {
      res = {'success': false, 'message': 'Could not reach the server. Please check your connection and try again. Your reward was not used.'};
    }
    if (!mounted) return;
    setState(() => _busy = false);

    if (res['mismatch'] == true) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Check the number'),
          content: Text('${res['message']}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Change number')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue anyway')),
          ],
        ),
      );
      if (go == true && mounted) await _send(confirm: true);
      return;
    }
    final ok = res['success'] == true;
    await showPurchaseResult(context, res, onOk: () {
      if (ok && mounted) Navigator.pop(context, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Use Reward')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: cs.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(_isAirtime ? Icons.phone_android : Icons.wifi, size: 34, color: cs.primary),
                  const SizedBox(width: 14),
                  Expanded(child: Text('${widget.reward['title']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (_isAirtime) ...[
            DropdownButtonFormField<String>(
              value: _network,
              decoration: InputDecoration(labelText: tr('Network'), border: const OutlineInputBorder()),
              items: [for (final n in widget.networks) DropdownMenuItem(value: n, child: Text(n))],
              onChanged: (v) => setState(() => _network = v),
            ),
            const SizedBox(height: 14),
          ] else if ((widget.reward['network'] ?? '').toString().isNotEmpty) ...[
            Text('This data is for ${widget.reward['network']} numbers.', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
          ],
          PhoneField(controller: _phoneCtrl, labelText: tr('Phone Number'), hintText: '08012345678'),
          const SizedBox(height: 14),
          PinField(controller: _pinCtrl),
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _busy ? null : _send,
            child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Send Reward'),
          ),
        ],
      ),
    );
  }
}
