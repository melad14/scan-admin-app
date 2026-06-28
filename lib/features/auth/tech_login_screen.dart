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
    final c = context.colors;
    final isDark = context.isDark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: [
          // ── Animated Background Orbs (Only shown in Dark Mode for premium contrast) ──
          if (isDark) ...[
            // Orb 1 — Teal
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
                        c.primary.withOpacity(0.18),
                        c.primary.withOpacity(0.0),
                      ]),
                    ),
                  ),
                );
              },
            ),
            // Orb 2 — Darker Accent
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
                        c.accent.withOpacity(0.12),
                        c.accent.withOpacity(0.0),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ],

          // ── Content ──────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),

                        // ── Brand Pill ─────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: c.primaryLight,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: c.primary.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 8, height: 8,
                                  decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text('بوابة الفني الطبي',
                                  style: TextStyle(color: c.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ── Logo ───────────────────────────────
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: c.primary,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: c.primaryGlow,
                          ),
                          child: const Icon(Icons.medical_services_rounded,
                              color: Colors.white, size: 40),
                        ),
                        const SizedBox(height: 20),

                        // ── Title ──────────────────────────────
                        Text('سكان جو',
                            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
                                color: c.textPrimary, letterSpacing: -0.5)),
                        const SizedBox(height: 6),
                        Text('لوحة تحكم الفني الطبي',
                            style: TextStyle(fontSize: 14, color: c.textSecondary)),
                        const SizedBox(height: 36),

                        // ── Form Card ──────────────────────────
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: c.border),
                            boxShadow: isDark ? [] : c.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Error Banner
                              if (_errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: c.errorBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: c.error.withOpacity(0.3)),
                                  ),
                                  child: Row(children: [
                                    Icon(Icons.error_outline_rounded, color: c.error, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(_errorMessage!,
                                        style: TextStyle(color: c.error, fontSize: 13, height: 1.4))),
                                    GestureDetector(
                                      onTap: () => setState(() => _errorMessage = null),
                                      child: Icon(Icons.close_rounded, color: c.error, size: 18),
                                    ),
                                  ]),
                                ),
                                const SizedBox(height: 20),
                              ],

                              // Phone
                              _FieldLabel(text: 'رقم الهاتف', colors: c),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.right,
                                style: TextStyle(color: c.textPrimary),
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.phone_rounded),
                                  hintText: '01012345678',
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Password
                              _FieldLabel(text: 'كلمة المرور', colors: c),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _passwordController,
                                obscureText: !_passwordVisible,
                                textDirection: TextDirection.ltr,
                                style: TextStyle(color: c.textPrimary),
                                onSubmitted: (_) => _handleLogin(),
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  hintText: '••••••••',
                                  suffixIcon: IconButton(
                                    icon: Icon(_passwordVisible
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                        color: c.textMuted, size: 20),
                                    onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Login Button
                              _TealButton(label: 'دخول', isLoading: _isLoading, primary: c.primary, onTap: _handleLogin),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Footer
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: c.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shield_outlined, size: 15, color: c.textMuted),
                              const SizedBox(width: 8),
                              Text('للفنيين الطبيين المعتمدين فقط',
                                  style: TextStyle(fontSize: 12, color: c.textMuted)),
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
          ),
        ],
      ),
    );
  }
}

// ── Field Label ────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  final AppColorTokens colors;
  const _FieldLabel({required this.text, required this.colors});
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textSecondary));
}

// ── Teal Solid Button ───────────────────────────────────────────
class _TealButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final Color primary;
  final VoidCallback onTap;
  const _TealButton({required this.label, required this.isLoading, required this.primary, required this.onTap});
  @override
  State<_TealButton> createState() => _TealButtonState();
}

class _TealButtonState extends State<_TealButton> {
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
            color: widget.isLoading
                ? widget.primary.withOpacity(0.6)
                : _pressed ? widget.primary.withOpacity(0.85) : widget.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.isLoading ? [] : [
              BoxShadow(color: widget.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(height: 22, width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text(widget.label,
                    style: const TextStyle(color: Colors.white, fontSize: 17,
                        fontWeight: FontWeight.w800, fontFamily: 'Cairo')),
          ),
        ),
      ),
    );
  }
}
