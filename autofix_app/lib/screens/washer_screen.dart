// lib/screens/washer_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart'; // Ensure this import is present
import '../services/auth_helper.dart';
import 'profile_screen.dart';
import '../utils/app_constants.dart';

class WasherScreen extends StatefulWidget {
  const WasherScreen({super.key});

  @override
  State<WasherScreen> createState() => _WasherScreenState();
}

class _WasherScreenState extends State<WasherScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allWashQueue = []; // Store original list
  List<Map<String, dynamic>> _filteredWashQueue = []; // List to display
  bool _isLoading = false;

  // ✅ Add Search Controller
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWashQueue();
    // ✅ Add listener for search
    _searchController.addListener(_filterQueue);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterQueue); // ✅ Remove listener
    _searchController.dispose(); // ✅ Dispose controller
    super.dispose();
  }

  Future<void> _loadWashQueue() async {
    setState(() => _isLoading = true);

    try {
      final response = await supabase
          .from('reports')
          .select('''
            id,
            vehicles!reports_vehicle_fk(
              "Guid",
              "Vehicle Number",
              vehicle_name,
              "Color",
              vehicle_models(brand, "Model name")
            ),
            executive:executive_id(username)
          ''')
          .filter('status', 'in', '("${AppConstants.statusSentToWash}","${AppConstants.statusWashing}")')
          .order('created_at', ascending: true);

      setState(() {
        _allWashQueue = List<Map<String, dynamic>>.from(response);
        _filteredWashQueue = _allWashQueue; // Initially show all
        _isLoading = false; // Set loading false here
      });
    } catch (e) {
      _showError('Could not fetch wash queue: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ New method to filter the list
  void _filterQueue() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredWashQueue = _allWashQueue;
      } else {
        _filteredWashQueue = _allWashQueue.where((report) {
          final vehicleNo =
              report['vehicles']?['Vehicle Number']?.toString().toLowerCase() ?? '';
          final executiveName =
              report['executive']?['username']?.toString().toLowerCase() ?? '';
          return vehicleNo.contains(query) || executiveName.contains(query);
        }).toList();
      }
    });
  }

  

  Future<void> _completeWash(int reportId, String vehicleNo) async {
    final confirmed = await _showConfirmDialog(
      'Confirm Wash Completion',
      'Mark wash as completed for vehicle $vehicleNo?',
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await supabase
          .from('reports')
          .update({'status': AppConstants.statusWashCompleted}).eq('id', reportId);

      _showSuccess(
          'Wash completed for $vehicleNo. Vehicle sent back to executive.');
      _loadWashQueue();
    } catch (e) {
      _showError('Failed to update status: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final buttonText = await AuthHelper.getLogoutButtonText();

    final confirmed = await _showConfirmDialog(
      buttonText,
      'Are you sure?',
    );

    if (confirmed != true) return;

    if (mounted) {
      await AuthHelper.logout(context);
    }
  }

  // ... all other helper methods (_showConfirmDialog, _showError, etc.) and the build method remain unchanged ...
  // They are already well-written and don't need modification.
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
            child: const Text('Confirm'),
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

  void _showSuccess(String message) {
    // Commented out to reduce UI noise
    // if (!mounted) return;
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text(message),
    //     backgroundColor: Colors.green,
    //     behavior: SnackBarBehavior.floating,
    //     shape: RoundedRectangleBorder(
    //       borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg),
    //     ),
    //     margin: const EdgeInsets.all(16),
    //   ),
    // );
  }

  String _getBrandModel(Map<String, dynamic> vehicle) {
    final brand = vehicle['vehicle_models']?['brand'] ?? '';
    final model = vehicle['vehicle_models']?['Model name'] ?? '';
    return '$brand $model'.trim();
  }

  // ✅ ADD THIS METHOD
  void _onMenuItemSelected(String value) {
    switch (value) {
      case 'profile':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
        break;
      case 'logout':
        _logout(); // Call the existing _logout method
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // MUST start with Scaffold
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      // Add the AppBar here
      appBar: AppBar(
        title: const Text(
          'Washer',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 24,
            color: AppTheme.primaryColor,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
            onPressed: _loadWashQueue,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: _onMenuItemSelected,
            icon: const Icon(Icons.more_vert),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text('Profile'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: AppTheme.errorColor),
                  title: Text('Logout',
                      style: TextStyle(color: AppTheme.errorColor)),
                ),
              ),
            ],
          ),
        ],
      ),
      // ✅ Place the original body content inside the Scaffold's body
      body: RefreshIndicator(
        onRefresh: _loadWashQueue,
        child: Column(
          // Column contains Search + List
          children: [
            Padding(
              // Search Bar
              padding: const EdgeInsets.all(AppTheme.spacingMd)
                  .copyWith(bottom: AppTheme.spacingSm),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by Vehicle No or Executive...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                ),
              ),
            ),
            // ✅ Existing List content inside Expanded
            Expanded(
              // List Area
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredWashQueue.isEmpty
                      ? _buildEmptyState(_searchController.text.isNotEmpty)
                      : _buildWashList(),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Modify empty state
  Widget _buildEmptyState(bool isSearching) {
    return Center(
      child: Padding(
        // Added padding
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching
                  ? Icons.search_off
                  : Icons.local_car_wash, // Different icon
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              isSearching
                  ? 'No vehicles found matching search'
                  : 'No vehicles in wash queue', // Different message
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Try a different search term.'
                  : 'Pull down to refresh', // Different subtitle
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWashList() {
    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      itemCount: _filteredWashQueue.length,
      itemBuilder: (context, index) {
        final report = _filteredWashQueue[index];
        final vehicle = report['vehicles'];
        final executive = report['executive'];

        final vehicleNo = vehicle?['Vehicle Number'] ?? 'N/A';
        final vehicleName = vehicle?['vehicle_name'] ?? '';
        final color = vehicle?['Color'] ?? '';
        final brandModel = _getBrandModel(vehicle ?? {});
        final executiveName = executive?['username'] ?? 'N/A';

        return AppCard(
          margin: const EdgeInsets.only(
              top: AppTheme.spacingMd), // Use AppCard's margin
          padding: const EdgeInsets.all(16), // Padding is now valid
          child: Column(
            // The rest of the card's content remains the same
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicleNo,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (brandModel.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              brandModel,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        if (vehicleName.isNotEmpty || color.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              [vehicleName, color]
                                  .where((s) => s.isNotEmpty)
                                  .join(' • '),
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person,
                          size: 14,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          executiveName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _completeWash(report['id'], vehicleNo),
                  icon: const Icon(Icons.check_circle, size: 20),
                  label: const Text(
                    'Mark Wash Completed',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.borderRadiusLg),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
