import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../services/purchase_pin_service.dart';

/// The transaction-PIN field used on every purchase screen. Same as a
/// plain PIN TextField, but with a fingerprint button that fills the PIN
/// in automatically once fingerprint-for-purchases has been turned on in
/// Account Settings.
class PinField extends StatefulWidget {
  final TextEditingController controller;
  const PinField({super.key, required this.controller});

  @override
  State<PinField> createState() => _PinFieldState();
}

class _PinFieldState extends State<PinField> {
  bool _fingerprintOn = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    PurchasePinService().isEnabled().then((v) {
      if (mounted) setState(() => _fingerprintOn = v);
    });
  }

  Future<void> _useFingerprint() async {
    setState(() => _busy = true);
    final pin = await PurchasePinService().getPinViaFingerprint();
    if (!mounted) return;
    setState(() => _busy = false);
    if (pin != null) {
      widget.controller.text = pin;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: tr('Transaction PIN'),
        border: const OutlineInputBorder(),
        suffixIcon: _fingerprintOn
            ? IconButton(
                icon: _busy
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.fingerprint),
                onPressed: _busy ? null : _useFingerprint,
                tooltip: 'Use fingerprint',
              )
            : null,
      ),
    );
  }
}
