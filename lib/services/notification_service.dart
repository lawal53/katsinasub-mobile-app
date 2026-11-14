import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

/// Must be a top-level function (not a class method) — this is how
/// Firebase requires background message handling to be wired up.
/// Nothing to do here: when a "notification" payload arrives while the
/// app is backgrounded/terminated, Android/iOS show the system-tray
/// popup on their own (using the "katsinasub_popups_v4" channel that
/// main.dart creates) — no Dart code needs to run for that.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {}

/// Registers this device for push notifications and keeps the saved
/// token in sync with the backend. The actual notification channel and
/// popup display (both foreground and background) are handled once,
/// centrally, in main.dart — this class used to also create its own
/// separate channel and its own foreground listener, which duplicated
/// (and could conflict with) what main.dart does, so that part was
/// removed. Keep everything notification-*display*-related in main.dart
/// only, and keep this class limited to token registration.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _api = ApiService();
  String? _currentToken;

  String? get currentToken => _currentToken;

  Future<void> initAndRegister() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    _currentToken = await messaging.getToken();
    if (_currentToken != null) {
      await _api.registerDevice(fcmToken: _currentToken!, platform: Platform.isIOS ? 'ios' : 'android');
    }

    // Token can rotate during the app's lifetime — re-register when it does.
    messaging.onTokenRefresh.listen((newToken) {
      _currentToken = newToken;
      _api.registerDevice(fcmToken: newToken, platform: Platform.isIOS ? 'ios' : 'android');
    });
  }
}
