import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tech_app/core/api/api_client.dart';
import 'package:tech_app/core/services/storage_service.dart';
import 'package:tech_app/core/utils/constants.dart';
import 'package:tech_app/core/theme/app_colors.dart';
import 'package:tech_app/core/theme/theme_provider.dart';
import 'package:dio/dio.dart';

class TechProfileScreen extends ConsumerStatefulWidget {
  const TechProfileScreen({super.key});

  @override
  ConsumerState<TechProfileScreen> createState() => _TechProfileScreenState();
}

class _TechProfileScreenState extends ConsumerState<TechProfileScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await _api.dio.get(Constants.profile);
      if (res.statusCode == 200 && mounted) {
        setState(() => _profile = res.data['data']);
      }
    } on DioException catch (e) {
      if (mounted) {
        if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
          setState(() => _error = 'تعذر الاتصال. تحقق من الإنترنت.');
        } else {
          setState(() => _error = e.response?.data?['message'] ?? 'حدث خطأ أثناء تحميل البيانات.');
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'حدث خطأ غير متوقع.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
            Text('تسجيل الخروج', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const SizedBox(height: 6),
            Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟',
                style: TextStyle(fontSize: 13, color: c.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء'))),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(color: c.error, borderRadius: BorderRadius.circular(14)),
                      child: const Center(child: Text('خروج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'Cairo', fontSize: 15))),
                    ),
                  ),
                ),
              ],
            ),
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = context.isDark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/');
        }
      },
      child: Scaffold(
        backgroundColor: c.background,
      body: RefreshIndicator(
        color: c.primary,
        backgroundColor: c.surface,
        onRefresh: _fetchProfile,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Header ──────────────────────────────────────────
            SliverToBoxAdapter(child: _buildHeader(c, isDark)),

            // ── Content ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: _isLoading
                  ? _buildLoadingState(c)
                  : _error != null
                      ? _buildErrorState(c)
                      : _buildProfileContent(c, isDark),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildHeader(AppColorTokens c, bool isDark) {
    final name = _profile?['name'] ?? 'الفني';
    final phone = _profile?['phone'] ?? '';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final rating = (_profile?['rating'] ?? 0).toDouble();
    final completedOrders = _profile?['completedOrders'] ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0A0F1E), const Color(0xFF0F1729)]
              : [const Color(0xFF085041), const Color(0xFF1D9E75)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // ── Top bar ─────────────────────────────────────────
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.go('/');
                  }
                },
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              const Text('الملف الشخصي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              const Spacer(),
              _ThemeToggleButton(),
            ],
          ),
          const SizedBox(height: 24),

          // ── Avatar ──────────────────────────────────────────
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 3),
            ),
            child: Center(
              child: Text(initials,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 14),
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(phone, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7), fontFamily: 'Inter')),
          ],

          const SizedBox(height: 20),

          // ── Stats Row ───────────────────────────────────────
          if (!_isLoading && _error == null)
            Row(
              children: [
                Expanded(child: _StatBadge(
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFD97B0A),
                  label: 'التقييم',
                  value: rating > 0 ? rating.toStringAsFixed(1) : '—',
                )),
                const SizedBox(width: 12),
                Expanded(child: _StatBadge(
                  icon: Icons.check_circle_rounded,
                  iconColor: const Color(0xFF4D8C2C),
                  label: 'طلبات مكتملة',
                  value: completedOrders.toString(),
                )),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(AppColorTokens c) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3, color: c.primary)),
            const SizedBox(height: 16),
            Text('جارٍ تحميل البيانات...', style: TextStyle(color: c.textSecondary, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(AppColorTokens c) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(color: c.errorBg, borderRadius: BorderRadius.circular(18)),
              child: Icon(Icons.wifi_off_rounded, color: c.error, size: 30),
            ),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: c.textSecondary, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _fetchProfile,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(12)),
                child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(AppColorTokens c, bool isDark) {
    final profile = _profile!;
    final nationalId = profile['nationalId'] ?? '';
    final maskedNationalId = nationalId.length > 4
        ? '${'*' * (nationalId.length - 4)}${nationalId.substring(nationalId.length - 4)}'
        : nationalId;
    final isAvailable = profile['isAvailable'] == true;
    final createdAt = profile['createdAt'] != null
        ? DateTime.tryParse(profile['createdAt'])
        : null;
    final memberSince = createdAt != null
        ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
        : 'غير محدد';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section: Personal Information ─────────────────
          _sectionTitle(c, 'المعلومات الشخصية', Icons.person_outline_rounded),
          const SizedBox(height: 12),
          _infoCard(c, isDark, [
            _InfoRow(icon: Icons.person_rounded, label: 'الاسم', value: profile['name'] ?? 'غير محدد'),
            _InfoRow(icon: Icons.phone_outlined, label: 'رقم الهاتف', value: profile['phone'] ?? 'غير مسجل', mono: true),
            _InfoRow(icon: Icons.badge_outlined, label: 'الرقم القومي', value: maskedNationalId.isNotEmpty ? maskedNationalId : 'غير محدد', mono: true),
          ]),

          const SizedBox(height: 20),

          // ── Section: Work Details ──────────────────────────
          _sectionTitle(c, 'بيانات العمل', Icons.work_outline_rounded),
          const SizedBox(height: 12),
          _infoCard(c, isDark, [
            _InfoRow(icon: Icons.location_on_outlined, label: 'منطقة العمل', value: profile['region'] ?? 'غير محدد'),
            _InfoRow(
              icon: isAvailable ? Icons.check_circle_outline_rounded : Icons.pause_circle_outline_rounded,
              label: 'حالة الاستقبال',
              value: isAvailable ? 'نشط ومتاح ✅' : 'متوقف عن الاستقبال ⏸️',
            ),
            _InfoRow(icon: Icons.calendar_today_rounded, label: 'عضو منذ', value: memberSince),
          ]),

          const SizedBox(height: 20),

          // ── Section: Support & Disputes ────────────────────
          _sectionTitle(c, 'الدعم والاعتراضات الإدارية', Icons.warning_amber_rounded),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.border),
              boxShadow: isDark ? [] : c.cardShadow,
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => context.push('/profile/complaints'),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: c.primaryLight, borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.notifications_active_rounded, color: c.primary, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('شكاوى واعتراضات فريق المركز', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary, fontFamily: 'Cairo')),
                              const SizedBox(height: 3),
                              Text('متابعة الشكاوى المرسلة والتنبيهات المحولة من الإدارة', style: TextStyle(fontSize: 11, color: c.textSecondary, fontFamily: 'Cairo')),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, color: c.textMuted, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Logout Button ─────────────────────────────────
          GestureDetector(
            onTap: _logout,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: c.errorBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.error.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: c.error, size: 20),
                  const SizedBox(width: 10),
                  Text('تسجيل الخروج', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.error)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionTitle(AppColorTokens c, String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 4, height: 20,
          decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: c.primary, size: 18),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
      ],
    );
  }

  Widget _infoCard(AppColorTokens c, bool isDark, List<_InfoRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
        boxShadow: isDark ? [] : c.cardShadow,
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: c.primaryLight, borderRadius: BorderRadius.circular(12)),
                    child: Icon(rows[i].icon, color: c.primary, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rows[i].label, style: TextStyle(fontSize: 11, color: c.textMuted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(rows[i].value,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                            fontFamily: rows[i].mono ? 'Inter' : 'Cairo',
                          )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (i < rows.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(height: 1, color: c.borderLight),
              ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  final bool mono;
  const _InfoRow({required this.icon, required this.label, required this.value, this.mono = false});
}

// ══════════════════════════════════════════════════════════
//  Stat Badge — shows rating or completed orders count
// ══════════════════════════════════════════════════════════
class _StatBadge extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const _StatBadge({required this.icon, required this.iconColor, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Inter')),
              Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Theme Toggle Button
// ══════════════════════════════════════════════════════════
class _ThemeToggleButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    return GestureDetector(
      onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            key: ValueKey(isDark),
            color: Colors.white, size: 18,
          ),
        ),
      ),
    );
  }
}
