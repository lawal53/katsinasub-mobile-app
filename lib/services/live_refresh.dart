import 'package:flutter/material.dart';

import 'api_cache.dart';

/// Add `with LiveRefresh` to a screen's State and implement [onLiveRefresh] (re-read the data
/// quietly, no spinner). It runs whenever the app's background refresh, pull-to-refresh, or a
/// page's own background fetch brings in changed data.
mixin LiveRefresh<T extends StatefulWidget> on State<T> {
  void onLiveRefresh();

  void _liveTick() {
    if (mounted) onLiveRefresh();
  }

  @override
  void initState() {
    super.initState();
    ApiCache.refreshTick.addListener(_liveTick);
  }

  @override
  void dispose() {
    ApiCache.refreshTick.removeListener(_liveTick);
    super.dispose();
  }
}

/// The small message at the bottom after a pull-to-refresh.
void showRefreshResult(BuildContext context, bool ok) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(ok ? 'Updated just now' : 'No connection. Showing your saved data.'),
    duration: const Duration(seconds: 2),
    behavior: SnackBarBehavior.floating,
  ));
}
