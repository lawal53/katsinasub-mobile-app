import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import 'home_tab.dart';
import 'wallet_summary_screen.dart';
import 'rewards_screen.dart';
import 'support_screen.dart';
import 'profile_screen.dart';

/// The app's main screen: Home, History, Reward (centre), Support, Profile.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _index = 0;
  final _visited = <bool>[true, false, false, false, false];

  void _go(int i) => setState(() { _index = i; _visited[i] = true; });

  Widget _page(int i) {
    if (!_visited[i]) return const SizedBox.shrink();
    switch (i) {
      case 0: return HomeTab(onSelectTab: _go);
      case 1: return const WalletSummaryScreen();
      case 2: return const RewardsScreen();
      case 3: return const SupportScreen();
      default: return const ProfileScreen();
    }
  }

  Widget _navItem(int i, IconData icon, IconData activeIcon, String label) {
    final cs = Theme.of(context).colorScheme;
    final sel = _index == i;
    return Expanded(
      child: InkWell(
        onTap: () => _go(i),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(sel ? activeIcon : icon, color: sel ? cs.primary : Colors.grey.shade600, size: 26),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(fontSize: 11.5, fontWeight: sel ? FontWeight.w800 : FontWeight.w500, color: sel ? cs.primary : Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _go(0); },
      child: Scaffold(
        body: IndexedStack(index: _index, children: [for (var i = 0; i < 5; i++) _page(i)]),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -2))],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _navItem(0, Icons.home_outlined, Icons.home, 'Home'),
                  _navItem(1, Icons.history, Icons.history, 'History'),
                  Expanded(
                    child: InkWell(
                      onTap: () => _go(2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.translate(
                            offset: const Offset(0, -14),
                            child: Container(
                              width: 58, height: 58,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: [cs.primary, cs.primary.withOpacity(0.75)]),
                                border: Border.all(color: Theme.of(context).colorScheme.surface, width: 4),
                                boxShadow: [BoxShadow(color: cs.primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                              ),
                              child: const Icon(Icons.card_giftcard, color: Colors.white, size: 28),
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(0, -12),
                            child: Text('Reward', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _index == 2 ? cs.primary : Colors.grey.shade700)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _navItem(3, Icons.headset_mic_outlined, Icons.headset_mic, 'Support'),
                  _navItem(4, Icons.person_outline, Icons.person, 'Profile'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
