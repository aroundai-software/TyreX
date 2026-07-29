// lib/screens/admin/vehicle_management_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/company_service.dart';

class VehicleManagementScreen extends StatefulWidget {
  const VehicleManagementScreen({super.key});

  @override
  State<VehicleManagementScreen> createState() => _VehicleManagementScreenState();
}

class _VehicleManagementScreenState extends State<VehicleManagementScreen> {
  final supabase = Supabase.instance.client;
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();

  List<Map<String, dynamic>> _vehicleModels = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadVehicleModels();
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicleModels() async {
    setState(() => _isLoading = true);

    try {
      final response = await supabase
          .from('vehicle_models')
          .select('*')
          .order('brand');

      setState(() {
        _vehicleModels = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      _showError('Could not load vehicle models: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addVehicleModel() async {
    final brand = _normalizeName(_brandController.text);
    final model = _normalizeName(_modelController.text);

    if (brand.isEmpty || model.isEmpty) {
      _showError('Brand and model are required.');
      return;
    }

    // Check for duplicates
    final duplicate = _vehicleModels.any(
          (item) => item['brand'] == brand && item['Model name'] == model,
    );

    if (duplicate) {
      _showError('$brand - $model already exists.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Auto-fill company fields
      final companyService = CompanyService();
      final modelData = companyService.addCompanyFields({
        'brand': brand,
        'Model name': model,
      }, tableName: 'vehicle_models');
      
      await supabase.from('vehicle_models').insert(modelData);

      _showSuccess('Vehicle model added successfully.');
      _brandController.clear();
      _modelController.clear();
      _loadVehicleModels();
    } catch (e) {
      _showError('Could not add model: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteVehicleModel(int id, String brand, String model) async {
    final confirmed = await _showConfirmDialog(
      'Delete Vehicle Model',
      'Are you sure you want to delete "$brand - $model"? This may affect existing records.',
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await supabase.from('vehicle_models').delete().eq('id', id);

      _showSuccess('Vehicle model deleted successfully.');
      _loadVehicleModels();
    } catch (e) {
      _showError('Deletion failed: $e');
      setState(() => _isLoading = false);
    }
  }

  String _normalizeName(String str) {
    if (str.isEmpty) return '';
    return str.trim()
        .replaceAll(RegExp(r'[\s-]+'), ' ')
        .toLowerCase()
        .split(' ')
        .map((word) => word.isNotEmpty
        ? word[0].toUpperCase() + word.substring(1)
        : '')
        .join(' ');
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
      backgroundColor:Colors.white,
      appBar: AppBar(
        title: const Text('Vehicle Management'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Add Form
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create New Vehicle Brand & Model',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _brandController,
                    decoration: const InputDecoration(
                      labelText: 'Brand *',
                      hintText: 'e.g., Maruti Suzuki',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _modelController,
                    decoration: const InputDecoration(
                      labelText: 'Model *',
                      hintText: 'e.g., Swift',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _addVehicleModel,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Vehicle Model'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // List - Expanded container with fixed height
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Existing Brands & Models',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 400, // Fixed height for the list container
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _vehicleModels.isEmpty
                        ? const Center(
                      child: Text(
                        'No vehicle models created yet.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    )
                        : ListView.builder(
                      itemCount: _vehicleModels.length,
                      itemBuilder: (context, index) {
                        final item = _vehicleModels[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item['brand']} - ${item['Model name']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteVehicleModel(
                                  item['id'],
                                  item['brand'],
                                  item['Model name'],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20), // Extra padding at bottom
          ],
        ),
      ),
    );
  }
}