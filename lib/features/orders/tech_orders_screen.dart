import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tech_app/core/api/api_client.dart';
import 'package:tech_app/core/models/order.dart';
import 'package:tech_app/core/services/storage_service.dart';
import 'package:tech_app/core/utils/constants.dart';

class TechOrdersScreen extends StatefulWidget {
  const TechOrdersScreen({super.key});

  @override
  State<TechOrdersScreen> createState() => _TechOrdersScreenState();
}

class _TechOrdersScreenState extends State<TechOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isAvailable = true;
  bool _isLoading = false;

  List<MedicalOrder> _availableOrders = [];
  MedicalOrder? _activeOrder;
  List<MedicalOrder> _historyOrders = [];

  // Report Upload inputs (Mock uploads buffer)
  final List<String> _uploadedImageUrls = ['https://placehold.co/600x400.png']; // Mock uploaded X-ray
  final _reportNotesController = TextEditingController();

  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAvailability();
    _fetchAvailableOrders();
    _fetchActiveOrder();
    _fetchHistory();
  }

  Future<void> _loadAvailability() async {
    final userData = await StorageService.getUserData();
    if (userData != null) {
      setState(() => _isAvailable = userData['isAvailable'] ?? true);
    }
  }

  Future<void> _fetchAvailableOrders() async {
    try {
      final res = await _api.dio.get(Constants.techAvailableOrders);
      if (res.statusCode == 200) {
        final List list = res.data['data'] ?? [];
        setState(() {
          _availableOrders = list.map((item) => MedicalOrder.fromJson(item)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchActiveOrder() async {
    try {
      final res = await _api.dio.get(Constants.techActiveOrder);
      if (res.statusCode == 200 && res.data['data'] != null) {
        setState(() {
          _activeOrder = MedicalOrder.fromJson(res.data['data']);
        });
      } else {
        setState(() => _activeOrder = null);
      }
    } catch (_) {}
  }

  Future<void> _fetchHistory() async {
    try {
      final res = await _api.dio.get(Constants.techOrdersHistory);
      if (res.statusCode == 200) {
        final List list = res.data['data'] ?? [];
        setState(() {
          _historyOrders = list.map((item) => MedicalOrder.fromJson(item)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleDuty() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.dio.put(Constants.techAvailability);
      if (res.statusCode == 200) {
        setState(() => _isAvailable = res.data['data']['isAvailable']);
        
        final userData = await StorageService.getUserData();
        if (userData != null) {
          userData['isAvailable'] = _isAvailable;
          await StorageService.saveUserData(userData);
        }
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _acceptOrder(String orderId) async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.dio.put('/technician/orders/$orderId/accept');
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم قبول الطلب وتعيينه لك بنجاح')),
        );
        _fetchActiveOrder();
        _fetchAvailableOrders();
        _tabController.animateTo(1); // switch to Active tab
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل قبول الطلب. ربما تم تعيينه لفني آخر.')),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _updateStatus(String endpoint, String successMsg) async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.dio.put(endpoint);
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMsg)));
        _fetchActiveOrder();
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل تحديث الحالة')));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _completeOrder() async {
    if (_uploadedImageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إرفاق صورة فحص واحدة على الأقل لإتمام الطلب')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final orderId = _activeOrder!.id;
      final payload = {
        'images': _uploadedImageUrls,
        'pdf': 'http://localhost:3000/uploads/reports/mock-result.pdf', // Mock PDF report
        'notes': _reportNotesController.text.trim()
      };

      final res = await _api.dio.post('/technician/orders/$orderId/upload-report', data: payload);
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفع التقرير الطبي والنتائج وإتمام الطلب بنجاح!')),
        );
        _reportNotesController.clear();
        _fetchActiveOrder();
        _fetchHistory();
        _tabController.animateTo(2); // switch to history
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل إتمام الطلب')));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _logout() async {
    await _api.dio.post(Constants.logout);
    await StorageService.clearAll();
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بوابة الفني الطبي'),
        actions: [
          Row(
            children: [
              Text(_isAvailable ? 'نشط للعمل' : 'مغلق', style: const TextStyle(fontSize: 12)),
              Switch(
                value: _isAvailable,
                activeColor: const Color(0xFF0D9488),
                onChanged: _isLoading ? null : (_) => _toggleDuty(),
              ),
            ],
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF0D9488),
          labelColor: const Color(0xFF0D9488),
          tabs: const [
            Tab(text: 'الطلبات المتاحة'),
            Tab(text: 'الطلب النشط'),
            Tab(text: 'الزيارات المنفذة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAvailableOrdersTab(),
          _buildActiveOrderTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildAvailableOrdersTab() {
    return RefreshIndicator(
      onRefresh: _fetchAvailableOrders,
      child: _availableOrders.isEmpty
          ? const Center(child: Text('لا توجد طلبات معلقة متوفرة في منطقتك حالياً'))
          : ListView.builder(
              itemCount: _availableOrders.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final order = _availableOrders[index];
                return Card(
                  color: const Color(0xFF131B2E),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
                            Text('${order.pricing?['total']} ج.م', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('الموقع: ${order.location?['district']} - الشارع: ${order.location?['street']}', style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 8),
                        Text('الفحوصات: ${order.services.map((s) => s.nameAr).join(' + ')}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _acceptOrder(order.id),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
                          child: const Text('قبول الطلب وتأكيد الانتقال'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildActiveOrderTab() {
    if (_activeOrder == null) {
      return const Center(child: Text('ليس لديك طلبات نشطة حالياً. اقبل طلب من تبويب الطلبات المتاحة.'));
    }

    final order = _activeOrder!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Order Header
          Text(
            'طلب نشط رقم ${order.orderNumber}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Patient details card
          Card(
            color: const Color(0xFF131B2E),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('بيانات المريض وموقع الزيارة:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(height: 20),
                  Text('الاسم: ${order.patientSnapshot?['name']}'),
                  const SizedBox(height: 4),
                  Text('الهاتف: ${order.patientSnapshot?['phone']}'),
                  const SizedBox(height: 4),
                  Text('العنوان: ${order.location?['street']}، ${order.location?['district']}'),
                  const SizedBox(height: 4),
                  Text('ملاحظات الحالة: ${order.caseDetails?['notes'] ?? 'لا يوجد'}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Dynamic Status controller actions
          if (order.status == 'assigned') ...[
            ElevatedButton(
              onPressed: () => _updateStatus('/technician/orders/${order.id}/start-trip', 'تم بدء الرحلة للمريض'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
              child: const Text('بدء الرحلة والتوجه للمريض (Start Trip)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ] else if (order.status == 'on_way') ...[
            ElevatedButton(
              onPressed: () => _updateStatus('/technician/orders/${order.id}/arrived', 'تم تسجيل وصولك للموقع'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.all(16)),
              child: const Text('لقد وصلت لموقع المريض (Arrived)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ] else if (order.status == 'arrived') ...[
            ElevatedButton(
              onPressed: () => _updateStatus('/technician/orders/${order.id}/start-service', 'بدء الفحص الطبي'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, padding: const EdgeInsets.all(16)),
              child: const Text('بدء إجراء الفحص الطبي (Start Service)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ] else if (order.status == 'in_progress') ...[
            // Report Upload inputs Form
            const Text('رفع التقارير الطبية ونتائج الفحص:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFF131B2E),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _reportNotesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات الفني وتقرير الأشعة المكتوب',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        // Simulate taking X-ray / picking files
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم محاكاة التقاط ورفع صور الفحص الطبي')),
                        );
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('التقاط/رفع صور الأشعة والنتائج'),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _completeOrder,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(14)),
                      child: const Text('تأكيد رفع النتائج وإكمال الطلب'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return RefreshIndicator(
      onRefresh: _fetchHistory,
      child: _historyOrders.isEmpty
          ? const Center(child: Text('لم تقم بإتمام أي زيارات طبية بعد'))
          : ListView.builder(
              itemCount: _historyOrders.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final order = _historyOrders[index];
                return Card(
                  color: const Color(0xFF131B2E),
                  child: ListTile(
                    title: Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${order.patientSnapshot?['name']} - الفحوصات: ${order.services.map((s) => s.nameEn).join(', ')}'),
                    trailing: Text('${order.pricing?['total']} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ),
                );
              },
            ),
    );
  }

  @override
  void dispose() {
    _reportNotesController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}
