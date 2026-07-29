import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// A searchable dropdown widget for selecting materials
/// Displays materials with search functionality and category grouping
class MaterialSearchDropdown extends StatefulWidget {
  final Function(String) onMaterialSelected;
  final String? initialValue;
  final String hintText;

  const MaterialSearchDropdown({
    super.key,
    required this.onMaterialSelected,
    this.initialValue,
    this.hintText = 'Search material',
  });

  @override
  State<MaterialSearchDropdown> createState() => _MaterialSearchDropdownState();
}

class _MaterialSearchDropdownState extends State<MaterialSearchDropdown> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _allMaterials = [];
  List<Map<String, dynamic>> _filteredMaterials = [];
  bool _isLoading = true;
  bool _showDropdown = false;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
    _searchController.addListener(_filterMaterials);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    try {
      final materials = await _supabaseService.getAllMaterials();
      setState(() {
        _allMaterials = materials;
        _filteredMaterials = materials;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading materials: $e')),
        );
      }
    }
  }

  void _filterMaterials() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      if (query.isEmpty) {
        _filteredMaterials = _allMaterials;
      } else {
        _filteredMaterials = _allMaterials
            .where((material) =>
                material['name'].toString().toLowerCase().contains(query) ||
                (material['category'] as String?)?.toLowerCase().contains(query) == true)
            .toList();
      }
    });
  }

  void _selectMaterial(String materialName) {
    widget.onMaterialSelected(materialName);
    _searchController.clear();
    setState(() => _showDropdown = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input Field
        TextField(
          controller: _searchController,
          onTap: () => setState(() => _showDropdown = true),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(fontSize: 12),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF6B7280)),
            suffixIcon: _searchController.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _filterMaterials();
                    },
                    child: const Icon(Icons.close, size: 18, color: Color(0xFF6B7280)),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          style: const TextStyle(fontSize: 13),
        ),
        
        // Dropdown List
        if (_showDropdown)
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
            constraints: const BoxConstraints(maxHeight: 300),
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _filteredMaterials.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'No materials available'
                              : 'No materials found',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _filteredMaterials.length,
                        itemBuilder: (context, index) {
                          final material = _filteredMaterials[index];
                          final name = material['name'] as String;
                          final category = material['category'] as String?;
                          final unit = material['unit'] as String?;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _selectMaterial(name),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    if (category != null || unit != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          [category, unit]
                                              .where((e) => e != null)
                                              .join(' • '),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF9CA3AF),
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
}

/// A compact material selection widget for inline use
/// Shows selected material with option to change
class MaterialSelector extends StatefulWidget {
  final String selectedMaterial;
  final Function(String) onMaterialChanged;
  final VoidCallback onRemove;

  const MaterialSelector({
    super.key,
    required this.selectedMaterial,
    required this.onMaterialChanged,
    required this.onRemove,
  });

  @override
  State<MaterialSelector> createState() => _MaterialSelectorState();
}

class _MaterialSelectorState extends State<MaterialSelector> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.selectedMaterial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Text(
              widget.selectedMaterial,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: widget.onRemove,
            child: const Icon(Icons.close, size: 14, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}
