class AdminSettingModel {
  final String key;
  dynamic value; // Can be bool, List<String>, int, String, etc.
  final String label;
  final String description;
  final String category;
  final String type;
  
  // Phase 2 enhancements
  final int displayOrder;
  final String inputType;
  final Map<String, dynamic>? inputConfig;
  final dynamic defaultValue;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AdminSettingModel({
    required this.key,
    required this.value,
    required this.label,
    required this.description,
    required this.category,
    required this.type,
    this.displayOrder = 999,
    String? inputType,
    this.inputConfig,
    this.defaultValue,
    this.createdAt,
    this.updatedAt,
  }) : inputType = inputType ?? type; // Fallback to type for backward compatibility

  factory AdminSettingModel.fromSupabase(Map<String, dynamic> row) {
    final key = row['setting_key'] as String;
    final dbValue = row['setting_value'];

    // Parse value based on type (coerce common string booleans)
    dynamic parsedValue;
    if (key == 'visible_report_columns') {
      parsedValue = dbValue is List ? List<String>.from(dbValue) : <String>[];
    } else if (dbValue is bool) {
      parsedValue = dbValue;
    } else if (dbValue is int || dbValue is double) {
      parsedValue = dbValue;
    } else if (dbValue is String) {
      final lower = dbValue.toLowerCase();
      if (lower == 'true') {
        parsedValue = true;
      } else if (lower == 'false') {
        parsedValue = false;
      } else {
        parsedValue = dbValue;
      }
    } else {
      parsedValue = dbValue;
    }

    // Phase 2: Read metadata from database if available (backward compatible)
    final label = row['label'] as String? ?? _generateLabel(key);
    final description = row['description'] as String? ?? '';
    final category = row['category'] as String? ?? 'General';
    final type = row['input_type'] as String? ?? (key == 'visible_report_columns' ? 'checkbox_group' : 'toggle');
    final displayOrder = row['display_order'] as int? ?? 999;
    final inputConfig = row['input_config'] as Map<String, dynamic>?;
    final defaultValue = row['default_value'];
    
    // Parse timestamps if available
    DateTime? createdAt;
    DateTime? updatedAt;
    try {
      if (row['created_at'] != null) {
        createdAt = DateTime.parse(row['created_at'].toString());
      }
      if (row['updated_at'] != null) {
        updatedAt = DateTime.parse(row['updated_at'].toString());
      }
    } catch (e) {
      // Ignore timestamp parsing errors
    }

    return AdminSettingModel(
      key: key,
      value: parsedValue,
      label: label,
      description: description,
      category: category,
      type: type,
      displayOrder: displayOrder,
      inputType: type,
      inputConfig: inputConfig,
      defaultValue: defaultValue ?? parsedValue,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
  
  /// Generate a human-readable label from the setting key
  static String _generateLabel(String key) {
    // Convert snake_case to Title Case
    return key
        .split('_')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  dynamic toJsonValue() {
    return value;
  }
  
  /// Convert to JSON for caching or export
  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'value': value,
      'label': label,
      'description': description,
      'category': category,
      'type': type,
      'display_order': displayOrder,
      'input_type': inputType,
      'input_config': inputConfig,
      'default_value': defaultValue,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
  
  /// Reset setting to default value
  AdminSettingModel resetToDefault() {
    return AdminSettingModel(
      key: key,
      value: defaultValue ?? value,
      label: label,
      description: description,
      category: category,
      type: type,
      displayOrder: displayOrder,
      inputType: inputType,
      inputConfig: inputConfig,
      defaultValue: defaultValue,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
  
  /// Create a copy with updated value
  AdminSettingModel copyWith({
    dynamic value,
    String? label,
    String? description,
    String? category,
    String? type,
    int? displayOrder,
    String? inputType,
    Map<String, dynamic>? inputConfig,
    dynamic defaultValue,
  }) {
    return AdminSettingModel(
      key: key,
      value: value ?? this.value,
      label: label ?? this.label,
      description: description ?? this.description,
      category: category ?? this.category,
      type: type ?? this.type,
      displayOrder: displayOrder ?? this.displayOrder,
      inputType: inputType ?? this.inputType,
      inputConfig: inputConfig ?? this.inputConfig,
      defaultValue: defaultValue ?? this.defaultValue,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
