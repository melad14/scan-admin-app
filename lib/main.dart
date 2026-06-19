import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tech_app/core/services/storage_service.dart';
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
    final role = await StorageService.getUserRole();
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

class ScanGoTechApp extends StatelessWidget {
  const ScanGoTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ScanGo Tech | فني أشعتك',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF59E0B), // Surcharge Warning Gold/Orange
          brightness: Brightness.dark,
          background: const Color(0xFF0B0F19),
        ),
        useMaterial3: true,
        fontFamily: 'Cairo',
      ),
      locale: const Locale('ar', 'EG'),
      routerConfig: techRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
