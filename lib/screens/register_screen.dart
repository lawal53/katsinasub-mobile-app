import 'package:flutter/material.dart' hide Text;
import 'package:device_info_plus/device_info_plus.dart';
import '../password_rules.dart';
import 'checkout_webview_screen.dart';
import '../l10n.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'dashboard_screen.dart';
import '../widgets/phone_field.dart';

class RegisterScreen extends StatefulWidget {
  final String? referralCode;
  const RegisterScreen({super.key, this.referralCode});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _api = ApiService();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _referralCode = TextEditingController();

  @override
  void initState() {
    super.initState();
    if ((widget.referralCode ?? '').isNotEmpty) _referralCode.text = widget.referralCode!;
  }
  bool _loading = false;
  bool _acceptTerms = false;
  String? _error;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  Future<void> _submit() async {
    final problem = passwordProblem(_password.text, username: _username.text.trim(), email: _email.text.trim(), phone: _phone.text.trim(), name: _fullName.text.trim());
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Password and Confirm Password do not match.');
      return;
    }
    if (!_acceptTerms) {
      setState(() => _error = 'Please read and accept the Terms and Conditions to create your account.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    String? deviceId;
    try {
      // One welcome reward per phone: the phone's own Android ID identifies it.
      deviceId = (await DeviceInfoPlugin().androidInfo).id;
    } catch (_) {}
    final res = await _api.register(
      fullName: _fullName.text.trim(),
      username: _username.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
      confirmPassword: _confirm.text,
      referralCode: _referralCode.text.trim(),
      deviceId: deviceId,
      acceptTerms: _acceptTerms,
    );
    setState(() => _loading = false);
    if (res['success'] == true) {
      try { await NotificationService().initAndRegister(); } catch (e) { /* push is optional */ }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const DashboardScreen()), (r) => false);
    } else {
      setState(() => _error = res['message'] ?? 'Registration failed.');
    }
  }

  Widget _field(TextEditingController c, String label, {bool obscure = false, TextInputType? type, VoidCallback? onToggleObscure}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          obscureText: obscure,
          keyboardType: type,
          decoration: InputDecoration(
            labelText: tr(label),
            border: const OutlineInputBorder(),
            suffixIcon: onToggleObscure == null ? null : IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: onToggleObscure,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],
            _field(_fullName, 'Full Name'),
            _field(_username, 'Username'),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: PhoneField(controller: _phone, labelText: tr('Phone Number'))),
            _field(_email, 'Email', type: TextInputType.emailAddress),
            _field(_password, 'Password', obscure: _obscurePassword, onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword)),
            const Padding(
              padding: EdgeInsets.only(bottom: 12, left: 4),
              child: Text('At least 8 characters, mixing letters and numbers, for example Kasuwa@2026. Simple ones like 12345678 are not accepted.', style: TextStyle(fontSize: 12.5)),
            ),
            _field(_confirm, 'Confirm Password', obscure: _obscureConfirm, onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm)),
            _field(_referralCode, 'Referral Code (optional)'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Checkbox(value: _acceptTerms, onChanged: (v) => setState(() => _acceptTerms = v ?? false)),
                Expanded(
                  child: Wrap(
                    children: [
                      const Text('I agree to the '),
                      InkWell(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const CheckoutWebViewScreen(
                            url: 'https://katsinasub.com/terms-and-conditions.php',
                            title: 'Terms and Conditions',
                            lockHosts: ['katsinasub.com', 'www.katsinasub.com'],
                          ),
                        )),
                        child: Text('Terms and Conditions', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
                      ),
                      const Text('.'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading ? const CircularProgressIndicator() : const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }
}
