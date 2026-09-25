import 'package:flutter/material.dart' hide Text;
import 'l10n.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/lock_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/lock_screen.dart';

/// Used by LockScreen to log out and reset to the Login screen from
/// outside the Navigator (LockScreen is overlaid above it via
/// MaterialApp's `builder`, so `Navigator.of(context)` from inside it
/// wouldn't find this app's Navigator).
final rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase.initializeApp() reads android/app/google-services.json (and
  // ios/Runner/GoogleService-Info.plist on iOS) automatically — see
  // MOBILE-PUSH-SETUP.md for how to generate those files. The app still
  // runs fine without them; push notifications just won't be delivered.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);
  } catch (e) {
    // Firebase not configured yet — everything else in the app still works.
  }

  await AppLang.load();
  runApp(const VtuApp());
}

class VtuApp extends StatefulWidget {
  const VtuApp({super.key});
  @override
  State<VtuApp> createState() => _VtuAppState();
}

/// Watches app lifecycle so the 5-minute inactivity lock (same rule as
/// the website) fires when the app comes back from the background,
/// and overlays [LockScreen] on top of whatever screen is showing —
/// without touching the Navigator stack underneath — via MaterialApp's
/// `builder`, so returning from the lock screen goes right back to
/// wherever the user was.
class _VtuAppState extends State<VtuApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      LockService.instance.onPause();
    } else if (state == AppLifecycleState.resumed) {
      LockService.instance.onResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Katsinasub',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF0F9D6B)),
      home: const _AppRoot(),
      builder: (context, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: LockService.instance.locked,
          builder: (context, isLocked, _) {
            final content = Stack(children: [
              if (child != null) child,
              if (isLocked) const LockScreen(),
            ]);
            // On a tablet or a very wide phone in landscape, cap the
            // content at a normal phone-ish width and center it — so
            // forms and buttons don't stretch edge-to-edge and look
            // stray/oversized. Small and normal phone screens are
            // narrower than the cap, so this is a no-op for them.
            return LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth <= 600) return content;
              return Container(
                color: Theme.of(context).colorScheme.surface,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: content,
                  ),
                ),
              );
            });
          },
        );
      },
    );
  }
}

/// Shows the branded splash first, then — once it finishes — checks
/// whether a login session is already saved and goes straight to the
/// dashboard if so, otherwise to Login. Either way, once we know a
/// session exists, register this device for push notifications.
class _AppRoot extends StatefulWidget {
  const _AppRoot();
  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(onFinished: () => setState(() => _showSplash = false));
    }
    return const _StartupGate();
  }
}

class _StartupGate extends StatefulWidget {
  const _StartupGate();
  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  final _api = ApiService();
  bool _checking = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _api.isLoggedIn().then((v) async {
      if (v) {
        try { await NotificationService().initAndRegister(); } catch (e) { /* push is optional */ }
        // Cold start with an already-saved session is exactly like
        // reopening the website after being away — always show the
        // lock screen first if this account has a transaction PIN.
        try {
          final me = await _api.me();
          if (me['success'] == true && me['user']?['has_transaction_pin'] == true) {
            LockService.instance.locked.value = true;
          }
        } catch (e) { /* if this fails, fall through unlocked rather than block startup */ }
      }
      setState(() { _loggedIn = v; _checking = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _loggedIn ? const DashboardScreen() : const LoginScreen();
  }
}
