import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tech_app/core/theme/app_colors.dart';
import '../../core/models/notification.dart';
import '../../core/services/notification_provider.dart';

class TechNotificationsScreen extends ConsumerStatefulWidget {
  const TechNotificationsScreen({super.key});

  @override
  ConsumerState<TechNotificationsScreen> createState() => _TechNotificationsScreenState();
}

class _TechNotificationsScreenState extends ConsumerState<TechNotificationsScreen> {
  final Set<String> _loadingIds = {};

  void _handleBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/');
    }
  }

  void _onNotificationTap(BuildContext context, TechNotification item) async {
    if (_loadingIds.contains(item.id)) return;
    setState(() {
      _loadingIds.add(item.id);
    });

    try {
      if (!item.isRead) {
        await ref.read(techNotificationsProvider.notifier).markAsRead(item.id);
      }
    } catch (e) {
      debugPrint('Error marking tech notification as read: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingIds.remove(item.id);
        });
      }
    }

    final orderId = item.orderId ?? '';

    if (!mounted) return;
    switch (item.type) {
      case 'new_order':
        final query = orderId.isNotEmpty
            ? '?orderId=$orderId&tab=available&t=${DateTime.now().millisecondsSinceEpoch}'
            : '?tab=available&t=${DateTime.now().millisecondsSinceEpoch}';
        context.go('/$query');
        break;
      case 'order_assigned':
      case 'order_cancelled':
        final query = orderId.isNotEmpty
            ? '?orderId=$orderId&tab=active&t=${DateTime.now().millisecondsSinceEpoch}'
            : '?tab=active&t=${DateTime.now().millisecondsSinceEpoch}';
        context.go('/$query');
        break;
      case 'new_complaint':
        context.push('/profile/complaints');
        break;
      default:
        if (orderId.isNotEmpty) {
          final query = '?orderId=$orderId&tab=active&t=${DateTime.now().millisecondsSinceEpoch}';
          context.go('/$query');
        } else {
          context.go('/');
        }
        break;
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'new_order':
      case 'order_assigned':
        return Icons.assignment_turned_in_rounded;
      case 'order_cancelled':
        return Icons.cancel_rounded;
      case 'new_complaint':
        return Icons.report_problem_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _getIconColor(String type, BuildContext context) {
    final c = context.colors;
    switch (type) {
      case 'new_order':
      case 'order_assigned':
        return c.primary;
      case 'order_cancelled':
        return c.error;
      case 'new_complaint':
        return Colors.amber.shade800;
      default:
        return c.accent;
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = ref.watch(techNotificationsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack(context);
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.textPrimary, size: 18),
            onPressed: () => _handleBack(context),
          ),
          title: Text(
            'الإشعارات',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: 'Cairo',
            ),
          ),
          centerTitle: true,
          actions: [
            if (state.notifications.isNotEmpty && state.unreadCount > 0)
              TextButton(
                onPressed: () => ref.read(techNotificationsProvider.notifier).markAllAsRead(),
                child: Text(
                  'قراءة الكل',
                  style: TextStyle(
                    color: c.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => ref.read(techNotificationsProvider.notifier).fetchNotifications(),
          color: c.primary,
          child: state.isLoading && state.notifications.isEmpty
              ? Center(child: CircularProgressIndicator(color: c.primary))
              : state.notifications.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.7,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: c.surfaceVariant,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.notifications_off_outlined, size: 48, color: c.textMuted),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد إشعارات حالياً',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: c.textSecondary,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'سيتم تنبيهك عند تعيين طلبات جديدة أو تحديثات عليها',
                              style: TextStyle(fontSize: 13, color: c.textMuted, fontFamily: 'Cairo'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = state.notifications[index];
                        final iconColor = _getIconColor(item.type, context);
                        final iconData = _getIconForType(item.type);

                        return GestureDetector(
                          onTap: () => _onNotificationTap(context, item),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: item.isRead ? c.surface : c.primaryLight.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: item.isRead ? c.border : c.primary.withOpacity(0.3),
                                width: item.isRead ? 1 : 1.5,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: iconColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: _loadingIds.contains(item.id)
                                      ? SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: iconColor,
                                          ),
                                        )
                                      : Icon(iconData, color: iconColor, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.titleAr,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                                                color: c.textPrimary,
                                                fontFamily: 'Cairo',
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _formatDate(item.createdAt),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: c.textMuted,
                                              fontFamily: 'Cairo',
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.bodyAr,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: c.textSecondary,
                                          height: 1.4,
                                          fontFamily: 'Cairo',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!item.isRead) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(top: 4),
                                    decoration: BoxDecoration(
                                      color: c.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
