import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tech_app/core/api/api_client.dart';
import 'package:tech_app/core/models/order.dart';
import 'package:tech_app/core/services/storage_service.dart';
import 'package:tech_app/core/services/notification_service.dart';
import 'package:tech_app/core/utils/constants.dart';
import 'package:tech_app/core/theme/app_colors.dart';
import 'package:tech_app/core/theme/theme_provider.dart';
import 'package:tech_app/core/theme/ui_components.dart';
import 'package:dio/dio.dart';
import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class TechOrdersScreen extends ConsumerStatefulWidget {
  const TechOrdersScreen({super.key});
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

  List<dynamic> _allServices = [];
  bool _isLoadingAvailable = false;
  bool _isLoadingActive = false;
  bool _isLoadingHistory = false;
  bool _isActionLoading = false;
  String? _loadingOrderId;

  String? _availableError;
  String? _activeError;
  String? _historyError;

  final List<String> _uploadedImageUrls = ['https://placehold.co/600x400.png'];
  final _reportNotesController = TextEditingController();
  final _api = ApiClient();
  
  String _paymentStatus = 'completed';
  String _paymentMethod = 'cash';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _loadUserData();
    _fetchAll();
    
    // Register FCM Device Token for notifications
    NotificationService.registerDeviceToken();
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
          _availableOrders = allOrders.where((order) => !rejected.contains(order.id)).toList();
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
    await StorageService.rejectOrder(orderId);
    setState(() {
      _availableOrders.removeWhere((order) => order.id == orderId);
    });
    _showSnack('❌ تم رفض وإخفاء الطلب بنجاح.', success: false);
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
        _showSnack(v ? '✅ أنت الآن نشط ومتاح' : '⏸️ تم إيقاف الاستقبال', success: v);
      }
    } on DioException catch (e) {
      _showSnack(_parseError(e), success: false);
    } catch (_) {
      _showSnack('فشل تغيير الحالة.', success: false);
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
        _showSnack('✅ تم قبول الطلب بنجاح!', success: true);
        // Remove the accepted order from the available list locally (no reload spinner)
        setState(() {
          _availableOrders.removeWhere((o) => o.id == orderId);
        });
        await _fetchActiveOrder();
        _tabController.animateTo(1);
      }
    } on DioException catch (e) {
      _showSnack(e.response?.data?['message'] ?? 'فشل القبول. ربما أُعطي لفني آخر.', success: false);
    } catch (_) {
      _showSnack('حدث خطأ. حاول مرة أخرى.', success: false);
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
        _showSnack(msg, success: true);
        await _fetchActiveOrder();
      }
    } on DioException catch (e) {
      _showSnack(e.response?.data?['message'] ?? 'فشل تحديث الحالة.', success: false);
    } catch (_) {
      _showSnack('حدث خطأ. حاول مرة أخرى.', success: false);
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _completeOrder() async {
    if (_uploadedImageUrls.isEmpty) { _showSnack('يرجى إرفاق صورة فحص واحدة على الأقل', success: false); return; }
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
        _showSnack('🎉 تم رفع التقرير وإتمام الطلب!', success: true);
        await _fetchActiveOrder();
        await _fetchHistory();
        if (mounted) {
          _showCompletionSuccessDialog(orderId);
        }
      }
    } on DioException catch (e) {
      _showSnack(e.response?.data?['message'] ?? 'فشل إتمام الطلب.', success: false);
    } catch (_) {
      _showSnack('حدث خطأ. حاول مرة أخرى.', success: false);
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
      try { await _api.dio.post(Constants.logout); } catch (_) {}
      await StorageService.clearAll();
      if (mounted) context.go('/login');
    }
  }

  void _showSnack(String msg, {required bool success}) {
    if (!mounted) return;
    final c = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        msg,
        style: TextStyle(
          fontFamily: 'Cairo',
          color: success ? c.success : c.error,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      backgroundColor: success ? c.successBg : c.errorBg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
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
      _showSnack('عذراً، فشل تحميل قائمة الخدمات الطبية.', success: false);
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
        _showSnack('🎉 تم حفظ التسعير وتحديث الطلب بنجاح!', success: true);
        _fetchAvailableOrders();
      }
    } on DioException catch (e) {
      _showSnack(e.response?.data?['message'] ?? 'فشل تسعير الطلب.', success: false);
    } catch (_) {
      _showSnack('حدث خطأ أثناء إرسال التسعير.', success: false);
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
                    ],
                  ),
                ),
              ],
            ),
          ],
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
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
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
      child: Row(
        children: [
          // Logo
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('سكان جو',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('مرحباً، $_techName',
                    style: const TextStyle(fontSize: 12, color: Color(0xCCFFFFFF))),
              ],
            ),
          ),

          // Duty toggle
          GestureDetector(
            onTap: _isDutyLoading ? null : _toggleDuty,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _isAvailable ? c.successBg : c.surfaceVariant.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                    color: _isAvailable ? c.success : c.border, width: 1.5),
              ),
              child: _isDutyLoading
                  ? SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: c.primary))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: _isAvailable ? c.success : c.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(_isAvailable ? 'نشط' : 'مغلق',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Cairo',
                                color: _isAvailable ? c.success : c.textMuted)),
                      ],
                    ),
            ),
          ),
          const SizedBox(width: 8),
          
          // Theme Toggle Button
          GestureDetector(
            onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.25))),
              child: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Profile Button
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.25))),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 8),

          GestureDetector(
            onTap: _logout,
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.25))),
              child: const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
            ),
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
                  _showSnack('تعذر فتح الخرائط. لا توجد تطبيقات خرائط مثبتة.', success: false);
                }
              } catch (e) {
                try {
                  await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
                } catch (_) {
                  _showSnack('حدث خطأ أثناء محاولة فتح الخرائط.', success: false);
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
            if (order.status == 'assigned')
              _ActionBtn(label: 'بدء الرحلة 🚗', color: c.warning,
                  onTap: () => _updateStatus('/technician/orders/${order.id}/start-trip', '✅ بدأت الرحلة')),
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
                    OutlinedButton.icon(
                      onPressed: () => _showSnack('✅ تم محاكاة رفع الصور', success: true),
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text('التقاط/رفع صور الأشعة'),
                    ),
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
  const _AvailableCard({
    required this.order,
    required this.isLoading,
    required this.onAccept,
    required this.onReject,
    required this.onPrice,
  });
  @override
  State<_AvailableCard> createState() => _AvailableCardState();
}

class _AvailableCardState extends State<_AvailableCard> {
  bool _pressed = false;
  bool _isExpanded = false;

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
          border: Border.all(color: c.border),
          boxShadow: isDark ? [] : c.cardShadow,
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
