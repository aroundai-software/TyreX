import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';

class ServiceCatalogScreen extends StatefulWidget {
  const ServiceCatalogScreen({super.key});

  @override
  State<ServiceCatalogScreen> createState() => _ServiceCatalogScreenState();
}

class _ServiceCatalogScreenState extends State<ServiceCatalogScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _services = [];
  bool _isLoading = false;
  int? _editingId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    try {
      final services = await _supabaseService.getServiceCatalog();
      setState(() {
        _services = services;
      });
    } catch (e) {
      _showError('Failed to load services: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveService() async {
    final name = _nameController.text.trim().toUpperCase();
    if (name.isEmpty) {
      _showError('Service name is required.');
      return;
    }

    double? price;
    if (_priceController.text.trim().isNotEmpty) {
      price = double.tryParse(_priceController.text.trim());
      if (price == null) {
        _showError('Invalid price format.');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (_editingId != null) {
        await _supabaseService.updateServiceCatalogItem(_editingId!, name, price);
        _showSuccess('Service updated successfully.');
      } else {
        await _supabaseService.addServiceCatalogItem(name, price);
        _showSuccess('Service added successfully.');
      }
      _resetForm();
      _loadServices();
    } catch (e) {
      _showError('Failed to save service: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteService(int id, String name) async {
    final confirmed = await _showConfirmDialog(
      'Delete Service',
      'Are you sure you want to delete "$name"?',
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await _supabaseService.deleteServiceCatalogItem(id);
      _showSuccess('Service deleted successfully.');
      _loadServices();
    } catch (e) {
      _showError('Deletion failed: $e');
      setState(() => _isLoading = false);
    }
  }

  void _editService(Map<String, dynamic> service) {
    setState(() {
      _editingId = service['id'];
      _nameController.text = service['name'];
      _priceController.text = service['default_price']?.toString() ?? '';
    });
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _nameController.clear();
      _priceController.clear();
    });
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
        behavior: SnackBarBehavior.floating,
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
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredServices {
    if (_searchQuery.isEmpty) return _services;
    final q = _searchQuery.toLowerCase();
    return _services.where((item) {
      final name = item['name']?.toString().toLowerCase() ?? '';
      return name.contains(q);
    }).toList();
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0).copyWith(bottom: 12.0),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search by Service Name...',
          prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredServices = _filteredServices;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Service Catalog'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.build, color: Colors.orange, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _editingId == null ? 'Add New Service' : 'Edit Service',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (_editingId != null)
                            TextButton(
                              onPressed: _resetForm,
                              child: const Text('Cancel Edit'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 600) {
                            return Column(
                              children: [
                                TextField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Service Name *',
                                    hintText: 'e.g., WHEEL ALIGNMENT',
                                  ),
                                  textCapitalization: TextCapitalization.characters,
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _priceController,
                                  decoration: const InputDecoration(
                                    labelText: 'Default Price (Optional)',
                                    hintText: 'e.g., 500',
                                    prefixText: '₹ ',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Service Name *',
                                    hintText: 'e.g., WHEEL ALIGNMENT',
                                  ),
                                  textCapitalization: TextCapitalization.characters,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: _priceController,
                                  decoration: const InputDecoration(
                                    labelText: 'Default Price (Optional)',
                                    hintText: 'e.g., 500',
                                    prefixText: '₹ ',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _saveService,
                          icon: Icon(_editingId == null ? Icons.add : Icons.save),
                          label: Text(_editingId == null ? 'Add Service' : 'Update Service'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverAppBar(
              pinned: true,
              floating: false,
              automaticallyImplyLeading: false,
              backgroundColor: const Color(0xFFF8FAFC),
              surfaceTintColor: Colors.transparent,
              elevation: innerBoxIsScrolled ? 2 : 0,
              shadowColor: Colors.black12,
              toolbarHeight: 50,
              titleSpacing: 0,
              title: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const Text(
                      'Service Catalog',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        '${filteredServices.length} total',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(68),
                child: _buildSearchBar(),
              ),
            ),
          ];
        },
        body: Container(
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: _isLoading && _services.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : filteredServices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.build, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text(
                            'No services found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          if (_searchQuery.isEmpty) ...[
                            const SizedBox(height: 4),
                            const Text(
                              'Add your first service above.',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: filteredServices.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = filteredServices[index];
                        final price = item['default_price'];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.build, color: Colors.orange, size: 16),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      price != null ? '₹ $price' : 'No price',
                                      style: TextStyle(
                                        color: price != null ? AppTheme.textPrimary : AppTheme.textSecondary,
                                        fontSize: 14,
                                        fontWeight: price != null ? FontWeight.w500 : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: AppTheme.primaryColor),
                                    onPressed: () => _editService(item),
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _deleteService(item['id'], item['name']),
                                    tooltip: 'Delete',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
