import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:tech_app/core/api/api_client.dart';
import 'package:tech_app/core/services/storage_service.dart';

// ─── Global navigator key — used to navigate from notification taps ──────────
final GlobalKey<NavigatorState> notificationNavigatorKey =
    GlobalKey<NavigatorState>();

// ─── High-importance Android notification channel ────────────────────────────
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'scango_tech_high_importance',
  'ScanGo Tech Notifications',
  description: 'إشعارات تطبيق الفني لمنصة سكان جو',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

// ─── Local notifications plugin instance ─────────────────────────────────────
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

class NotificationService {
  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  // ── Init (called once at app startup, after Firebase.initializeApp) ─────────
  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      // 1. Register background handler FIRST (before any other FCM setup)
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 2. Set up local notifications (for foreground display)
      await _initLocalNotifications();

      // 3. Foreground messages → show as local notification
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showLocalNotification(message);
      });

      // 4. Background tap → navigate when app resumes
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationTap(message.data);
      });

      // 5. Terminated state tap → app was cold-started from notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        Future.delayed(const Duration(milliseconds: 800), () {
          _handleNotificationTap(initialMessage.data);
        });
      }

      // 6. Auto-refresh token when Firebase rotates it
      _messaging.onTokenRefresh.listen((String token) async {
        await _sendTokenToServer(token);
      });
    } catch (e) {
      debugPrint('[TechNotificationService] init error: $e');
    }
  }

  // ── Initialize FlutterLocalNotifications ────────────────────────────────────
  static Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Tapped a foreground local notification → navigate
        if (response.payload != null && response.payload!.isNotEmpty) {
          _handleNotificationTap({'orderId': response.payload, 'type': 'local'});
        }
      },
    );

    // Create the Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  // ── Show a local notification banner (foreground) ───────────────────────────
  static void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final orderId = message.data['orderId'] ?? '';

    _localNotifications.show(
      id: message.messageId.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
      ),
      payload: orderId,
    );
  }

  // ── Navigate to the relevant screen based on notification data ──────────────
  static void _handleNotificationTap(Map<String, dynamic> data) {
    final context = notificationNavigatorKey.currentContext;
    if (context == null) return;

    // Tech app has only one main screen (orders screen at '/').
    // Always navigate to '/' so the tech can see the relevant order.
    GoRouter.of(context).go('/');
  }

  // ── Request permission + register FCM token with backend ────────────────────
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
          await _sendTokenToServer(token);
        }
      } else {
        debugPrint('[TechNotificationService] Permission denied by user');
      }
    } catch (e) {
      debugPrint('[TechNotificationService] registerDeviceToken error: $e');
    }
  }

  // ── Send FCM token to ScanGo backend ────────────────────────────────────────
  static Future<void> _sendTokenToServer(String token) async {
    try {
      final accessToken = await StorageService.getAccessToken();
      if (accessToken == null) {
        debugPrint('[TechNotificationService] Not authenticated — skipping token upload');
        return;
      }

      final client = ApiClient();
      final response = await client.dio.put(
        '/auth/fcm-token',
        data: {'fcmToken': token},
      );

      if (response.statusCode == 200) {
        debugPrint('[TechNotificationService] FCM token updated on server ✅');
      }
    } catch (e) {
      debugPrint('[TechNotificationService] _sendTokenToServer error: $e');
    }
  }
}

// ─── Background message handler — MUST be a top-level function ───────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[TechNotificationService] Background message: ${message.messageId}');
}
