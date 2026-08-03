import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tech_app/core/api/api_client.dart';
import 'package:tech_app/core/models/order.dart';
import 'package:tech_app/core/services/storage_service.dart';
import 'package:tech_app/core/services/notification_service.dart';
import 'package:tech_app/core/utils/constants.dart';
import 'package:tech_app/core/utils/app_snackbar.dart';
import 'package:tech_app/core/utils/loading_overlay.dart';
import 'package:tech_app/core/theme/app_colors.dart';
import 'package:tech_app/core/theme/theme_provider.dart';
import 'package:tech_app/core/theme/ui_components.dart';
import 'package:dio/dio.dart';
import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';

class TechOrdersScreen extends ConsumerStatefulWidget {
  final String? highlightOrderId;
  final String? initialTab;
  const TechOrdersScreen({super.key, this.highlightOrderId, this.initialTab});
  @override
  ConsumerState<TechOrdersScreen> createState() => _TechOrdersScreenState();
}

class _TechOrdersScreenState extends ConsumerState<TechOrdersScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _bgController;

  bool _isAvailable = true;
  bool _isDutyLoading = false;
  String _techName = 'الفني';

  List<MedicalOrder> _availableOrders = [];
  MedicalOrder? _activeOrder;
  List<MedicalOrder> _historyOrders = [];
  List<MedicalOrder> _rejectedOrders = [];

  List<dynamic> _allServices = [];
  bool _isLoadingAvailable = false;
  bool _isLoadingActive = false;
  bool _isLoadingHistory = false;
  bool _isLoadingRejected = false;
  bool _isActionLoading = false;
  bool _isLoggingOut = false;
  String? _loadingOrderId;

  String? _availableError;
  String? _activeError;
  String? _historyError;

  final List<String> _uploadedImageUrls = [];
  bool _isUploadingImages = false;
  final _reportNotesController = TextEditingController();
  final _api = ApiClient();
  
  String _paymentStatus = 'completed';
  String _paymentMethod = 'cash';
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    int initialIndex = 0;
    if (widget.initialTab == 'active') {
      initialIndex = 1;
    } else if (widget.initialTab == 'history') {
      initialIndex = 2;
    } else if (widget.initialTab == 'available') {
      initialIndex = 0;
    }
    _tabController = TabController(length: 4, vsync: this, initialIndex: initialIndex);
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _loadUserData();
    _fetchAll();
    
    // Register FCM Device Token for notifications
    NotificationService.registerDeviceToken();
    _fetchUnreadCount();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bgController.dispose();
    _reportNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final d = await StorageService.getUserData();
    if (d != null && mounted) setState(() {
      _techName = d['name'] ?? 'الفني';
      _isAvailable = d['isAvailable'] ?? true;
    });
  }

  Future<void> _fetchAll() async {
    _fetchAvailableOrders();
    _fetchActiveOrder();
    _fetchHistory();
    _fetchRejectedOrders();
  }

  Future<void> _fetchAvailableOrders() async {
    setState(() { _isLoadingAvailable = true; _availableError = null; });
    try {
      final res = await _api.dio.get(Constants.techAvailableOrders);
      if (res.statusCode == 200 && mounted) {
        final List list = res.data['data'] ?? [];
        final allOrders = list.map((e) => MedicalOrder.fromJson(e)).toList();
        final rejected = await StorageService.getRejectedOrders();
        setState(() {
          final filtered = allOrders.where((order) => !rejected.contains(order.id)).toList();
          if (widget.highlightOrderId != null) {
            final targetIndex = filtered.indexWhere((o) => o.id == widget.highlightOrderId);
            if (targetIndex != -1) {
              final targetOrder = filtered.removeAt(targetIndex);
              filtered.insert(0, targetOrder);
            }
          }
          _availableOrders = filtered;
        });
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _availableError = _parseError(e));
    } catch (_) {
      if (mounted) setState(() => _availableError = 'حدث خطأ غير متوقع.');
    } finally {
      if (mounted) setState(() => _isLoadingAvailable = false);
    }
  }

  Future<void> _rejectOrder(String orderId) async {
    final c = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.errorBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.block_rounded, color: c.error, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('تأكيد رفض الطلب',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 17)),
            ),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من رفض هذا الطلب؟\nسيتم نقله إلى قائمة الطلبات المرفوضة ويمكنك الرجوع إليه لاحقاً.',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 14, height: 1.6),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('تراجع', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('نعم، ارفض', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await StorageService.rejectOrder(orderId);
    setState(() {
      _availableOrders.removeWhere((order) => order.id == orderId);
    });
    if (mounted) AppSnackBar.show(context, message: 'تم رفض وإخفاء الطلب بنجاح', type: SnackType.info);
    _fetchRejectedOrders();
  }

  Future<void> _fetchRejectedOrders() async {
    setState(() => _isLoadingRejected = true);
    try {
      final rejectedIds = await StorageService.getRejectedOrders();
      if (rejectedIds.isEmpty) {
        if (mounted) setState(() => _rejectedOrders = []);
        return;
      }
      final res = await _api.dio.get(Constants.techAvailableOrders);
      if (res.statusCode == 200 && mounted) {
        final List list = res.data['data'] ?? [];
        final allOrders = list.map((e) => MedicalOrder.fromJson(e)).toList();
        setState(() {
          _rejectedOrders = allOrders.where((o) => rejectedIds.contains(o.id)).toList();
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoadingRejected = false);
    }
  }

  Future<void> _undoRejectOrder(String orderId) async {
    await StorageService.undoRejectOrder(orderId);
    await _fetchRejectedOrders();
    await _fetchAvailableOrders();
    if (mounted) AppSnackBar.show(context, message: 'تم استعادة الطلب بنجاح', type: SnackType.success);
  }

  Future<void> _fetchActiveOrder() async {
    setState(() { _isLoadingActive = true; _activeError = null; });
    try {
      final res = await _api.dio.get(Constants.techActiveOrder);
      if (mounted) setState(() => _activeOrder =
          res.data['data'] != null ? MedicalOrder.fromJson(res.data['data']) : null);
    } on DioException catch (e) {
      if (mounted) setState(() => _activeError = _parseError(e));
    } catch (_) {
      if (mounted) setState(() => _activeError = 'حدث خطأ غير متوقع.');
    } finally {
      if (mounted) setState(() => _isLoadingActive = false);
    }
  }

  Future<void> _fetchHistory() async {
    setState(() { _isLoadingHistory = true; _historyError = null; });
    try {
      final res = await _api.dio.get(Constants.techOrdersHistory);
      if (res.statusCode == 200 && mounted) {
        final List list = res.data['data'] ?? [];
        setState(() => _historyOrders = list.map((e) => MedicalOrder.fromJson(e)).toList());
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _historyError = _parseError(e));
    } catch (_) {
      if (mounted) setState(() => _historyError = 'حدث خطأ غير متوقع.');
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  String _parseError(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) return 'تعذر الاتصال. تحقق من الإنترنت.';
    if ((e.response?.statusCode ?? 0) >= 500) return 'خطأ في الخادم. اسحب للتحديث.';
    return e.response?.data?['message'] ?? 'حدث خطأ. اسحب للتحديث.';
  }

  Future<void> _toggleDuty() async {
    setState(() => _isDutyLoading = true);
    try {
      final res = await _api.dio.put(Constants.techAvailability);
      if (res.statusCode == 200 && mounted) {
        final v = res.data['data']['isAvailable'] as bool;
        setState(() => _isAvailable = v);
        final d = await StorageService.getUserData();
        if (d != null) { d['isAvailable'] = v; await StorageService.saveUserData(d); }
        AppSnackBar.show(context, message: v ? 'أنت الآن نشط ومتاح' : 'تم إيقاف الاستقبال', type: v ? SnackType.success : SnackType.info);
      }
    } on DioException catch (e) {
      AppSnackBar.show(context, message: _parseError(e), type: SnackType.error);
    } catch (_) {
      AppSnackBar.show(context, message: 'فشل تغيير الحالة.', type: SnackType.error);
    } finally {
      if (mounted) setState(() => _isDutyLoading = false);
    }
  }

  Future<void> _acceptOrder(String orderId) async {
    setState(() {
      _loadingOrderId = orderId;
      _isActionLoading = true;
    });
    try {
      final res = await _api.dio.put('/technician/orders/$orderId/accept');
      if (res.statusCode == 200 && mounted) {
        AppSnackBar.show(context, message: 'تم قبول الطلب بنجاح!', type: SnackType.success);
        // Remove the accepted order from the available list locally (no reload spinner)
        setState(() {
          _availableOrders.removeWhere((o) => o.id == orderId);
        });
        await _fetchActiveOrder();
        _tabController.animateTo(1);
        if (_activeOrder != null && _activeOrder!.technicianArrivalTime == null) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _showArrivalTimeBottomSheet(_activeOrder!);
          });
        }
      }
    } on DioException catch (e) {
      AppSnackBar.show(context, message: e.response?.data?['message'] ?? 'فشل القبول. ربما أُعطي لفني آخر.', type: SnackType.error);
    } catch (_) {
      AppSnackBar.show(context, message: 'حدث خطأ. حاول مرة أخرى.', type: SnackType.error);
    } finally {
      if (mounted) {
        setState(() {
          _loadingOrderId = null;
          _isActionLoading = false;
        });
      }
    }
  }

  Future<void> _updateStatus(String endpoint, String msg) async {
    setState(() => _isActionLoading = true);
    try {
      final res = await _api.dio.put(endpoint);
      if (res.statusCode == 200 && mounted) {
        AppSnackBar.show(context, message: msg, type: SnackType.success);
        await _fetchActiveOrder();
      }
    } on DioException catch (e) {
      AppSnackBar.show(context, message: e.response?.data?['message'] ?? 'فشل تحديث الحالة.', type: SnackType.error);
    } catch (_) {
      AppSnackBar.show(context, message: 'حدث خطأ. حاول مرة أخرى.', type: SnackType.error);
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _pickAndUploadReportImages() async {
    if (_isUploadingImages) return;

    final ImagePicker picker = ImagePicker();
    try {
      final List<XFile> images = await picker.pickMultiImage(
        imageQuality: 80,
      );

      if (images.isEmpty) return;

      setState(() {
        _isUploadingImages = true;
      });

      final List<MultipartFile> multipartFiles = [];
      for (final image in images) {
        final bytes = await image.readAsBytes();
        
        final ext = image.name.split('.').last.toLowerCase();
        MediaType mediaType;
        if (ext == 'png') {
          mediaType = MediaType('image', 'png');
        } else if (ext == 'pdf') {
          mediaType = MediaType('application', 'pdf');
        } else {
          mediaType = MediaType('image', 'jpeg');
        }

        multipartFiles.add(
          MultipartFile.fromBytes(
            bytes,
            filename: image.name,
            contentType: mediaType,
          ),
        );
      }

      final formData = FormData();
      for (final file in multipartFiles) {
        formData.files.add(MapEntry('reportImage', file));
      }

      final res = await _api.dio.post(
        '/upload/report-images',
        data: formData,
      );

      if (res.statusCode == 200 && res.data['success'] == true) {
        final List returnedUrls = res.data['data']['urls'] ?? [];
        setState(() {
          _uploadedImageUrls.addAll(returnedUrls.map((url) => url.toString()));
        });
        AppSnackBar.show(context, message: 'تم رفع ${returnedUrls.length} صور بنجاح!', type: SnackType.success);
      } else {
        AppSnackBar.show(context, message: 'فشل في رفع بعض أو كل الصور المحددة.', type: SnackType.error);
      }
    } catch (e) {
      debugPrint('Error picking or uploading report images: $e');
      String msg = 'حدث خطأ أثناء رفع الصور.';
      if (e is DioException) {
        final serverMsg = e.response?.data?['message'];
        if (serverMsg != null && serverMsg.toString().isNotEmpty) {
          msg = serverMsg.toString();
        }
      }
      AppSnackBar.show(context, message: msg, type: SnackType.error);
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImages = false;
        });
      }
    }
  }

  Future<void> _completeOrder() async {
    if (_uploadedImageUrls.isEmpty) { AppSnackBar.show(context, message: 'يرجى إرفاق صورة فحص واحدة على الأقل', type: SnackType.warning); return; }
    setState(() => _isActionLoading = true);
    try {
      final res = await _api.dio.post('/technician/orders/${_activeOrder!.id}/upload-report', data: {
        'images': _uploadedImageUrls,
        'pdf': '${Constants.socketUrl}/uploads/reports/mock-result.pdf',
        'notes': _reportNotesController.text.trim(),
        'paymentStatus': _paymentStatus,
        'paymentMethod': _paymentMethod,
      });
      if (res.statusCode == 200 && mounted) {
        final orderId = _activeOrder!.id;
        AppSnackBar.show(context, message: 'تم رفع التقرير وإتمام الطلب!', type: SnackType.success);
        await _fetchActiveOrder();
        await _fetchHistory();
        if (mounted) {
          _showCompletionSuccessDialog(orderId);
        }
      }
    } on DioException catch (e) {
      AppSnackBar.show(context, message: e.response?.data?['message'] ?? 'فشل إتمام الطلب.', type: SnackType.error);
    } catch (_) {
      AppSnackBar.show(context, message: 'حدث خطأ. حاول مرة أخرى.', type: SnackType.error);
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _showCompletionSuccessDialog(String orderId) {
    final c = context.colors;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'تم إكمال الطلب بنجاح 🎉',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 54),
            const SizedBox(height: 16),
            const Text(
              'تم رفع نتائج الفحص الطبي وحفظ بيانات التحصيل والتقرير بنجاح.',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'الصور المرفوعة: ${_uploadedImageUrls.length} صور\nالملاحظات: ${_reportNotesController.text.isNotEmpty ? _reportNotesController.text : "لا يوجد"}',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowButtonSpacing: 10,
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _showUploadedResultsGallery();
            },
            icon: const Icon(Icons.visibility_rounded, size: 18),
            label: const Text('عرض النتائج المرفوعة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _reportNotesController.clear();
              _tabController.animateTo(2); // Go to history
            },
            child: const Text('العودة للرئيسية', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showUploadedResultsGallery() {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('النتائج والتقارير الطبية المرفوعة 📋',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary, fontFamily: 'Cairo')),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _uploadedImageUrls.length,
                itemBuilder: (ctx, i) => Container(
                  width: 150,
                  margin: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.borderLight),
                    image: DecorationImage(
                      image: NetworkImage(_uploadedImageUrls[i]),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            if (_reportNotesController.text.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('ملاحظات التقرير:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: c.textPrimary)),
              const SizedBox(height: 6),
              Text(_reportNotesController.text, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: c.textSecondary)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _reportNotesController.clear();
                _tabController.animateTo(2); // Go to history
              },
              style: ElevatedButton.styleFrom(backgroundColor: c.primary, foregroundColor: Colors.white),
              child: const Text('حسنًا'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final c = context.colors;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(width: 60, height: 60,
                decoration: BoxDecoration(color: c.errorBg, borderRadius: BorderRadius.circular(18)),
                child: Icon(Icons.logout_rounded, color: c.error, size: 30)),
            const SizedBox(height: 14),
            Text('تسجيل الخروج',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const SizedBox(height: 6),
            Text('هل أنت متأكد؟', style: TextStyle(color: c.textSecondary)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع'))),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(height: 50,
                    decoration: BoxDecoration(color: c.error, borderRadius: BorderRadius.circular(14)),
                    child: const Center(child: Text('خروج',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'Cairo', fontSize: 15)))),
              )),
            ]),
          ],
        ),
      ),
    );
    if (ok == true) {
      setState(() => _isLoggingOut = true);
      try { await _api.dio.post(Constants.logout); } catch (_) {}
      await StorageService.clearAll();
      if (mounted) context.go('/login');
    }
  }

  Future<void> _fetchServicesList() async {
    if (_allServices.isNotEmpty) return;
    try {
      final res = await _api.dio.get('/services');
      if (res.statusCode == 200) {
        final body = res.data;
        if (body['success'] == true) {
          setState(() {
            _allServices = body['data'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading services: $e');
    }
  }

  Future<void> _showPricingBottomSheet(MedicalOrder order) async {
    final c = context.colors;
    
    // Load services if not already loaded
    if (_allServices.isEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      await _fetchServicesList();
      if (mounted) Navigator.pop(context); // Close loading dialog
    }
    
    if (_allServices.isEmpty) {
      AppSnackBar.show(context, message: 'عذراً، فشل تحميل قائمة الخدمات الطبية.', type: SnackType.error);
      return;
    }

    List<String> localSelectedServiceIds = [];
    double localTransferFee = 150.0;
    final feeController = TextEditingController(text: '150');

    // If order already has some services, pre-select them
    if (order.services.isNotEmpty) {
      localSelectedServiceIds = order.services.map((s) => s.id).toList();
      if (order.pricing?['transferFee'] != null) {
        localTransferFee = (order.pricing!['transferFee'] as num).toDouble();
        feeController.text = localTransferFee.toStringAsFixed(0);
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double calculatedTotal = localTransferFee;
            for (var sId in localSelectedServiceIds) {
              final service = _allServices.firstWhere((element) => element['_id'] == sId, orElse: () => null);
              if (service != null) {
                calculatedTotal += (service['price'] as num).toDouble();
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'معاينة الروشتة وتسعير الطلب',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary, fontFamily: 'Cairo'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    // Prescription Image Preview
                    if (order.prescription?.images.isNotEmpty == true) ...[
                      Text(
                        'صورة الروشتة المرفقة:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textSecondary, fontFamily: 'Cairo'),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: c.border),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  insetPadding: const EdgeInsets.all(10),
                                  child: InteractiveViewer(
                                    child: Image.network(order.prescription!.images[0]),
                                  ),
                                ),
                              );
                            },
                            child: Image.network(
                              order.prescription!.images[0],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Text(
                      'حدد الخدمات / التحاليل المطلوبة:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textSecondary, fontFamily: 'Cairo'),
                    ),
                    const SizedBox(height: 8),

                    // Services Checkbox List
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: c.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _allServices.length,
                        itemBuilder: (context, index) {
                          final service = _allServices[index];
                          final sId = service['_id'] as String;
                          final isChecked = localSelectedServiceIds.contains(sId);
                          return CheckboxListTile(
                            title: Text(
                              '${service['nameAr']} (${service['price']} ج.م)',
                              style: TextStyle(fontSize: 13, color: c.textPrimary, fontFamily: 'Cairo'),
                            ),
                            value: isChecked,
                            activeColor: c.primary,
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  localSelectedServiceIds.add(sId);
                                } else {
                                  localSelectedServiceIds.remove(sId);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'رسوم انتقال الفريق الطبي:',
                            style: TextStyle(fontSize: 13, color: c.textSecondary, fontFamily: 'Cairo'),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: feeController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: c.textPrimary, fontSize: 14),
                            decoration: const InputDecoration(
                              suffixText: 'ج.م',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: (val) {
                              final parsed = double.tryParse(val) ?? 0.0;
                              setModalState(() {
                                localTransferFee = parsed;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: c.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'إجمالي الفاتورة:',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.primary, fontFamily: 'Cairo'),
                          ),
                          Text(
                            '${calculatedTotal.toStringAsFixed(0)} ج.م',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.primary, fontFamily: 'Inter'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        if (localSelectedServiceIds.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('يرجى اختيار خدمة واحدة على الأقل لتسعير الطلب.')),
                          );
                          return;
                        }
                        Navigator.pop(ctx); // Close sheet
                        await _submitPricing(order.id, localSelectedServiceIds, localTransferFee);
                      },
                      child: const Text(
                        'تأكيد وحفظ التسعير للعميل',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitPricing(String orderId, List<String> serviceIds, double transferFee) async {
    setState(() {
      _loadingOrderId = orderId;
      _isActionLoading = true;
    });
    try {
      final res = await _api.dio.patch(
        '/technician/orders/$orderId/price-prescription',
        data: {
          'serviceIds': serviceIds,
          'transferFee': transferFee,
        },
      );
      if (res.statusCode == 200 && res.data['success'] == true) {
        AppSnackBar.show(context, message: 'تم حفظ التسعير وتحديث الطلب بنجاح!', type: SnackType.success);
        _fetchAvailableOrders();
      }
    } on DioException catch (e) {
      AppSnackBar.show(context, message: e.response?.data?['message'] ?? 'فشل تسعير الطلب.', type: SnackType.error);
    } catch (_) {
      AppSnackBar.show(context, message: 'حدث خطأ أثناء إرسال التسعير.', type: SnackType.error);
    } finally {
      if (mounted) {
        setState(() {
          _loadingOrderId = null;
          _isActionLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = context.isDark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: LoadingOverlay(
        isVisible: _isLoggingOut,
        message: 'جاري تسجيل الخروج...',
        child: Scaffold(
          backgroundColor: c.background,
          body: Stack(
            children: [
              // Animated background orb
              AnimatedBuilder(
                animation: _bgController,
                builder: (_, __) {
                  final t = _bgController.value * 2 * math.pi;
                  return Positioned(
                    top: -60 + math.sin(t) * 20,
                    right: -80 + math.cos(t) * 15,
                    child: Container(
                      width: 220, height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          c.primary.withOpacity(isDark ? 0.12 : 0.04),
                          c.primary.withOpacity(0.0),
                        ]),
                      ),
                    ),
                  );
                },
              ),

              Column(
                children: [
                  _buildHeader(),
                  _buildTabBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildAvailableTab(),
                        _buildActiveTab(),
                        _buildHistoryTab(),
                        _buildRejectedTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  HEADER
  // ══════════════════════════════════════════════════════
  Widget _buildHeader() {
    final c = context.colors;
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0A0F1E), const Color(0xFF0F1729)]
              : [const Color(0xFF085041), const Color(0xFF1D9E75)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Column(
        children: [
          // ── Row 1: Logo + Name + Duty Toggle ──
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('سكان جو',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text('مرحباً، $_techName',
                        style: const TextStyle(fontSize: 11, color: Color(0xCCFFFFFF)),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              // Duty toggle
              GestureDetector(
                onTap: _isDutyLoading ? null : _toggleDuty,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isAvailable ? c.successBg : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: _isAvailable ? c.success : Colors.white.withOpacity(0.3), width: 1.5),
                  ),
                  child: _isDutyLoading
                      ? SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: c.primary))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 7, height: 7,
                              decoration: BoxDecoration(
                                color: _isAvailable ? c.success : Colors.white.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(_isAvailable ? 'نشط' : 'مغلق',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Cairo',
                                    color: _isAvailable ? c.success : Colors.white.withOpacity(0.7))),
                          ],
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── Row 2: Action Buttons ──
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _HeaderBtn(icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  onTap: () => ref.read(themeProvider.notifier).toggleTheme()),
              const SizedBox(width: 8),
              _HeaderBtn(icon: Icons.person_rounded, onTap: () => context.push('/profile')),
              const SizedBox(width: 8),
              // Notifications bell with badge
              GestureDetector(
                onTap: () async {
                  await context.push('/notifications');
                  _fetchUnreadCount();
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _HeaderBtn(icon: Icons.notifications_rounded, onTap: () async {
                      await context.push('/notifications');
                      _fetchUnreadCount();
                    }),
                    if (_unreadCount > 0)
                      Positioned(
                        top: -3, right: -3,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.2),
                          ),
                          constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                          child: Text(
                            _unreadCount > 9 ? '9+' : '$_unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _HeaderBtn(icon: Icons.logout_rounded, onTap: _logout),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildTabBar() {
    final c = context.colors;
    return Container(
      color: c.surface,
      child: TabBar(
        controller: _tabController,
        indicatorColor: c.primary,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: c.primary,
        unselectedLabelColor: c.textMuted,
        labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
        tabs: [
          Tab(child: _TabItem(label: 'المتاحة', count: _availableOrders.length, active: false)),
          const Tab(text: 'النشط'),
          Tab(child: _TabItem(label: 'السجل', count: _historyOrders.length, active: false)),
          Tab(child: _TabItem(label: 'المرفوضة', count: _rejectedOrders.length, active: false)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  TAB 1
  // ══════════════════════════════════════════════════════
  Widget _buildAvailableTab() {
    final c = context.colors;
    return RefreshIndicator(
      color: c.primary,
      backgroundColor: c.surface,
      onRefresh: _fetchAvailableOrders,
      child: _isLoadingAvailable
          ? _buildSkeletons()
          : _availableOrders.isEmpty && _availableError == null
              ? _buildScrollableEmpty('لا توجد طلبات متاحة', 'انتظر طلبات جديدة في منطقتك', Icons.inbox_rounded)
              : _availableError != null
                  ? _buildScrollableError(_availableError!, _fetchAvailableOrders)
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      itemCount: _availableOrders.length,
                      itemBuilder: (_, i) => _AvailableCard(
                        order: _availableOrders[i],
                        isLoading: _loadingOrderId == _availableOrders[i].id,
                        onAccept: () => _acceptOrder(_availableOrders[i].id),
                        onReject: () => _rejectOrder(_availableOrders[i].id),
                        onPrice: () => _showPricingBottomSheet(_availableOrders[i]),
                        isHighlighted: widget.highlightOrderId == _availableOrders[i].id,
                      ),
                    ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  TAB 2
  // ══════════════════════════════════════════════════════
  Widget _buildActiveTab() {
    final c = context.colors;
    return RefreshIndicator(
      color: c.primary,
      backgroundColor: c.surface,
      onRefresh: _fetchActiveOrder,
      child: _isLoadingActive
          ? _buildSkeletons(count: 2)
          : _activeError != null
              ? _buildScrollableError(_activeError!, _fetchActiveOrder)
              : _activeOrder == null
                  ? _buildScrollableEmpty('لا يوجد طلب نشط', 'اقبل طلباً من تبويب المتاحة', Icons.assignment_outlined)
                  : _buildActiveContent(_activeOrder!),
    );
  }

  Widget _buildActiveOrderMap(MedicalOrder order) {
    final c = context.colors;
    final locObj = order.location;
    double lat = 30.0444;
    double lng = 31.2357;
    
    if (locObj != null) {
      final coordsWrapper = locObj['coordinates'];
      if (coordsWrapper is Map && coordsWrapper['coordinates'] is List) {
        final list = coordsWrapper['coordinates'] as List;
        if (list.length >= 2) {
          lng = (list[0] as num).toDouble();
          lat = (list[1] as num).toDouble();
        }
      } else if (coordsWrapper is List && coordsWrapper.length >= 2) {
        lng = (coordsWrapper[0] as num).toDouble();
        lat = (coordsWrapper[1] as num).toDouble();
      }
    }
    
    final targetLatLng = LatLng(lat, lng);

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHead(
            icon: Icons.map_rounded,
            title: 'موقع الزيارة الجغرافي',
            color: c.primary,
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.border),
              ),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: targetLatLng,
                  initialZoom: 14.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.scango.tech',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: targetLatLng,
                        width: 45,
                        height: 45,
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Colors.red,
                          size: 38,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () async {
              final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
              final geoUrl = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
              
              try {
                if (await canLaunchUrl(geoUrl)) {
                  await launchUrl(geoUrl);
                } else if (await canLaunchUrl(googleMapsUrl)) {
                  await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
                } else {
                  AppSnackBar.show(context, message: 'تعذر فتح الخرائط. لا توجد تطبيقات خرائط مثبتة.', type: SnackType.warning);
                }
              } catch (e) {
                try {
                  await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
                } catch (_) {
                  AppSnackBar.show(context, message: 'حدث خطأ أثناء محاولة فتح الخرائط.', type: SnackType.error);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: const Icon(Icons.navigation_rounded, size: 20),
            label: const Text(
              'بدء التوجيه في خرائط جوجل 🧭',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveContent(MedicalOrder order) {
    final c = context.colors;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Header Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: c.primary,
              borderRadius: BorderRadius.circular(20),
              boxShadow: c.primaryGlow,
            ),
            child: Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('طلب · ${order.orderNumber}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700,
                              fontSize: 15, fontFamily: 'Inter')),
                      const SizedBox(height: 4),
                      Text(AppColors.getStatusLabel(order.status),
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${order.pricing?['total']} ج.م',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800,
                          fontFamily: 'Inter', fontSize: 14)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Patient Card
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHead(icon: Icons.person_pin_circle_rounded, title: 'بيانات المريض', color: c.primary),
                const SizedBox(height: 14),
                _InfoTile(Icons.person_outline, 'الاسم', order.patientSnapshot?['name'] ?? '-'),
                _InfoTile(Icons.phone_rounded, 'الهاتف', order.patientSnapshot?['phone'] ?? '-'),
                _InfoTile(Icons.location_on_rounded, 'العنوان',
                    '${order.location?['street']}، ${order.location?['district']}'),
                if ((order.caseDetails?['notes'] ?? '').toString().isNotEmpty)
                  _InfoTile(Icons.notes_rounded, 'ملاحظات', order.caseDetails?['notes'] ?? ''),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Map Card
          _buildActiveOrderMap(order),
          const SizedBox(height: 12),

          // Services
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHead(icon: Icons.science_rounded, title: 'الفحوصات', color: c.accent),
                const SizedBox(height: 12),
                ...order.services.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Container(width: 6, height: 6,
                        decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Text(s.nameAr, style: TextStyle(color: c.textPrimary, fontSize: 14)),
                  ]),
                )),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action
          if (_isActionLoading)
            Center(child: CircularProgressIndicator(color: c.primary))
          else ...[
            if (order.status == 'accepted' || order.status == 'assigned') ...[
              // Show arrival time row if already set
              if (order.technicianArrivalTime != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _GlassCard(
                    child: Row(
                      children: [
                        Icon(Icons.access_time_rounded, color: c.primary, size: 18),
                        const SizedBox(width: 8),
                        Text('وقت الوصول المحدد: ${order.technicianArrivalTime}',
                            style: TextStyle(fontSize: 14, color: c.textPrimary, fontFamily: 'Cairo')),
                      ],
                    ),
                  ),
                ),
              _ActionBtn(
                label: order.technicianArrivalTime == null
                    ? 'تحديد وقت الوصول ⏰'
                    : 'تعديل وقت الوصول ✏️',
                color: c.primary,
                onTap: () => _showArrivalTimeBottomSheet(order),
              ),
            ],
            if (order.status == 'assigned') ...[
              const SizedBox(height: 10),
              _ActionBtn(
                label: 'بدء الرحلة 🚗',
                color: c.warning,
                onTap: () => _updateStatus('/technician/orders/${order.id}/start-trip', '✅ بدأت الرحلة'),
              ),
            ],
            if (order.status == 'on_way')
              _ActionBtn(label: 'وصلت للموقع 📍', color: c.primary,
                  onTap: () => _updateStatus('/technician/orders/${order.id}/arrived', '✅ تم تسجيل وصولك')),
            if (order.status == 'arrived')
              _ActionBtn(label: 'بدء الفحص الطبي 🩺', color: c.accent,
                  onTap: () => _updateStatus('/technician/orders/${order.id}/start-service', '✅ بدأ الفحص')),
            if (order.status == 'in_progress') ...[
              _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionHead(icon: Icons.upload_file_rounded, title: 'رفع نتائج الفحص', color: c.success),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _reportNotesController,
                      maxLines: 3,
                      style: TextStyle(color: c.textPrimary, fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات التقرير الطبي',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isUploadingImages)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _pickAndUploadReportImages,
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: const Text('التقاط/رفع صور الأشعة'),
                      ),
                    if (_uploadedImageUrls.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 90,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _uploadedImageUrls.length,
                          itemBuilder: (context, index) {
                            final url = _uploadedImageUrls[index];
                            return Stack(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(right: 8, top: 6, left: 2),
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: c.borderLight),
                                    image: DecorationImage(
                                      image: NetworkImage(url),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _uploadedImageUrls.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                    const Divider(height: 24),
                    _SectionHead(icon: Icons.payments_outlined, title: 'تفاصيل تحصيل الرسوم', color: c.primary),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('حالة الدفع:', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: const Text('تم التحصيل', style: TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                          selected: _paymentStatus == 'completed',
                          onSelected: (val) => setState(() => _paymentStatus = 'completed'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('لم يتم التحصيل', style: TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                          selected: _paymentStatus == 'pending',
                          onSelected: (val) => setState(() => _paymentStatus = 'pending'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('طريقة الدفع:', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                        ChoiceChip(
                          label: const Text('نقدي', style: TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                          selected: _paymentMethod == 'cash',
                          onSelected: (val) => setState(() => _paymentMethod = 'cash'),
                        ),
                        ChoiceChip(
                          label: const Text('محفظة', style: TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                          selected: _paymentMethod == 'wallet',
                          onSelected: (val) => setState(() => _paymentMethod = 'wallet'),
                        ),
                        ChoiceChip(
                          label: const Text('بطاقة', style: TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                          selected: _paymentMethod == 'card',
                          onSelected: (val) => setState(() => _paymentMethod = 'card'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SolidTealBtn(label: 'تأكيد إكمال الطلب ✅', onTap: _completeOrder, primary: c.primary),
            ],
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  Arrival Time Bottom Sheet
  // ══════════════════════════════════════════════════════
  Future<void> _showArrivalTimeBottomSheet(MedicalOrder order) async {
    final c = context.colors;
    final isEmergency = order.schedule?['isEmergency'] == true;
    final slotKey = order.schedule?['timeSlot']?.toString() ?? '';

    String slotSubtitle;
    TimeOfDay initialTimeOfDay;

    if (isEmergency) {
      slotSubtitle = 'طلب طارئ ⚡ (يمكن تحديد أي وقت)';
      initialTimeOfDay = TimeOfDay.now();
    } else if (slotKey == 'morning_9_12') {
      slotSubtitle = 'الفترة المحجوزة: 09:00 ص – 12:00 م';
      initialTimeOfDay = const TimeOfDay(hour: 10, minute: 0);
    } else if (slotKey == 'afternoon_12_3') {
      slotSubtitle = 'الفترة المحجوزة: 12:00 م – 03:00 م';
      initialTimeOfDay = const TimeOfDay(hour: 13, minute: 0);
    } else if (slotKey == 'evening_3_6') {
      slotSubtitle = 'الفترة المحجوزة: 03:00 م – 06:00 م';
      initialTimeOfDay = const TimeOfDay(hour: 16, minute: 0);
    } else {
      slotSubtitle = 'اختر الوقت المتوقع للوصول';
      initialTimeOfDay = TimeOfDay.now();
    }

    if (order.technicianArrivalTime != null) {
      final parts = order.technicianArrivalTime!.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) {
          initialTimeOfDay = TimeOfDay(hour: h, minute: m);
        }
      }
    }

    TimeOfDay? selectedTime = initialTimeOfDay;
    String? localError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final formattedTimeDisplay = selectedTime == null
                ? 'لم يتم التحديد بعد'
                : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
                top: 24, left: 24, right: 24,
              ),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: c.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('تحديد وقت الوصول',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                          color: c.textPrimary, fontFamily: 'Cairo'),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(slotSubtitle,
                      style: TextStyle(fontSize: 13, color: c.textMuted, fontFamily: 'Cairo'),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  if (localError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.errorBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(localError!,
                          style: TextStyle(color: c.error, fontSize: 13, fontFamily: 'Cairo'),
                          textAlign: TextAlign.center),
                    ),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: modalContext,
                        initialTime: selectedTime ?? TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setModalState(() {
                          selectedTime = picked;
                          localError = null;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: c.surfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.primary.withOpacity(0.3), width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('الوقت المحدد:',
                                  style: TextStyle(fontSize: 12, color: c.textMuted, fontFamily: 'Cairo')),
                              const SizedBox(height: 4),
                              Text(formattedTimeDisplay,
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                                      color: c.textPrimary, fontFamily: 'Cairo')),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: c.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.schedule, color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text('تغيير',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold,
                                        fontSize: 13, fontFamily: 'Cairo')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: selectedTime == null
                        ? null
                        : () async {
                            if (!isEmergency) {
                              final totalMinutes = selectedTime!.hour * 60 + selectedTime!.minute;
                              int? startMinutes;
                              int? endMinutes;
                              String boundsLabel = '';
                              
                              if (slotKey == 'morning_9_12') {
                                startMinutes = 9 * 60;
                                endMinutes = 12 * 60;
                                boundsLabel = '09:00 ص – 12:00 م';
                              } else if (slotKey == 'afternoon_12_3') {
                                startMinutes = 12 * 60;
                                endMinutes = 15 * 60;
                                boundsLabel = '12:00 م – 03:00 م';
                              } else if (slotKey == 'evening_3_6') {
                                startMinutes = 15 * 60;
                                endMinutes = 18 * 60;
                                boundsLabel = '03:00 م – 06:00 م';
                              }
                              
                              if (startMinutes != null && endMinutes != null) {
                                if (totalMinutes < startMinutes || totalMinutes > endMinutes) {
                                  setModalState(() {
                                    localError = 'وقت الوصول يجب أن يكون ضمن الفترة المحجوزة للطلب ($boundsLabel)';
                                  });
                                  return;
                                }
                              }
                            }

                            final time24 =
                                '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';
                            try {
                              final res = await _api.dio.put(
                                '${Constants.techOrders}/${order.id}/set-arrival-time',
                                data: {'arrivalTime': time24},
                              );
                              if (res.statusCode == 200 && res.data['success'] == true) {
                                if (mounted) {
                                  Navigator.pop(ctx);
                                  AppSnackBar.show(context, message: 'تم تحديد وقت الوصول بنجاح!', type: SnackType.success);
                                  await _fetchActiveOrder();
                                }
                              }
                            } on DioException catch (e) {
                              final serverMsg = e.response?.data?['message']?.toString();
                              setModalState(() {
                                localError = serverMsg ?? 'فشل تحديد وقت الوصول. حاول مرة أخرى.';
                              });
                            } catch (_) {
                              setModalState(() {
                                localError = 'حدث خطأ غير متوقع.';
                              });
                            }
                          },
                    child: const Text('تأكيد وحفظ وقت الوصول',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final res = await _api.dio.get(Constants.techNotifications);
      if (res.statusCode == 200 && mounted) {
        final notifications = res.data['notifications'] as List? ?? [];
        final count = notifications.where((n) => n['isRead'] == false).length;
        setState(() => _unreadCount = count);
      }
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════
  //  TAB 3
  // ══════════════════════════════════════════════════════
  Widget _buildHistoryTab() {
    final c = context.colors;
    return RefreshIndicator(
      color: c.primary,
      backgroundColor: c.surface,
      onRefresh: _fetchHistory,
      child: _isLoadingHistory
          ? _buildSkeletons()
          : _historyError != null
              ? _buildScrollableError(_historyError!, _fetchHistory)
              : _historyOrders.isEmpty
                  ? _buildScrollableEmpty('لا توجد زيارات مكتملة', 'الزيارات المنفذة ستظهر هنا', Icons.history_rounded)
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      itemCount: _historyOrders.length,
                      itemBuilder: (_, i) => _HistoryCard(order: _historyOrders[i]),
                    ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  TAB 4 — REJECTED ORDERS
  // ══════════════════════════════════════════════════════
  Widget _buildRejectedTab() {
    final c = context.colors;
    return RefreshIndicator(
      color: c.primary,
      backgroundColor: c.surface,
      onRefresh: _fetchRejectedOrders,
      child: _isLoadingRejected
          ? _buildSkeletons()
          : _rejectedOrders.isEmpty
              ? _buildScrollableEmpty('لا توجد طلبات مرفوضة', 'الطلبات التي ترفضها ستظهر هنا لاستعادتها عند الحاجة', Icons.block_rounded)
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  itemCount: _rejectedOrders.length,
                  itemBuilder: (_, i) {
                    final order = _rejectedOrders[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: c.error.withOpacity(0.2)),
                        boxShadow: c.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: c.errorBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.block_rounded, color: c.error, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'طلب #${order.orderNumber}',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary, fontFamily: 'Cairo'),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      order.patientSnapshot?['name'] ?? 'مريض',
                                      style: TextStyle(fontSize: 12, color: c.textSecondary, fontFamily: 'Cairo'),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${order.pricing?['total'] ?? 0} جنيه',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.primary, fontFamily: 'Cairo'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _undoRejectOrder(order.id),
                              icon: const Icon(Icons.restore_rounded, size: 18),
                              label: const Text('استعادة الطلب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: c.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════
  Widget _buildSkeletons({int count = 3}) {
    final c = context.colors;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: count,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 110,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border),
        ),
      ),
    );
  }

  /// Empty state
  Widget _buildScrollableEmpty(String title, String sub, IconData icon) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: EmptyStateWidget(
              icon: icon,
              title: title,
              description: '$sub\n\n↑ اسحب للأسفل للتحديث',
            ),
          ),
        ),
      ],
    );
  }

  /// Error state
  Widget _buildScrollableError(String msg, VoidCallback retry) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: ErrorStateWidget(
              message: '$msg\n\n↑ اسحب للأسفل لإعادة المحاولة',
              onRetry: retry,
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════
//  Available Order Card
// ══════════════════════════════════════════════════════
class _AvailableCard extends StatefulWidget {
  final MedicalOrder order;
  final bool isLoading;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onPrice;
  final bool isHighlighted;
  const _AvailableCard({
    required this.order,
    required this.isLoading,
    required this.onAccept,
    required this.onReject,
    required this.onPrice,
    this.isHighlighted = false,
  });
  @override
  State<_AvailableCard> createState() => _AvailableCardState();
}

class _AvailableCardState extends State<_AvailableCard> {
  bool _pressed = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    if (widget.isHighlighted) {
      _isExpanded = true;
    }
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String title, String value) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: c.primary),
          const SizedBox(width: 8),
          Text('$title: ', style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 12, color: c.textPrimary)),
          ),
        ],
      ),
    );
  }

  String _formatOrderTime(MedicalOrder order) {
    final schedule = order.schedule;
    if (schedule == null) return '-';
    
    String dateStr = '-';
    if (schedule['date'] != null) {
      try {
        final parsedDate = DateTime.parse(schedule['date']);
        final now = DateTime.now();
        if (parsedDate.year == now.year && parsedDate.month == now.month && parsedDate.day == now.day) {
          dateStr = 'اليوم';
        } else {
          dateStr = '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}';
        }
      } catch (_) {}
    }
    
    String slotStr = '';
    final slot = schedule['timeSlot'];
    if (slot == 'morning_9_12') slotStr = 'صباحاً (9:00 - 12:00)';
    if (slot == 'afternoon_12_3') slotStr = 'ظهراً (12:00 - 3:00)';
    if (slot == 'evening_3_6') slotStr = 'مساءً (3:00 - 6:00)';
    
    return '$dateStr · $slotStr';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = context.isDark;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: widget.isHighlighted ? c.primary : c.border,
            width: widget.isHighlighted ? 2.0 : 1.0,
          ),
          boxShadow: widget.isHighlighted
              ? [BoxShadow(color: c.primary.withOpacity(0.3), blurRadius: 10, spreadRadius: 2)]
              : (isDark ? [] : c.cardShadow),
        ),
        child: Column(
          children: [
            // Top
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: c.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(widget.order.orderNumber,
                                        style: TextStyle(fontWeight: FontWeight.w700, color: c.primary,
                                            fontFamily: 'Inter', fontSize: 13)),
                                    if (widget.order.schedule?['isEmergency'] == true) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: c.errorBg,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: c.error.withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          'عاجل',
                                          style: TextStyle(color: c.error, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                    widget.order.status == 'pending_review'
                                        ? 'حجز بواسطة الروشتة 📄 (يتطلب تسعير)'
                                        : widget.order.services.map((s) => s.nameAr).join(' + '),
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: widget.order.status == 'pending_review' ? FontWeight.w700 : FontWeight.normal,
                                        color: widget.order.status == 'pending_review' ? c.warning : c.textSecondary),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Text('${widget.order.pricing?['total'] ?? widget.order.pricing?['servicesTotal']} ج.م',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                                    color: c.primary, fontFamily: 'Inter')),
                            const SizedBox(width: 4),
                            Icon(
                              _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              color: c.textMuted,
                              size: 18,
                            ),
                          ],
                        ),
                        Text('نقداً', style: TextStyle(fontSize: 11, color: c.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Expanded details section
            if (_isExpanded) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(context, Icons.person_outline_rounded, 'اسم المريض', widget.order.patientSnapshot?['name'] ?? '-'),
                    _buildDetailRow(context, Icons.phone_outlined, 'الهاتف', widget.order.patientSnapshot?['phone'] ?? '-'),
                    _buildDetailRow(context, Icons.escalator_warning_outlined, 'بيانات الحالة', 
                        '${widget.order.patientSnapshot?['gender'] == 'male' ? 'ذكر' : 'أنثى'}، ${widget.order.patientSnapshot?['age'] ?? '-'} سنة'),
                    _buildDetailRow(context, Icons.hotel_outlined, 'ملازم للفراش', widget.order.caseDetails?['isBedridden'] == true ? 'نعم' : 'لا'),
                    if (widget.order.caseDetails?['weight'] != null)
                      _buildDetailRow(context, Icons.monitor_weight_outlined, 'الوزن', '${widget.order.caseDetails?['weight']} كجم'),
                    _buildDetailRow(context, Icons.layers_outlined, 'الطابق / المصعد', 
                        'الطابق ${widget.order.caseDetails?['floor'] ?? '-'} - ${widget.order.caseDetails?['hasElevator'] == true ? 'يوجد مصعد' : 'لا يوجد مصعد'}'),
                    _buildDetailRow(context, Icons.calendar_today_outlined, 'موعد الزيارة', _formatOrderTime(widget.order)),
                    if (widget.order.caseDetails?['notes']?.toString().isNotEmpty == true)
                      _buildDetailRow(context, Icons.description_outlined, 'ملاحظات', widget.order.caseDetails?['notes']),
                  ],
                ),
              ),
            ],
            
            // Divider
            Container(height: 1, color: c.border, margin: const EdgeInsets.symmetric(horizontal: 16)),
            
            // Location info
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(children: [
                Icon(Icons.location_on_rounded, size: 14, color: c.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${widget.order.location?['district'] ?? '-'} — ${widget.order.location?['street'] ?? '-'}',
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
            
            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(14),
              child: widget.order.status == 'pending_review'
                  ? Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: widget.isLoading ? null : widget.onPrice,
                            onTapDown: (_) => setState(() => _pressed = true),
                            onTapUp: (_) => setState(() => _pressed = false),
                            onTapCancel: () => setState(() => _pressed = false),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: widget.isLoading
                                    ? c.warning.withOpacity(0.6)
                                    : _pressed ? c.warning.withOpacity(0.85) : c.warning,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: widget.isLoading
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: c.warning.withOpacity(0.25),
                                          blurRadius: 16,
                                          offset: const Offset(0, 4),
                                        )
                                      ],
                              ),
                              child: Center(
                                child: widget.isLoading
                                    ? const SizedBox(height: 20, width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.edit_note_rounded, color: Colors.white, size: 20),
                                          SizedBox(width: 8),
                                          Text('معاينة الروشتة وتسعير الطلب',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700,
                                                  fontFamily: 'Cairo', fontSize: 13)),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: widget.isLoading ? null : widget.onAccept,
                            onTapDown: (_) => setState(() => _pressed = true),
                            onTapUp: (_) => setState(() => _pressed = false),
                            onTapCancel: () => setState(() => _pressed = false),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: widget.isLoading
                                    ? c.primary.withOpacity(0.6)
                                    : _pressed ? c.primary.withOpacity(0.85) : c.primary,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: widget.isLoading ? null : c.primaryGlow,
                              ),
                              child: Center(
                                child: widget.isLoading
                                    ? const SizedBox(height: 20, width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_rounded, color: Colors.white, size: 18),
                                          SizedBox(width: 8),
                                          Text('قبول وانطلاق',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700,
                                                  fontFamily: 'Cairo', fontSize: 13)),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: GestureDetector(
                            onTap: widget.isLoading ? null : widget.onReject,
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: c.errorBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: c.error.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.close_rounded, color: c.error, size: 16),
                                  const SizedBox(width: 4),
                                  Text('رفض',
                                      style: TextStyle(color: c.error, fontWeight: FontWeight.w700,
                                          fontFamily: 'Cairo', fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  History Card
// ══════════════════════════════════════════════════════
class _HistoryCard extends StatelessWidget {
  final MedicalOrder order;
  const _HistoryCard({required this.order});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
                color: c.successBg,
                borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.check_circle_rounded, color: c.success, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.orderNumber,
                    style: TextStyle(fontWeight: FontWeight.w700, color: c.textPrimary,
                        fontSize: 13, fontFamily: 'Inter')),
                const SizedBox(height: 3),
                Text('${order.patientSnapshot?['name']} · ${order.services.map((s) => s.nameAr).join(', ')}',
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${order.pricing?['total']} ج.م',
                  style: TextStyle(fontWeight: FontWeight.w800, color: c.success,
                      fontSize: 15, fontFamily: 'Inter')),
              Text('مكتمل', style: TextStyle(fontSize: 11, color: c.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  Shared UI Components
// ══════════════════════════════════════════════════════
class _TabItem extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  const _TabItem({required this.label, required this.count, required this.active});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: c.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count', style: TextStyle(fontSize: 10, color: c.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
        boxShadow: isDark ? [] : c.cardShadow,
      ),
      child: child,
    );
  }
}

class _SectionHead extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _SectionHead({required this.icon, required this.title, required this.color});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 10),
      Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
    ]);
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoTile(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: c.textMuted),
          const SizedBox(width: 8),
          SizedBox(width: 52, child: Text(label, style: TextStyle(fontSize: 12, color: c.textMuted))),
          const SizedBox(width: 6),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: c.textPrimary))),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 52,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Center(child: Text(label,
          style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Cairo'))),
    ),
  );
}

class _SolidTealBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Color primary;
  const _SolidTealBtn({required this.label, required this.onTap, required this.primary});
  @override
  State<_SolidTealBtn> createState() => _SolidTealBtnState();
}

class _SolidTealBtnState extends State<_SolidTealBtn> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: _pressed ? widget.primary.withOpacity(0.85) : widget.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: c.primaryGlow,
          ),
          child: Center(child: Text(widget.label,
              style: const TextStyle(color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.w800, fontFamily: 'Cairo'))),
        ),
      ),
    );
  }
}

// Small icon button used in the header
class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Icon(icon, color: Colors.white, size: 17),
    ),
  );
}
