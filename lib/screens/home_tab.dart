import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import '../currency.dart';
import '../theme.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'wallet_summary_screen.dart';
import 'buy_data_screen.dart';
import 'buy_airtime_screen.dart';
import 'buy_cable_screen.dart';
import 'buy_electricity_screen.dart';
import 'buy_exam_pin_screen.dart';
import 'bulk_sms_screen.dart';
import 'nin_verification_screen.dart';
import 'bvn_verification_screen.dart';
import 'card_printing_screen.dart';
import 'airtime_to_cash_screen.dart';
import 'bonus_transfer_screen.dart';
import 'account_settings_screen.dart';
import 'referral_screen.dart';
import 'notifications_screen.dart';
import 'verify_contact_screen.dart';
import 'fund_wallet_screen.dart';
import 'transfer_screen.dart';
import 'checkout_webview_screen.dart';
import 'fund_wallet_screen.dart';
import 'support_menu.dart';
import 'welcome_screen.dart';

import 'rewards_screen.dart';
import '../widgets/marquee_banner.dart';

class HomeTab extends StatefulWidget {
  final void Function(int) onSelectTab;
  const HomeTab({super.key, required this.onSelectTab});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _api = ApiService();
  Map<String, dynamic>? _user;
  String _notice = '';
  bool _loading = true;
  bool _balanceHidden = false;
  static const _hideKey = 'balance_hidden';
  static const _secure = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _restoreBalanceHidden();
    _load();
  }

  Future<void> _restoreBalanceHidden() async {
    try {
      final v = await _secure.read(key: _hideKey);
      if (mounted && v == '1') setState(() => _balanceHidden = true);
    } catch (_) {}
  }

  // Hides the wallet balance AND the bonus balance together.
  Future<void> _toggleBalanceHidden() async {
    setState(() => _balanceHidden = !_balanceHidden);
    try { await _secure.write(key: _hideKey, value: _balanceHidden ? '1' : '0'); } catch (_) {}
  }

  Future<void> _load() async {
    final meRes = await _api.me();
    if (!mounted) return;
    setState(() {
      _user = meRes['success'] == true ? meRes['user'] : null;
      _notice = meRes['success'] == true ? '${meRes['home_notice'] ?? ''}'.trim() : '';
      _loading = false;
    });
  }

  Future<void> _logout() async {
    await _api.logout(fcmToken: NotificationService().currentToken);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const WelcomeScreen()), (r) => false);
  }

  Future<void> _openAndRefresh(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  void _comingSoon(String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: const Text('This feature is coming soon.'),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  void _chooser(String title, List<(IconData, String, VoidCallback)> options) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(padding: const EdgeInsets.all(16), child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            for (final o in options)
              ListTile(
                leading: Icon(o.$1),
                title: Text(o.$2),
                onTap: () { Navigator.pop(ctx); o.$3(); },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final cs = Theme.of(context).colorScheme;
    final unread = (_user?['unread_notifications'] ?? 0) as int;
    final balanceText = _balanceHidden ? '****' : '\u20a6${nairaAmount(_user?['wallet_balance'])}';
    final bonus = double.tryParse('${_user?['bonus_balance'] ?? 0}') ?? 0;
    final bonusText = _balanceHidden ? 'Bonus: ****' : 'Bonus: ₦${nairaAmount(_user?['bonus_balance'])}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${_user?['full_name']?.split(' ')?.first ?? ''}'),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: AppTheme.notifier,
            builder: (context, mode, __) => IconButton(
              icon: Icon(mode == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
              tooltip: 'Dark mode',
              onPressed: AppTheme.toggle,
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => _openAndRefresh(const NotificationsScreen())),
              if (unread > 0)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 9)),
                  ),
                ),
            ],
          ),
        ],
      ),
      drawer: _buildAccountDrawer(),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_notice.isNotEmpty) ...[MarqueeBanner(text: _notice), const SizedBox(height: 12)],
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [cs.primaryContainer, cs.primaryContainer.withOpacity(0.55)]),
                boxShadow: [BoxShadow(color: cs.primary.withOpacity(0.18), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Wallet Balance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      InkWell(onTap: _toggleBalanceHidden, child: Icon(_balanceHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(balanceText, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                  if (bonus > 0) ...[
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _openAndRefresh(const BonusTransferScreen()),
                      child: Text('$bonusText – tap to move to wallet', style: TextStyle(fontSize: 13, color: cs.primary, fontWeight: FontWeight.w700)),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                          onPressed: () => _openAndRefresh(const FundWalletScreen()),
                          child: const Text('Fund Wallet'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                          onPressed: () => _openAndRefresh(const WalletSummaryScreen()),
                          child: const Text('Summary'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: cs.primary.withOpacity(0.25)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Data Today ${_user?['data_usage']?['today'] ?? '0MB'}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                      Text('All Time ${_user?['data_usage']?['all_time'] ?? '0MB'}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_user?['email_verified'] == false)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFDF1D6), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Expanded(child: Text('Your email is not verified yet.', style: TextStyle(color: Colors.brown.shade800))),
                      TextButton(onPressed: () => _openAndRefresh(const VerifyContactScreen(type: 'email')), child: const Text('Verify now')),
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openAndRefresh(const TransferScreen()),
                    icon: const Icon(Icons.person_outline, size: 20),
                    label: const Text('Transfer', textAlign: TextAlign.center),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _comingSoon('Withdraw'),
                    icon: const Icon(Icons.account_balance, size: 20),
                    label: const Text('Withdraw'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _packageCard(),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Services', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                TextButton(
                  onPressed: () => _openAndRefresh(AllServicesScreen(onOpen: _openAndRefresh)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('View All', style: TextStyle(fontWeight: FontWeight.w800)), Icon(Icons.chevron_right)]),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LayoutBuilder(builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 900 ? 6 : (width >= 600 ? 5 : 3);
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.98,
                children: [
                  ServiceTile(emoji: '📶', label: 'Data', onTap: () => _openAndRefresh(const BuyDataScreen())),
                  ServiceTile(emoji: '📱', label: 'Airtime', onTap: () => _openAndRefresh(const BuyAirtimeScreen())),
                  ServiceTile(emoji: '📺', label: 'Cable TV', onTap: () => _openAndRefresh(const BuyCableScreen())),
                  ServiceTile(emoji: '💡', label: 'Electricity', onTap: () => _openAndRefresh(const BuyElectricityScreen())),
                  ServiceTile(emoji: '🎓', label: 'Exam Pins', onTap: () => _openAndRefresh(const BuyExamPinScreen())),
                  ServiceTile(emoji: '💬', label: 'Bulk SMS', onTap: () => _openAndRefresh(const BulkSmsScreen())),
                  ServiceTile(emoji: '🎁', label: 'Reward', onTap: () => widget.onSelectTab(2)),
                  ServiceTile(
                    icon: Icons.verified_user, iconColor: const Color(0xFF1B9E55), label: 'Bill Payment',
                    onTap: () => _chooser('Bill Payment', [
                      (Icons.tv, 'Cable TV', () => _openAndRefresh(const BuyCableScreen())),
                      (Icons.bolt, 'Electricity', () => _openAndRefresh(const BuyElectricityScreen())),
                    ]),
                  ),
                  ServiceTile(
                    icon: Icons.sync_alt, iconColor: const Color(0xFF1E6FD9), label: 'Money Transfer',
                    onTap: () => _chooser('Money Transfer', [
                      (Icons.person_outline, 'Transfer', () => _openAndRefresh(const TransferScreen())),
                      (Icons.account_balance, 'Withdraw to Bank (coming soon)', () => _comingSoon('Withdraw')),
                    ]),
                  ),
                ],
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _packageCard() {
    final tier = '${_user?['account_type'] ?? 'regular'}';
    final tierDesc = tier == 'api'
        ? "You're on the API tier – you get the best pricing across the platform."
        : tier == 'agent'
            ? "You're on the Agent tier – you enjoy discounted pricing compared to regular users."
            : "You're on the Regular tier. Upgrade your account to enjoy more discounts.";
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Current Package: ${tier.toUpperCase()}'),
          content: Text(tierDesc),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.45), borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Package: ${tier.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(tierDesc, style: const TextStyle(fontSize: 12.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_user?['full_name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(_user?['email'] ?? '', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Language'),
              onTap: () async { Navigator.pop(context); await showLanguagePicker(context); if (mounted) setState(() {}); },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Account Settings'),
              onTap: () { Navigator.pop(context); _openAndRefresh(const AccountSettingsScreen()); },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Transaction History'),
              onTap: () { Navigator.pop(context); _openAndRefresh(const WalletSummaryScreen()); },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text('Fund Wallet'),
              onTap: () { Navigator.pop(context); _openAndRefresh(const FundWalletScreen()); },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Referral'),
              onTap: () { Navigator.pop(context); _openAndRefresh(const ReferralScreen()); },
            ),
            ListTile(
              leading: const Icon(Icons.card_giftcard),
              title: const Text('Bonus Transfer'),
              onTap: () { Navigator.pop(context); _openAndRefresh(const BonusTransferScreen()); },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              onTap: () { Navigator.pop(context); _openAndRefresh(const NotificationsScreen()); },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Get Help'),
              onTap: () { Navigator.pop(context); showSupportMenu(context); },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy Policy'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CheckoutWebViewScreen(
                    url: 'https://katsinasub.com/privacy-policy.php',
                    title: 'Privacy Policy',
                  ),
                ));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }
}

/// One rounded service tile (emoji or icon + label).
class ServiceTile extends StatelessWidget {
  final String? emoji;
  final IconData? icon;
  final Color? iconColor;
  final String label;
  final VoidCallback onTap;
  const ServiceTile({super.key, this.emoji, this.icon, this.iconColor, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(20),
      elevation: 1.5,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              emoji != null ? Text(emoji!, style: const TextStyle(fontSize: 34)) : Icon(icon, size: 36, color: iconColor ?? cs.primary),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "View All": every service the app has.
class AllServicesScreen extends StatelessWidget {
  final Future<void> Function(Widget) onOpen;
  const AllServicesScreen({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    Future<void> go(Widget w) async {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    }
    final tiles = <ServiceTile>[
      ServiceTile(emoji: '📶', label: 'Data', onTap: () => go(const BuyDataScreen())),
      ServiceTile(emoji: '📱', label: 'Airtime', onTap: () => go(const BuyAirtimeScreen())),
      ServiceTile(emoji: '📺', label: 'Cable TV', onTap: () => go(const BuyCableScreen())),
      ServiceTile(emoji: '💡', label: 'Electricity', onTap: () => go(const BuyElectricityScreen())),
      ServiceTile(emoji: '🎓', label: 'Exam Pins', onTap: () => go(const BuyExamPinScreen())),
      ServiceTile(emoji: '💬', label: 'Bulk SMS', onTap: () => go(const BulkSmsScreen())),
      ServiceTile(emoji: '🆔', label: 'NIN Verify', onTap: () => go(const NinVerificationScreen())),
      ServiceTile(emoji: '🏦', label: 'BVN Verify', onTap: () => go(const BvnVerificationScreen())),
      ServiceTile(emoji: '🖨️', label: 'Recharge Card', onTap: () => go(const CardPrintingScreen(cardType: 'recharge'))),
      ServiceTile(emoji: '🖨️', label: 'Data Card', onTap: () => go(const CardPrintingScreen(cardType: 'data'))),
      ServiceTile(emoji: '💵', label: 'Airtime2Cash', onTap: () => go(const AirtimeToCashScreen())),
      ServiceTile(emoji: '🎁', label: 'Bonus Transfer', onTap: () => go(const BonusTransferScreen())),
      ServiceTile(emoji: '👥', label: 'Referral', onTap: () => go(const ReferralScreen())),
      ServiceTile(emoji: '🧾', label: 'History', onTap: () => go(const WalletSummaryScreen())),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('All Services')),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.98,
        children: tiles,
      ),
    );
  }
}
