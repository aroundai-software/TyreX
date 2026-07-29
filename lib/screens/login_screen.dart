// lib/screens/login_screen.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/admin_settings_provider.dart'; // ✅ Import AdminSettingsProvider
import '../providers/report_provider.dart';
import 'main_dashboard.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import 'admin/admin_dashboard_screen.dart';
import 'pudo_dashboard_screen.dart';
import 'telecaller_dashboard_screen.dart';
import 'accountant/accountant_dashboard_screen.dart';

import '../utils/validators.dart';
import '../utils/app_constants.dart';
import '../utils/app_exceptions.dart';
import '../services/biometric_auth_service.dart';
import '../providers/user_preferences_provider.dart';
import '../widgets/modern_page_route.dart';
import '../widgets/modern_input.dart';
import '../widgets/modern_button.dart';
import '../services/company_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _companies = [];
  bool _loadingCompanies = true;
  

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    try {
      final companies = await CompanyService().getActiveCompanies();
      if (mounted) {
        setState(() {
          _companies = companies;
          _loadingCompanies = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingCompanies = false;
        });
        _showErrorSnackBar('Failed to load companies: $e');
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await supabase
          .from('users')
          .select()
          .ilike('username', username)
          .single();

      if (response['password'] == password) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            AppConstants.cacheKeyCurrentUser, jsonEncode(response));

        if (!mounted) return;
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final reportProvider = Provider.of<ReportProvider>(context, listen: false);
        final settingsProvider = context.read<AdminSettingsProvider>();

        // ✅ Clear any cached report data before setting new user
        reportProvider.clearCache();
        debugPrint('🗑️ LoginScreen: Cleared report cache before login');

        // Auto-assign company from user's profile
        final userCompany = response['company_name'];
        if (userCompany == null || userCompany.toString().trim().isEmpty) {
          throw AuthenticationException('Your account is not assigned to any company. Please contact the administrator.');
        }

        final normalizedUserCompany = userCompany.toString().trim().toLowerCase();
        var companyData = _companies.firstWhere(
          (c) => (c['company_name']?.toString().trim().toLowerCase() ?? '') == normalizedUserCompany,
          orElse: () => <String, dynamic>{},
        );

        if (companyData.isEmpty) {
          debugPrint('⚠️ Warning: Company "$userCompany" not found in tally_companies. Using fallback.');
          companyData = {'company_name': userCompany};
        }

        CompanyService().setActiveCompany(companyData);
        debugPrint('✅ LoginScreen: Automatically assigned company to $userCompany');

        // Set the user FIRST
        userProvider.setUser(response);
        
        // Save FCM token to Supabase for push notifications
        _saveFcmToken(response['id']);

        // ✅ LOAD SETTINGS AFTER SUCCESSFUL LOGIN
        await settingsProvider.loadSettings();
        debugPrint('>>> Settings loaded after login <<<');

        if (!mounted) return;
        final role = response['role'];
        
        // Check if telecaller module is disabled and user is telecaller
        if (role == AppConstants.roleTeleCaller && !settingsProvider.featureTelecallerModule) {
          throw AuthenticationException('Telecaller module is currently disabled. Please contact administrator.');
        }
        
        Widget targetScreen;

        switch (role) {
          case AppConstants.roleAdmin:
            targetScreen = const AdminDashboardScreen();
            break;
          case AppConstants.roleTeleCaller:
            targetScreen = const TelecallerDashboardScreen();
            break;
          case AppConstants.rolePickupDropoff:
            targetScreen = const PudoDashboardScreen();
            break;
          case AppConstants.roleAccountant:
            targetScreen = const AccountantDashboardScreen();
            break;

          case AppConstants.roleExecutive:
          default:
            targetScreen = const MainDashboard();
            break;
        }

        context.pushReplacementModern(
          targetScreen,
          transition: RouteTransitionType.fadeScale,
        );
      } else {
        throw AuthenticationException('Invalid credentials');
      }
    } on PostgrestException catch (e) {
      _showErrorSnackBar('Login failed: ${e.message}');
    } on AuthenticationException catch (e) {
      _showErrorSnackBar(e.message);
    } catch (error) {
      _showErrorSnackBar('Invalid credentials or network error.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveFcmToken(int userId) async {
    try {
      final messaging = FirebaseMessaging.instance;
      // Request permission (needed on iOS, harmless on Android)
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await messaging.getToken();
      if (token != null) {
        await supabase.from('users').update({'fcm_token': token}).eq('id', userId);
        debugPrint('✅ FCM token saved for user $userId');
      }
    } catch (e) {
      debugPrint('⚠️ FCM token save failed (non-critical): $e');
    }
  }

  Future<void> _biometricLogin() async {
    try {
      final biometricService = BiometricAuthService();
      final authenticated = await biometricService.authenticate(
        localizedReason: 'Authenticate to login to AutoFix',
      );

      if (authenticated) {
        // Get last logged in user from cache
        final prefs = await SharedPreferences.getInstance();
        final cachedUserJson = prefs.getString(AppConstants.cacheKeyCurrentUser);
        
        if (cachedUserJson != null) {
          final cachedUser = jsonDecode(cachedUserJson);
          
          
          if (!mounted) return;
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          final reportProvider = Provider.of<ReportProvider>(context, listen: false);
          final settingsProvider = context.read<AdminSettingsProvider>();

          // ✅ Clear any cached report data before setting new user
          reportProvider.clearCache();
          debugPrint('🗑️ BiometricLogin: Cleared report cache before login');

          // Auto-assign company from user's profile for biometric login
          final userCompany = cachedUser['company_name'];
          if (userCompany != null && userCompany.toString().trim().isNotEmpty) {
            final normalizedUserCompany = userCompany.toString().trim().toLowerCase();
            var companyData = _companies.firstWhere(
              (c) => (c['company_name']?.toString().trim().toLowerCase() ?? '') == normalizedUserCompany,
              orElse: () => <String, dynamic>{},
            );
            
            if (companyData.isEmpty) {
              debugPrint('⚠️ Warning: Company "$userCompany" not found in tally_companies for BiometricLogin. Using fallback.');
              companyData = {'company_name': userCompany};
            }
            
            CompanyService().setActiveCompany(companyData);
            debugPrint('✅ BiometricLogin: Automatically assigned company to $userCompany');
          }

          // Set the user
          userProvider.setUser(cachedUser);
          
          
          // Load settings
          await settingsProvider.loadSettings();
          
          if (!mounted) return;
          final role = cachedUser['role'];
          
          // Check if telecaller module is disabled and user is telecaller
          if (role == AppConstants.roleTeleCaller && !settingsProvider.featureTelecallerModule) {
            _showErrorSnackBar('Telecaller module is currently disabled. Please contact administrator.');
            return;
          }
          
          Widget targetScreen;

          switch (role) {
            case AppConstants.roleAdmin:
              targetScreen = const AdminDashboardScreen();
              break;
            case AppConstants.roleTeleCaller:
              targetScreen = const TelecallerDashboardScreen();
              break;
            case AppConstants.rolePickupDropoff:
              targetScreen = const PudoDashboardScreen();
              break;

            case AppConstants.roleExecutive:
            default:
              targetScreen = const MainDashboard();
              break;
          }

          context.pushReplacementModern(
            targetScreen,
            transition: RouteTransitionType.fadeScale,
          );
        } else {
          _showErrorSnackBar('Please login with username and password first');
        }
      }
    } catch (error) {
      _showErrorSnackBar('Biometric authentication failed');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFF8FAFC),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Icon
                      Container(
                        width: 300,
                        height: 100,
                        decoration: BoxDecoration(
                            image: DecorationImage(
                                image: AssetImage('assets/images/logo2.png'))),
                      ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8)),
                      // const SizedBox(height: 32),

                      // Welcome Text
                      const Text(
                        'Welcome Back!',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in to continue to AutoFix',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideY(begin: 0.3, end: 0),
                      const SizedBox(height: 40),

                      // Username Field
                      ModernTextField(
                        controller: _usernameController,
                        label: 'Username',
                        hint: 'Enter your username',
                        prefixIcon: const Icon(Icons.person_outline),
                        validator: (value) => Validators.validateRequired(
                          value,
                          fieldName: 'Username',
                        ),
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                      ).animate().fadeIn(duration: 500.ms, delay: 300.ms).slideX(begin: -0.2, end: 0),
                      const SizedBox(height: 16),

                      // Password Field
                      ModernTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF8F9BB3),
                            size: 22,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        validator: (value) => Validators.validateRequired(
                          value,
                          fieldName: 'Password',
                        ),
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _login(),
                      ).animate().fadeIn(duration: 500.ms, delay: 400.ms).slideX(begin: 0.2, end: 0),
                      const SizedBox(height: 16),

                      // Company selection has been removed. It is automatically assigned based on user.
                      
                      const SizedBox(height: 28),

                      // Sign In Button
                      ModernButton(
                        text: 'Sign In',
                        icon: Icons.login,
                        onPressed: _login,
                        isLoading: _isLoading,
                        width: double.infinity,
                      ).animate().fadeIn(duration: 500.ms, delay: 500.ms).scale(begin: const Offset(0.9, 0.9)),
                      const SizedBox(height: 20),

                      // Biometric Login Button
                      Consumer2<UserPreferencesProvider, AdminSettingsProvider>(
                        builder: (context, prefsProvider, adminSettingsProvider, child) {
                          // Check if biometric feature is enabled by admin
                          if (!adminSettingsProvider.featureBiometricAuth) {
                            return const SizedBox.shrink();
                          }
                          
                          // Check if user has enabled biometric login
                          if (!prefsProvider.biometricEnabled) {
                            return const SizedBox.shrink();
                          }
                          
                          return FutureBuilder<bool>(
                            future: BiometricAuthService().canCheckBiometrics(),
                            builder: (context, snapshot) {
                              if (snapshot.data != true) {
                                return const SizedBox.shrink();
                              }
                              
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Divider(color: Colors.grey.shade300)),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Text(
                                          'OR',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Expanded(child: Divider(color: Colors.grey.shade300)),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  ModernButton(
                                    text: 'Login with Biometrics',
                                    icon: Icons.fingerprint,
                                    onPressed: _biometricLogin,
                                    isOutlined: true,
                                    width: double.infinity,
                                  ).animate().fadeIn(duration: 500.ms, delay: 600.ms).slideY(begin: 0.3, end: 0),
                                  const SizedBox(height: 20),
                                ],
                              );
                            },
                          );
                        },
                      ).animate().fadeIn(duration: 500.ms, delay: 550.ms),

                      // Feature Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F7FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFD6E9FF),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  image: DecorationImage(
                                      image:
                                          AssetImage('assets/images/spanner.png'),
                                      fit: BoxFit.cover)),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Manage Services Easily',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Track and manage all your auto repair services in one place.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 600.ms, delay: 600.ms).slideY(begin: 0.3, end: 0),
                      const SizedBox(height: 5),

                      // Version Text
                      Text(
                        'Version 1.0.0',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 800.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
