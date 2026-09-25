import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
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
import 'fund_wallet_screen.dart';
import 'checkout_webview_screen.dart';
import 'fund_wallet_screen.dart';
import 'support_menu.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _user;
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

  // The hide/show choice survives closing and reopening the app: once the
  // balance is hidden it stays hidden until the customer reveals it.
  Future<void> _restoreBalanceHidden() async {
    try {
      final v = await _secure.read(key: _hideKey);
      if (mounted && v == '1') setState(() => _balanceHidden = true);
    } catch (_) {}
  }

  Future<void> _toggleBalanceHidden() async {
    setState(() => _balanceHidden = !_balanceHidden);
    try { await _secure.write(key: _hideKey, value: _balanceHidden ? '1' : '0'); } catch (_) {}
  }

  Future<void> _load() async {
    final meRes = await _api.me();
    setState(() {
      _user = meRes['success'] == true ? meRes['user'] : null;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    await _api.logout(fcmToken: NotificationService().currentToken);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
  }

  // Every "Services" tile and every drawer item goes through this so the
  // wallet balance badge refreshes the moment you're back on the dashboard.
  Future<void> _openAndRefresh(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final unread = (_user?['unread_notifications'] ?? 0) as int;
    final balanceText = _balanceHidden ? '****' : '\u20a6${_user?['wallet_balance']}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${_user?['full_name']?.split(' ')?.first ?? ''}'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => _openAndRefresh(const NotificationsScreen()),
              ),
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
      floatingActionButton: Stack(
        alignment: Alignment.topRight,
        children: [
          FloatingActionButton(
            onPressed: () => showSupportMenu(context),
            tooltip: tr('Get Help'),
            child: const Icon(Icons.chat_bubble_outline),
          ),
          if (((_user?['unread_chat'] ?? 0) as int) > 0)
            Container(
              margin: const EdgeInsets.only(top: 2, right: 2),
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: Text('${_user?['unread_chat']}', style: const TextStyle(color: Colors.white, fontSize: 10)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Wallet Balance'),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: _toggleBalanceHidden,
                          child: Icon(_balanceHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 16),
                        ),
                      ],
                    ),
                    Text(balanceText, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _openAndRefresh(const FundWalletScreen()),
                            child: const Text('Fund Wallet'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _openAndRefresh(const WalletSummaryScreen()),
                            child: const Text('Wallet Summary'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildQuickFundAndTier(),
            const SizedBox(height: 20),
            const Text('Services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (context, constraints) {
              // 3 tiles/row on a normal phone; more on a wide screen
              // or tablet, so tiles don't stretch huge and ugly.
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 900 ? 6 : (width >= 600 ? 5 : 3);
              return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
              children: [
                _serviceTile(Icons.sim_card_outlined, 'Data', () => _openAndRefresh(const BuyDataScreen())),
                _serviceTile(Icons.phone_android, 'Airtime', () => _openAndRefresh(const BuyAirtimeScreen())),
                _serviceTile(Icons.tv, 'Cable TV', () => _openAndRefresh(const BuyCableScreen())),
                _serviceTile(Icons.bolt, 'Electricity', () => _openAndRefresh(const BuyElectricityScreen())),
                _serviceTile(Icons.school, 'Exam Pins', () => _openAndRefresh(const BuyExamPinScreen())),
                _serviceTile(Icons.sms, 'Bulk SMS', () => _openAndRefresh(const BulkSmsScreen())),
                _serviceTile(Icons.badge, 'NIN Verify', () => _openAndRefresh(const NinVerificationScreen())),
                _serviceTile(Icons.badge_outlined, 'BVN Verify', () => _openAndRefresh(const BvnVerificationScreen())),
                _serviceTile(Icons.print, 'Recharge Card', () => _openAndRefresh(const CardPrintingScreen(cardType: 'recharge'))),
                _serviceTile(Icons.sim_card, 'Data Card', () => _openAndRefresh(const CardPrintingScreen(cardType: 'data'))),
                _serviceTile(Icons.currency_exchange, 'Airtime2Cash', () => _openAndRefresh(const AirtimeToCashScreen())),
                _serviceTile(Icons.card_giftcard, 'Bonus Transfer', () => _openAndRefresh(const BonusTransferScreen())),
                _serviceTile(Icons.share, 'Referral', () => _openAndRefresh(const ReferralScreen())),
                _serviceTile(Icons.history, 'History', () => _openAndRefresh(const WalletSummaryScreen())),
              ],
              );
            }),
          ],
        ),
      ),
    );
  }

  // Same colourful icons the website dashboard uses.
  static const Map<String, String> _emojiIcons = {
    'Data': '📶', 'Airtime': '📱', 'Cable TV': '📺', 'Electricity': '💡',
    'Exam Pins': '🎓', 'Bulk SMS': '💬', 'NIN Verify': '🆔', 'BVN Verify': '🏦',
    'Recharge Card': '🖨️', 'Data Card': '🖨️', 'Airtime2Cash': '💵',
    'Bonus Transfer': '🎁', 'Referral': '👥', 'History': '🧾',
  };


  // Small "Payment Methods" + "Current Package" summary — same info the
  // website shows on its dashboard, kept compact rather than as a big card.
  Widget _buildQuickFundAndTier() {
    final tier = '${_user?['account_type'] ?? 'regular'}';
    final tierDesc = tier == 'api'
        ? "You're on the API tier — you get the best pricing across the platform."
        : tier == 'agent'
            ? "You're on the Agent tier — you enjoy discounted pricing compared to regular users."
            : "You're on the Regular tier. Upgrade your account to enjoy more discounts.";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openAndRefresh(const FundWalletScreen()),
                icon: const Icon(Icons.credit_card, size: 18),
                label: const Text('Pay with Card'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openAndRefresh(const FundWalletScreen()),
                icon: const Icon(Icons.account_balance, size: 18),
                label: const Text('Bank Transfer'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Package: ${tier.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text(tierDesc, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _serviceTile(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _emojiIcons.containsKey(label)
                  ? Text(_emojiIcons[label]!, style: const TextStyle(fontSize: 26))
                  : Icon(icon, size: 26),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
            ],
          ),
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
