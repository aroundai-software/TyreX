import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';

class TyreCatalogScreen extends StatefulWidget {
  const TyreCatalogScreen({super.key});

  @override
  State<TyreCatalogScreen> createState() => _TyreCatalogScreenState();
}

class _TyreCatalogScreenState extends State<TyreCatalogScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _sizeController = TextEditingController();

  List<Map<String, dynamic>> _tyres = [];
  bool _isLoading = false;
  int? _editingId;

  @override
  void initState() {
    super.initState();
    _loadTyres();
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  Future<void> _loadTyres() async {
    setState(() => _isLoading = true);
    try {
      final tyres = await _supabaseService.getTyreCatalog();
      setState(() {
        _tyres = tyres;
      });
    } catch (e) {
      _showError('Failed to load tyre catalog: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTyre() async {
    final brand = _brandController.text.trim().toUpperCase();
    final model = _modelController.text.trim();
    final size = _sizeController.text.trim().toUpperCase();
    
    if (brand.isEmpty || model.isEmpty || size.isEmpty) {
      _showError('Brand, Model, and Size are required.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_editingId != null) {
        await _supabaseService.updateTyreCatalogItem(_editingId!, brand, model, size);
        _showSuccess('Tyre updated successfully.');
      } else {
        await _supabaseService.addTyreCatalogItem(brand, model, size);
        _showSuccess('Tyre added successfully.');
      }
      _resetForm();
      _loadTyres();
    } catch (e) {
      _showError('Failed to save tyre: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTyre(int id, String desc) async {
    final confirmed = await _showConfirmDialog(
      'Delete Tyre',
      'Are you sure you want to delete "$desc"?',
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await _supabaseService.deleteTyreCatalogItem(id);
      _showSuccess('Tyre deleted successfully.');
      _loadTyres();
    } catch (e) {
      _showError('Deletion failed: $e');
      setState(() => _isLoading = false);
    }
  }

  void _editTyre(Map<String, dynamic> tyre) {
    setState(() {
      _editingId = tyre['id'];
      _brandController.text = tyre['brand'];
      _modelController.text = tyre['model'];
      _sizeController.text = tyre['size'];
    });
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _brandController.clear();
      _modelController.clear();
      _sizeController.clear();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Tyre Catalog'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Add/Edit Form
            AppCard(
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
                              color: Colors.teal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.tire_repair, color: Colors.teal, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _editingId == null ? 'Add New Tyre' : 'Edit Tyre',
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
                              controller: _brandController,
                              decoration: const InputDecoration(
                                labelText: 'Brand *',
                                hintText: 'e.g., MICHELIN',
                              ),
                              textCapitalization: TextCapitalization.characters,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _modelController,
                              decoration: const InputDecoration(
                                labelText: 'Model / Pattern *',
                                hintText: 'e.g., Pilot Sport 4',
                              ),
                              textCapitalization: TextCapitalization.words,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _sizeController,
                              decoration: const InputDecoration(
                                labelText: 'Size *',
                                hintText: 'e.g., 205/55 R16',
                              ),
                              textCapitalization: TextCapitalization.characters,
                            ),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _brandController,
                                  decoration: const InputDecoration(
                                    labelText: 'Brand *',
                                    hintText: 'e.g., MICHELIN',
                                  ),
                                  textCapitalization: TextCapitalization.characters,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: _modelController,
                                  decoration: const InputDecoration(
                                    labelText: 'Model / Pattern *',
                                    hintText: 'e.g., Pilot Sport 4',
                                  ),
                                  textCapitalization: TextCapitalization.words,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _sizeController,
                            decoration: const InputDecoration(
                              labelText: 'Size *',
                              hintText: 'e.g., 205/55 R16',
                            ),
                            textCapitalization: TextCapitalization.characters,
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
                      onPressed: _isLoading ? null : _saveTyre,
                      icon: Icon(_editingId == null ? Icons.add : Icons.save),
                      label: Text(_editingId == null ? 'Add Tyre' : 'Update Tyre'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // List of Tyres
            Expanded(
              child: AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Text(
                          'Tyre Catalog',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_tyres.length} total',
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
                  const Divider(height: 1),
                  if (_tyres.isEmpty && !_isLoading)
                    Padding(
                      padding: const EdgeInsets.all(48.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.tire_repair, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text(
                              'No tyres yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Add your first tyre above.',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: _tyres.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                        final item = _tyres[index];
                        final desc = '${item['brand']} ${item['model']} ${item['size']}';
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.tire_repair, color: Colors.teal, size: 16),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['brand'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item['model']} - ${item['size']}',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 14,
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
                                    onPressed: () => _editTyre(item),
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _deleteTyre(item['id'], desc),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
