import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/notification.dart';
import '../utils/constants.dart';

class TechNotificationsState {
  final List<TechNotification> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  TechNotificationsState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  TechNotificationsState copyWith({
    List<TechNotification>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? error,
  }) {
    return TechNotificationsState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class TechNotificationsNotifier extends StateNotifier<TechNotificationsState> {
  final ApiClient _api = ApiClient();

  TechNotificationsNotifier() : super(TechNotificationsState()) {
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.dio.get(Constants.techNotifications);
      if (res.statusCode == 200 && res.data['success'] == true) {
        final List list = res.data['data']['notifications'] ?? [];
        final int unread = res.data['data']['unreadCount'] ?? 0;

        final notifications = list.map((item) => TechNotification.fromJson(item)).toList();
        state = state.copyWith(
          notifications: notifications,
          unreadCount: unread,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل تحميل الإشعارات');
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _api.dio.patch('${Constants.techNotifications}/$id/read');
      final updatedList = state.notifications.map((n) {
        if (n.id == id) {
          return TechNotification(
            id: n.id,
            type: n.type,
            titleAr: n.titleAr,
            bodyAr: n.bodyAr,
            orderId: n.orderId,
            isRead: true,
            createdAt: n.createdAt,
          );
        }
        return n;
      }).toList();

      final newUnread = updatedList.where((n) => !n.isRead).length;
      state = state.copyWith(notifications: updatedList, unreadCount: newUnread);
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await _api.dio.patch(Constants.techNotificationsReadAll);
      final updatedList = state.notifications.map((n) {
        return TechNotification(
          id: n.id,
          type: n.type,
          titleAr: n.titleAr,
          bodyAr: n.bodyAr,
          orderId: n.orderId,
          isRead: true,
          createdAt: n.createdAt,
        );
      }).toList();

      state = state.copyWith(notifications: updatedList, unreadCount: 0);
    } catch (_) {}
  }
}

final techNotificationsProvider = StateNotifierProvider<TechNotificationsNotifier, TechNotificationsState>(
  (ref) => TechNotificationsNotifier(),
);
