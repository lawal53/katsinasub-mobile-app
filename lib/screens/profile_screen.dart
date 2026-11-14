import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'account_settings_screen.dart';
import 'bonus_transfer_screen.dart';
import 'checkout_webview_screen.dart';
import 'notifications_screen.dart';
import 'referral_screen.dart';
import 'welcome_screen.dart';

/// Profile tab: the account, settings and sign-out in one place.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _api.me();
      if (mounted && r['success'] == true) setState(() => _user = r['user']);
    } catch (_) {}
  }

  Future<void> _open(Widget w) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    _load();
  }

  Future<void> _logout() async {
    await _api.logout(fcmToken: NotificationService().currentToken);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const WelcomeScreen()), (r) => false);
  }

  Widget _item(IconData icon, String label, VoidCallback onTap, {Color? color}) => ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = '${_user?['full_name'] ?? ''}';
    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), automaticallyImplyLeading: false),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(22)),
              child: Row(
                children: [
                  CircleAvatar(radius: 28, backgroundColor: cs.primary, child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Text('${_user?['email'] ?? ''}', style: const TextStyle(fontSize: 12.5)),
                        Text('Package: ${'${_user?['account_type'] ?? 'regular'}'.toUpperCase()}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _item(Icons.settings_outlined, 'Account Settings', () => _open(const AccountSettingsScreen())),
            _item(Icons.share_outlined, 'Referral', () => _open(const ReferralScreen())),
            _item(Icons.card_giftcard, 'Bonus Transfer', () => _open(const BonusTransferScreen())),
            _item(Icons.notifications_outlined, 'Notifications', () => _open(const NotificationsScreen())),
            _item(Icons.language, 'Language', () async { await showLanguagePicker(context); if (mounted) setState(() {}); }),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: AppTheme.notifier,
              builder: (context, mode, _) => SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Dark mode', style: TextStyle(fontWeight: FontWeight.w600)),
                value: mode == ThemeMode.dark,
                onChanged: (_) => AppTheme.toggle(),
              ),
            ),
            _item(Icons.privacy_tip_outlined, 'Privacy Policy', () => _open(const CheckoutWebViewScreen(url: 'https://katsinasub.com/privacy-policy.php', title: 'Privacy Policy', lockHosts: ['katsinasub.com', 'www.katsinasub.com']))),
            _item(Icons.description_outlined, 'Terms and Conditions', () => _open(const CheckoutWebViewScreen(url: 'https://katsinasub.com/terms-and-conditions.php', title: 'Terms and Conditions', lockHosts: ['katsinasub.com', 'www.katsinasub.com']))),
            const Divider(),
            _item(Icons.logout, 'Logout', _logout, color: Colors.red),
          ],
        ),
      ),
    );
  }
}
