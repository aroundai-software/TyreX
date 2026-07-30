// lib/screens/update_screen.dart (IMPROVED VERSION - Fixes Memory Leaks)
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform, File;
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import '../providers/report_provider.dart';
import '../services/supabase_service.dart';
import '../services/local_media_service.dart';
import '../services/company_service.dart';
import '../screens/job_card_screen.dart';
import '../screens/custom_scanner_screen.dart';
import '../screens/continuous_camera_screen.dart';
import '../widgets/loading_dialog.dart';
import '../widgets/error_display.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint, kIsWeb;
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/admin_settings_provider.dart';
import '../utils/app_constants.dart';
import '../utils/validators.dart';
import '../utils/haptic_utils.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../widgets/material_search_dropdown.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/notification_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class UpdateScreen extends StatefulWidget {
  final bool isAdminMode;
  const UpdateScreen({super.key, this.isAdminMode = false});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final supabase = Supabase.instance.client;

  bool _showUpdateForm = false;
  // ✅ FIX: Local loading state for form submissions
  bool _isSubmitting = false;

  // ✅ NEW: Wash integration
  bool _washRequired = true;
  String _currentStatus = '';

  // Current selected job data
  int? _currentReportId;
  String _openedFromTab = '';
  List<String> _jobMediaUrls = []; // Before photos
  List<String> _afterJobMediaUrls = []; // After photos from DB
  List<String> _newAfterJobMediaPaths = []; // Newly captured after photos
  String? _scannedBarcodeText; // ✅ Barcode text
  String? _scannedBarcodeImageUrl; // ✅ Barcode image URL
  Uint8List? _newBarcodeImageBytes; // For new uploaded barcode
  final _barcodeController = TextEditingController();
  String? _currentStartedAt;
  String? _currentCompletedAt;
  String? _currentJobCardId;
  String? _currentVehicleNo;
  List<Map<String, dynamic>> _currentTechnicianAssignments = [];
  Map<String, dynamic>? _currentBookingData; // ✅ Store for later use
  List<Map<String, dynamic>> _originalComplaints = [];
  List<Map<String, dynamic>> _newSuggestions = [];
  List<Map<String, dynamic>> _approvedItems = [];
  bool _hasCustomerApproval = false;
  
  // ✅ NEW: Store approval state per report ID to persist across navigation
  final Map<int, bool> _reportApprovalStates = {};

  // Track notified overdue jobs
  final Set<int> _notifiedOverdueJobs = {};

  // ✅ Add state variable for remarks
  String? _rejectionRemarks;

  // Customer voice feedback
  String? _currentCustomerFeedbackAudio;
  String? _currentCustomerFeedbackText;
  final AudioPlayer _feedbackAudioPlayer = AudioPlayer();
  bool _isFeedbackAudioPlaying = false;

  // Controllers
  final _suggestionTextController = TextEditingController();
  final _suggestionAmountController = TextEditingController();
  final _deliveryDateController = TextEditingController();
  final _laborCostController = TextEditingController(); // ✅ Add labor cost controller

  // ✅ FIX: Store controllers properly for disposal
  final Map<String, TextEditingController> _complaintControllers = {};
  final Map<String, List<String>> _approvedItemMaterials = {};
  final Map<String, TextEditingController> _materialControllers = {};
  
  // Store materials for each item (complaint or suggestion)
  final Map<String, List<String>> _itemMaterials = {};
  
  // State for direct bookings
  List<Map<String, dynamic>> _directBookings = [];
  bool _isLoadingDirectBookings = false;

  @override
  void initState() {
    super.initState();
    final adminSettings = Provider.of<AdminSettingsProvider>(context, listen: false);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    // ✅ Better initialization
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
  }

  // Robust WhatsApp opener: tries app schemes first, then wa.me/api links, with store fallback
  Future<bool> _openWhatsApp(String rawPhone, String message) async {
    try {
      final digits = rawPhone.replaceAll(RegExp(r'[^\d]'), '');
      String phone = digits;
      // If 10-digit Indian number, prefix 91. If already includes 91, keep as is
      if (digits.length == 10) {
        phone = '91$digits';
      } else if (digits.length == 12 && digits.startsWith('91')) {
        phone = digits;
      }

      final encodedMsg = Uri.encodeComponent(message);
      final candidates = <Uri>[
        Uri.parse('whatsapp://send?phone=$phone&text=$encodedMsg'),
        Uri.parse('whatsapp://send?text=$encodedMsg&phone=$phone'),
        // Universal links fallback
        Uri.parse('https://wa.me/$phone?text=$encodedMsg'),
        Uri.parse('https://api.whatsapp.com/send?phone=$phone&text=$encodedMsg'),
      ];

      for (int i = 0; i < candidates.length; i++) {
        final uri = candidates[i];
        try {
          final mode = (uri.scheme == 'whatsapp')
              ? LaunchMode.externalNonBrowserApplication
              : LaunchMode.platformDefault;
          final launched = await launchUrl(uri, mode: mode);
          if (launched) return true;
        } catch (e) {
          // Continue to next candidate if this one fails
          debugPrint('WhatsApp candidate $i failed: $e');
          continue;
        }
      }

      // As a last resort, nudge user to install/open WhatsApp from store
      if (Platform.isAndroid) {
        final market = Uri.parse('market://details?id=com.whatsapp');
        final webPlay = Uri.parse('https://play.google.com/store/apps/details?id=com.whatsapp');
        try {
          if (await canLaunchUrl(market)) {
            await launchUrl(market, mode: LaunchMode.externalApplication);
            return true;
          }
        } catch (e) {
          debugPrint('Market URL failed: $e');
        }
        try {
          if (await canLaunchUrl(webPlay)) {
            await launchUrl(webPlay, mode: LaunchMode.externalApplication);
            return true;
          }
        } catch (e) {
          debugPrint('Play Store web URL failed: $e');
        }
      } else if (Platform.isIOS) {
        final appStore = Uri.parse('https://apps.apple.com/app/whatsapp-messenger/id310633997');
        try {
          if (await canLaunchUrl(appStore)) {
            await launchUrl(appStore, mode: LaunchMode.externalApplication);
            return true;
          }
        } catch (e) {
          debugPrint('App Store URL failed: $e');
        }
      }
    } catch (e) {
      debugPrint('WhatsApp launch error: $e');
    }
    return false;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _suggestionTextController.dispose();
    _suggestionAmountController.dispose();
    _deliveryDateController.dispose();
    _laborCostController.dispose(); // ✅ Dispose labor cost controller
    _feedbackAudioPlayer.dispose();

    // ✅ FIX: Properly dispose all dynamically created controllers
    _disposeAllControllers();

    super.dispose();
  }

  // ✅ NEW: Helper method to dispose all controllers
  void _disposeAllControllers() {
    for (var controller in _complaintControllers.values) {
      controller.dispose();
    }
    _complaintControllers.clear();

    for (var controller in _materialControllers.values) {
      controller.dispose();
    }
    _materialControllers.clear();
    
    // Clear materials map to prevent sharing across different job cards
    _itemMaterials.clear();
  }

  // Map of tech_id to username
  final Map<int, String> _technicianNames = {};

  // ✅ NEW: Centralized data refresh method
  Future<void> _refreshData() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user != null) {
      final userId = user['id'] as int;
      // Use the ReportProvider to fetch the latest data
      await Provider.of<ReportProvider>(context, listen: false).refresh(userId, isAdminMode: widget.isAdminMode);
      // Also fetch direct bookings
      await _fetchDirectBookings(userId);
      
      // Fetch all technicians to map names
      try {
        final techs = await SupabaseService().getAllTechnicians();
        if (mounted) {
          setState(() {
            for (var t in techs) {
              _technicianNames[t['id']] = t['username'];
            }
          });
        }
      } catch (e) {
        debugPrint('Failed to load technician names: $e');
      }
    }
  }

  // Fetch direct bookings assigned to this executive
  Future<void> _fetchDirectBookings(int executiveId) async {
    if (!mounted) return;
    
    setState(() => _isLoadingDirectBookings = true);
    
    try {
      final supabaseService = SupabaseService();
      final bookings = await supabaseService.getAssignedBookingsForExecutive(executiveId);
      
      if (mounted) {
        setState(() {
          _directBookings = bookings;
          _isLoadingDirectBookings = false;
        });
        
        if (kDebugMode) {
          print('✅ Fetched ${bookings.length} direct bookings for executive $executiveId');
          for (var booking in bookings) {
            print('  - Booking ${booking['id']}: ${booking['customer_name']} (${booking['status']})');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDirectBookings = false);
        if (kDebugMode) {
          print('Error fetching direct bookings: $e');
        }
      }
    }
  }

  List<dynamic> _safeJsonDecodeList(dynamic data) {
    if (data is String && data.isNotEmpty && data.startsWith('[')) {
      try {
        return jsonDecode(data) as List;
      } catch (e) {
        return [];
      }
    } else if (data is List) {
      return data;
    }
    return [];
  }

  Future<void> _selectJob(int reportId, {String sourceTab = ''}) async {
    // Prevent selection if submitting
    if (_isSubmitting) return;

    setState(() {
      _openedFromTab = sourceTab;
    });

    try {
      // ✅ Include booking and vehicle data in the query
      final response = await supabase
          .from('reports')
          .select('''
          *,
          vehicles!reports_vehicle_fk(
            "Guid", "Vehicle Number", vehicle_name, "Color", "Engine Number", "Chasis Number",
            vehicle_models!inner(brand, "Model name")
          ),
          bookings!booking_id(customer_name, customer_phone, pickup_address, scheduled_time)
        ''')
          .eq('id', reportId)
          .single();

      // debugPrint("--- Viewing Report ID: ${response['id']} ---");

      final suggestedList = _safeJsonDecodeList(response['suggested']);
      final complaintList = _safeJsonDecodeList(response['complaint']);
      final approvedList = _safeJsonDecodeList(response['approved']);

      // ✅ Extract rejection remarks
      final status = response['status'];
      final remarks = response['inspection_remarks'];

      // --- ✅ ADD DEBUG PRINT FOR APPROVAL STATUS ---
      if (kDebugMode) {
        debugPrint("--- _selectJob Check ---");
        debugPrint("Report ID: ${response['id']}");
        debugPrint("Fetched 'approved' value raw: ${response['approved']}");
        debugPrint("Fetched 'approved' value type: ${response['approved'].runtimeType}");
        debugPrint("Result of _safeJsonDecodeList(approved): $approvedList");
        debugPrint("Resulting _hasCustomerApproval: ${approvedList.isNotEmpty}");
        debugPrint("--------------------------");
      }
      // --- END DEBUG PRINT ---

      // ✅ FIX: Dispose old controllers before creating new ones
      _disposeAllControllers();
      List<Map<String, dynamic>> originalComplaints = [];
      List<Map<String, dynamic>> newSuggestions = [];

      if (suggestedList.isNotEmpty) {
        originalComplaints = suggestedList
            .where((item) => item['type'] == AppConstants.typeComplaint)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        newSuggestions = suggestedList
            .where((item) => item['type'] == AppConstants.typeSuggestion)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        // ✅ Handle both old format (strings) and new format (objects)
        originalComplaints = complaintList.map((e) {
          if (e is String) {
            // Convert old format to new format
            return {
              'text': e,
              'amount': 0,
              'type': AppConstants.typeComplaint,
            };
          } else if (e is Map) {
            return Map<String, dynamic>.from(e);
          }
          return <String, dynamic>{};
        }).where((item) => item.isNotEmpty).toList();
      }

      List<Map<String, dynamic>> approvedItems = approvedList
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      bool hasApproval = approvedItems.isNotEmpty;

      _approvedItemMaterials.clear();
      _materialControllers.clear();
      _itemMaterials.clear();

      // Initialize materials for approved items or suggested items
      List<Map<String, dynamic>> itemsWithMaterials = hasApproval ? approvedItems : [...originalComplaints, ...newSuggestions];
      for (var item in itemsWithMaterials) {
        final itemText = item['text'] as String;
        List<String> existingMaterials = [];
        if (item['materials'] != null && item['materials'] is List) {
          existingMaterials = List<String>.from(
              item['materials'].map((e) => e.toString()));
        }
        _approvedItemMaterials[itemText] = existingMaterials;
        _materialControllers[itemText] = TextEditingController();
      }

      // Populate per-item materials map used in pending / awaiting states
      for (var entry in originalComplaints.asMap().entries) {
        final index = entry.key;
        final complaint = entry.value;
        final key = 'complaint_$index';
        List<String> existingMaterials = [];
        if (complaint['materials'] != null && complaint['materials'] is List) {
          existingMaterials = List<String>.from(
              complaint['materials'].map((e) => e.toString()));
        }
        _itemMaterials[key] = existingMaterials;
      }

      for (var entry in newSuggestions.asMap().entries) {
        final index = entry.key;
        final suggestion = entry.value;
        final key = 'suggestion_$index';
        List<String> existingMaterials = [];
        if (suggestion['materials'] != null && suggestion['materials'] is List) {
          existingMaterials = List<String>.from(
              suggestion['materials'].map((e) => e.toString()));
        }
        _itemMaterials[key] = existingMaterials;
      }

      _complaintControllers.clear();
      for (var complaint in originalComplaints) {
        final controller = TextEditingController(
            text: (complaint['amount'] ?? 0).toString());
        _complaintControllers[complaint['text']] = controller;
      }

      // ✅ Store booking data for reference
      final bookingData = response['bookings'];

      if (mounted) {
        setState(() {
          _currentReportId = reportId;
          _currentStartedAt = response['started_at'];
          _currentCompletedAt = response['completed_at'];
          _currentJobCardId = response['job_card_id'];
          _currentVehicleNo = response['vehicles']['Vehicle Number'];
          
          final techList = _safeJsonDecodeList(response['technician_assignments']);
          _currentTechnicianAssignments = List<Map<String, dynamic>>.from(techList);
          
          var rawUrls = response['photo_urls'];
          if (rawUrls != null) {
            if (rawUrls is String) {
              try { _jobMediaUrls = List<String>.from(jsonDecode(rawUrls)); } catch (_) { _jobMediaUrls = []; }
            } else if (rawUrls is List) {
              _jobMediaUrls = List<String>.from(rawUrls.map((e) => e.toString()));
            }
          } else {
            _jobMediaUrls = [];
          }

          var afterUrls = response['after_photo_urls'];
          if (afterUrls != null) {
            if (afterUrls is String) {
              try { _afterJobMediaUrls = List<String>.from(jsonDecode(afterUrls)); } catch (_) { _afterJobMediaUrls = []; }
            } else if (afterUrls is List) {
              _afterJobMediaUrls = List<String>.from(afterUrls.map((e) => e.toString()));
            }
          } else {
            _afterJobMediaUrls = [];
          }
          
          _scannedBarcodeText = response['barcode'] as String?;
          _scannedBarcodeImageUrl = null;
          
          if (_jobMediaUrls.isNotEmpty) {
            final barcodeImgIndex = _jobMediaUrls.indexWhere((url) => url.contains('_barcode_'));
            if (barcodeImgIndex != -1) {
              _scannedBarcodeImageUrl = _jobMediaUrls[barcodeImgIndex];
              _jobMediaUrls.removeAt(barcodeImgIndex);
            }
          }
          
          _newAfterJobMediaPaths = []; // Reset newly captured paths

          _currentBookingData = bookingData; // ✅ Store for later use
          _currentStatus = status; // ✅ Capture current status
          _washRequired = true; // Reset toggle
          _originalComplaints = originalComplaints;
          _newSuggestions = newSuggestions;
          _approvedItems = approvedItems;
          // ✅ FIX: Always use fresh database value to avoid lag/caching issues
          _hasCustomerApproval = hasApproval;
          // ✅ Update the cached state with fresh value
          _reportApprovalStates[reportId] = hasApproval;
          _deliveryDateController.text = response['expected_delivery'] ?? '';
          _laborCostController.text = (response['labour_cost'] ?? 0.0).toString();
          // Rejection remarks removed
          _rejectionRemarks = null;
          _currentCustomerFeedbackAudio = response['customer_feedback_audio'] as String?;
          _currentCustomerFeedbackText = response['customer_feedback_text'] as String?;
          _isFeedbackAudioPlaying = false;
          _showUpdateForm = true;
        });
      }
    } catch (e) {
      _showError('Could not load job details: ${e.toString()}');
    }
  }

  void _addMaterial(String approvedItemText) {
    final controller = _materialControllers[approvedItemText];
    if (controller == null || controller.text.trim().isEmpty) return;

    setState(() {
      _approvedItemMaterials[approvedItemText]?.add(controller.text.trim());
      controller.clear();
    });
  }

  void _removeMaterial(String approvedItemText, int materialIndex) {
    setState(() {
      _approvedItemMaterials[approvedItemText]?.removeAt(materialIndex);
    });
  }

  void _addSuggestion() {
    final text = _suggestionTextController.text.trim();

    // ✅ USE VALIDATOR
    final amountError = Validators.validateAmount(_suggestionAmountController.text.trim());
    if (amountError != null) {
      _showError(amountError);
      return;
    }

    final amount = double.parse(_suggestionAmountController.text.trim());

    if (text.isNotEmpty && amount > 0) {
      setState(() {
        _newSuggestions.add({
          'text': text,
          'amount': amount,
          'type': AppConstants.typeSuggestion
        });
        _suggestionTextController.clear();
        _suggestionAmountController.clear();
      });
    }
  }


  double _calculateTotal() {
    double laborCost = double.tryParse(_laborCostController.text) ?? 0.0;
    
    if (_hasCustomerApproval) {
      double itemsTotal = _approvedItems.fold(0.0, (sum, item) =>
      sum + (item['amount'] as num? ?? 0.0).toDouble());
      return itemsTotal + laborCost;
    } else {
      double total = 0.0;
      for (var complaint in _originalComplaints) {
        total += double.tryParse(_complaintControllers[complaint['text']]?.text ?? '0') ?? 0;
      }
      for (var suggestion in _newSuggestions) {
        total += (suggestion['amount'] as num? ?? 0.0).toDouble();
      }
      return total + laborCost;
    }
  }

  Future<void> _promptAfterJobPhotos() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Complete Job', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Please capture after-job photos to confirm completion.'),
                  const SizedBox(height: 16),
                  if (_newAfterJobMediaPaths.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _newAfterJobMediaPaths.map((path) => Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: kIsWeb 
                                ? Image.network(path, width: 80, height: 80, fit: BoxFit.cover)
                                : Image.file(File(path), width: 80, height: 80, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: -8,
                            right: -8,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () {
                                setDialogState(() {
                                  _newAfterJobMediaPaths.remove(path);
                                });
                              },
                            ),
                          )
                        ],
                      )).toList(),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ContinuousCameraScreen(),
                          ),
                        );
                        if (result != null && result is List<String> && result.isNotEmpty) {
                          setDialogState(() {
                            _newAfterJobMediaPaths.addAll(result);
                          });
                        }
                      },
                      icon: const Icon(Icons.add_a_photo, color: AppTheme.primaryColor),
                      label: const Text('Add Photos (Camera)', style: TextStyle(color: AppTheme.primaryColor)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Proceed to save update
                    _saveUpdate();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                  child: const Text('Confirm Completion'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _saveUpdate() async {
    // ✅ Check local state
    if (_currentReportId == null || _isSubmitting) return;

    // ✅ Determine target tab for navigation
    final int targetTabIndex = 0; // Default to Pending Jobs



    // Prepare data early for validation
    final updatedComplaints = _originalComplaints.map((c) => {
      'text': c['text'],
      'amount': double.tryParse(_complaintControllers[c['text']]?.text ?? '0') ?? 0,
      'type': AppConstants.typeComplaint
    }).toList();

    Map<String, dynamic> updateData = {
      
    };

    // Always save everything we have
    final updatedApprovedItemsWithMaterials = _approvedItems.map((item) {
      final itemText = item['text'] as String;
      return {...item, 'materials': _approvedItemMaterials[itemText] ?? []};
    }).toList();
    
    final updatedSuggestedItems = [...updatedComplaints, ..._newSuggestions].map((item) {
      final itemText = item['text'] as String;
      return {...item, 'materials': _approvedItemMaterials[itemText] ?? []};
    }).toList();
    
    // Save all fields
    updateData['approved'] = jsonEncode(updatedApprovedItemsWithMaterials);
    updateData['complaint'] = jsonEncode(updatedComplaints);
    updateData['suggested'] = jsonEncode(updatedSuggestedItems);
    updateData['labour_cost'] = double.tryParse(_laborCostController.text) ?? 0.0;

    // Handle status transition based on tab
    if (_openedFromTab == 'Work in Progress') {
      updateData['status'] = AppConstants.statusCompleted;
      updateData['completed_at'] = DateTime.now().toIso8601String();
    } else {
      // It's from 'Jobs' tab (Pending), so it should just save as 'Work in Progress' if they updated something
      // or we can just leave it to whatever it currently is. 
      // The user requested: "when i select a job from jobs section and click save save it with latest updates and dont mark it as draft"
      // So we don't modify the status, we just let it save.
    }

    // ✅ Start submission loading
    setState(() => _isSubmitting = true);

    try {
      if (_openedFromTab == 'Work in Progress' && _newAfterJobMediaPaths.isNotEmpty) {
        List<String> uploadedAfterUrls = [];
        for (var path in _newAfterJobMediaPaths) {
          Uint8List bytes;
          if (kIsWeb) {
            try {
              final response = await http.get(Uri.parse(path));
              bytes = response.bodyBytes;
            } catch (e) {
              debugPrint('Failed to load blob image on web: $e');
              bytes = Uint8List(0);
            }
          } else {
            final file = File(path);
            bytes = await file.readAsBytes();
          }
          if (bytes.isNotEmpty) {
            final fileName = 'after_job_${_currentReportId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final url = await SupabaseService().uploadJobMedia(bytes, fileName);
            if (url != null) uploadedAfterUrls.add(url);
          }
        }
        if (uploadedAfterUrls.isNotEmpty) {
          updateData['after_photo_urls'] = uploadedAfterUrls; // Supabase handles list encoding
        }
      }
      
      if (_newBarcodeImageBytes != null && _barcodeController.text.isNotEmpty) {
        final fileName = 'job_${_currentReportId}_barcode_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final url = await SupabaseService().uploadJobMedia(_newBarcodeImageBytes!, fileName);
        if (url != null) {
          updateData['barcode'] = _barcodeController.text;
          _jobMediaUrls.add(url);
          updateData['photo_urls'] = _jobMediaUrls;
        }
      }

      await supabase.from('reports').update(updateData).eq('id', _currentReportId!);

      if (!context.mounted) return;
      _showSuccess(AppConstants.successUpdated);

      // Refresh data while form is still loading (awaiting ensures data consistency before navigation)
      if (!mounted) return;
      final user = Provider.of<UserProvider>(context, listen: false).user;
      if (user != null && mounted) {
        final userId = user['id'] as int;
        await Provider.of<ReportProvider>(context, listen: false).refresh(userId, isAdminMode: widget.isAdminMode);
      }

      if (!mounted) return;

      // Close form and switch tab
      _resetUpdateForm();
      _tabController.animateTo(targetTabIndex);

    } catch (e) {
      if (context.mounted) _showError('Failed to save update: $e');
    } finally {
      // Ensure loading stops if an error occurred (as _resetUpdateForm might not be called)
      if (mounted && _isSubmitting) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _sendApprovalLink() async {
    // ✅ Check local state
    if (_currentReportId == null || _isSubmitting) return;

    if (_deliveryDateController.text.isEmpty) {
      _showError('Please set a delivery date before sending.');
      return;
    }

    // ✅ Determine target tab for navigation
    const int targetTabIndex = 2; // Always Awaiting

    // Prepare data with materials
    final updatedComplaints = _originalComplaints.asMap().entries.map((entry) {
      final index = entry.key;
      final c = entry.value;
      final complaintKey = 'complaint_$index';
      return {
        'text': c['text'],
        'amount': double.tryParse(_complaintControllers[c['text']]?.text ?? '0') ?? 0,
        'type': AppConstants.typeComplaint,
        'materials': _itemMaterials[complaintKey] ?? []
      };
    }).toList();

    // Add materials to suggestions
    final suggestionsWithMaterials = _newSuggestions.asMap().entries.map((entry) {
      final index = entry.key;
      final suggestion = entry.value;
      final suggestionKey = 'suggestion_$index';
      return {
        ...suggestion,
        'materials': _itemMaterials[suggestionKey] ?? []
      };
    }).toList();

    final allItems = [...updatedComplaints, ...suggestionsWithMaterials];

    // Workflow Validation
    if (allItems.isEmpty) {
      _showError('Please add at least one repair item.');
      return;
    }

    // ✅ Start submission loading
    setState(() => _isSubmitting = true);

    try {
      // 1. Save updates including labour cost
      final laborCost = double.tryParse(_laborCostController.text) ?? 0.0;
      await supabase.from('reports').update({
        'complaint': jsonEncode(updatedComplaints),
        'suggested': jsonEncode(allItems),
        'status': AppConstants.statusOngoing,
        // Removed started_at from here; it now starts when "Start Work" is clicked
        
        'labour_cost': laborCost,
      }).eq('id', _currentReportId!);

      // 2. Get client phone
      final reportData = await supabase
          .from('reports')
          .select('client_phone')
          .eq('id', _currentReportId!)
          .single();

      final clientPhone = reportData['client_phone'];

      // Validate phone number
      final phoneError = Validators.validatePhoneNumber(clientPhone);
      if (phoneError != null) {
        _showError('Client phone number is missing or invalid.');
        // Loading stops in finally block
        return;
      }

      // 3. Construct WhatsApp URL with simple message format
      final approvalUrl = '${AppConstants.approvalBaseUrl}$_currentReportId';
      
      // Build simple, clean message
      final message = 'Dear Customer,\n\n'
          'Please review and approve the suggested repairs for your vehicle:\n'
          '$approvalUrl\n\n'
          'Thank you,\n'
          'AutoFix Service';

      final success = await _openWhatsApp(clientPhone, message);
      if (success) {
        if (!context.mounted) return;
        _showSuccess('Opening WhatsApp...');

        // Refresh data while form is still loading (awaiting ensures data consistency)
        if (!mounted) return;
        final user = Provider.of<UserProvider>(context, listen: false).user;
        if (user != null && mounted) {
          final userId = user['id'] as int;
          await Provider.of<ReportProvider>(context, listen: false).refresh(userId, isAdminMode: widget.isAdminMode);
        }

        if (!mounted) return;

        // Close form and switch tab
        _resetUpdateForm();
        _tabController.animateTo(targetTabIndex);
      } else {
        if (context.mounted) {
          _showError('Could not open WhatsApp. Please ensure it is installed and try again.');
        }
      }
    } catch (e) {
      debugPrint('❌ WhatsApp error: $e');
      if (context.mounted) {
        _showError('Failed to send approval link: $e');
      }
    } finally {
       // Ensure loading stops if an error occurred or launch failed
      if (mounted && _isSubmitting) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _bypassApprovalAndStartJob() async {
    if (_currentReportId == null || _isSubmitting) return;

    if (_deliveryDateController.text.isEmpty) {
      _showError('Please set a delivery date before bypassing.');
      return;
    }

    const int targetTabIndex = 2; // Always Awaiting

    final updatedComplaints = _originalComplaints.asMap().entries.map((entry) {
      final index = entry.key;
      final c = entry.value;
      final complaintKey = 'complaint_$index';
      return {
        'text': c['text'],
        'amount': double.tryParse(_complaintControllers[c['text']]?.text ?? '0') ?? 0,
        'type': AppConstants.typeComplaint,
        'materials': _itemMaterials[complaintKey] ?? []
      };
    }).toList();

    final suggestionsWithMaterials = _newSuggestions.asMap().entries.map((entry) {
      final index = entry.key;
      final suggestion = entry.value;
      final suggestionKey = 'suggestion_$index';
      return {
        ...suggestion,
        'materials': _itemMaterials[suggestionKey] ?? []
      };
    }).toList();

    final allItems = [...updatedComplaints, ...suggestionsWithMaterials];

    if (allItems.isEmpty) {
      _showError('Please add at least one repair item.');
      return;
    }

    // Auto-approve all items
    final approvedItems = allItems.map((item) {
      return {
        ...item,
        'status': 'Approved',
      };
    }).toList();

    setState(() => _isSubmitting = true);

    try {
      final laborCost = double.tryParse(_laborCostController.text) ?? 0.0;
      await supabase.from('reports').update({
        'complaint': jsonEncode(updatedComplaints),
        'suggested': jsonEncode(allItems),
        'approved': jsonEncode(approvedItems),
        'status': AppConstants.statusOngoing,
        
        'labour_cost': laborCost,
        'customer_feedback_text': 'Bypassed Approval',
      }).eq('id', _currentReportId!);

      if (!context.mounted) return;
      _showSuccess('Job successfully bypassed to Response Received.');

      final user = Provider.of<UserProvider>(context, listen: false).user;
      if (user != null && mounted) {
        final userId = user['id'] as int;
        await Provider.of<ReportProvider>(context, listen: false).refresh(userId, isAdminMode: widget.isAdminMode);
      }

      if (!mounted) return;
      _resetUpdateForm();
      _tabController.animateTo(targetTabIndex);
    } catch (e) {
      if (context.mounted) _showError('Failed to bypass approval: $e');
    } finally {
      if (mounted && _isSubmitting) {
        setState(() => _isSubmitting = false);
      }
    }
  }


  void _openCancelModal(int reportId, String vehicleNo) {
    // Prevent action if submitting
    if (_isSubmitting) return;
    
    final confirmationController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isValid = confirmationController.text.trim().toLowerCase() == 'cancel';
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 8,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Modern gradient header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red.shade400, Colors.red.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.warning_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Cancel Job',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.shade200,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.red.shade700,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Vehicle: $vehicleNo',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'This action cannot be undone. The job will be permanently cancelled.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Type "cancel" to confirm',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: confirmationController,
                            decoration: InputDecoration(
                              hintText: 'Type cancel here...',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            onChanged: (value) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                    // Actions
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                confirmationController.dispose();
                                Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'Go Back',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: isValid
                                    ? LinearGradient(
                                        colors: [Colors.red.shade400, Colors.red.shade600],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: isValid ? null : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: isValid
                                    ? [
                                        BoxShadow(
                                          color: Colors.red.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: ElevatedButton(
                                onPressed: isValid
                                    ? () {
                                        Navigator.pop(context);
                                        _executeCancellation(reportId, vehicleNo);
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  disabledForegroundColor: Colors.grey.shade500,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel Job',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _executeCancellation(int reportId, String vehicleNo) async {
    try {
      await supabase
          .from('reports')
          .update({'status': AppConstants.statusCancelled})
          .eq('id', reportId);

      if (mounted) _showSuccess('Job for $vehicleNo has been cancelled.');

      if (!mounted) return;
      final user = Provider.of<UserProvider>(context, listen: false).user;
      if (user != null && mounted) {
        final userId = user['id'] as int; // ✅ Extract as int
        await Provider.of<ReportProvider>(context, listen: false).refresh(userId, isAdminMode: widget.isAdminMode);
      }
    } catch (e) {
      _showError('Failed to cancel job: ${e.toString()}');
    }
  }

  void _resetUpdateForm() {
    _disposeAllControllers();

    setState(() {
      _showUpdateForm = false;
      _isSubmitting = false; // ✅ Reset local submission state
      _currentReportId = null;
      _currentJobCardId = null;
      _currentVehicleNo = null;
      _currentBookingData = null;
      _currentStatus = '';
      _washRequired = true;
      _originalComplaints.clear();
      _newSuggestions.clear();
      _approvedItems.clear();
      _hasCustomerApproval = false;
      _deliveryDateController.clear();
      _suggestionTextController.clear();
      _suggestionAmountController.clear();
      _laborCostController.clear(); // ✅ Clear labor cost controller
      _approvedItemMaterials.clear();
      _rejectionRemarks = null;
      _currentCustomerFeedbackAudio = null;
      _currentCustomerFeedbackText = null;
      _isFeedbackAudioPlaying = false;
      // ✅ DON'T clear persistent state here - only clear when actually closing
      // _reportApprovalStates.clear();
    });
  }

  
  // ✅ NEW: Complete form reset with state clearing (for actual form closure)
  void _resetUpdateFormComplete() {
    _disposeAllControllers();
    setState(() {
      _showUpdateForm = false;
      _isSubmitting = false; // ✅ Reset local submission state
      _currentReportId = null;
      _currentJobCardId = null;
      _currentVehicleNo = null;
      _currentBookingData = null;
      _currentStatus = '';
      _washRequired = true;
      _originalComplaints.clear();
      _newSuggestions.clear();
      _approvedItems.clear();
      _hasCustomerApproval = false;
      _deliveryDateController.clear();
      _suggestionTextController.clear();
      _suggestionAmountController.clear();
      _approvedItemMaterials.clear();
      _rejectionRemarks = null;
      _currentCustomerFeedbackAudio = null;
      _currentCustomerFeedbackText = null;
      _isFeedbackAudioPlaying = false;
      // ✅ Clear persistent state when actually closing form
      _reportApprovalStates.clear();
    });
  }

  Future<void> _scanBarcode() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CustomScannerScreen(),
        ),
      );
      if (result != null && result is Map) {
        final String? barcodeScanRes = result['barcode'];
        final Uint8List? imageBytes = result['image'];
        
        if (barcodeScanRes != null && barcodeScanRes != '-1' && barcodeScanRes.isNotEmpty) {
          setState(() {
            _barcodeController.text = barcodeScanRes;
            if (imageBytes != null) {
              _newBarcodeImageBytes = imageBytes;
            }
          });
        }
      }
    } catch (e) {
      _showError('Failed to get barcode: $e');
    }
  }

  Future<void> _shareWarrantyPDF() async {
    final barcodeJson = _scannedBarcodeText ?? _barcodeController.text;
    if (barcodeJson.isEmpty || barcodeJson == '{}') {
      _showError('No warranty QR codes recorded.');
      return;
    }

    Map<String, dynamic> barcodeData = {};
    try {
      barcodeData = jsonDecode(barcodeJson) as Map<String, dynamic>;
    } catch (e) {
      _showError('Could not parse warranty data. Make sure they are JSON.');
      return;
    }

    final String jobIdStr = (_currentJobCardId?.isNotEmpty == true) 
        ? _currentJobCardId! 
        : _currentReportId?.toString() ?? 'N/A';
    final vehicleNo = _currentVehicleNo ?? 'N/A';
    
    final reportProvider = Provider.of<ReportProvider>(context, listen: false);
    final report = reportProvider.reports.firstWhere((r) => r['id'] == _currentReportId, orElse: () => <String, dynamic>{});
    final clientName = report['Owner name'] ?? 'N/A';
    final clientPhone = report['client_phone'] ?? 'N/A';
    final vehicleBrand = report['vehicles']?['vehicle_models']?['brand'] ?? 'N/A';
    final vehicleModel = report['vehicles']?['vehicle_models']?['Model name'] ?? 'N/A';

    try {
      final pdf = pw.Document();

      for (final entry in barcodeData.entries) {
        final position = entry.key;
        final details = entry.value as Map<String, dynamic>;
        final hasImage = details['has_image'] == 'true';
        final spec = details['spec']?.toString() ?? '';

        Uint8List? imageBytes;
        if (hasImage && _jobMediaUrls.isNotEmpty) {
          final safePosition = position.replaceAll(" ", "_");
          final urlStr = _jobMediaUrls.firstWhere(
            (url) => url.contains('_tyreqr_$safePosition'), 
            orElse: () => ''
          );
          if (urlStr.isNotEmpty) {
            try {
              final response = await http.get(Uri.parse(urlStr));
              imageBytes = response.bodyBytes;
            } catch (e) {
              debugPrint('Failed to download image for PDF: $e');
            }
          }
        }

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Header(
                    level: 0,
                    child: pw.Text('Tyre Warranty Details - $position', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text('Job Card: $jobIdStr', style: const pw.TextStyle(fontSize: 16)),
                  pw.Text('Vehicle: $vehicleNo', style: const pw.TextStyle(fontSize: 16)),
                  pw.Text('Model: $vehicleBrand $vehicleModel', style: const pw.TextStyle(fontSize: 16)),
                  pw.Text('Client: $clientName ($clientPhone)', style: const pw.TextStyle(fontSize: 16)),
                  pw.SizedBox(height: 20),
                  if (spec.isNotEmpty) pw.Text('Spec: $spec', style: const pw.TextStyle(fontSize: 16)),
                  pw.SizedBox(height: 10),
                  if (imageBytes != null)
                    pw.Expanded(
                      child: pw.Center(
                        child: pw.Image(
                          pw.MemoryImage(imageBytes),
                          fit: pw.BoxFit.contain,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      }

      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/job_${jobIdStr}_warranty_qrs.pdf');
      await file.writeAsBytes(bytes);

      final String message = 'Warranty details for Job $jobIdStr (Vehicle: $vehicleNo)';
      await Share.shareXFiles(
        [XFile(file.path)],
        text: message,
        subject: 'Warranty details for Job $jobIdStr',
      );
    } catch (e) {
      _showError('Error generating or sharing PDF: $e');
    }
  }

  
  String _getBrandModel(Map<String, dynamic> job) {
    final brand = job['vehicles']?['vehicle_models']?['brand'] ?? '';
    final model = job['vehicles']?['vehicle_models']?['Model name'] ?? '';
    return '$brand $model'.trim();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showSuccess(String message) {
    // Commented out to reduce UI noise
    // if (!mounted) return;
    // ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    //   content: Text(message),
    //   backgroundColor: Colors.green,
    //   behavior: SnackBarBehavior.floating,
    //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg)),
    //   margin: const EdgeInsets.all(16),
    // ));
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<AdminSettingsProvider>();

    return Consumer<ReportProvider>(
      builder: (context, reportProvider, child) {

        // --- ✅ ADD DEBUG PRINT FOR SETTINGS CHECK (if needed later) ---
        // Access settingsProvider here if you also need to check it within the Consumer
        // final settingsProviderHere = context.watch<AdminSettingsProvider>();
        // if (kDebugMode) {
        //   debugPrint("--- Build Check ---");
        //   debugPrint("featureWhatsappApproval from Provider in build: ${settingsProviderHere.featureWhatsappApproval}");
        //   debugPrint("-------------------");
        // }
        // --- END DEBUG PRINT ---

        if (_showUpdateForm) {
          // ✅ We no longer need to pass reportProvider here for isLoading
          return _buildUpdateForm(settingsProvider);
        }

        final unassignedJobs = reportProvider.unassignedReports;
        final allReports = reportProvider.reports;
            final pendingJobs = allReports
        .where((r) => r['status'] == AppConstants.statusNotStarted || r['status'] == AppConstants.statusWorkInProgress)
        .toList();
            
        final workInProgressJobs = allReports
            .where((r) => r['status'] == AppConstants.statusWorkInProgress)
            .toList();
            
        final completedJobs = allReports
            .where((r) => r['status'] == AppConstants.statusCompleted)
            .toList();
            
        // Direct bookings tab removed per requirements

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            leading: widget.isAdminMode 
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null,
            title: const Text(
              'Job Cards',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 24,
                color: AppTheme.primaryColor,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
                onPressed: _refreshData,
                tooltip: 'Refresh Data',
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Consumer<AdminSettingsProvider>(
                  builder: (context, adminSettings, _) {
                    List<Widget> tabs = [];
                    
                    tabs.addAll([
                      _buildProfessionalTab('Jobs', pendingJobs.length),
                      _buildProfessionalTab('Work in Progress', workInProgressJobs.length),
                      _buildProfessionalTab('Completed', completedJobs.length),
                    ]);
                    
                    return TabBar(
                      controller: _tabController,
                      labelColor: AppTheme.primaryColor,
                      unselectedLabelColor: const Color(0xFF6B7280),
                      indicatorColor: AppTheme.primaryColor,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                      tabs: tabs,
                    );
                  },
                ),
              ),
              // Content (Expanded TabBarView)
              Expanded(
                child: (reportProvider.isLoading &&
                    allReports.isEmpty)
                    ? const ListShimmerLoading()
                    : RefreshIndicator( // ✅ Use the new method for pull-to-refresh
                  onRefresh: _refreshData,
                  child: Consumer<AdminSettingsProvider>(
                    builder: (context, adminSettings, _) {
                      List<Widget> tabViews = [];
                      tabViews.addAll([
                        _buildJobList(pendingJobs, 'No jobs are currently pending.', 'Jobs'),
                        _buildJobList(workInProgressJobs, 'No jobs currently in progress.', 'Work in Progress'),
                        _buildJobList(completedJobs, 'No completed jobs.', 'Completed'),
                      ]);
                      
                      return TabBarView(
                        controller: _tabController,
                        children: tabViews,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(String? start, String? end) {
    if (start == null) return '';
    final startTime = DateTime.tryParse(start);
    if (startTime == null) return '';

    final endTime = (end != null ? DateTime.tryParse(end) : null) ?? DateTime.now();
    final duration = endTime.difference(startTime);
    
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes} mins';
    } else {
      final hours = duration.inHours;
      final mins = duration.inMinutes % 60;
      return '${hours}h ${mins}m';
    }
  }

  Tab _buildProfessionalTab(String title, int count) {
    return Tab(
      height: 48,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '($count)',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildJobList(List<Map<String, dynamic>> jobs, String emptyMessage, String tabName) {
    if (jobs.isEmpty) {
      return EmptyDisplay(
        message: emptyMessage,
        icon: Icons.assignment_outlined,
        subtitle: 'Pull down to refresh',
      );
    }

    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: jobs.length,
        itemBuilder: (context, index) {
          final job = jobs[index];
          final vehicleNo = job['vehicles']?['Vehicle Number'] ?? 'N/A';
          final brandModel = _getBrandModel(job);
          final approvedList = _safeJsonDecodeList(job['approved']);
          final suggestedList = _safeJsonDecodeList(job['suggested']);
          final technicianAssignments = _safeJsonDecodeList(job['technician_assignments']);
          
          // Debug: Check if source fields are present
          if (kDebugMode) {
            print('Job ${job['id']}: booking_id=${job['booking_id']}, created_by_pudo_id=${job['created_by_pudo_id']}');
          }
          
          bool isOverdue = false;
          int overdueBy = 0;
          String overdueText = '';
          if (job['status'] == AppConstants.statusWorkInProgress && job['started_at'] != null) {
            final startTime = DateTime.tryParse(job['started_at']);
            if (startTime != null) {
              final adminSettings = Provider.of<AdminSettingsProvider>(context, listen: false);
              final int threshold = adminSettings.overdueMinutesThreshold;
              final minutesRunning = DateTime.now().difference(startTime).inMinutes;
              
              if (minutesRunning > threshold) {
                isOverdue = true;
                overdueBy = minutesRunning - threshold;
                
                if (overdueBy >= 60) {
                  final hrs = overdueBy ~/ 60;
                  final mins = overdueBy % 60;
                  overdueText = mins > 0 ? '$hrs hr $mins min' : '$hrs hr${hrs == 1 ? '' : 's'}';
                } else {
                  overdueText = '$overdueBy min';
                }
                
                final int jobId = job['id'];
                
              }
            }
          }

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _selectJob(job['id'], sourceTab: tabName),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isOverdue)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '⚠️ Overdue by $overdueText',
                                style: const TextStyle(
                                  color: Color(0xFFB91C1C),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDEEBFF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.directions_car_rounded,
                            color: AppTheme.primaryColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  Text(
                                    job['job_card_id'] ?? 'Job #${job['id']}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  if (approvedList.isNotEmpty)
                                    Text(
                                      '${approvedList.length} service${approvedList.length > 1 ? 's' : ''} approved',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF10B981),
                                      ),
                                    )
                                  else if (suggestedList.isNotEmpty && job['status'] == AppConstants.statusOngoing)
                                    const Text(
                                      'Approval Sent',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFF59E0B),
                                      ),
                                    )
                                  else if (suggestedList.isNotEmpty && job['status'] == AppConstants.statusNotStarted)
                                    const Text(
                                      'Draft Saved',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF6B7280), // Gray for draft
                                      ),
                                    ),

                                  // Add source label
                                  if (job['created_by_pudo_id'] != null || job['booking_id'] != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        job['booking_id'] != null ? 'From Booking' : 'Assigned by Telecaller',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF8B5CF6),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                brandModel.isNotEmpty ? brandModel : 'Vehicle',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (technicianAssignments.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                ...technicianAssignments.map((assignment) {
                                  final roleRaw = assignment['role']?.toString() ?? '';
                                  final role = roleRaw.replaceAll('_', ' ');
                                  final roleDisplay = role.isNotEmpty ? role[0].toUpperCase() + role.substring(1) : '';
                                  final techId = assignment['tech_id'];
                                  final techName = techId != null ? _technicianNames[techId] ?? 'Unknown Tech' : 'Unassigned';
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.handyman, size: 14, color: AppTheme.primaryColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$roleDisplay: ',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                        Text(
                                          techName,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                              if (job['started_at'] != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.timer_outlined, size: 14, color: AppTheme.primaryColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      job['completed_at'] != null 
                                          ? 'Completed in ${_formatDuration(job['started_at'], job['completed_at'])}'
                                          : 'Ongoing for ${_formatDuration(job['started_at'], null)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (job['status'] != AppConstants.statusCompleted)
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              color: AppTheme.textSecondary,
                              size: 24,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                            onSelected: (value) {
                              if (value == 'cancel') {
                                HapticUtils.medium();
                                _openCancelModal(job['id'], vehicleNo);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem<String>(
                                value: 'cancel',
                                child: Row(
                                  children: const [
                                    Icon(
                                      Icons.cancel_outlined,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Cancel Job',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Spacer(),
                        const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSavedJobList(List<Map<String, dynamic>> jobs, String emptyMessage) {
    if (jobs.isEmpty) {
      return EmptyDisplay(
        message: emptyMessage,
        icon: Icons.task_alt_outlined,
        subtitle: 'Jobs saved after customer approval will appear here',
      );
    }

    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: jobs.length,
        itemBuilder: (context, index) {
          final job = jobs[index];
          final vehicleNo = job['vehicles']?['Vehicle Number'] ?? 'N/A';
          final brandModel = _getBrandModel(job);
          final approvedList = _safeJsonDecodeList(job['approved']);
          final hasVoice = job['customer_feedback_audio'] != null &&
              job['customer_feedback_audio'].toString().isNotEmpty;
          final hasText = job['customer_feedback_text'] != null &&
              job['customer_feedback_text'].toString().isNotEmpty;
          final ownerName = job['Owner name'] ?? '';

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFE5E7EB), width: 1),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _selectJob(job['id'], sourceTab: 'Saved'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.task_alt_rounded,
                                color: Color(0xFF10B981),
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        vehicleNo,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (approvedList.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981)
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${approvedList.length} approved',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF10B981),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  if (brandModel.isNotEmpty)
                                    Text(
                                      brandModel,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF6B7280),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  if (ownerName.isNotEmpty)
                                    Text(
                                      ownerName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  if (job['started_at'] != null) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.timer_outlined, size: 14, color: AppTheme.primaryColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          job['completed_at'] != null 
                                              ? 'Completed in ${_formatDuration(job['started_at'], job['completed_at'])}'
                                              : 'Ongoing for ${_formatDuration(job['started_at'], null)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      if (hasVoice)
                                        Container(
                                          margin:
                                              const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981)
                                                .withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: const Color(0xFF10B981)
                                                    .withValues(alpha: 0.3)),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.mic,
                                                  size: 12,
                                                  color: Color(0xFF10B981)),
                                              SizedBox(width: 4),
                                              Text('Voice',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: Color(0xFF10B981),
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                      if (hasText && !hasVoice)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981)
                                                .withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: const Color(0xFF10B981)
                                                    .withValues(alpha: 0.3)),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.comment_rounded,
                                                  size: 12,
                                                  color: Color(0xFF10B981)),
                                              SizedBox(width: 4),
                                              Text('Response',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: Color(0xFF10B981),
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: Color(0xFF9CA3AF)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDirectBookingsList(List<Map<String, dynamic>> bookings, String emptyMessage) {
    if (bookings.isEmpty) {
      return EmptyDisplay(
        message: emptyMessage,
        icon: Icons.event_note_outlined,
        subtitle: 'Direct bookings assigned by telecaller will appear here',
      );
    }

    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];
          final customerName = booking['customer_name'] ?? 'N/A';
          final bookingId = 'Booking #${booking['id'] ?? 'N/A'}';
          final brandModel = 'Walk-in Booking'; // Default description

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _createJobCardFromBooking(booking),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDEEBFF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.event_note_rounded,
                                    color: AppTheme.primaryColor,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          Text(
                                            bookingId,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: const Text(
                                              'Direct Booking',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF10B981),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        brandModel.isNotEmpty ? brandModel : 'Vehicle',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF6B7280),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Customer: $customerName',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _createJobCardFromBooking(Map<String, dynamic> booking) async {
    // Navigate to job card creation screen with booking data
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => JobCardScreen(
          bookingId: booking['id'],
          customerName: booking['customer_name'],
          customerPhone: booking['customer_phone'],
        ),
      ),
    );

    // If job card was created successfully, refresh the data
    if (result == true && mounted) {
      _refreshData();
    }
  }

  Widget _buildUnassignedJobList(List<Map<String, dynamic>> jobs) {
    if (jobs.isEmpty) {
      return const EmptyDisplay(
        message: 'No unassigned jobs available.',
        icon: Icons.assignment_outlined,
        subtitle: 'Pull down to refresh',
      );
    }

    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: jobs.length,
        itemBuilder: (context, index) {
          final job = jobs[index];
          final vehicle = job['vehicles'];
          final model = vehicle?['vehicle_models'];
          final vehicleNo = vehicle?['Vehicle Number'] ?? 'N/A';
          final brandModel =
          '${model?['brand'] ?? ''} ${model?['Model name'] ?? ''}'.trim();

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDEEBFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.directions_car_rounded,
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
                            vehicleNo,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            brandModel.isNotEmpty ? brandModel : 'Vehicle',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.person_add_rounded, size: 16),
                      label: const Text(
                        'Claim',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                      HapticUtils.light();
                      final user = Provider.of<UserProvider>(context,
                          listen: false)
                          .user;
                      if (user == null) return;

                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Confirm Claim'),
                          content: Text(
                              'Are you sure you want to take up the job for vehicle $vehicleNo?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel')),
                            ElevatedButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Confirm')),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        try {
                          if (!context.mounted) return;
                          LoadingDialog.show(context, message: 'Claiming job...');
                          final userId = user['id'] as int;
                          await Provider.of<ReportProvider>(context, listen: false)
                              .claimJob(job['id'], userId);
                          if (context.mounted) LoadingDialog.hide(context);

                          // ✅ ADD: Switch to Pending tab and show success
                          if (context.mounted) {
                            _tabController.animateTo(1); // Switch to Pending tab
                            // Commented out to reduce UI noise
                            // ScaffoldMessenger.of(context).showSnackBar(
                            //   const SnackBar(
                            //     content: Text('✓ Job claimed successfully! Moved to your Pending tab.'),
                            //     backgroundColor: Colors.green,
                            //     behavior: SnackBarBehavior.floating,
                            //   ),
                            // );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            LoadingDialog.hide(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Failed to claim job: $e'),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 2)),
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUpdateForm(AdminSettingsProvider settingsProvider) {
    final total = _calculateTotal();
    final showWhatsAppButton = !_hasCustomerApproval && settingsProvider.featureWhatsappApproval;
    // ✅ Use the local submission state
    final isFormBusy = _isSubmitting;
    final bool isEditable = _openedFromTab == 'Jobs';

    if (kDebugMode) {
      debugPrint('--- _buildUpdateForm Visibility Check ---');
      debugPrint('Local _isSubmitting state: $_isSubmitting');
      debugPrint('Current Report ID: $_currentReportId');
      debugPrint('_hasCustomerApproval value: $_hasCustomerApproval');
      debugPrint('Persistent state for this report: ${_reportApprovalStates[_currentReportId]}');
      debugPrint('All persistent states: $_reportApprovalStates');
      debugPrint('settingsProvider.featureWhatsappApproval value: ${settingsProvider.featureWhatsappApproval}');
      debugPrint('Calculated showWhatsAppButton: $showWhatsAppButton');
      debugPrint('Form visible: $_showUpdateForm');
      debugPrint('---------------------------------------');
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          _currentJobCardId ?? (_currentVehicleNo ?? 'Job Update'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryColor,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.primaryColor),
          onPressed: isFormBusy ? null : _resetUpdateFormComplete,
          tooltip: 'Close Form',
        ),
        actions: [
          if ((_scannedBarcodeText != null && _scannedBarcodeText!.isNotEmpty && _scannedBarcodeText!.startsWith('{')) || 
              (_barcodeController.text.isNotEmpty && _barcodeController.text.startsWith('{')))
            IconButton(
              icon: const Icon(Icons.share, color: AppTheme.primaryColor),
              onPressed: _shareWarrantyPDF,
              tooltip: 'Share QRs',
            ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: isFormBusy,
          child: ListView(
            padding: const EdgeInsets.all(0),
          children: [
          // Header Summary Card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 18,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.directions_car_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentJobCardId ?? 'Vehicle Number',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentVehicleNo ?? 'N/A',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${_originalComplaints.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Issues',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Technician Assignments Card
          if (_currentTechnicianAssignments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(top: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.engineering, color: Color(0xFFF59E0B), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Assigned Technicians',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._currentTechnicianAssignments.map((assignment) {
                      final roleRaw = assignment['role']?.toString() ?? '';
                      final role = roleRaw.replaceAll('_', ' ');
                      final roleDisplay = role.isNotEmpty ? role[0].toUpperCase() + role.substring(1) : '';
                      final techId = assignment['tech_id'];
                      final techName = techId != null ? _technicianNames[techId] ?? 'Unknown Tech' : 'Unassigned';
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.handyman, size: 16, color: AppTheme.primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              '$roleDisplay: ',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                techName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            
          const SizedBox(height: 16),

          // Booking Information Card
          if (_currentBookingData != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.person_outline,
                            color: Color(0xFF3B82F6),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Customer Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Name', _currentBookingData!['customer_name'] ?? 'N/A', Icons.person),
                    _buildInfoRow('Phone', _currentBookingData!['customer_phone'] ?? 'N/A', Icons.phone),
                    if (_currentBookingData!['pickup_address'] != null)
                      _buildInfoRow('Address', _currentBookingData!['pickup_address'], Icons.location_on),
                    if (_currentBookingData!['scheduled_time'] != null)
                      _buildInfoRow(
                        'Scheduled',
                        DateFormat('dd MMM yyyy, hh:mm a').format(
                            DateTime.parse(_currentBookingData!['scheduled_time'])
                        ),
                        Icons.schedule,
                      ),
                  ],
                ),
              ),
            ),
          
          if (_currentBookingData != null) const SizedBox(height: 16),
          
          if (_currentStartedAt != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.timer_outlined,
                            color: Color(0xFFF59E0B),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Time Tracking',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      'Started At',
                      DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(_currentStartedAt!).toLocal()),
                      Icons.play_circle_outline,
                    ),
                    if (_currentCompletedAt != null)
                      _buildInfoRow(
                        'Completed At',
                        DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(_currentCompletedAt!).toLocal()),
                        Icons.stop_circle_outlined,
                      ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Duration:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          if (_currentStartedAt != null)
                            LiveTimer(
                              startTime: DateTime.tryParse(_currentStartedAt!) ?? DateTime.now(),
                              endTime: _currentCompletedAt != null ? DateTime.tryParse(_currentCompletedAt!) : null,
                            )
                          else
                            const Text('-'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_currentStartedAt != null) const SizedBox(height: 16),


          // Customer Approved Services Section
          if (_hasCustomerApproval)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(Icons.check, color: Colors.white, size: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Approved Services',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Customer has approved the following services. Add materials needed for each service.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ..._buildResponseSummaryList(),
                    // ✅ Add Labor Cost Field
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

          // Client Voice Response Card
          if (_currentCustomerFeedbackAudio != null && _currentCustomerFeedbackAudio!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.mic, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Client Voice Response',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF065F46),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_currentCustomerFeedbackText != null && _currentCustomerFeedbackText!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        _currentCustomerFeedbackText!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF374151),
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _toggleFeedbackAudio,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: _isFeedbackAudioPlaying ? const Color(0xFF065F46) : const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isFeedbackAudioPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isFeedbackAudioPlaying ? 'Pause Voice Message' : 'Play Voice Message',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Step 1: Customer Complaints Section
          if (!_hasCustomerApproval) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              '1',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Customer Complaints',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Enter the estimated cost for each reported issue',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._originalComplaints.asMap().entries.map((entry) {
                      final index = entry.key;
                      final complaint = entry.value;
                      final complaintKey = 'complaint_$index';

                      // Initialize materials list if not exists
                      _itemMaterials[complaintKey] ??= [];
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    complaint['text'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 100,
                                  child: TextField(
                                    controller: _complaintControllers[complaint['text']],
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.right,
                                    readOnly: !isEditable,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                    decoration: InputDecoration(
                                      prefixText: '₹ ',
                                      hintText: '0',
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.white,
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
                                        borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    onChanged: (value) {
                                      if (value.isNotEmpty) {
                                        final amountError = Validators.validateAmount(value, minAmount: 0);
                                        if (amountError != null && value != '0') {
                                          // Validation feedback
                                        }
                                      }
                                      setState(() {});
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // Materials Section
                            Row(
                              children: [
                                const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF6B7280)),
                                const SizedBox(width: 6),
                                const Text(
                                  'Materials',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            // Materials List
                            if (_itemMaterials[complaintKey]!.isNotEmpty) ...[
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _itemMaterials[complaintKey]!.asMap().entries.map((matEntry) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          matEntry.value,
                                          style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(width: 4),
                                        if (isEditable)
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _itemMaterials[complaintKey]!.removeAt(matEntry.key);
                                              });
                                            },
                                            child: const Icon(Icons.close, size: 14, color: Color(0xFF6B7280)),
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 8),
                            ],
                            
                            // Add Material Input with Searchable Dropdown
                            if (isEditable)
                              MaterialSearchDropdown(
                                hintText: 'Search and select material',
                                onMaterialSelected: (materialName) {
                                  setState(() {
                                    _itemMaterials[complaintKey]!.add(materialName);
                                  });
                                },
                              ),
                          ],
                        ),
                      );
                    }),
                    // ✅ Add Labor Cost Field
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Step 2: Additional Suggestions Section – only show when editable OR has saved suggestions
            if (isEditable || _newSuggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              '2',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Additional Suggestions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Add any additional repairs or services you recommend',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isEditable)
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _suggestionTextController,
                            decoration: InputDecoration(
                              hintText: 'e.g., Change engine oil',
                              prefixIcon: const Icon(Icons.build_circle_outlined, size: 20),
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _suggestionAmountController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              hintText: 'Cost',
                              prefixText: '₹ ',
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: _addSuggestion,
                            icon: const Icon(Icons.add, color: Colors.white),
                            tooltip: 'Add Suggestion',
                          ),
                        ),
                      ],
                    ),
                    if (_newSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ..._newSuggestions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final suggestion = entry.value;
                        final suggestionText = suggestion['text'];
                        final itemKey = 'suggestion_$index';
                        
                        // Initialize materials list if not exists
                        _itemMaterials[itemKey] ??= [];
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      suggestionText,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '₹${suggestion['amount']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isEditable)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _newSuggestions.removeAt(index);
                                          _itemMaterials.remove(itemKey);
                                        });
                                      },
                                      child: const Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              // Materials Section
                              Row(
                                children: [
                                  const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF6B7280)),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Materials',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              // Materials List
                              if (_itemMaterials[itemKey]!.isNotEmpty) ...[
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _itemMaterials[itemKey]!.asMap().entries.map((matEntry) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            matEntry.value,
                                            style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(width: 4),
                                          if (isEditable)
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _itemMaterials[itemKey]!.removeAt(matEntry.key);
                                                });
                                              },
                                              child: const Icon(Icons.close, size: 14, color: Color(0xFF6B7280)),
                                            ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 8),
                              ],
                              
                              // Add Material Input with Searchable Dropdown
                              if (isEditable)
                                MaterialSearchDropdown(
                                  hintText: 'Search and select material',
                                  onMaterialSelected: (materialName) {
                                    setState(() {
                                      _itemMaterials[itemKey]!.add(materialName);
                                    });
                                  },
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Labour Cost Card (Above Summary)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED), // Light orange/amber background
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFED7AA), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFED7AA),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.engineering_outlined,
                          color: Color(0xFFEA580C),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Labour Charges',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9A3412),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isEditable)
                    TextField(
                      controller: _laborCostController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Color(0xFF9A3412),
                      ),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        prefixStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Color(0xFF9A3412),
                        ),
                        hintText: '0',
                        hintStyle: const TextStyle(color: Color(0xFFC2410C)),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFFED7AA)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFFED7AA)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFEA580C), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: (value) {
                        setState(() {});
                      },
                    )
                  else
                    Text(
                      '₹${_laborCostController.text.isEmpty ? '0' : _laborCostController.text}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: Color(0xFF9A3412),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Step 3: Summary & Delivery Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _hasCustomerApproval ? const Color(0xFF10B981) : AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            _hasCustomerApproval ? '✓' : '3',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Total Amount Display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryColor.withValues(alpha: 0.1), AppTheme.primaryColor.withValues(alpha: 0.05)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primaryColor, size: 24),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Approximate service amount',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '₹${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 24,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  

                  // Captured Media and Barcode
                  if (true) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Captured Details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Barcode Section
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8.0),
                            child: Text('Scanned Barcode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                          if ((_scannedBarcodeText != null && _scannedBarcodeText!.isNotEmpty) || _scannedBarcodeImageUrl != null) ...[
                            if (_scannedBarcodeText != null && _scannedBarcodeText!.isNotEmpty)
                              _buildBarcodeContent(_scannedBarcodeText!),
                            if (_scannedBarcodeImageUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: GestureDetector(
                                  onTap: () => showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      insetPadding: const EdgeInsets.all(8),
                                      child: Stack(
                                        children: [
                                          Image.network(
                                            _scannedBarcodeImageUrl!,
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                                          ),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: IconButton(
                                              icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                              onPressed: () => Navigator.pop(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      _scannedBarcodeImageUrl!,
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: 120,
                                        height: 120,
                                        color: Colors.grey[200],
                                        child: const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            const Divider(),
                            const SizedBox(height: 8),
                          ] else if (_barcodeController.text.isNotEmpty) ...[
                            _buildBarcodeContent(_barcodeController.text),
                            if (_newBarcodeImageBytes != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    _newBarcodeImageBytes!,
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            const Divider(),
                            const SizedBox(height: 8),
                          ] else if (isEditable) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: InkWell(
                                onTap: _scanBarcode,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.qr_code_scanner, color: AppTheme.primaryColor),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Scan Missing Barcode',
                                        style: TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const Divider(),
                            const SizedBox(height: 8),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Reminder: Barcode not uploaded',
                                      style: TextStyle(
                                        color: Colors.orange.shade800,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          // Before Images
                          if (_jobMediaUrls.isNotEmpty) ...[
                            Builder(
                              builder: (context) {
                                final qrUrls = _jobMediaUrls.where((url) => url.contains('_tyreqr_')).toList();
                                final otherUrls = _jobMediaUrls.where((url) => !url.contains('_tyreqr_')).toList();
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (qrUrls.isNotEmpty) ...[
                                      const Padding(
                                        padding: EdgeInsets.only(bottom: 8.0),
                                        child: Text('Scanned Tyre QRs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      ),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: qrUrls.map((url) => _buildImageThumbnail(url)).toList(),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    if (otherUrls.isNotEmpty) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0),
                                        child: Text(_openedFromTab == 'Completed' && _afterJobMediaUrls.isNotEmpty ? 'Before Job Pictures' : 'Vehicle & Wheel Photos', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      ),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: otherUrls.map((url) => _buildImageThumbnail(url)).toList(),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    // After Images
                                    if (_afterJobMediaUrls.isNotEmpty) ...[
                                      const Padding(
                                        padding: EdgeInsets.only(bottom: 8.0),
                                        child: Text('After Job Pictures', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      ),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _afterJobMediaUrls.map((url) => _buildImageThumbnail(url)).toList(),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                  ],
                                );
                              }
                            )
                          ],
                        ],
                      ),
                    ),
                  ],
          
          const SizedBox(height: 24),
          
          // Action Buttons
          if (_openedFromTab != 'Completed')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Action Button (Dynamic)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isFormBusy ? null : (_openedFromTab == 'Work in Progress' ? _promptAfterJobPhotos : _saveUpdate),
                      icon: isFormBusy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 20),
                      label: Text(
                        _openedFromTab == 'Work in Progress' ? 'Complete Job' : 'Save Updates',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _openedFromTab == 'Work in Progress' ? const Color(0xFF10B981) : AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          if (_openedFromTab != 'Completed')
            const SizedBox(height: 24),
        ],
      ),
    ),
  ),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _toggleFeedbackAudio() async {
    final audioUrl = _currentCustomerFeedbackAudio;
    if (audioUrl == null || audioUrl.isEmpty) return;
    try {
      if (_isFeedbackAudioPlaying) {
        await _feedbackAudioPlayer.pause();
        if (mounted) setState(() => _isFeedbackAudioPlaying = false);
      } else {
        await _feedbackAudioPlayer.play(UrlSource(audioUrl));
        if (mounted) setState(() => _isFeedbackAudioPlaying = true);
        _feedbackAudioPlayer.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _isFeedbackAudioPlaying = false);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isFeedbackAudioPlaying = false);
      _showError('Could not play audio: $e');
    }
  }

  List<Widget> _buildResponseSummaryList() {
    return _approvedItems.map((item) {
      final itemText = item['text'] as String;
      final materials = _approvedItemMaterials[itemText] ?? [];

      return Padding( // Add padding around each item section
        padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Use ListTile for better structure and alignment
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                itemText,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), // Slightly larger font
              ),
              trailing: Text(
                '₹${(item['amount'] as num? ?? 0.0).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16, // Larger amount
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm), // Smaller gap
            // Material Input Row
            // Row(
            //   children: [
            //     // Expanded(
            //     //   child: TextField(
            //     //     controller: _materialControllers[itemText],
            //     //     decoration: InputDecoration(
            //     //       hintText: 'Add material needed (e.g., Oil Filter)',
            //     //       isDense: true,
            //     //       contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Adjust padding
            //     //     ),
            //     //     onSubmitted: (_) => _addMaterial(itemText),
            //     //   ),
            //     // ),
            //     IconButton(
            //       icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor),
            //       onPressed: () => _addMaterial(itemText),
            //       tooltip: 'Add Material', // Add tooltip
            //     ),
            //   ],
            // ),
            // Material Chips using Wrap
            if (materials.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingMd),
              Wrap( // Use Wrap for better layout if many items
                spacing: AppTheme.spacingSm,
                runSpacing: AppTheme.spacingXs,
                children: materials.asMap().entries.map((entry) {
                  return Chip(
                    label: Text(
                      entry.value,
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 14), // Smaller icon
                    deleteIconColor: AppTheme.primaryColor.withValues(alpha: 0.9),
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                    shape: StadiumBorder(
                      side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                    ),
                    onDeleted: () => _removeMaterial(itemText, entry.key),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduce tap area
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // Adjust padding
                  );
                }).toList(),
              ),
            ],
            const Divider(height: AppTheme.spacingLg), // Use theme spacing
          ],
        ),
      );
    }).toList();
  }

  // Helper method for info rows with icon
  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeContent(String barcodeContent) {
    bool isJson = false;
    Map<String, dynamic> barcodeData = {};
    
    try {
      barcodeData = jsonDecode(barcodeContent) as Map<String, dynamic>;
      isJson = barcodeData.isNotEmpty;
    } catch (_) {
      isJson = false;
    }

    if (isJson) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Wrap(
          spacing: 16.0,
          runSpacing: 20.0,
          children: barcodeData.entries.map((entry) {
            final position = entry.key;
            final details = entry.value as Map<String, dynamic>;
            final qr = details['qr']?.toString() ?? '';
            final spec = details['spec']?.toString() ?? '';

            return SizedBox(
              width: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    position.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (spec.isNotEmpty)
                    Text(
                      spec,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (qr.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                        color: Colors.white,
                      ),
                      child: QrImageView(
                        data: qr,
                        version: QrVersions.auto,
                        size: 130.0,
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            const Icon(Icons.qr_code, size: 20, color: Colors.blueGrey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                barcodeContent,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildImageThumbnail(String url) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 120,
            height: 120,
            color: Colors.grey[200],
            child: const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
          ),
        ),
      ),
    );
  }
}

class LiveTimer extends StatefulWidget {
  final DateTime startTime;
  final DateTime? endTime;
  final TextStyle? style;
  final String prefix;

  const LiveTimer({
    Key? key,
    required this.startTime,
    this.endTime,
    this.style,
    this.prefix = '',
  }) : super(key: key);

  @override
  _LiveTimerState createState() => _LiveTimerState();
}

class _LiveTimerState extends State<LiveTimer> {
  late Timer _timer;
  
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (widget.endTime == null && mounted) {
        setState(() {});
      }
    });
  }
  
  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final endTime = widget.endTime ?? DateTime.now();
    final duration = endTime.difference(widget.startTime);
    
    String formatted;
    if (duration.inHours > 0) {
      formatted = '${duration.inHours}h ${duration.inMinutes % 60}m ${duration.inSeconds % 60}s';
    } else {
      formatted = '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    }
    
    return Text(
      '${widget.prefix}$formatted',
      style: widget.style ?? const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFFF59E0B),      ),
    );
  }
}
