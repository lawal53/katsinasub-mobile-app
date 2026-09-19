import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

/// Must be a top-level function (not a class method) — this is how
/// Firebase requires background message handling to be wired up.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  // Nothing to do here — when a "notification" payload arrives while
  // the app is backgrounded/terminated, Android/iOS already show the
  // system tray notification on their own. This handler only matters
  // if you later add silent "data-only" pushes you want to react to.
}

/// Wires up push notifications end-to-end:
///  1. Ask the user for permission
///  2. Get this device's FCM token and register it with our backend
///  3. Show a local banner when a push arrives while the app is open
///     (iOS/Android don't show their own banner in the foreground by default)
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _api = ApiService();
  final _localNotifications = FlutterLocalNotificationsPlugin();
  String? _currentToken;

  String? get currentToken => _currentToken;

  Future<void> initAndRegister() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(alert: true, badge: true, sound: true);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(const InitializationSettings(android: androidInit, iOS: iosInit));

    if (Platform.isAndroid) {
      final channel = const AndroidNotificationChannel(
        'default_channel', 'General Notifications',
        description: 'Order updates, chat replies, and announcements', importance: Importance.high,
      );
      await _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    _currentToken = await messaging.getToken();
    if (_currentToken != null) {
      await _api.registerDevice(fcmToken: _currentToken!, platform: Platform.isIOS ? 'ios' : 'android');
    }

    // Token can rotate during the app's lifetime — re-register when it does.
    messaging.onTokenRefresh.listen((newToken) {
      _currentToken = newToken;
      _api.registerDevice(fcmToken: newToken, platform: Platform.isIOS ? 'ios' : 'android');
    });

    // Foreground messages don't show a system banner on their own —
    // show one manually so chat replies/order updates aren't silent
    // just because the app happens to be open.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails('default_channel', 'General Notifications', importance: Importance.high, priority: Priority.high),
          iOS: DarwinNotificationDetails(),
        ),
      );
    });
  }
}
