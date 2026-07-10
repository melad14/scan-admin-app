import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tech_app/core/services/notification_service.dart';
import 'package:tech_app/core/services/storage_service.dart';
import 'package:tech_app/core/theme/app_theme.dart';
import 'package:tech_app/core/theme/theme_provider.dart';
import 'features/auth/tech_login_screen.dart';
import 'features/orders/tech_orders_screen.dart';
import 'features/profile/tech_profile_screen.dart';
import 'features/profile/tech_complaints_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase & notifications only on native mobile platforms
  if (!kIsWeb) {
    await Firebase.initializeApp();
    await NotificationService.init();
  } else {
    debugPrint('Running on Web: Skipping mobile push notifications init.');
  }

  runApp(
    const ProviderScope(
      child: ScanGoTechApp(),
    ),
  );
}

final GoRouter techRouter = GoRouter(
  navigatorKey: notificationNavigatorKey,
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
    GoRoute(
      path: '/profile',
      builder: (BuildContext context, GoRouterState state) => const TechProfileScreen(),
    ),
    GoRoute(
      path: '/profile/complaints',
      builder: (BuildContext context, GoRouterState state) => const TechComplaintsScreen(),
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
