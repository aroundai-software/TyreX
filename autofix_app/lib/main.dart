// lib/main.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Providers
import './providers/admin_settings_provider.dart';
import './providers/user_provider.dart';
import './providers/report_provider.dart';
import './providers/user_preferences_provider.dart';

// Screens
import './screens/login_screen.dart';
import './screens/admin/admin_dashboard_screen.dart';
import './screens/main_dashboard.dart';
import './screens/pudo_dashboard_screen.dart';
import './screens/telecaller_dashboard_screen.dart';
import './screens/washer_screen.dart';
import './screens/inspector_screen.dart';

// Theme & Utils
import './theme/app_theme.dart';
import './utils/app_constants.dart';
import './services/local_media_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocalMediaService.initialize();

  await Supabase.initialize(
    url: 'https://gfylsjfljnwyomfouwvs.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdmeWxzamZsam53eW9tZm91d3ZzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc0MDc5MTYsImV4cCI6MjA3Mjk4MzkxNn0.hMvLvCDVaFtq0rXToHGOJPSFe-QnJ6_S-MYsI0d5zOs',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdminSettingsProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(create: (_) => UserPreferencesProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoFix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const StartupRouter(),
    );
  }
}

class StartupRouter extends StatefulWidget {
  const StartupRouter({super.key});

  @override
  State<StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<StartupRouter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapSession());
  }

  Future<void> _bootstrapSession() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUserJson = prefs.getString(AppConstants.cacheKeyCurrentUser);

    // Initialize UserProvider and load active company regardless of login status
    await context.read<UserProvider>().initialize();

    if (!mounted) return;

    if (storedUserJson == null) {
      _navigateTo(const LoginScreen());
      return;
    }

    try {
      final storedUser = jsonDecode(storedUserJson) as Map<String, dynamic>;
      final userProvider = context.read<UserProvider>();
      userProvider.setUser(storedUser);

      await context.read<AdminSettingsProvider>().loadSettings();

      if (!mounted) return;
      final destination = _screenForRole(storedUser['role'] as String?);
      _navigateTo(destination);
    } catch (_) {
      await prefs.remove(AppConstants.cacheKeyCurrentUser);
      if (!mounted) return;
      _navigateTo(const LoginScreen());
    }
  }

  Widget _screenForRole(String? role) {
    final normalizedRole = _normalizeRole(role);

    switch (normalizedRole) {
      case AppConstants.roleAdmin:
        return const AdminDashboardScreen();
      case AppConstants.roleTeleCaller:
        return const TelecallerDashboardScreen();
      case AppConstants.rolePickupDropoff:
        return const PudoDashboardScreen();
      case AppConstants.roleWasher:
        return const WasherScreen();
      case AppConstants.roleInspector:
        return const InspectorScreen();
      case AppConstants.roleExecutive:
      default:
        return const MainDashboard();
    }
  }

  void _navigateTo(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  String _normalizeRole(String? role) {
    switch (role) {
      case 'tele_caller':
      case 'telecaller':
        return AppConstants.roleTeleCaller;
      case 'pudo':
        return AppConstants.rolePickupDropoff;
      default:
        return role ?? AppConstants.roleExecutive;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}