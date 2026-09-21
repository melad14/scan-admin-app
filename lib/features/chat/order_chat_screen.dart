import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:dr_ray_technician/core/api/api_client.dart';
import 'package:dr_ray_technician/core/services/notification_service.dart';
import 'package:dr_ray_technician/core/theme/app_colors.dart';

/// Message thread for one order: assigned technician <-> patient.
///
/// Text only, and read-only once the visit is finished. Updates arrive by FCM
/// push (the list refreshes when one lands) plus a light poll while open —
/// deliberately not a live socket chat.
class OrderChatScreen extends StatefulWidget {
  final String orderId;
  final String? orderNumber;

  const OrderChatScreen({super.key, required this.orderId, this.orderNumber});

  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  final _api = ApiClient();
  final _composer = TextEditingController();
  final _scroll = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _canSend = true;
  String? _error;
  Timer? _poll;

  String get _threadPath => '/orders/${widget.orderId}/messages';

  @override
  void initState() {
    super.initState();
    _fetch(initial: true);
    NotificationService.onNotificationReceived.addListener(_onPush);
    // Cheap catch-up for messages that arrive while the screen is open.
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _fetch());
  }

  @override
  void dispose() {
    _poll?.cancel();
    NotificationService.onNotificationReceived.removeListener(_onPush);
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onPush() {
    if (mounted) _fetch();
  }

  Future<void> _fetch({bool initial = false}) async {
    try {
      final res = await _api.dio.get(_threadPath);
      if (!mounted || res.statusCode != 200) return;
      final data = res.data['data'] ?? {};
      final list = (data['messages'] as List? ?? []).cast<Map<String, dynamic>>();
      final wasAtBottom = _isAtBottom;
      setState(() {
        _messages = list;
        _canSend = data['canSend'] ?? false;
        _isLoading = false;
        _error = null;
      });
      if (initial || wasAtBottom) _jumpToBottom();
      // Opening the thread counts as reading it.
      _api.dio.put('$_threadPath/read').catchError((_) => Response(requestOptions: RequestOptions(path: '')));
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.response?.data?['message'] ?? 'تعذر تحميل المحادثة. تحقق من اتصالك بالإنترنت.';
      });
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _error = 'حدث خطأ غير متوقع.'; });
    }
  }

  bool get _isAtBottom {
    if (!_scroll.hasClients) return true;
    return _scroll.position.pixels >= _scroll.position.maxScrollExtent - 80;
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      final res = await _api.dio.post(_threadPath, data: {'text': text});
      if (res.statusCode == 201 && mounted) {
        _composer.clear();
        setState(() => _messages = [..._messages, Map<String, dynamic>.from(res.data['data'])]);
        _jumpToBottom();
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.response?.data?['message'] ?? 'تعذر إرسال الرسالة',
              style: const TextStyle(fontFamily: 'Cairo')),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر إرسال الرسالة', style: TextStyle(fontFamily: 'Cairo')),
        ));
      }
    }
    if (mounted) setState(() => _isSending = false);
  }

  /// True when this message was written by the technician (this app's user).
  bool _isMine(Map<String, dynamic> m) => m['senderModel'] == 'Technician';

  String _time(Map<String, dynamic> m) {
    final raw = m['createdAt'];
    final dt = raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
    if (dt == null) return '';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour < 12 ? 'ص' : 'م';
    return '$h:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_forward_rounded, color: c.textPrimary),
          onPressed: () => Navigator.of(context).canPop() ? context.pop() : context.go('/'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('محادثة المريض',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary, fontFamily: 'Cairo')),
            if (widget.orderNumber != null)
              Text(widget.orderNumber!,
                  style: TextStyle(fontSize: 11, color: c.textMuted, fontFamily: 'Inter')),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(c)),
          _buildComposer(c),
        ],
      ),
    );
  }

  Widget _buildBody(AppColorTokens c) {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, i) => Align(
          alignment: i.isEven ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(
            width: 180,
            height: 46,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: c.skeletonBase, borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
    }

    if (_error != null) {
      return _CenteredHint(
        icon: Icons.wifi_off_rounded,
        color: c.error,
        title: _error!,
        actionLabel: 'إعادة المحاولة',
        onAction: () { setState(() { _isLoading = true; _error = null; }); _fetch(initial: true); },
      );
    }

    if (_messages.isEmpty) {
      return _CenteredHint(
        icon: Icons.forum_outlined,
        color: c.textMuted,
        title: _canSend
            ? 'ابدأ المحادثة مع المريض بخصوص الزيارة'
            : 'لا توجد رسائل على هذا الطلب',
      );
    }

    return RefreshIndicator(
      color: c.primary,
      onRefresh: () => _fetch(),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        itemCount: _messages.length,
        itemBuilder: (context, i) {
          final m = _messages[i];
          final mine = _isMine(m);
          return Align(
            alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: mine ? c.primary : c.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(mine ? 4 : 16),
                  bottomRight: Radius.circular(mine ? 16 : 4),
                ),
                border: mine ? null : Border.all(color: c.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m['text'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      fontFamily: 'Cairo',
                      color: mine ? Colors.white : c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _time(m),
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'Inter',
                      color: mine ? Colors.white.withOpacity(0.7) : c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildComposer(AppColorTokens c) {
    if (!_canSend) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: Text(
          'انتهت هذه الزيارة — المحادثة للاطلاع فقط',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: c.textMuted, fontFamily: 'Cairo'),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.of(context).viewPadding.bottom),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _composer,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              textInputAction: TextInputAction.newline,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'اكتب رسالتك...',
                counterText: '',
                filled: true,
                fillColor: c.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: c.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: c.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: c.primary, width: 1.4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isSending ? null : _send,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredHint extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CenteredHint({
    required this.icon,
    required this.color,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: color),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: c.textSecondary, fontFamily: 'Cairo', height: 1.6)),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!, style: const TextStyle(fontFamily: 'Cairo'))),
            ],
          ],
        ),
      ),
    );
  }
}
