import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../services/api_service.dart';
import '../services/lock_service.dart';
import '../services/purchase_pin_service.dart';
import 'delete_account_screen.dart';
import 'verify_contact_screen.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});
  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _user;

  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _passwordBusy = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  // Which form is open: only one at a time ('pin' or 'password'), or none.
  String? _openSection;

  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  bool _pinBusy = false;
  bool _obscureNewPin = true;
  bool _obscureConfirmPin = true;

  final _lock = LockService.instance;
  bool _biometricOn = false;
  bool _biometricBusy = false;

  final _purchasePin = PurchasePinService();
  bool _purchaseFingerprintOn = false;
  bool _purchaseFingerprintBusy = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _lock.biometricEnabled.then((v) { if (mounted) setState(() => _biometricOn = v); });
    _purchasePin.isEnabled().then((v) { if (mounted) setState(() => _purchaseFingerprintOn = v); });
  }

  Future<void> _loadUser() async {
    final res = await _api.me();
    if (res['success'] == true) setState(() => _user = res['user']);
  }

  Future<void> _changePassword() async {
    setState(() => _passwordBusy = true);
    final res = await _api.changePassword(
      currentPassword: _currentPasswordCtrl.text,
      newPassword: _newPasswordCtrl.text,
      confirmPassword: _confirmPasswordCtrl.text,
    );
    setState(() => _passwordBusy = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Done')));
    if (res['success'] == true) {
      _currentPasswordCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
    }
  }

  Future<void> _changePin() async {
    setState(() => _pinBusy = true);
    final res = await _api.changePin(
      newPin: _newPinCtrl.text,
      confirmPin: _confirmPinCtrl.text,
    );
    setState(() => _pinBusy = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Done')));
    if (res['success'] == true) {
      _newPinCtrl.clear();
      _confirmPinCtrl.clear();
    }
  }

  Future<void> _onBiometricToggle(bool wantOn) async {
    if (!wantOn) {
      await _lock.disableBiometric();
      setState(() => _biometricOn = false);
      return;
    }
    final canAuth = await _lock.canUseBiometrics();
    if (!canAuth) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No fingerprint or face is enrolled on this phone. Go to your phone Settings to set one up first.'),
      ));
      return;
    }
    final pin = await _promptForPin();
    if (pin == null) return; // canceled
    setState(() => _biometricBusy = true);
    final valid = await _lock.verifyPin(pin);
    if (!valid) {
      setState(() => _biometricBusy = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect PIN.')));
      return;
    }
    try {
      await _lock.enableBiometric(); // this itself prompts for a fingerprint scan
      setState(() { _biometricOn = true; _biometricBusy = false; });
    } catch (e) {
      setState(() => _biometricBusy = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not enable fingerprint: $e')));
    }
  }

  Future<void> _onPurchaseFingerprintToggle(bool wantOn) async {
    if (!wantOn) {
      await _purchasePin.disable();
      setState(() => _purchaseFingerprintOn = false);
      return;
    }
    final canAuth = await _purchasePin.canUseBiometrics();
    if (!canAuth) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No fingerprint or face is enrolled on this phone. Go to your phone Settings to set one up first.'),
      ));
      return;
    }
    final pin = await _promptForPin();
    if (pin == null) return; // canceled
    setState(() => _purchaseFingerprintBusy = true);
    final valid = await _lock.verifyPin(pin);
    if (!valid) {
      setState(() => _purchaseFingerprintBusy = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect PIN.')));
      return;
    }
    final ok = await _purchasePin.enable(pin); // itself prompts for a fingerprint scan
    setState(() { _purchaseFingerprintOn = ok; _purchaseFingerprintBusy = false; });
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not enable fingerprint')));
    }
  }

  Future<String?> _promptForPin() async {
    final ctrl = TextEditingController();
    bool obscure = true;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Enter your PIN'),
          content: TextField(
            controller: ctrl, obscureText: obscure, maxLength: 4, keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: tr('Transaction PIN'),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setDialogState(() => obscure = !obscure),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('OK')),
          ],
        ),
      ),
    );
  }

  Widget _sectionButton(String key, IconData icon, String label) {
    final selected = _openSection == key;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 56,
      child: selected
          ? FilledButton.icon(
              onPressed: () => setState(() => _openSection = null),
              icon: Icon(icon, size: 20),
              label: Text(label, textAlign: TextAlign.center),
            )
          : OutlinedButton.icon(
              style: OutlinedButton.styleFrom(side: BorderSide(color: scheme.primary.withOpacity(0.6))),
              onPressed: () => setState(() => _openSection = key),
              icon: Icon(icon, size: 20),
              label: Text(label, textAlign: TextAlign.center),
            ),
    );
  }

  Widget _passwordCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(controller: _currentPasswordCtrl, obscureText: _obscureCurrentPassword, decoration: InputDecoration(labelText: tr('Current Password'), border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(_obscureCurrentPassword ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword)))),
            const SizedBox(height: 10),
            TextField(controller: _newPasswordCtrl, obscureText: _obscureNewPassword, decoration: InputDecoration(labelText: tr('New Password'), border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(_obscureNewPassword ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword)))),
            const SizedBox(height: 10),
            TextField(controller: _confirmPasswordCtrl, obscureText: _obscureConfirmPassword, decoration: InputDecoration(labelText: tr('Confirm New Password'), border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)))),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _passwordBusy ? null : _changePassword,
              child: _passwordBusy ? const CircularProgressIndicator() : const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pinCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Set / Change Transaction PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Your PIN confirms transactions. Choose a 4-digit PIN, confirm it, then save.', style: TextStyle(fontSize: 12.5)),
            const SizedBox(height: 12),
            TextField(controller: _newPinCtrl, obscureText: _obscureNewPin, maxLength: 4, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('New PIN (4 digits)'), border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(_obscureNewPin ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscureNewPin = !_obscureNewPin)))),
            TextField(controller: _confirmPinCtrl, obscureText: _obscureConfirmPin, maxLength: 4, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('Confirm New PIN'), border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(_obscureConfirmPin ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscureConfirmPin = !_obscureConfirmPin)))),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _pinBusy ? null : _changePin,
              child: _pinBusy ? const CircularProgressIndicator() : const Text('Save PIN'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_user != null && (_user!['email_verified'] == false || _user!['phone_verified'] == false))
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Verify Your Contact Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    if (_user!['email_verified'] == false)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.email_outlined),
                        label: const Text('Verify Email'),
                        onPressed: () async {
                          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VerifyContactScreen(type: 'email')));
                          _loadUser();
                        },
                      ),
                    if (_user!['phone_verified'] == false) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.phone_outlined),
                        label: const Text('Verify Phone'),
                        onPressed: () async {
                          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VerifyContactScreen(type: 'phone')));
                          _loadUser();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (_user != null && (_user!['email_verified'] == false || _user!['phone_verified'] == false)) const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _sectionButton('pin', Icons.pin_outlined, 'Set / Change PIN')),
              const SizedBox(width: 12),
              Expanded(child: _sectionButton('password', Icons.lock_outline, 'Change Password')),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _openSection == 'pin'
                ? _pinCard()
                : _openSection == 'password'
                    ? _passwordCard()
                    : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Security', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text('The app locks after 5 minutes of inactivity. Enable fingerprint to unlock quickly instead of typing your PIN.', style: TextStyle(fontSize: 12.5)),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fingerprint Unlock'),
                    subtitle: const Text('If the fingerprints on this phone change, you will need to re-enable this with your PIN.', style: TextStyle(fontSize: 11.5)),
                    value: _biometricOn,
                    onChanged: _biometricBusy ? null : _onBiometricToggle,
                  ),
                  if (_biometricBusy) const Padding(padding: EdgeInsets.only(top: 4), child: LinearProgressIndicator()),
                  const Divider(height: 28),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fingerprint for Purchases'),
                    subtitle: const Text('Confirm purchases with your fingerprint instead of typing your transaction PIN.', style: TextStyle(fontSize: 11.5)),
                    value: _purchaseFingerprintOn,
                    onChanged: _purchaseFingerprintBusy ? null : _onPurchaseFingerprintToggle,
                  ),
                  if (_purchaseFingerprintBusy) const Padding(padding: EdgeInsets.only(top: 4), child: LinearProgressIndicator()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700, side: BorderSide(color: Colors.red.shade300), minimumSize: const Size.fromHeight(50)),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DeleteAccountScreen())),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete Account'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
