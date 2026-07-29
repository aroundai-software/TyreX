// lib/widgets/service_reminder_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';

class ServiceReminderCard extends StatefulWidget {
  final Map<String, dynamic> reminder;
  final VoidCallback onStatusUpdated;

  const ServiceReminderCard({
    super.key,
    required this.reminder,
    required this.onStatusUpdated,
  });

  @override
  State<ServiceReminderCard> createState() => _ServiceReminderCardState();
}

class _ServiceReminderCardState extends State<ServiceReminderCard> {
  final _supabaseService = SupabaseService();
  bool _isUpdating = false;

  String get _customerName => widget.reminder['customer_name'] ?? 'Unknown';
  String get _customerPhone => widget.reminder['customer_phone'] ?? '';
  String get _vehicleNumber => widget.reminder['vehicle_number'] ?? 'N/A';
  String get _vehicleBrand => widget.reminder['vehicle_brand'] ?? '';
  String get _vehicleModel => widget.reminder['vehicle_model'] ?? '';
  String get _followUpStatus => widget.reminder['follow_up_status'] ?? 'pending';
  String get _notes => widget.reminder['notes'] ?? '';

  DateTime? get _lastServiceDate {
    final dateStr = widget.reminder['last_service_date'];
    return dateStr != null ? DateTime.tryParse(dateStr) : null;
  }

  DateTime? get _nextServiceDueDate {
    final dateStr = widget.reminder['next_service_due_date'];
    return dateStr != null ? DateTime.tryParse(dateStr) : null;
  }

  Color get _statusColor {
    switch (_followUpStatus) {
      case 'contacted':
        return Colors.blue;
      case 'scheduled':
        return Colors.green;
      case 'no_response':
        return Colors.orange;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.red;
    }
  }

  String get _statusText {
    switch (_followUpStatus) {
      case 'contacted':
        return 'Contacted';
      case 'scheduled':
        return 'Scheduled';
      case 'no_response':
        return 'No Response';
      case 'completed':
        return 'Completed';
      default:
        return 'Pending';
    }
  }

  Future<void> _makePhoneCall() async {
    if (_customerPhone.isEmpty) return;
    
    final phoneUrl = Uri.parse('tel:+91$_customerPhone');
    try {
      if (await canLaunchUrl(phoneUrl)) {
        await launchUrl(phoneUrl);
      } else {
        _showError('Could not launch phone dialer');
      }
    } catch (e) {
      _showError('Error launching phone dialer: $e');
    }
  }

  Future<void> _updateStatus(String newStatus, {String? notes}) async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);

    try {
      await _supabaseService.updateServiceReminderStatus(
        widget.reminder['id'],
        newStatus,
        notes: notes,
      );
      
      if (mounted) {
        _showSuccess('Status updated to ${_getStatusDisplayName(newStatus)}');
        widget.onStatusUpdated();
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to update status: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'contacted':
        return 'Contacted';
      case 'scheduled':
        return 'Scheduled';
      case 'no_response':
        return 'No Response';
      case 'completed':
        return 'Completed';
      default:
        return 'Pending';
    }
  }

  void _showStatusUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) => _StatusUpdateDialog(
        currentStatus: _followUpStatus,
        currentNotes: _notes,
        onUpdate: _updateStatus,
        isUpdating: _isUpdating,
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
      ),
    );
  }

  void _showSuccess(String message) {
    // Commented out to reduce UI noise
    // if (!mounted) return;
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text(message),
    //     backgroundColor: Colors.green,
    //     behavior: SnackBarBehavior.floating,
    //   ),
    // );
  }

  @override
  Widget build(BuildContext context) {
    final daysOverdue = _nextServiceDueDate != null
        ? DateTime.now().difference(_nextServiceDueDate!).inDays
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: daysOverdue > 30 ? Colors.red.shade200 : const Color(0xFFE5E7EB),
          width: daysOverdue > 30 ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.schedule_rounded,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _customerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _customerPhone,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Vehicle Details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_car, size: 16, color: Color(0xFF6B7280)),
                      const SizedBox(width: 8),
                      Text(
                        '$_vehicleNumber • $_vehicleBrand $_vehicleModel',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.history, size: 16, color: Color(0xFF6B7280)),
                      const SizedBox(width: 8),
                      Text(
                        'Last Service: ${_lastServiceDate != null ? DateFormat('dd MMM yyyy').format(_lastServiceDate!) : 'N/A'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.event,
                        size: 16,
                        color: daysOverdue > 0 ? Colors.red : const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Due: ${_nextServiceDueDate != null ? DateFormat('dd MMM yyyy').format(_nextServiceDueDate!) : 'N/A'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: daysOverdue > 0 ? Colors.red : const Color(0xFF6B7280),
                          fontWeight: daysOverdue > 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      if (daysOverdue > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$daysOverdue days overdue',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            if (_notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.note, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _notes,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.blue,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _customerPhone.isNotEmpty ? _makePhoneCall : null,
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUpdating ? null : _showStatusUpdateDialog,
                    icon: _isUpdating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit, size: 18),
                    label: Text(_isUpdating ? 'Updating...' : 'Update Status'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusUpdateDialog extends StatefulWidget {
  final String currentStatus;
  final String currentNotes;
  final Function(String status, {String? notes}) onUpdate;
  final bool isUpdating;

  const _StatusUpdateDialog({
    required this.currentStatus,
    required this.currentNotes,
    required this.onUpdate,
    required this.isUpdating,
  });

  @override
  State<_StatusUpdateDialog> createState() => _StatusUpdateDialogState();
}

class _StatusUpdateDialogState extends State<_StatusUpdateDialog> {
  late String _selectedStatus;
  late TextEditingController _notesController;

  final List<Map<String, dynamic>> _statusOptions = [
    {'value': 'contacted', 'label': 'Contacted', 'icon': Icons.phone},
    {'value': 'scheduled', 'label': 'Scheduled', 'icon': Icons.event},
    {'value': 'no_response', 'label': 'No Response', 'icon': Icons.phone_missed},
    {'value': 'completed', 'label': 'Completed', 'icon': Icons.check_circle},
  ];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.currentStatus;
    _notesController = TextEditingController(text: widget.currentNotes);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.edit, color: AppTheme.primaryColor),
          SizedBox(width: 8),
          Text('Update Follow-up Status'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Status:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ..._statusOptions.map((option) => RadioListTile<String>(
            value: option['value'],
            groupValue: _selectedStatus,
            onChanged: (value) {
              setState(() => _selectedStatus = value!);
            },
            title: Row(
              children: [
                Icon(option['icon'], size: 20),
                const SizedBox(width: 8),
                Text(option['label']),
              ],
            ),
            contentPadding: EdgeInsets.zero,
          )),
          const SizedBox(height: 16),
          const Text(
            'Notes (Optional):',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Add any notes about the follow-up...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.isUpdating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: widget.isUpdating
              ? null
              : () {
                  Navigator.pop(context);
                  widget.onUpdate(
                    _selectedStatus,
                    notes: _notesController.text.trim().isEmpty
                        ? null
                        : _notesController.text.trim(),
                  );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: widget.isUpdating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }
}
