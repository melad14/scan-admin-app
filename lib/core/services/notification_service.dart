import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:dr_ray_technician/core/api/api_client.dart';
import 'package:dr_ray_technician/core/services/storage_service.dart';

// Global navigator key
final GlobalKey<NavigatorState> notificationNavigatorKey =
    GlobalKey<NavigatorState>();

// High-importance Android notification channel (Importance.max = heads-up banner)
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'drray_tech_high_importance_v2',
  'Dr Ray Technician Notifications',
  description: 'اشعارات تطبيق فني Dr Ray',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  enableLights: true,
  showBadge: true,
);

// Local notifications plugin instance
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

class NotificationService {
  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  static AppLifecycleListener? _lifecycleListener;

  static final ValueNotifier<RemoteMessage?> onNotificationReceived =
      ValueNotifier<RemoteMessage?>(null);

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      await _initLocalNotifications();

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        onNotificationReceived.value = message;
        _showLocalNotification(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationTap(message.data);
      });

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        Future.delayed(const Duration(milliseconds: 800), () {
          _handleNotificationTap(initialMessage.data);
        });
      }

      _messaging.onTokenRefresh.listen((String token) async {
        await _sendTokenToServer(token);
      });

      // Re-sync the token whenever the app comes back to the foreground
      _lifecycleListener ??= AppLifecycleListener(onResume: () {
        _onAppResumed();
      });
    } catch (e) {
      debugPrint('[TechNotificationService] init error: $e');
    }
  }

  static Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          final parts = response.payload!.split('|');
          final type = parts.isNotEmpty ? parts[0] : '';
          final orderId = parts.length > 1 ? parts[1] : response.payload!;
          _handleNotificationTap({'orderId': orderId, 'type': type});
        }
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);
  }

  static void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final orderId = message.data['orderId'] ?? '';
    final type = message.data['type'] ?? '';

    _localNotifications.show(
      id: (message.messageId ?? '').hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
      ),
      payload: '$type|$orderId',
    );
  }

  static bool _isNavigating = false;

  static void _handleNotificationTap(Map<String, dynamic> data) {
    if (_isNavigating) return;
    _isNavigating = true;
    Future.delayed(const Duration(milliseconds: 1500), () {
      _isNavigating = false;
    });

    final context = notificationNavigatorKey.currentContext;
    if (context == null) return;

    final type = data['type']?.toString() ?? '';
    final orderId = data['orderId']?.toString() ?? '';

    if (type == 'new_message') {
      if (orderId.isNotEmpty) {
        GoRouter.of(context).push('/orders/$orderId/chat');
      } else {
        GoRouter.of(context).go('/');
      }
    } else if (type == 'new_complaint') {
      GoRouter.of(context).push('/profile/complaints');
    } else if (type == 'new_order') {
      final query = orderId.isNotEmpty
          ? '?orderId=$orderId&tab=available&t=${DateTime.now().millisecondsSinceEpoch}'
          : '?tab=available&t=${DateTime.now().millisecondsSinceEpoch}';
      GoRouter.of(context).go('/$query');
    } else if (type == 'order_assigned' || type == 'order_cancelled') {
      final query = orderId.isNotEmpty
          ? '?orderId=$orderId&tab=active&t=${DateTime.now().millisecondsSinceEpoch}'
          : '?tab=active&t=${DateTime.now().millisecondsSinceEpoch}';
      GoRouter.of(context).go('/$query');
    } else {
      if (orderId.isNotEmpty) {
        final query =
            '?orderId=$orderId&tab=active&t=${DateTime.now().millisecondsSinceEpoch}';
        GoRouter.of(context).go('/$query');
      } else {
        GoRouter.of(context).go('/');
      }
    }
  }

  /// True when the user has refused the Android 13+ notification permission.
  /// The UI watches this to tell the technician how to re-enable it.
  static final ValueNotifier<bool> notificationsBlocked =
      ValueNotifier<bool>(false);

  /// Sent with error reports so the server log shows which build failed.
  /// Keep in sync with `version:` in pubspec.yaml.
  static const String _appTag = 'tech';
  static const String _buildTag = '1.0.1+2';

  static Future<void>? _inFlight;
  static DateTime? _lastSuccess;

  /// Ask for permission (unless [askPermission] is false), fetch the FCM token
  /// and upload it. Never throws; concurrent calls share one run. Every failure
  /// is reported to the server (`[FCM CLIENT ERROR]` in pm2 logs) instead of
  /// being swallowed — that silent catch is why technicians had no token.
  static Future<void> registerDeviceToken({bool askPermission = true}) {
    if (kIsWeb) return Future.value();
    return _inFlight ??=
        _register(askPermission).whenComplete(() => _inFlight = null);
  }

  /// Called when the app returns to the foreground: re-sync the token (it may
  /// have been purged server-side as dead) without showing a permission dialog.
  static Future<void> _onAppResumed() async {
    final last = _lastSuccess;
    if (last != null && DateTime.now().difference(last).inMinutes < 15) return;
    if (await StorageService.getAccessToken() == null) return;
    await registerDeviceToken(askPermission: false);
  }

  static Future<void> _register(bool askPermission) async {
    String permission = 'unknown';
    try {
      final settings = askPermission
          ? await _messaging.requestPermission(
              alert: true,
              badge: true,
              sound: true,
              provisional: false,
            )
          : await _messaging.getNotificationSettings();
      permission = settings.authorizationStatus.name;
      final denied =
          settings.authorizationStatus == AuthorizationStatus.denied;
      notificationsBlocked.value = denied;
      if (denied) {
        debugPrint('[TechNotificationService] Permission denied by user');
      }
    } catch (e) {
      // Don't stop here — the token can still be fetched and uploaded.
      await _reportError('permission', e, permission);
    }

    // Always register the token, even when permission is denied: the backend
    // still writes in-app notifications, and if the technician later enables
    // notifications from Settings, pushes start working without a re-login.
    String? token;
    Object? lastError;
    for (var attempt = 1; attempt <= 3 && token == null; attempt++) {
      try {
        token = await _messaging.getToken().timeout(const Duration(seconds: 20));
        if (token == null) lastError = 'getToken() returned null';
      } catch (e) {
        lastError = e;
      }
      if (token == null && attempt < 3) {
        await Future.delayed(Duration(seconds: 3 * attempt));
      }
    }

    if (token == null) {
      debugPrint('[TechNotificationService] getToken failed: $lastError');
      await _reportError('getToken', lastError, permission);
      return;
    }
    debugPrint('[TechNotificationService] FCM Token: $token');
    if (await _sendTokenToServer(token, permission: permission)) {
      _lastSuccess = DateTime.now();
    }
  }

  static Future<void> _reportError(
      String stage, Object? error, String permission) async {
    debugPrint('[TechNotificationService] $stage error: $error');
    try {
      if (await StorageService.getAccessToken() == null) return;
      await ApiClient().dio.post('/auth/fcm-token/error', data: {
        'app': _appTag,
        'build': _buildTag,
        'platform': defaultTargetPlatform.name,
        'permission': permission,
        'stage': stage,
        'error': error?.toString() ?? 'unknown',
      });
    } catch (_) {
      // Reporting is best-effort (no network → nothing we can do).
    }
  }

  /// This device's token — sent with /auth/logout so only this device is forgotten.
  static Future<String?> currentToken() async {
    if (kIsWeb) return null;
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Returns true when the server stored the token.
  static Future<bool> _sendTokenToServer(String token,
      {String permission = 'unknown'}) async {
    try {
      final accessToken = await StorageService.getAccessToken();
      if (accessToken == null) {
        debugPrint('[TechNotificationService] Not authenticated - skipping token upload');
        return false;
      }

      final client = ApiClient();
      final response = await client.dio.put(
        '/auth/fcm-token',
        data: {'fcmToken': token},
      );

      if (response.statusCode == 200) {
        debugPrint('[TechNotificationService] FCM token updated on server');
        return true;
      }
      await _reportError('upload', 'HTTP ${response.statusCode}', permission);
      return false;
    } catch (e) {
      await _reportError('upload', e, permission);
      return false;
    }
  }
}

// Background handler - MUST be top-level function
// FCM auto-shows the notification banner using channel in AndroidManifest.xml
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[TechNotificationService] Background: ${message.data["type"]}');
}
