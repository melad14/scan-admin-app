import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tech_app/core/api/api_client.dart';
import 'package:tech_app/core/theme/app_colors.dart';
import 'package:tech_app/core/theme/ui_components.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

class TechComplaintsScreen extends StatefulWidget {
  const TechComplaintsScreen({super.key});

  @override
  State<TechComplaintsScreen> createState() => _TechComplaintsScreenState();
}

class _TechComplaintsScreenState extends State<TechComplaintsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _api = ApiClient();

  List<dynamic> _myComplaints = [];
  List<dynamic> _forwardedComplaints = [];

  bool _isLoadingMy = true;
  bool _isLoadingForwarded = true;

  String? _errorMy;
  String? _errorForwarded;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchMyComplaints();
    _fetchForwardedComplaints();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchMyComplaints() async {
    setState(() {
      _isLoadingMy = true;
      _errorMy = null;
    });
    try {
      final res = await _api.dio.get('/complaints/my');
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _myComplaints = res.data['data'] ?? [];
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _errorMy = e.response?.data?['message'] ?? 'فشل تحميل قائمة شكاواك';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMy = 'حدث خطأ غير متوقع';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMy = false;
        });
      }
    }
  }

  Future<void> _fetchForwardedComplaints() async {
    setState(() {
      _isLoadingForwarded = true;
      _errorForwarded = null;
    });
    try {
      final res = await _api.dio.get('/complaints/forwarded');
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _forwardedComplaints = res.data['data'] ?? [];
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _errorForwarded = e.response?.data?['message'] ?? 'فشل تحميل التنبيهات الإدارية';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorForwarded = 'حدث خطأ غير متوقع';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingForwarded = false;
        });
      }
    }
  }

  Future<void> _resolveForwardedComplaint(String id) async {
    try {
      final res = await _api.dio.patch('/complaints/$id/resolve');
      if (res.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم حل الشكوى وتسوية النزاع بنجاح')),
        );
        _fetchForwardedComplaints();
      }
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data?['message'] ?? 'فشل تحديث الشكوى')),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ غير متوقع')),
      );
    }
  }

  Future<void> _callPatient(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح تطبيق الاتصال')),
        );
      }
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'قيد مراجعة الأدمن';
      case 'forwarded':
        return 'محولة لك للمتابعة والحل';
      case 'resolved':
        return 'تم حل النزاع بنجاح ✅';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status, AppColorTokens c) {
    switch (status) {
      case 'pending':
        return c.warning;
      case 'forwarded':
        return c.accent;
      case 'resolved':
        return c.success;
      default:
        return c.textSecondary;
    }
  }

  Color _getStatusBgColor(String status, AppColorTokens c) {
    switch (status) {
      case 'pending':
        return c.warningBg.withOpacity(0.08);
      case 'forwarded':
        return c.primaryLight;
      case 'resolved':
        return c.successBg;
      default:
        return c.borderLight;
    }
  }

  void _showCreateComplaintSheet() {
    final c = context.colors;
    String? selectedOrderId;
    final textController = TextEditingController();
    bool isSubmitting = false;
    bool isLoadingOrders = true;
    List<dynamic> myOrders = [];
    String? ordersError;

    // Load orders immediately
    void loadOrders(StateSetter setModalState) async {
      try {
        final historyRes = await _api.dio.get('/technician/orders/history');
        final List historyList = historyRes.data['data'] ?? [];

        final activeRes = await _api.dio.get('/technician/orders/active');
        final activeOrder = activeRes.data['data'];

        final allOrders = [...historyList];
        if (activeOrder != null) {
          allOrders.insert(0, activeOrder);
        }

        setModalState(() {
          myOrders = allOrders;
          isLoadingOrders = false;
          if (myOrders.isNotEmpty) {
            selectedOrderId = myOrders.first['_id'];
          }
        });
      } catch (e) {
        setModalState(() {
          ordersError = 'فشل تحميل الطلبات الخاصة بك';
          isLoadingOrders = false;
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (isLoadingOrders && myOrders.isEmpty && ordersError == null) {
              loadOrders(setModalState);
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36, height: 4,
                        decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'تقديم شكوى جديدة للإدارة ✍️',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary, fontFamily: 'Cairo'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (isLoadingOrders)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (ordersError != null)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(ordersError!, style: TextStyle(color: c.error, fontFamily: 'Cairo', fontSize: 13), textAlign: TextAlign.center),
                      )
                    else if (myOrders.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(30),
                        child: Text(
                          'لا توجد لديك طلبات نشطة أو منتهية حالياً لتقديم شكوى عليها.',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else ...[
                      Text(
                        'اختر الطلب المتعلق بالشكوى:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.textSecondary, fontFamily: 'Cairo'),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: c.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedOrderId,
                            isExpanded: true,
                            dropdownColor: c.surfaceElevated,
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: c.textPrimary),
                            onChanged: (val) {
                              setModalState(() => selectedOrderId = val);
                            },
                            items: myOrders.map<DropdownMenuItem<String>>((o) {
                              final orderNum = o['orderNumber'] ?? 'غير معروف';
                              final patientName = o['patientSnapshot']?['name'] ?? 'مريض غير معروف';
                              final cat = o['serviceCategory'] ?? '';
                              final catAr = cat == 'xray' ? 'أشعة' : cat == 'lab' ? 'تحاليل' : 'خدمة طبية';
                              return DropdownMenuItem<String>(
                                value: o['_id'] as String,
                                child: Text('طلب $orderNum - $patientName ($catAr)'),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'تفاصيل وموضوع الشكوى:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.textSecondary, fontFamily: 'Cairo'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: textController,
                        maxLines: 4,
                        style: TextStyle(fontSize: 13, color: c.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'اكتب تفاصيل الشكوى بوضوح هنا وسيتم مراجعتها واتخاذ اللازم من قبل الإدارة...',
                          hintStyle: TextStyle(fontSize: 12, color: c.textMuted, fontFamily: 'Cairo'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: isSubmitting
                            ? null
                            : () async {
                                final text = textController.text.trim();
                                if (selectedOrderId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('الرجاء اختيار الطلب أولاً')),
                                  );
                                  return;
                                }
                                if (text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('الرجاء كتابة تفاصيل الشكوى')),
                                  );
                                  return;
                                }

                                setModalState(() => isSubmitting = true);
                                try {
                                  final res = await _api.dio.post('/complaints', data: {
                                    'orderId': selectedOrderId,
                                    'text': text,
                                  });
                                  if (res.statusCode == 201 && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('🎉 تم إرسال الشكوى بنجاح وسيتم مراجعتها من قبل الإدارة')),
                                    );
                                    Navigator.pop(context);
                                    _fetchMyComplaints();
                                  }
                                } on DioException catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.response?.data?['message'] ?? 'فشل إرسال الشكوى')),
                                    );
                                  }
                                } catch (_) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('حدث خطأ غير متوقع')),
                                    );
                                  }
                                } finally {
                                  setModalState(() => isSubmitting = false);
                                }
                              },
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: isSubmitting ? c.primary.withOpacity(0.5) : c.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: isSubmitting
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('إرسال الشكوى للإدارة 📤', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'Cairo', fontSize: 14)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/profile');
        }
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.surface,
          elevation: 0,
          title: Text(
            'الشكاوى والاعتراضات الإدارية',
            style: TextStyle(color: c.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: c.textPrimary, size: 20),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/profile');
              }
            },
          ),
          bottom: TabBar(
            controller: _tabController,
            labelColor: c.primary,
            unselectedLabelColor: c.textMuted,
            indicatorColor: c.primary,
            labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(text: 'شكاوى محولة للمركز 📥'),
              Tab(text: 'شكاوى مرفوعة منى 📤'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildForwardedTab(c),
            _buildMyComplaintsTab(c),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCreateComplaintSheet,
          backgroundColor: c.primary,
          label: const Text('تقديم شكوى للإدارة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
          icon: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildForwardedTab(AppColorTokens c) {
    if (_isLoadingForwarded) {
      return Center(child: CircularProgressIndicator(color: c.primary));
    }
    if (_errorForwarded != null) {
      return ErrorStateWidget(
        message: _errorForwarded!,
        onRetry: _fetchForwardedComplaints,
      );
    }
    if (_forwardedComplaints.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.assignment_turned_in_rounded,
        title: 'لا توجد تنبيهات محولة',
        description: 'لم يتم توجيه أو تحويل أي تنبيهات أو شكاوى لك من قبل الإدارة حتى الآن.',
        actionLabel: 'تحديث الصفحة',
        onAction: _fetchForwardedComplaints,
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchForwardedComplaints,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _forwardedComplaints.length,
        itemBuilder: (context, index) {
          final comp = _forwardedComplaints[index];
          final status = comp['status'] ?? 'forwarded';
          final order = comp['orderId'];
          final patientPhone = order != null ? order['patientPhone'] : '';
          final patientName = order != null ? order['patientName'] : 'مريض غير معروف';
          final dateStr = comp['createdAt'] != null
              ? DateTime.parse(comp['createdAt']).toLocal().toString().substring(0, 16)
              : '-';

          return Card(
            color: c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: c.borderLight),
            ),
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        order != null ? 'طلب رقم: ${order['orderNumber']}' : 'طلب غير معروف',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: c.textPrimary, fontFamily: 'Cairo'),
                      ),
                      Text(
                        dateStr,
                        style: TextStyle(fontSize: 11, color: c.textMuted, fontFamily: 'Inter'),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Text(
                    'الشكوى المرفوعة من المريض ($patientName):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.accent, fontFamily: 'Cairo'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    comp['text'] ?? '',
                    style: TextStyle(fontSize: 13, color: c.textPrimary, fontFamily: 'Cairo', height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getStatusBgColor(status, c),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusLabel(status),
                      style: TextStyle(color: _getStatusColor(status, c), fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Cairo'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (status == 'forwarded') ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _callPatient(patientPhone),
                            icon: const Icon(Icons.phone, size: 16),
                            label: const Text('تواصل مع المريض', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _resolveForwardedComplaint(comp['_id']),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('تم حل المشكلة', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    )
                  ]
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMyComplaintsTab(AppColorTokens c) {
    if (_isLoadingMy) {
      return Center(child: CircularProgressIndicator(color: c.primary));
    }
    if (_errorMy != null) {
      return ErrorStateWidget(
        message: _errorMy!,
        onRetry: _fetchMyComplaints,
      );
    }
    if (_myComplaints.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.mark_chat_read_rounded,
        title: 'لا توجد شكاوى مرفوعة',
        description: 'لم تقم بتسجيل أي شكاوى أو اعتراضات خاصة بالطلبات حتى الآن.',
        actionLabel: 'تحديث الصفحة',
        onAction: _fetchMyComplaints,
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchMyComplaints,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myComplaints.length,
        itemBuilder: (context, index) {
          final comp = _myComplaints[index];
          final status = comp['status'] ?? 'pending';
          final order = comp['orderId'];
          final dateStr = comp['createdAt'] != null
              ? DateTime.parse(comp['createdAt']).toLocal().toString().substring(0, 16)
              : '-';

          return Card(
            color: c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: c.borderLight),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        order != null ? 'طلب رقم: ${order['orderNumber']}' : 'طلب غير معروف',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: c.textPrimary, fontFamily: 'Cairo'),
                      ),
                      Text(
                        dateStr,
                        style: TextStyle(fontSize: 11, color: c.textMuted, fontFamily: 'Inter'),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Text(
                    comp['text'] ?? '',
                    style: TextStyle(fontSize: 13, color: c.textPrimary, fontFamily: 'Cairo', height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getStatusBgColor(status, c),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusLabel(status),
                      style: TextStyle(color: _getStatusColor(status, c), fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Cairo'),
                      textAlign: TextAlign.center,
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
}
