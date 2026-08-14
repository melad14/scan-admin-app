import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:dr_ray_technician/core/utils/constants.dart';
import 'package:dr_ray_technician/core/services/storage_service.dart';
import 'package:dr_ray_technician/core/services/notification_service.dart';
import 'package:dr_ray_technician/core/theme/app_colors.dart';

class TechLoginScreen extends StatefulWidget {
  const TechLoginScreen({super.key});
  @override
  State<TechLoginScreen> createState() => _TechLoginScreenState();
}

class _TechLoginScreenState extends State<TechLoginScreen>
    with TickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneFocus = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _passwordVisible = false;
  String? _errorMessage;

  late AnimationController _bgController;
  late AnimationController _entryController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _scaleAnim;

  final _dio = Dio(BaseOptions(
    baseUrl: Constants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: const Interval(0.3, 1.0, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic)));
    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.0, 0.65, curve: Curves.elasticOut)));
    _entryController.forward();

    _phoneFocus.addListener(() => setState(() {}));
    _passwordFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entryController.dispose();
    _pulseController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _phoneFocus.dispose();
    _passwordFocusNode.dispose();
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
        await NotificationService.registerDeviceToken();
        if (mounted) context.go('/');
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      String? msg;
      if (e.response?.data is Map) {
        msg = e.response?.data['message']?.toString();
      } else if (e.response?.data is String) {
        msg = e.response?.data as String;
      }
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF070D1F),
        body: Stack(
          children: [
            // ── Animated Background ─────────────────────────────
            AnimatedBuilder(
              animation: Listenable.merge([_bgController, _pulseController]),
              builder: (_, __) {
                final t = _bgController.value * 2 * math.pi;
                final p = _pulseController.value;
                return Stack(
                  children: [
                    // Base gradient
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF070D1F), Color(0xFF0D1530), Color(0xFF070D1F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    // Orb teal — top right
                    Positioned(
                      top: size.height * 0.05 + math.sin(t) * 20,
                      right: -size.width * 0.2 + math.cos(t) * 10,
                      child: Container(
                        width: size.width * 0.75,
                        height: size.width * 0.75,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                            color: const Color(0xFF1D9E75).withOpacity(0.12 + p * 0.06),
                            blurRadius: 100,
                            spreadRadius: 40,
                          )],
                        ),
                      ),
                    ),
                    // Orb blue — bottom left
                    Positioned(
                      bottom: size.height * 0.1 + math.cos(t * 0.7) * 25,
                      left: -size.width * 0.25 + math.sin(t * 0.7) * 15,
                      child: Container(
                        width: size.width * 0.8,
                        height: size.width * 0.8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                            color: const Color(0xFF2B7EC2).withOpacity(0.10 + p * 0.04),
                            blurRadius: 100,
                            spreadRadius: 30,
                          )],
                        ),
                      ),
                    ),
                    // Hex grid pattern
                    CustomPaint(
                      size: size,
                      painter: _HexGridPainter(opacity: 0.035),
                    ),
                  ],
                );
              },
            ),

            // ── Content ─────────────────────────────────────────
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 24),

                          // ── Role Badge ──────────────────────────
                          ScaleTransition(
                            scale: _scaleAnim,
                            child: Column(
                              children: [
                                // Badge pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: const Color(0xFF1D9E75).withOpacity(0.4)),
                                    color: const Color(0xFF1D9E75).withOpacity(0.1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8, height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF2DDBA4),
                                          shape: BoxShape.circle,
                                          boxShadow: [BoxShadow(color: Color(0xFF2DDBA4), blurRadius: 6)],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'بوابة فريق الفنيين',
                                        style: TextStyle(
                                          color: Color(0xFF2DDBA4),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'Cairo',
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 28),

                                // Logo with layered glow
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Outer glow
                                    Container(
                                      width: 100, height: 100,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(color: const Color(0xFF1D9E75).withOpacity(0.3), blurRadius: 40, spreadRadius: 10),
                                        ],
                                      ),
                                    ),
                                    // Logo container
                                    Container(
                                      width: 88, height: 88,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF2DDBA4), Color(0xFF1D9E75), Color(0xFF085041)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        border: Border.all(color: Colors.white.withOpacity(0.15), width: 2),
                                      ),
                                      child: ClipOval(
                                        child: Image.asset(
                                          'assets/icon/app_icon.png',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(
                                            Icons.engineering_rounded,
                                            color: Colors.white, size: 44,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                const Text(
                                  'Dr Ray Technician',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                    shadows: [Shadow(color: Color(0xFF1D9E75), blurRadius: 20)],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'نظام إدارة الفنيين الميدانيين',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.5),
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 36),

                          // ── Glass Form Card ─────────────────────
                          ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Container(
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'تسجيل الدخول',
                                      style: TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        fontFamily: 'Cairo',
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 24),

                                    // Error
                                    if (_errorMessage != null) ...[
                                      _TechErrorBanner(message: _errorMessage!, onClose: () => setState(() => _errorMessage = null)),
                                      const SizedBox(height: 20),
                                    ],

                                    // Phone field
                                    _TechInputField(
                                      controller: _phoneController,
                                      focusNode: _phoneFocus,
                                      label: 'رقم الهاتف',
                                      hint: '01012345678',
                                      icon: Icons.phone_rounded,
                                      isFocused: _phoneFocus.hasFocus,
                                      keyboardType: TextInputType.phone,
                                      textDirection: TextDirection.ltr,
                                      textAlign: TextAlign.right,
                                      onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                                    ),
                                    const SizedBox(height: 16),

                                    // Password field
                                    _TechInputField(
                                      controller: _passwordController,
                                      focusNode: _passwordFocusNode,
                                      label: 'كلمة المرور',
                                      hint: '••••••••',
                                      icon: Icons.lock_outline_rounded,
                                      isFocused: _passwordFocusNode.hasFocus,
                                      obscureText: !_passwordVisible,
                                      onSubmitted: (_) => _handleLogin(),
                                      suffixWidget: GestureDetector(
                                        onTap: () => setState(() => _passwordVisible = !_passwordVisible),
                                        child: Icon(
                                          _passwordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                          color: Colors.white.withOpacity(0.45),
                                          size: 20,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 32),

                                    // Login Button
                                    _TechGlowButton(
                                      label: 'دخول',
                                      isLoading: _isLoading,
                                      onTap: _handleLogin,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Security Notice
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.shield_outlined, size: 15, color: Colors.white.withOpacity(0.35)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'لممثلي المركز المعتمدين فقط',
                                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.35), fontFamily: 'Cairo'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hex Grid Painter ─────────────────────────────────────────────────
class _HexGridPainter extends CustomPainter {
  final double opacity;
  _HexGridPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const r = 24.0;
    final h = r * math.sqrt(3);
    double x = 0, y = 0;
    int row = 0;
    while (y < size.height + r) {
      x = (row % 2 == 0) ? 0 : h;
      while (x < size.width + r) {
        _drawHex(canvas, paint, x, y, r);
        x += h * 2;
      }
      y += r * 1.5;
      row++;
    }
  }

  void _drawHex(Canvas canvas, Paint paint, double cx, double cy, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = math.pi / 180 * (60 * i - 30);
      final px = cx + r * math.cos(angle);
      final py = cy + r * math.sin(angle);
      if (i == 0) path.moveTo(px, py); else path.lineTo(px, py);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HexGridPainter oldDelegate) => false;
}

// ── Tech Input Field ─────────────────────────────────────────────────
class _TechInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final bool isFocused;
  final bool obscureText;
  final TextDirection? textDirection;
  final TextAlign textAlign;
  final TextInputType? keyboardType;
  final Widget? suffixWidget;
  final ValueChanged<String>? onSubmitted;

  const _TechInputField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    required this.isFocused,
    this.obscureText = false,
    this.textDirection,
    this.textAlign = TextAlign.start,
    this.keyboardType,
    this.suffixWidget,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF1D9E75);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.65),
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFocused ? accentColor.withOpacity(0.7) : Colors.white.withOpacity(0.1),
              width: isFocused ? 1.5 : 1,
            ),
            boxShadow: isFocused
                ? [BoxShadow(color: accentColor.withOpacity(0.15), blurRadius: 12)]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                obscureText: obscureText,
                textDirection: textDirection,
                textAlign: textAlign,
                keyboardType: keyboardType,
                onSubmitted: onSubmitted,
                autocorrect: false,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'Cairo'),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.28), fontFamily: 'Cairo'),
                  prefixIcon: Icon(icon, color: isFocused ? accentColor : Colors.white.withOpacity(0.4), size: 20),
                  suffixIcon: suffixWidget != null ? Padding(padding: const EdgeInsets.only(right: 12), child: suffixWidget) : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tech Glow Button ─────────────────────────────────────────────────
class _TechGlowButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;
  const _TechGlowButton({required this.label, required this.isLoading, required this.onTap});
  @override
  State<_TechGlowButton> createState() => _TechGlowButtonState();
}

class _TechGlowButtonState extends State<_TechGlowButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isLoading ? null : widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _pressed
                  ? [const Color(0xFF16755A), const Color(0xFF1D9E75)]
                  : [const Color(0xFF2DDBA4), const Color(0xFF1D9E75), const Color(0xFF085041)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: widget.isLoading ? [] : [
              BoxShadow(
                color: const Color(0xFF1D9E75).withOpacity(_pressed ? 0.2 : 0.4),
                blurRadius: _pressed ? 8 : 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Cairo'),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_back_rounded, color: Colors.white.withOpacity(0.8), size: 20),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Tech Error Banner ─────────────────────────────────────────────────
class _TechErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onClose;
  const _TechErrorBanner({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFD44245).withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD44245).withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFFF6B6E), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Color(0xFFFF9B9D), fontSize: 13, height: 1.4, fontFamily: 'Cairo'),
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close_rounded, color: Color(0xFFFF6B6E), size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


