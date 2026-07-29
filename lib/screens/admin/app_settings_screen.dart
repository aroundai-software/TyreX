import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../providers/admin_settings_provider.dart';
import '../../models/admin_setting_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptic_utils.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminSettingsProvider>().loadSettings();
    });
  }

  // Column labels for report columns (fallback if not in inputConfig)
  final List<Map<String, String>> allReportColumns = [
    {'key': 'vehicle_no', 'label': 'Vehicle No.'},
    {'key': 'vehicle_name', 'label': 'Vehicle Name'},
    {'key': 'model', 'label': 'Model'},
    {'key': 'brand', 'label': 'Brand'},
    {'key': 'client_name', 'label': 'Client Name'},
    {'key': 'client_phone', 'label': 'Client Phone'},
    {'key': 'executive', 'label': 'Executive'},
    {'key': 'date_time', 'label': 'Date & Time'},
    {'key': 'status', 'label': 'Status'},
    {'key': 'complaint', 'label': 'Complaint'},
    {'key': 'approved', 'label': 'Approved'},
    {'key': 'media', 'label': 'Media'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('App Settings'),
        actions: [
          // Cache status indicator
          Consumer<AdminSettingsProvider>(
            builder: (context, provider, _) {
              final cacheAge = provider.cacheAgeMinutes;
              final isExpired = provider.isCacheExpired;
              
              return IconButton(
                icon: Icon(
                  isExpired ? Icons.cloud_download : Icons.cached,
                  color: isExpired ? Colors.orange : Colors.green,
                ),
                tooltip: cacheAge != null 
                    ? 'Cache age: ${cacheAge}m ${isExpired ? "(expired)" : ""}'
                    : 'No cache',
                onPressed: () async {
                  await provider.refreshSettings();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Settings refreshed from database'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<AdminSettingsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return Center(child: Text(provider.error!));
          }

          // Group settings by category from database metadata
          final groupedSettings = _groupSettingsByCategory(provider.allSettings.values.toList());
          final sortedCategories = groupedSettings.keys.toList();
          
          // Debug: Log category grouping
          debugPrint('📂 Settings grouped into ${sortedCategories.length} categories:');
          for (var category in sortedCategories) {
            debugPrint('   - $category: ${groupedSettings[category]!.length} settings');
          }

          return RefreshIndicator(
            onRefresh: () => provider.refreshSettings(),
            child: AnimationLimiter(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sortedCategories.length + 1, // +1 for cache info card
                itemBuilder: (context, index) {
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: index == 0
                            ? _buildCacheInfoCard(provider)
                            : _buildCategoryCard(sortedCategories[index - 1], groupedSettings, provider),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build category card with settings
  Widget _buildCategoryCard(String category, Map<String, List<AdminSettingModel>> groupedSettings, AdminSettingsProvider provider) {
    final settings = groupedSettings[category]!;
    
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  category,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              Text(
                '${settings.length} settings',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ...settings.map((setting) => _buildSettingItem(provider, setting)),
        ],
      ),
    );
  }

  /// Build cache info card
  Widget _buildCacheInfoCard(AdminSettingsProvider provider) {
    final cacheAge = provider.cacheAgeMinutes;
    final isExpired = provider.isCacheExpired;
    
    return AppCard(
      padding: const EdgeInsets.all(16),
      color: isExpired ? Colors.orange.shade50 : Colors.green.shade50,
      child: Row(
        children: [
          Icon(
            isExpired ? Icons.cloud_download : Icons.cached,
            color: isExpired ? Colors.orange : Colors.green,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpired ? 'Cache Expired' : 'Using Cached Settings',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isExpired ? Colors.orange.shade900 : Colors.green.shade900,
                  ),
                ),
                if (cacheAge != null)
                  Text(
                    'Last updated ${cacheAge}m ago',
                    style: TextStyle(
                      fontSize: 12,
                      color: isExpired ? Colors.orange.shade700 : Colors.green.shade700,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => provider.refreshSettings(),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
  
  /// Group settings by category using database metadata
  Map<String, List<AdminSettingModel>> _groupSettingsByCategory(List<AdminSettingModel> settings) {
    // Define category order for consistent display
    final categoryOrder = [
      'Core Features',
      'Workflow',
      'Role-Based Modules',
      'Admin Features',
      'Security',
      'Data & Privacy',
      'Business Rules',
      'Notifications',
      'Workflow & Automation',
      'General',
    ];
    
    Map<String, List<AdminSettingModel>> grouped = {};
    
    for (var setting in settings) {
      // Use category from database metadata (Phase 2)
      final category = setting.category;
      
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(setting);
    }
    
    // Sort settings within each category by displayOrder
    for (var category in grouped.keys) {
      grouped[category]!.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    }
    
    // Return as LinkedHashMap with ordered categories
    final orderedGrouped = <String, List<AdminSettingModel>>{};
    
    // Add categories in defined order
    for (var category in categoryOrder) {
      if (grouped.containsKey(category)) {
        orderedGrouped[category] = grouped[category]!;
      }
    }
    
    // Add any remaining categories not in the predefined order
    for (var category in grouped.keys) {
      if (!orderedGrouped.containsKey(category)) {
        orderedGrouped[category] = grouped[category]!;
      }
    }
    
    return orderedGrouped;
  }

  Widget _buildSettingItem(AdminSettingsProvider provider, AdminSettingModel setting) {
    if (setting.key == 'feature_gdrive') {
      return const SizedBox.shrink();
    }
    // Use metadata from database (Phase 2)
    if (setting.type == 'toggle' || setting.inputType == 'toggle') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: Text(
                setting.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: setting.description.isNotEmpty
                  ? Text(
                      setting.description,
                      style: const TextStyle(fontSize: 12),
                    )
                  : null,
              value: setting.value as bool? ?? false,
              onChanged: (bool value) {
                HapticUtils.light();
                provider.updateSetting(setting.key, value);
              },
              contentPadding: EdgeInsets.zero,
            ),
            // Show last updated time if available
            if (setting.updatedAt != null)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text(
                  'Last updated: ${_formatDateTime(setting.updatedAt!)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (setting.type == 'checkbox_group' || setting.inputType == 'checkbox_group') {
      List<String> selectedColumns = provider.visibleReportColumns;
      
      // Get available options from inputConfig (Phase 2) or use default
      final availableOptions = setting.inputConfig?['options'] as List<dynamic>? ?? [];
      final columnOptions = availableOptions.isNotEmpty
          ? availableOptions.map((opt) => opt.toString()).toList()
          : allReportColumns.map((col) => col['key']!).toList();
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              setting.label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            if (setting.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                setting.description,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: columnOptions.map((columnKey) {
                final columnLabel = allReportColumns
                    .firstWhere(
                      (col) => col['key'] == columnKey,
                      orElse: () => {'key': columnKey, 'label': columnKey},
                    )['label']!;
                    
                bool isSelected = selectedColumns.contains(columnKey);
                
                return FilterChip(
                  label: Text(columnLabel),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryColor,
                  backgroundColor: Colors.grey[200],
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  checkmarkColor: Colors.white,
                  onSelected: (bool selected) {
                    HapticUtils.light();
                    List<String> newSelection = List.from(selectedColumns);
                    if (selected) {
                      newSelection.add(columnKey);
                    } else {
                      newSelection.remove(columnKey);
                    }
                    provider.updateSetting(setting.key, newSelection);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${selectedColumns.length} of ${columnOptions.length} selected',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                if (setting.updatedAt != null)
                  Text(
                    'Updated ${_formatDateTime(setting.updatedAt!)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
              ],
            ),
          ],
        ),
      );
    }
    
    if (setting.type == 'number' || setting.inputType == 'number') {
      final TextEditingController controller = TextEditingController(text: setting.value?.toString() ?? '');
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              setting.label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            if (setting.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                setting.description,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    HapticUtils.light();
                    final int? parsedValue = int.tryParse(controller.text);
                    if (parsedValue != null) {
                      provider.updateSetting(setting.key, parsedValue);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Setting saved successfully')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    
    if (setting.inputType == 'duration_minutes') {
      final int totalMinutes = setting.value is int ? setting.value as int : int.tryParse(setting.value?.toString() ?? '0') ?? 0;
      final int initialHours = totalMinutes ~/ 60;
      final int initialMinutes = totalMinutes % 60;
      
      final TextEditingController hoursController = TextEditingController(text: initialHours.toString());
      final TextEditingController minutesController = TextEditingController(text: initialMinutes.toString());
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              setting.label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            if (setting.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                setting.description,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: hoursController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Hours',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: minutesController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Minutes',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    HapticUtils.light();
                    final int hrs = int.tryParse(hoursController.text) ?? 0;
                    final int mins = int.tryParse(minutesController.text) ?? 0;
                    final int parsedValue = (hrs * 60) + mins;
                    
                    provider.updateSetting(setting.key, parsedValue);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Saved: $hrs hours and $mins minutes')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
  
  /// Format datetime for display
  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
