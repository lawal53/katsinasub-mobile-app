import 'package:flutter/material.dart';
import '../services/api_service.dart';
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

  final _currentPasswordForPinCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  bool _pinBusy = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
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
      currentPassword: _currentPasswordForPinCtrl.text,
      newPin: _newPinCtrl.text,
      confirmPin: _confirmPinCtrl.text,
    );
    setState(() => _pinBusy = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Done')));
    if (res['success'] == true) {
      _currentPasswordForPinCtrl.clear();
      _newPinCtrl.clear();
      _confirmPinCtrl.clear();
    }
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(controller: _currentPasswordCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Current Password', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: _newPasswordCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: _confirmPasswordCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm New Password', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _passwordBusy ? null : _changePassword,
                    child: _passwordBusy ? const CircularProgressIndicator() : const Text('Change Password'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Set / Change Transaction PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text('Your PIN confirms transactions. Enter your password to set a new one.', style: TextStyle(fontSize: 12.5)),
                  const SizedBox(height: 12),
                  TextField(controller: _currentPasswordForPinCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Current Password', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: _newPinCtrl, obscureText: true, maxLength: 4, decoration: const InputDecoration(labelText: 'New PIN (4 digits)', border: OutlineInputBorder())),
                  TextField(controller: _confirmPinCtrl, obscureText: true, maxLength: 4, decoration: const InputDecoration(labelText: 'Confirm New PIN', border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _pinBusy ? null : _changePin,
                    child: _pinBusy ? const CircularProgressIndicator() : const Text('Save PIN'),
                  ),
                ],
              ),
            ),
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
                  const Text('App din zai kulle bayan mintuna 5 na rashin aiki dashi. Shigar da PIN dinku don bude shi.', style: TextStyle(fontSize: 12.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
