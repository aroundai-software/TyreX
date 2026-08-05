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
  final _liSiController = TextEditingController();
  final _basicPriceController = TextEditingController();
  final _billingPriceController = TextEditingController();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _tyres = [];
  bool _isLoading = false;
  int? _editingId;
  String _searchQuery = '';

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
    _liSiController.dispose();
    _basicPriceController.dispose();
    _billingPriceController.dispose();
    _searchController.dispose();
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
    final liSi = _liSiController.text.trim();
    final basicPrice = double.tryParse(_basicPriceController.text.trim());
    final billingPrice = double.tryParse(_billingPriceController.text.trim());
    
    if (brand.isEmpty || model.isEmpty || size.isEmpty) {
      _showError('Brand, Model, and Size are required.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_editingId != null) {
        await _supabaseService.updateTyreCatalogItem(_editingId!, brand, model, size, liSi: liSi, basicPrice: basicPrice, billingPrice: billingPrice);
        _showSuccess('Tyre updated successfully.');
      } else {
        await _supabaseService.addTyreCatalogItem(brand, model, size, liSi: liSi, basicPrice: basicPrice, billingPrice: billingPrice);
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
      _liSiController.text = tyre['li_si']?.toString() ?? '';
      _basicPriceController.text = tyre['basic_price']?.toString() ?? '';
      _billingPriceController.text = tyre['billing_price']?.toString() ?? '';
    });
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _brandController.clear();
      _modelController.clear();
      _sizeController.clear();
      _liSiController.clear();
      _basicPriceController.clear();
      _billingPriceController.clear();
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

  List<Map<String, dynamic>> get _filteredTyres {
    if (_searchQuery.isEmpty) return _tyres;
    final q = _searchQuery.toLowerCase();
    return _tyres.where((item) {
      final brand = item['brand']?.toString().toLowerCase() ?? '';
      final model = item['model']?.toString().toLowerCase() ?? '';
      final size = item['size']?.toString().toLowerCase() ?? '';
      return brand.contains(q) || model.contains(q) || size.contains(q);
    }).toList();
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0).copyWith(bottom: 12.0),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search by Brand, Model or Size...',
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
    final filteredTyres = _filteredTyres;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Tyre Catalog'),
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
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _liSiController,
                                  decoration: const InputDecoration(
                                    labelText: 'LI/SI',
                                    hintText: 'e.g., 91V',
                                  ),
                                  textCapitalization: TextCapitalization.characters,
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _basicPriceController,
                                  decoration: const InputDecoration(
                                    labelText: 'Basic Price',
                                    prefixText: '₹ ',
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _billingPriceController,
                                  decoration: const InputDecoration(
                                    labelText: 'Billing Price',
                                    prefixText: '₹ ',
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _sizeController,
                                      decoration: const InputDecoration(
                                        labelText: 'Size *',
                                        hintText: 'e.g., 205/55 R16',
                                      ),
                                      textCapitalization: TextCapitalization.characters,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextField(
                                      controller: _liSiController,
                                      decoration: const InputDecoration(
                                        labelText: 'LI/SI',
                                        hintText: 'e.g., 91V',
                                      ),
                                      textCapitalization: TextCapitalization.characters,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _basicPriceController,
                                      decoration: const InputDecoration(
                                        labelText: 'Basic Price',
                                        prefixText: '₹ ',
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextField(
                                      controller: _billingPriceController,
                                      decoration: const InputDecoration(
                                        labelText: 'Billing Price',
                                        prefixText: '₹ ',
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    ),
                                  ),
                                ],
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
                      'Tyre Catalog',
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
                        '${filteredTyres.length} total',
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
          child: _isLoading && _tyres.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : filteredTyres.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.tire_repair, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text(
                            'No tyres found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          if (_searchQuery.isEmpty) ...[
                            const SizedBox(height: 4),
                            const Text(
                              'Add your first tyre above.',
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
                      itemCount: filteredTyres.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = filteredTyres[index];
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
                                      '${item['model']} - ${item['size']} ${item['li_si'] != null && item['li_si'].toString().isNotEmpty ? '(${item['li_si']})' : ''}',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (item['billing_price'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          '₹${item['billing_price']}',
                                          style: const TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
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
      ),
    );
  }
}
