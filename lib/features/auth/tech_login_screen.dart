import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:tech_app/core/utils/constants.dart';
import 'package:tech_app/core/services/storage_service.dart';
import 'package:tech_app/core/theme/app_colors.dart';
import 'dart:math' as math;

class TechLoginScreen extends StatefulWidget {
  const TechLoginScreen({super.key});
  @override
  State<TechLoginScreen> createState() => _TechLoginScreenState();
}

class _TechLoginScreenState extends State<TechLoginScreen>
    with TickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _passwordVisible = false;
  String? _errorMessage;

  late AnimationController _bgController;
  late AnimationController _entryController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final _dio = Dio(BaseOptions(
    baseUrl: Constants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));
    _entryController.forward();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entryController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (phone.isEmpty) { setState(() => _errorMessage = 'يرجى إدخال رقم الهاتف'); return; }
    if (phone.length < 10) { setState(() => _errorMessage = 'رقم الهاتف يجب أن يكون 10 أرقام على الأقل'); return; }
    if (password.isEmpty) { setState(() => _errorMessage = 'يرجى إدخال كلمة المرور'); return; }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final res = await _dio.post(Constants.loginTech, data: {'phone': phone, 'password': password});
      if (res.statusCode == 200 && res.data['success'] == true) {
        await StorageService.saveAccessToken(res.data['data']['accessToken']);
        await StorageService.saveRefreshToken(res.data['data']['refreshToken']);
        await StorageService.saveUserRole('technician');
        await StorageService.saveUserData(res.data['data']['technician']);
        if (mounted) context.go('/');
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final msg  = e.response?.data?['message'];
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.receiveTimeout) {
        setState(() => _errorMessage = 'تعذر الاتصال. تحقق من اتصالك بالإنترنت.');
      } else if (code == 401) {
        setState(() => _errorMessage = 'رقم الهاتف أو كلمة المرور غير صحيحة');
      } else if (code == 403) {
        setState(() => _errorMessage = 'حسابك غير مفعل. تواصل مع الإدارة.');
      } else if (code == 429) {
        setState(() => _errorMessage = 'محاولات كثيرة. انتظر قليلاً.');
      } else if ((code ?? 0) >= 500) {
        setState(() => _errorMessage = 'خطأ في الخادم. حاول مرة أخرى لاحقاً.');
      } else {
        setState(() => _errorMessage = msg ?? 'فشل تسجيل الدخول.');
      }
    } catch (_) {
      setState(() => _errorMessage = 'حدث خطأ غير متوقع. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          // ── Animated Background ──────────────────────────
          Container(
            decoration: const BoxDecoration(gradient: AppColors.heroGradient),
          ),
          // Orb 1 — Cyan
          AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) {
              final t = _bgController.value * 2 * math.pi;
              return Positioned(
                top: size.height * 0.08 + math.sin(t) * 18,
                right: -60,
                child: Container(
                  width: 260, height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.primary.withValues(alpha: 0.25),
                      AppColors.primary.withValues(alpha: 0.0),
                    ]),
                  ),
                ),
              );
            },
          ),
          // Orb 2 — Purple
          AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) {
              final t = _bgController.value * 2 * math.pi + 2;
              return Positioned(
                bottom: size.height * 0.12 + math.cos(t) * 15,
                left: -80,
                child: Container(
                  width: 300, height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.accent.withValues(alpha: 0.2),
                      AppColors.accent.withValues(alpha: 0.0),
                    ]),
                  ),
                ),
              );
            },
          ),

          // ── Content ──────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const SizedBox(height: 52),

                      // ── Brand Pill ─────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: AppColors.borderCyan),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 8, height: 8,
                                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            const Text('بوابة الفني الطبي',
                                style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Glowing Logo ───────────────────────
                      Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: AppColors.primaryGradient,
                          boxShadow: AppColors.cyanGlow,
                        ),
                        child: const Icon(Icons.medical_services_rounded,
                            color: Colors.white, size: 44),
                      ),
                      const SizedBox(height: 22),

                      // ── Title ─────────────────────────────
                      ShaderMask(
                        shaderCallback: (b) => AppColors.primaryGradient.createShader(b),
                        child: const Text('سكان جو',
                            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900,
                                color: Colors.white, letterSpacing: -1)),
                      ),
                      const SizedBox(height: 6),
                      const Text('لوحة تحكم الفني الطبي',
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      const SizedBox(height: 44),

                      // ── Glass Form Card ────────────────────
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: AppColors.borderCyan),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Error Banner
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.errorBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(_errorMessage!,
                                      style: const TextStyle(color: AppColors.error, fontSize: 13, height: 1.4))),
                                  GestureDetector(
                                    onTap: () => setState(() => _errorMessage = null),
                                    child: const Icon(Icons.close_rounded, color: AppColors.error, size: 18),
                                  ),
                                ]),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Phone
                            _FieldLabel('رقم الهاتف'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.phone_rounded),
                                hintText: '01012345678',
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Password
                            _FieldLabel('كلمة المرور'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _passwordController,
                              obscureText: !_passwordVisible,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(color: AppColors.textPrimary),
                              onSubmitted: (_) => _handleLogin(),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                hintText: '••••••••',
                                suffixIcon: IconButton(
                                  icon: Icon(_passwordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                      color: AppColors.textMuted, size: 20),
                                  onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Login Button
                            _CyanButton(label: 'دخول', isLoading: _isLoading, onTap: _handleLogin),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Footer
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield_outlined, size: 15, color: AppColors.textMuted),
                            SizedBox(width: 8),
                            Text('للفنيين الطبيين المعتمدين فقط',
                                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Field Label ────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary));
}

// ── Cyan Gradient Button ───────────────────────────────────────
class _CyanButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;
  const _CyanButton({required this.label, required this.isLoading, required this.onTap});
  @override
  State<_CyanButton> createState() => _CyanButtonState();
}

class _CyanButtonState extends State<_CyanButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isLoading ? null : widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: widget.isLoading ? null : AppColors.primaryGradient,
            color: widget.isLoading ? AppColors.surfaceVariant : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: widget.isLoading ? null : AppColors.cyanGlow,
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(height: 22, width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary))
                : Text(widget.label,
                    style: const TextStyle(color: Colors.white, fontSize: 17,
                        fontWeight: FontWeight.w800, fontFamily: 'Cairo')),
          ),
        ),
      ),
    );
  }
}
