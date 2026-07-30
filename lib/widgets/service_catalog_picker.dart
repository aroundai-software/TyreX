import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ServiceCatalogPicker extends StatefulWidget {
  final List<Map<String, dynamic>> serviceCatalog;
  final Function(String serviceName, double? defaultPrice) onServiceSelected;

  const ServiceCatalogPicker({
    Key? key,
    required this.serviceCatalog,
    required this.onServiceSelected,
  }) : super(key: key);

  @override
  State<ServiceCatalogPicker> createState() => _ServiceCatalogPickerState();
}

class _ServiceCatalogPickerState extends State<ServiceCatalogPicker> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, List<Map<String, dynamic>>> _groupedCatalog = {};
  Map<String, List<Map<String, dynamic>>> _filteredGroupedCatalog = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _groupCatalog();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _filterCatalog();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _groupCatalog() {
    _groupedCatalog.clear();
    for (var service in widget.serviceCatalog) {
      final category = (service['category']?.toString().trim().isNotEmpty == true)
          ? service['category'].toString().trim()
          : 'Common';
      if (!_groupedCatalog.containsKey(category)) {
        _groupedCatalog[category] = [];
      }
      _groupedCatalog[category]!.add(service);
    }
    _filteredGroupedCatalog = Map.from(_groupedCatalog);
  }

  void _filterCatalog() {
    if (_searchQuery.isEmpty) {
      _filteredGroupedCatalog = Map.from(_groupedCatalog);
      return;
    }
    
    _filteredGroupedCatalog.clear();
    for (var entry in _groupedCatalog.entries) {
      final filteredServices = entry.value.where((service) {
        return service['name'].toString().toLowerCase().contains(_searchQuery) ||
               entry.key.toLowerCase().contains(_searchQuery);
      }).toList();
      
      if (filteredServices.isNotEmpty) {
        _filteredGroupedCatalog[entry.key] = filteredServices;
      }
    }
  }

  void _addCustomService() {
    if (_searchQuery.trim().isNotEmpty) {
      widget.onServiceSelected(_searchQuery.trim(), null);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select Service',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search or type custom service...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                if (_searchQuery.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addCustomService,
                    child: const Text('Add Custom'),
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _filteredGroupedCatalog.isEmpty
                ? const Center(child: Text('No services found. Type to add custom.'))
                : ListView.builder(
                    itemCount: _filteredGroupedCatalog.keys.length,
                    itemBuilder: (context, index) {
                      final category = _filteredGroupedCatalog.keys.elementAt(index);
                      final services = _filteredGroupedCatalog[category]!;
                      
                      return ExpansionTile(
                        initiallyExpanded: _searchQuery.isNotEmpty,
                        title: Text(
                          category,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        children: services.map((service) {
                          final name = service['name'].toString();
                          final price = service['default_price'] != null
                              ? double.tryParse(service['default_price'].toString())
                              : null;
                          return ListTile(
                            title: Text(name),
                            trailing: price != null ? Text('₹$price', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)) : null,
                            onTap: () {
                              widget.onServiceSelected(name, price);
                              Navigator.pop(context);
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
