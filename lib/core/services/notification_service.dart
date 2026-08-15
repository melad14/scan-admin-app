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

    if (type == 'new_complaint') {
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

  static Future<void> registerDeviceToken() async {
    if (kIsWeb) return;
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await _messaging.getToken();
        if (token != null) {
          debugPrint('[TechNotificationService] FCM Token: $token');
          await _sendTokenToServer(token);
        }
      } else {
        debugPrint('[TechNotificationService] Permission denied by user');
      }
    } catch (e) {
      debugPrint('[TechNotificationService] registerDeviceToken error: $e');
    }
  }

  static Future<void> _sendTokenToServer(String token) async {
    try {
      final accessToken = await StorageService.getAccessToken();
      if (accessToken == null) {
        debugPrint('[TechNotificationService] Not authenticated - skipping token upload');
        return;
      }

      final client = ApiClient();
      final response = await client.dio.put(
        '/auth/fcm-token',
        data: {'fcmToken': token},
      );

      if (response.statusCode == 200) {
        debugPrint('[TechNotificationService] FCM token updated on server');
      }
    } catch (e) {
      debugPrint('[TechNotificationService] _sendTokenToServer error: $e');
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
