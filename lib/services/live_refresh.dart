import 'package:flutter/widgets.dart';

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
