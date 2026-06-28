import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tech_app/core/services/storage_service.dart';
import 'package:tech_app/core/theme/app_theme.dart';
import 'package:tech_app/core/theme/theme_provider.dart';
import 'features/auth/tech_login_screen.dart';
import 'features/orders/tech_orders_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: ScanGoTechApp(),
    ),
  );
}

final GoRouter techRouter = GoRouter(
  initialLocation: '/',
  redirect: (BuildContext context, GoRouterState state) async {
    final token = await StorageService.getAccessToken();
    final isLoggingIn = state.matchedLocation == '/login';

    if (token == null && !isLoggingIn) {
      return '/login';
    }
    
    if (token != null && isLoggingIn) {
      return '/';
    }
    
    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) => const TechLoginScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) => const TechOrdersScreen(),
    ),
  ],
);

class ScanGoTechApp extends ConsumerWidget {
  const ScanGoTechApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    ));

    return MaterialApp.router(
      title: 'ScanGo Tech | فني سكان جو',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: const Locale('ar', 'EG'),
      routerConfig: techRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
