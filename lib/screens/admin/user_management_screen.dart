// lib/screens/admin/user_management_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../utils/validators.dart';
// import '../../widgets/app_card.dart';
import '../../widgets/error_display.dart';
import '../../widgets/modern_card.dart';
import '../../widgets/modern_input.dart';
import '../../widgets/modern_button.dart';
import '../../widgets/modern_loading.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final supabase = Supabase.instance.client;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _selectedRole = AppConstants.roleExecutive;
  final List<String> _manageableRoles = [
    AppConstants.roleAdmin,
    AppConstants.roleExecutive,
    AppConstants.roleTeleCaller,
    AppConstants.rolePickupDropoff,
    AppConstants.roleAccountant,
    AppConstants.roleAlignmentTech,
    AppConstants.roleInstallationTech,
  ];

  String? _selectedTeam;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _roleDisplayName {
    String role = _selectedRole.replaceAll('_', ' ');
    return role[0].toUpperCase() + role.substring(1);
  }

  bool get _isTechnicianRole {
    return _selectedRole == AppConstants.roleAlignmentTech ||
           _selectedRole == AppConstants.roleInstallationTech;
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('users')
          .select('id, username, team')
          .eq('role', _selectedRole);

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      if (mounted) _showError('Could not load ${_roleDisplayName}s: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) {
      _showError('Please fix the errors in the form.');
      return;
    }

    if (_selectedRole == AppConstants.roleExecutive && _selectedTeam == null) {
      _showError('Please select a team for the executive.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Auto-generate a complex password for technicians so the admin doesn't have to
      String password = _isTechnicianRole 
          ? 'AutoTech_${DateTime.now().millisecondsSinceEpoch}@123!' 
          : _passwordController.text.trim();

      final userData = {
        'username': _usernameController.text.trim(),
        'password': password,
        'role': _selectedRole,
      };

      if (_selectedRole == AppConstants.roleExecutive) {
        userData['team'] = _selectedTeam!;
      }

      await supabase.from('users').insert(userData);

      _showSuccess('$_roleDisplayName created successfully.');
      _usernameController.clear();
      _passwordController.clear();
      if (mounted) {
        setState(() {
          _selectedTeam = null;
        });
      }
      _loadUsers();
    } catch (e) {
      if (mounted) {
        if (e is PostgrestException && e.code == '23505') {
          _showError('Username "${_usernameController.text.trim()}" already exists.');
        } else {
          _showError('Could not create $_roleDisplayName: $e');
        }
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteUser(int id, String username) async {
    final confirmed = await _showConfirmDialog(
      'Delete $_roleDisplayName',
      'Are you sure you want to delete "$username"? This action cannot be undone.',
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await supabase.from('users').delete().eq('id', id);
      _showSuccess('$_roleDisplayName deleted successfully.');
      _loadUsers();
    } catch (e) {
      if (mounted) _showError('Deletion failed: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor.withValues(alpha: 0.75),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('User Management'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
          children: [
            // Role Selector Card
            ModernCard(
              padding: const EdgeInsets.all(20),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Select Role to Manage',
                  prefixIcon: Icon(Icons.manage_accounts),
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 16, color: Colors.black),
                dropdownColor: Colors.white,
                items: _manageableRoles.map((role) {
                  String displayRole = role.replaceAll('_', ' ');
                  displayRole = displayRole[0].toUpperCase() + displayRole.substring(1);
                  return DropdownMenuItem(
                    value: role, 
                    child: Text(
                      displayRole,
                      style: const TextStyle(color: Colors.black, fontSize: 16),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null && value != _selectedRole) {
                    setState(() {
                      _selectedRole = value;
                      _users = [];
                      _selectedTeam = null;
                    });
                    _loadUsers();
                  }
                },
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),

            // Add Form Card
            ModernCard(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.person_add,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Create New $_roleDisplayName',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ModernTextField(
                      controller: _usernameController,
                      label: 'Username',
                      hint: 'Enter username',
                      prefixIcon: const Icon(Icons.person_outline),
                      validator: Validators.validateUsername,
                    ).animate().fadeIn(delay: 100.ms),
                    if (!_isTechnicianRole) ...[
                      const SizedBox(height: 16),
                      ModernTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: 'Enter password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        obscureText: true,
                        validator: Validators.validatePassword,
                      ).animate().fadeIn(delay: 200.ms),
                    ],
                    if (_selectedRole == AppConstants.roleExecutive) ...[
                      const SizedBox(height: 16),
                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1.5,
                          ),
                        ),
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedTeam,
                          decoration: const InputDecoration(
                            labelText: 'Team',
                            prefixIcon: Icon(Icons.group_work_outlined),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          style: const TextStyle(color: Colors.black, fontSize: 16),
                          dropdownColor: Colors.white,
                          items: AppConstants.teams
                              .map((team) => DropdownMenuItem(
                            value: team,
                            child: Text(
                              team,
                              style: const TextStyle(color: Colors.black, fontSize: 16),
                            ),
                          ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedTeam = value;
                            });
                          },
                          validator: (value) =>
                          value == null ? 'Please select a team' : null,
                        ),
                      ).animate().fadeIn(delay: 300.ms),
                    ],
                    const SizedBox(height: 24),
                    ModernButton(
                      text: _isLoading ? 'Creating...' : 'Create $_roleDisplayName',
                      icon: Icons.add,
                      onPressed: _isLoading ? null : _addUser,
                      isLoading: _isLoading,
                      width: double.infinity,
                    ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.95, 0.95)),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.2, end: 0),

            // User List Card
            ModernCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.people,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$_roleDisplayName List (${_users.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _isLoading && _users.isEmpty
                      ? const ModernLoadingIndicator(message: 'Loading users...')
                      : _users.isEmpty
                      ? EmptyDisplay(
                    message: 'No ${_roleDisplayName}s found.',
                    icon: Icons.people_outline,
                    subtitle: 'Use the form above to create one.',
                  )
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ModernCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    user['username'][0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user['username'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (user['team'] != null) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryLight,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          user['team'],
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Color(0xFFEF4444),
                                ),
                                tooltip: 'Delete ${user['username']}',
                                onPressed: _isLoading
                                    ? null
                                    : () => _deleteUser(
                                  user['id'],
                                  user['username'],
                                ),
                                splashRadius: 20,
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: Duration(milliseconds: index * 100)).slideY(begin: 0.1, end: 0),
                      );
                    },
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3, end: 0),
          ],
        ),
        ),
      ),
    );
  }
}