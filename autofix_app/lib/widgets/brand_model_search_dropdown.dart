import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// A searchable dropdown widget for selecting vehicle brand and model
/// Features alphabetical filtering (A-Z buttons) and text search
class BrandModelSearchDropdown extends StatefulWidget {
  final Function(String? brand, int? modelId, String? modelName) onSelectionChanged;
  final String? initialBrand;
  final int? initialModelId;
  final String? initialModelName;

  const BrandModelSearchDropdown({
    Key? key,
    required this.onSelectionChanged,
    this.initialBrand,
    this.initialModelId,
    this.initialModelName,
  }) : super(key: key);

  @override
  State<BrandModelSearchDropdown> createState() => _BrandModelSearchDropdownState();
}

class _BrandModelSearchDropdownState extends State<BrandModelSearchDropdown> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _allModels = [];
  List<Map<String, dynamic>> _filteredModels = [];
  List<String> _uniqueBrands = [];
  List<String> _filteredBrands = [];
  
  bool _isLoading = true;
  bool _showBrandDropdown = false;
  bool _showModelDropdown = false;
  String? _selectedBrand;
  int? _selectedModelId;
  String? _selectedModelName;
  String? _selectedLetter;

  @override
  void initState() {
    super.initState();
    _selectedBrand = widget.initialBrand;
    _selectedModelId = widget.initialModelId;
    _selectedModelName = widget.initialModelName;
    _loadAllModels();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllModels() async {
    try {
      final models = await _supabaseService.getAllVehicleModels();
      if (mounted) {
        setState(() {
          _allModels = models;
          _uniqueBrands = models
              .map<String>((e) => e['brand'] as String)
              .toSet()
              .toList()
            ..sort();
          _filteredBrands = _uniqueBrands;
          _filteredModels = models;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading vehicle models: $e')),
        );
      }
    }
  }

  void _filterBySearch(String query) {
    setState(() {
      _selectedLetter = null;
      if (query.isEmpty) {
        _filteredBrands = _uniqueBrands;
      } else {
        _filteredBrands = _uniqueBrands
            .where((brand) => brand.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _selectBrand(String brand) {
    setState(() {
      _selectedBrand = brand;
      _selectedModelId = null;
      _selectedModelName = null;
      _showBrandDropdown = false;
      _filteredModels = _allModels
          .where((m) => m['brand'] == brand)
          .toList();
    });
    widget.onSelectionChanged(_selectedBrand, null, null);
  }

  void _selectModel(Map<String, dynamic> model) {
    setState(() {
      _selectedModelId = model['id'] as int;
      _selectedModelName = model['Model name'] as String;
      _showModelDropdown = false;
    });
    widget.onSelectionChanged(_selectedBrand, _selectedModelId, _selectedModelName);
  }

  void _clearSelection() {
    setState(() {
      _selectedBrand = null;
      _selectedModelId = null;
      _selectedModelName = null;
      _selectedLetter = null;
      _searchController.clear();
      _filteredBrands = _uniqueBrands;
      _filteredModels = _allModels;
    });
    widget.onSelectionChanged(null, null, null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Brand and Model Selection Row
        Row(
          children: [
            Expanded(child: _buildBrandSelector()),
            const SizedBox(width: 12),
            Expanded(child: _buildModelSelector()),
          ],
        ),
      ],
    );
  }

  Widget _buildBrandSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Brand',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        
        // Search/Selected Brand Field
        GestureDetector(
          onTap: () => setState(() => _showBrandDropdown = !_showBrandDropdown),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _showBrandDropdown 
                    ? AppTheme.primaryColor 
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _selectedBrand != null
                      ? Text(
                          _selectedBrand!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                        )
                      : TextField(
                          controller: _searchController,
                          onChanged: _filterBySearch,
                          onTap: () => setState(() => _showBrandDropdown = true),
                          decoration: const InputDecoration(
                            hintText: 'Search brand...',
                            hintStyle: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                ),
                if (_selectedBrand != null)
                  GestureDetector(
                    onTap: _clearSelection,
                    child: const Icon(Icons.close, size: 18, color: Color(0xFF6B7280)),
                  )
                else
                  Icon(
                    _showBrandDropdown ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: const Color(0xFF6B7280),
                  ),
              ],
            ),
          ),
        ),
        
        // Brand Dropdown List
        if (_showBrandDropdown)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 250),
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _filteredBrands.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _searchController.text.isEmpty && _selectedLetter == null
                              ? 'No brands available'
                              : 'No brands found',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _filteredBrands.length,
                        itemBuilder: (context, index) {
                          final brand = _filteredBrands[index];
                          final modelCount = _allModels
                              .where((m) => m['brand'] == brand)
                              .length;
                          
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _selectBrand(brand),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        brand,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$modelCount',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
      ],
    );
  }

  Widget _buildModelSelector() {
    final modelsForBrand = _selectedBrand == null
        ? <Map<String, dynamic>>[]
        : _allModels.where((m) => m['brand'] == _selectedBrand).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Model',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        
        // Selected Model Field
        GestureDetector(
          onTap: _selectedBrand != null
              ? () => setState(() => _showModelDropdown = !_showModelDropdown)
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _selectedBrand != null ? Colors.white : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _showModelDropdown 
                    ? AppTheme.primaryColor 
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedModelName ?? 
                        (_selectedBrand != null ? 'Select model...' : 'Select brand first'),
                    style: TextStyle(
                      fontSize: 14,
                      color: _selectedModelName != null 
                          ? AppTheme.textPrimary 
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
                Icon(
                  _showModelDropdown ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: _selectedBrand != null 
                      ? const Color(0xFF6B7280) 
                      : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
        
        // Model Dropdown List
        if (_showModelDropdown && _selectedBrand != null)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 250),
            child: modelsForBrand.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No models available',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: modelsForBrand.length,
                    itemBuilder: (context, index) {
                      final model = modelsForBrand[index];
                      final modelName = model['Model name'] as String;
                      final isSelected = _selectedModelId == model['id'];
                      
                      return Material(
                        color: isSelected 
                            ? AppTheme.primaryColor.withValues(alpha: 0.1) 
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () => _selectModel(model),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    modelName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected 
                                          ? FontWeight.w600 
                                          : FontWeight.w500,
                                      color: isSelected 
                                          ? AppTheme.primaryColor 
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: AppTheme.primaryColor,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
      ],
    );
  }
}
