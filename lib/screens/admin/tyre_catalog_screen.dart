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
      body: SingleChildScrollView(
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
                      Text(
                        _editingId == null ? 'Add New Tyre' : 'Edit Tyre',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_editingId != null)
                        TextButton(
                          onPressed: _resetForm,
                          child: const Text('Cancel Edit'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tyre Catalog',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_tyres.isEmpty && !_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'No tyres found.\nAdd one above.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _tyres.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _tyres[index];
                      final desc = '${item['brand']} ${item['model']} ${item['size']}';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          item['brand'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('${item['model']} - ${item['size']}'),
                        trailing: Row(
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
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
