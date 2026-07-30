// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
// 👇 CORRECTED IMPORT STATEMENTS
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/auth_helper.dart';
import '../services/biometric_auth_service.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../providers/admin_settings_provider.dart';
import '../widgets/modern_card.dart';
import '../widgets/modern_input.dart';
import '../widgets/modern_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // State variables for the Reset Password form
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isResettingPassword = false;
  
  // Password visibility toggles
  bool _currentPasswordVisible = false;
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;

  // State variables for the user session
  String _logoutButtonText = 'Logout';
  bool _isQuickAccessSession = false;

  @override
  void initState() {
    super.initState();
    _checkSessionType();
  }

  @override
  void dispose() {
    // Dispose of the controllers to prevent memory leaks
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkSessionType() async {
    final isQuickAccess = await AuthHelper.isQuickAccessSession();
    final buttonText = await AuthHelper.getLogoutButtonText();

    if (mounted) {
      setState(() {
        _isQuickAccessSession = isQuickAccess;
        _logoutButtonText = buttonText;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.withValues(alpha: 0.75) : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _resetPassword() async {
    // 1. Validate the form fields
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isResettingPassword = true;
    });

    final user = Provider
        .of<UserProvider>(context, listen: false)
        .user;
    if (user == null) {
      _showSnackBar('User not found. Please log in again.', isError: true);
      setState(() {
        _isResettingPassword = false;
      });
      return;
    }

    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final supabase = Supabase.instance.client;

    try {
      // 2. Check if the current password is correct
      if (user['password'] != currentPassword) {
        _showSnackBar('Incorrect current password.', isError: true);
        setState(() {
          _isResettingPassword = false;
        });
        return;
      }

      // 3. Update the password in Supabase
      await supabase
          .from('users')
          .update({'password': newPassword})
          .eq('id', user['id']);

      // 4. Update the local user data in the provider
      final updatedUser = Map<String, dynamic>.from(user);
      updatedUser['password'] = newPassword;
      if (!mounted) return;
      Provider.of<UserProvider>(context, listen: false).setUser(updatedUser);

      // 5. Show success and clear fields
      if (!mounted) return;
      _showSnackBar('Password updated successfully!');
      _formKey.currentState?.reset();
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      FocusScope.of(context).unfocus(); // Close the keyboard

    } catch (error) {
      _showSnackBar('An error occurred. Please try again.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isResettingPassword = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 24,
            color: AppTheme.primaryColor,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Card with User Info
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: Text(
                          user?['username']?[0]?.toUpperCase() ?? 'U',
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user?['username'] ?? 'User',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        user?['role']?.toString() ?? 'Executive',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reset Password Card
                  _buildInfoCard(
                    icon: Icons.lock_reset,
                    title: 'Reset Password',
                    children: [
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            ModernTextField(
                              controller: _currentPasswordController,
                              label: 'Current Password',
                              hint: 'Enter current password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              obscureText: !_currentPasswordVisible,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _currentPasswordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF8F9BB3),
                                  size: 22,
                                ),
                                onPressed: () => setState(() => _currentPasswordVisible = !_currentPasswordVisible),
                              ),
                              validator: (value) => value == null || value.isEmpty ? 'Current password is required' : null,
                            ).animate().fadeIn(delay: 100.ms),
                            const SizedBox(height: 16),
                            ModernTextField(
                              controller: _newPasswordController,
                              label: 'New Password',
                              hint: 'Enter new password',
                              prefixIcon: const Icon(Icons.lock_reset),
                              obscureText: !_newPasswordVisible,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _newPasswordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF8F9BB3),
                                  size: 22,
                                ),
                                onPressed: () => setState(() => _newPasswordVisible = !_newPasswordVisible),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'New password is required';
                                if (value.length < 6) return 'Password must be at least 6 characters';
                                return null;
                              },
                            ).animate().fadeIn(delay: 200.ms),
                            const SizedBox(height: 16),
                            ModernTextField(
                              controller: _confirmPasswordController,
                              label: 'Confirm New Password',
                              hint: 'Re-enter new password',
                              prefixIcon: const Icon(Icons.lock_person),
                              obscureText: !_confirmPasswordVisible,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _confirmPasswordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF8F9BB3),
                                  size: 22,
                                ),
                                onPressed: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
                              ),
                              validator: (value) => value != _newPasswordController.text ? 'Passwords do not match' : null,
                            ).animate().fadeIn(delay: 300.ms),
                            const SizedBox(height: 20),
                            ModernButton(
                              text: 'Update Password',
                              icon: Icons.check_circle_outline,
                              onPressed: _resetPassword,
                              isLoading: _isResettingPassword,
                              width: double.infinity,
                            ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.95, 0.95)),
                          ],
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.2, end: 0),
                  const SizedBox(height: 16),

                  // Session Info Card
                  if (_isQuickAccessSession)
                    _buildInfoCard(
                      icon: Icons.access_time,
                      title: 'Session Information',
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'You are using Quick Access mode. Some features may be limited.',
                                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.2, end: 0),
                  if (_isQuickAccessSession) const SizedBox(height: 16),

                  // App Settings Card
                  _buildSettingsCard().animate().fadeIn(delay: 700.ms).slideY(begin: 0.3, end: 0),
                  const SizedBox(height: 16),

                  // Logout Button
                  ModernButton(
                    text: _logoutButtonText,
                    icon: Icons.logout,
                    onPressed: () => AuthHelper.logout(context),
                    color: Colors.red.shade50,
                    textColor: Colors.red,
                    width: double.infinity,
                  ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.3, end: 0),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String title, required List<Widget> children}) {
    return ModernCard(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Consumer<UserPreferencesProvider>(
      builder: (context, prefsProvider, child) {
        return _buildInfoCard(
          icon: Icons.settings,
          title: 'App Settings',
          children: [
            _buildSettingTile(
              icon: Icons.vibration,
              title: 'Haptic Feedback',
              subtitle: 'Feel vibrations on button taps',
              trailing: Switch(
                value: prefsProvider.hapticFeedback,
                onChanged: (value) {
                  prefsProvider.setHapticFeedback(value);
                },
                activeThumbColor: AppTheme.primaryColor,
              ),
            ),
            const Divider(height: 24),
            _buildSettingTile(
              icon: Icons.animation,
              title: 'Animations',
              subtitle: 'Enable smooth transitions',
              trailing: Switch(
                value: prefsProvider.animationsEnabled,
                onChanged: (value) {
                  prefsProvider.setAnimationsEnabled(value);
                },
                activeThumbColor: AppTheme.primaryColor,
              ),
            ),
            const Divider(height: 24),
            Consumer<AdminSettingsProvider>(
              builder: (context, adminSettingsProvider, child) {
                final isBiometricFeatureEnabled = adminSettingsProvider.featureBiometricAuth;
                
                if (!isBiometricFeatureEnabled) {
                  return _buildSettingTile(
                    icon: Icons.fingerprint,
                    title: 'Biometric Login',
                    subtitle: 'Disabled by administrator',
                    trailing: const Switch(
                      value: false,
                      onChanged: null,
                      activeThumbColor: AppTheme.primaryColor,
                    ),
                  );
                }
                
                return FutureBuilder<bool>(
                  future: BiometricAuthService().canCheckBiometrics(),
                  builder: (context, snapshot) {
                    final canUseBiometric = snapshot.data ?? false;
                    return _buildSettingTile(
                      icon: Icons.fingerprint,
                      title: 'Biometric Login',
                      subtitle: canUseBiometric
                          ? (prefsProvider.biometricEnabled ? 'Enabled' : 'Use fingerprint or face ID')
                          : 'Not available on this device',
                      trailing: Switch(
                        value: prefsProvider.biometricEnabled && canUseBiometric,
                        onChanged: (value) async {
                          final messenger = ScaffoldMessenger.of(context);
                          if (value && canUseBiometric) {
                            // Test biometric before enabling
                            final authenticated = await BiometricAuthService().authenticate(
                              localizedReason: 'Verify your identity to enable biometric login',
                            );
                            if (authenticated) {
                              prefsProvider.setBiometricEnabled(true);
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Biometric login enabled'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } else {
                            prefsProvider.setBiometricEnabled(false);
                            if (!canUseBiometric) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Biometric authentication is not available on this device'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          }
                        },
                        activeThumbColor: AppTheme.primaryColor,
                      ),
                    );
                  },
                );
              },
            ),
            const Divider(height: 24),
            _buildSettingTile(
              icon: Icons.timer_off,
              title: 'Auto Logout',
              subtitle: 'Logout after ${prefsProvider.autoLogoutMinutes} min of inactivity',
              trailing: Switch(
                value: prefsProvider.autoLogoutEnabled,
                onChanged: (value) {
                  prefsProvider.setAutoLogoutEnabled(value);
                },
                activeThumbColor: AppTheme.primaryColor,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}