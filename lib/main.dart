import 'package:flutter/material.dart' hide Text;
import 'l10n.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/lock_service.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/receipt_screen.dart';

/// Used by LockScreen to log out and reset to the Login screen from
/// outside the Navigator (LockScreen is overlaid above it via
/// MaterialApp's `builder`, so `Navigator.of(context)` from inside it
/// wouldn't find this app's Navigator).
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// A notification about a transaction was tapped before the app was ready
/// to navigate (app was closed / still on the splash). The start-up gate
/// opens it as soon as the dashboard is showing.
String? pendingReceiptReference;
bool appReadyForNavigation = false;

/// Opens a transaction's receipt from a tapped notification (a push in the
/// tray, or the popup shown while the app is open).
void openReceiptFromNotification(String? reference) {
  if (reference == null || reference.isEmpty) return;
  final nav = rootNavigatorKey.currentState;
  if (appReadyForNavigation && nav != null) {
    nav.push(MaterialPageRoute(builder: (_) => ReceiptScreen(reference: reference)));
  } else {
    pendingReceiptReference = reference;
  }
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Single source of truth for the push-notification channel. The server
// (api/FcmApi.php) targets this exact channel_id — if it's ever renamed
// here, it must be renamed there too, or Android silently drops
// background/terminated-app pushes instead of popping them up.
const AndroidNotificationChannel notificationChannel = AndroidNotificationChannel(
  'katsinasub_popups_v4',
  'Katsinasub Direct Popups',
  description: 'Mafi girman matsayi na sanarwa mai pop-up.',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase.initializeApp() reads android/app/google-services.json (and
  // ios/Runner/GoogleService-Info.plist on iOS) automatically — see
  // MOBILE-PUSH-SETUP.md for how to generate those files. The app still
  // runs fine without them; push notifications just won't be delivered.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      // Tapping the popup shown while the app is open (see onMessage below)
      // opens that transaction's receipt.
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        openReceiptFromNotification(response.payload);
      },
    );

    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Creating the channel here means it exists on the device from the
      // very first app launch onward — Android remembers it permanently
      // after that, even across app restarts, which is what lets a push
      // pop up correctly the *next* time the app isn't running at all.
      await androidPlugin.createNotificationChannel(notificationChannel);
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestFullScreenIntentPermission();
    }

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Foreground messages don't show a system banner on their own —
    // show one manually, on this one channel, so chat replies/order
    // updates aren't silent just because the app happens to be open.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final title = notification?.title ?? message.data['title'] ?? message.data['heading'];
      final body = notification?.body ?? message.data['body'] ?? message.data['message'];

      if (title != null || body != null) {
        flutterLocalNotificationsPlugin.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title ?? 'Katsinasub',
          body ?? '',
          NotificationDetails(
            android: AndroidNotificationDetails(
              notificationChannel.id,
              notificationChannel.name,
              channelDescription: notificationChannel.description,
              icon: '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.max,
              ticker: 'New Notification',
              playSound: true,
              enableVibration: true,
              fullScreenIntent: true,
              category: AndroidNotificationCategory.reminder,
              visibility: NotificationVisibility.public,
              styleInformation: BigTextStyleInformation(body ?? ''),
            ),
          ),
          payload: message.data['reference']?.toString(),
        );
      }
    });

    // Tapping a push notification about a specific transaction (a
    // refund, a status change, etc.) opens that transaction's receipt
    // directly — same behaviour as tapping it in the in-app
    // Notifications list. Covers both "app was backgrounded" (tapped
    // just now) and "app was fully closed" (tapped to launch it).
    void handlePushTap(RemoteMessage message) {
      openReceiptFromNotification(message.data['reference']?.toString());
    }

    FirebaseMessaging.onMessageOpenedApp.listen(handlePushTap);
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) handlePushTap(message);
    });
  } catch (e) {
    // Firebase not configured yet — everything else in the app still works.
  }

  await AppLang.load();
  await AppTheme.load();
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
    // AppLifecycleState.hidden (added in newer Flutter) fires in some
    // cases 'inactive'/'paused' don't — e.g. the screen being turned off
    // with the power button on some Android skins, without the app ever
    // being switched away from. Treat it as "went to background" too, so
    // the 5-minute timer still starts.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      LockService.instance.onPause();
    } else if (state == AppLifecycleState.resumed) {
      LockService.instance.onResume(); // fire-and-forget: it flips `locked` itself once resolved
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.notifier,
      builder: (context, mode, __) => MaterialApp(
        title: 'Katsinasub',
        debugShowCheckedModeBanner: false,
        navigatorKey: rootNavigatorKey,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF0F9D6B), brightness: Brightness.light),
        darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF0F9D6B), brightness: Brightness.dark),
        themeMode: mode,
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
      ),
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
      // The app is now showing the dashboard/login. If a notification was
      // tapped while it was starting up, open that receipt now.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appReadyForNavigation = true;
        final ref = pendingReceiptReference;
        pendingReceiptReference = null;
        if (v && ref != null && ref.isNotEmpty) {
          rootNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => ReceiptScreen(reference: ref)));
        }
      });
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
