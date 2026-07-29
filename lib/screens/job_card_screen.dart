// lib/screens/job_card_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../screens/custom_scanner_screen.dart';
import '../screens/multi_wheel_camera_screen.dart';
import '../screens/number_plate_scanner_screen.dart';
import '../screens/odometer_camera_screen.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../utils/app_constants.dart';
import '../utils/validators.dart';
import '../utils/vehicle_number_utils.dart';
import '../widgets/error_display.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
// Existing imports
import '../services/ocr_service.dart';
import '../services/supabase_service.dart';
import '../services/local_media_service.dart';
import '../services/vehicle_service.dart';
import '../services/company_service.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import '../providers/report_provider.dart';
import '../providers/admin_settings_provider.dart';
import '../widgets/brand_model_search_dropdown.dart';

class JobCardScreen extends StatefulWidget {
  final int? bookingId;
  final String? customerName;
  final String? customerPhone;
  
  const JobCardScreen({
    super.key,
    this.bookingId,
    this.customerName,
    this.customerPhone,
  });

  @override
  State<JobCardScreen> createState() => _JobCardScreenState();
}

class _JobCardScreenState extends State<JobCardScreen> {
  // Controllers
  final _vehicleNumberController = TextEditingController();
  final _newVehicleNameController = TextEditingController();
  final _newColorController = TextEditingController();
  final _newOdometerController = TextEditingController();
  final _newClientNameController = TextEditingController();
  final _newClientPhoneController = TextEditingController();
  final _newClientMobileController = TextEditingController();
  final _odometerController = TextEditingController();
  final _complaintInputController = TextEditingController();
  final FocusNode _complaintFocusNode = FocusNode();

  // Owner Master Field
  final _ownerGstController = TextEditingController();

  // Supabase
  final supabase = Supabase.instance.client;
  final vehicleService = VehicleService();


  // State Management
  bool _isLoading = false;
  String? _searchError;
  Map<String, dynamic>? _vehicleDetails;
  bool _showCreateVehicleForm = false;
  int? _currentVehicleId;
  int? _lastKnownOdometer;

  // ✅ Add flags to track if details differ
  bool _clientNameDiffers = false;
  bool _clientPhoneDiffers = false;

  // State variables for owner details
  Map<String, dynamic>? _ownerDetails;

  // ✅ NEW: Validation error states
  String? _vehicleNumberError;
  String? _phoneError;
  String? _odometerError;

  // Dropdown State
  List<Map<String, dynamic>> _vehicleModelsCache = [];
  List<String> _uniqueBrands = [];
  String? _selectedBrand;
  int? _selectedModelId;
  String? _selectedModelName;

  // Job Card Data
  final List<Map<String, dynamic>> _complaints = [];
  final List<Offset> _damageMarks = [];
  
  // Media & Barcode
  final Map<String, XFile> _wheelPhotos = {};
  XFile? _vehiclePhoto;
  XFile? _odometerPhoto;
  
  // Tyre Warranty Details
  final Map<String, TextEditingController> _tyreQRControllers = {};
  final Map<String, TextEditingController> _tyreSpecControllers = {};
  final Map<String, Uint8List> _tyreQRImages = {};
  
  final List<String> _requiredWheels = [
    'Front Left',
    'Front Right',
    'Rear Left',
    'Rear Right',
    'Stepney'
  ];
  final GlobalKey _imageKey = GlobalKey();

  // Media
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _audioPath;
  bool _isRecording = false;

  List<Map<String, dynamic>> _allTechnicians = [];
  List<Map<String, dynamic>> _technicianAssignments = [];
  List<Map<String, dynamic>> _serviceCatalog = [];

  @override
  void initState() {
    super.initState();
    _fetchVehicleModels();
    _fetchTechnicians();
    _fetchServiceCatalog();
    _fetchTyreCatalog();
    
    // Initialize tyre controllers
    for (String wheel in _requiredWheels) {
      _tyreQRControllers[wheel] = TextEditingController();
      _tyreSpecControllers[wheel] = TextEditingController();
    }

    // Prefill customer details if available (from bookings)
    if (widget.customerName != null) {
      _newClientNameController.text = widget.customerName!;
    }
    if (widget.customerPhone != null) {
      _newClientPhoneController.text = widget.customerPhone!;
    }
  }

  Future<void> _fetchTechnicians() async {
    try {
      final supabaseService = SupabaseService();
      final techs = await supabaseService.getAllTechnicians();
      if (mounted) {
        setState(() {
          _allTechnicians = techs;
        });
      }
    } catch (e) {
      debugPrint('Failed to load technicians: $e');
    }
  }

  Future<void> _fetchServiceCatalog() async {
    try {
      final supabaseService = SupabaseService();
      final catalog = await supabaseService.getServiceCatalog();
      if (mounted) {
        setState(() {
          _serviceCatalog = catalog;
        });
      }
    } catch (e) {
      debugPrint('Error fetching service catalog: $e');
    }
  }

  List<Map<String, dynamic>> _tyreCatalog = [];

  Future<void> _fetchTyreCatalog() async {
    try {
      final supabaseService = SupabaseService();
      final catalog = await supabaseService.getTyreCatalog();
      if (mounted) {
        setState(() {
          _tyreCatalog = catalog;
        });
      }
    } catch (e) {
      debugPrint('Error fetching tyre catalog: $e');
    }
  }

  @override
  void dispose() {
    _complaintFocusNode.dispose();
    _vehicleNumberController.dispose();
    _newVehicleNameController.dispose();
    _newColorController.dispose();
    _newOdometerController.dispose();
    _newClientNameController.dispose();
    _newClientPhoneController.dispose();
    _newClientMobileController.dispose();
    _odometerController.dispose();
    _complaintInputController.dispose();
    _ownerGstController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    
    for (var controller in _tyreQRControllers.values) {
      controller.dispose();
    }
    for (var controller in _tyreSpecControllers.values) {
      controller.dispose();
    }
    
    super.dispose();
  }

  // --- GOOGLE DRIVE REMOVED ---

  // --- DATA FETCHING & LOGIC ---

  void _resetScreen() {
    setState(() {
      _vehicleNumberController.clear();
      _vehicleDetails = null;
      _showCreateVehicleForm = false;
      _complaints.clear();
      _currentVehicleId = null;
      _searchError = null;
      _newVehicleNameController.clear();
      _newColorController.clear();
      _newOdometerController.clear();
      _newClientNameController.clear();
      _newClientPhoneController.clear();
      _newClientMobileController.clear();
      _odometerController.clear();
      _complaintInputController.clear();
      _selectedBrand = null;
      _selectedModelId = null;
      _selectedModelName = null;
      _wheelPhotos.clear();
      _vehiclePhoto = null;
      for (String wheel in _requiredWheels) {
        _tyreQRControllers[wheel]?.clear();
        _tyreSpecControllers[wheel]?.clear();
      }
      _tyreQRImages.clear();
      _audioPath = null;
      _isRecording = false;
      _damageMarks.clear();
      _clientNameDiffers = false;
      _clientPhoneDiffers = false;
      _ownerDetails = null;
      _ownerGstController.clear();

      // ✅ Clear validation errors
      _vehicleNumberError = null;
      _phoneError = null;
      _odometerError = null;
    });
  }

  Future<void> _fetchVehicleModels() async {
    try {
      final response =
          await supabase.from('vehicle_models').select('id, brand, "Model name"');
      if (mounted) {
        setState(() {
          _vehicleModelsCache = List<Map<String, dynamic>>.from(response);
          _uniqueBrands = _vehicleModelsCache
              .map<String>((e) => e['brand'] as String)
              .toSet()
              .toList()
            ..sort();
        });
      }
    } catch (e) {
      _showErrorSnackBar(AppConstants.errorUnknown); // ✅ Use constant
    }
  }

  Future<void> _searchVehicle() async {
    final rawVehicleNumber = _vehicleNumberController.text.trim();
    final normalizedVehicleNumber = VehicleNumberUtils.normalize(rawVehicleNumber);

    if (normalizedVehicleNumber.isNotEmpty &&
        _vehicleNumberController.text.trim() != normalizedVehicleNumber) {
      _vehicleNumberController.text = normalizedVehicleNumber;
      _vehicleNumberController.selection = TextSelection.fromPosition(
        TextPosition(offset: _vehicleNumberController.text.length),
      );
    }

    // ✅ Validate vehicle number
    final validationError = Validators.validateVehicleNumber(normalizedVehicleNumber);
    if (validationError != null) {
      setState(() => _vehicleNumberError = validationError);
      return;
    }

    setState(() {
      _isLoading = true;
      _searchError = null;
      _vehicleNumberError = null;
      _vehicleDetails = null;
      _showCreateVehicleForm = false;
    });

    try {
      // ✅ Use the updated service method
      final response = await SupabaseService().searchVehicle(normalizedVehicleNumber);

      if (response == null) {
        setState(() {
          _vehicleDetails = null;
          _showCreateVehicleForm = true; // Vehicle not found, show create form
          // Clear potential diff flags
          _clientNameDiffers = false;
          _clientPhoneDiffers = false;
          _ownerDetails = null;
        });
      } else {
        // ✅ Use the new keys from the service response
        final latestOdometer = response['latest_odometer'];
        final latestClientName = response['latest_client_name'];
        final latestClientPhone = response['latest_client_phone'];
        final ownerDetails = response['owner_details'];

        // Debug prints
        if (kDebugMode) {
          print('🔍 Vehicle found: ${response['Vehicle Number']}');
          print('👤 Owner details: $ownerDetails');
          print('📱 Latest client phone: $latestClientPhone');
        }

        setState(() {
          _vehicleDetails = response;
          _currentVehicleId = response['id'];
          _lastKnownOdometer = latestOdometer;
          _ownerDetails = ownerDetails;

          // Populate controllers with the LATEST info
          _newClientNameController.text = ownerDetails?['Owner name'] ?? latestClientName ?? '';
          _newClientPhoneController.text = ownerDetails?['PhoneNumber'] ?? latestClientPhone ?? ''; // Client Phone -> PhoneNumber
          _newClientMobileController.text = ownerDetails?['MobileNumber'] ?? ''; // Client Mobile -> MobileNumber
          _odometerController.text = latestOdometer?.toString() ?? '0';

          // Debug prints after population
          if (kDebugMode) {
            print('📝 Client name populated: ${_newClientNameController.text}');
            print('📞 Client phone populated: ${_newClientPhoneController.text}');
            print('📱 Client mobile populated: ${_newClientMobileController.text}');
          }

          _ownerGstController.text = ownerDetails?['GST Number'] ?? '';

          // ✅ Compare latest details with original vehicle record details
          _clientNameDiffers = (latestClientName != null &&
              latestClientName != response['MobileNumber']);
          _clientPhoneDiffers = (latestClientPhone != null &&
              latestClientPhone != response['MobileNumber']);
          _showCreateVehicleForm = false; // Vehicle found
        });
      }
    } catch (error) {
      setState(() {
        _vehicleDetails = null;
        _showCreateVehicleForm = true; // Assume error means not found
        _clientNameDiffers = false;
        _clientPhoneDiffers = false;
        _searchError = 'Error searching vehicle.'; // Provide generic error
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createVehicle() async {
    final adminSettings = Provider.of<AdminSettingsProvider>(context, listen: false);
    
    // ✅ Validate all required fields
    final phoneError =
        Validators.validatePhoneNumber(_newClientPhoneController.text);
    final odometerError =
        Validators.validateOdometer(_newOdometerController.text);

    if (_newClientNameController.text.isEmpty ||
        phoneError != null ||
        odometerError != null ||
        _selectedBrand == null ||
        _selectedModelId == null) {
      setState(() {
        _phoneError = phoneError;
        _odometerError = odometerError;
      });

      _showErrorSnackBar(AppConstants.errorInvalidInput); // ✅ Use constant
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get the model name from the selected model
      final selectedModel = _vehicleModelsCache.firstWhere(
        (model) => model['id'] == _selectedModelId,
        orElse: () => {},
      );
      final modelName = selectedModel['Model name'] as String?;

      // First, save owner details to owner_master table
      final ownerData = {
        'Owner name': _newClientNameController.text.trim(),
        'PhoneNumber': _newClientPhoneController.text.trim(), // Client Phone -> PhoneNumber
        'MobileNumber': _newClientMobileController.text.trim().isEmpty ? null : _newClientMobileController.text.trim(), // Client Mobile -> MobileNumber
        'GST Number': _ownerGstController.text.trim(),
      };
      
      final ownerId = await vehicleService.createOrUpdateOwner(context, ownerData);

      // Then save vehicle details with owner reference
      final vehicleData = {
        'Vehicle Number': VehicleNumberUtils.normalize(_vehicleNumberController.text.trim()),
        'vehicle_name': adminSettings.showFullVehicleForm ? _newVehicleNameController.text.trim() : null,
        'model_id': _selectedModelId,
        'Model name': modelName,
        'odometer': int.tryParse(_newOdometerController.text.trim()) ?? 0,
        'Owner name': _newClientNameController.text.trim(),
        'MobileNumber': _newClientMobileController.text.trim().isEmpty ? _newClientPhoneController.text.trim() : _newClientMobileController.text.trim(), // Use mobile if available, otherwise phone
        'owner_id': ownerId, // Link to owner_master table
      };
      
      await vehicleService.createOrUpdateVehicle(context, vehicleData);

      _showSuccessSnackBar(AppConstants.successSaved); // ✅ Use constant
      await _searchVehicle();
    } catch (error) {
      _showErrorSnackBar('Failed to create vehicle: ${error.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveJobCard() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (_complaints.isEmpty) {
      _showErrorSnackBar('Please add at least one complaint.');
      return;
    }

    if (!mounted) return;
    final user = userProvider.user;
    if (_currentVehicleId == null || user == null) {
      _showErrorSnackBar('No vehicle selected or user not logged in.');
      return;
    }

    final today = DateTime.now();
    final startOfDay =
        DateTime(today.year, today.month, today.day).toIso8601String();
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59)
        .toIso8601String();

    try {
      final existingReports = await supabase
          .from('reports')
          .select('id, executive:executive_id(username)')
          .eq('vehicle_id', _currentVehicleId!)
          .gte('created_at', startOfDay)
          .lte('created_at', endOfDay);

      if (!mounted) return;
      if (existingReports.isNotEmpty) {
        final executiveName = existingReports.first['executive']?['username'] ??
            'another executive';
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Duplicate Job Card Warning'),
            content: Text(
                'A job card for this vehicle was already created today by $executiveName. Are you sure you want to create another one?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm & Proceed'),
              ),
            ],
          ),
        );
        if (!mounted || confirmed != true) return;
      }

      await _executeSaveJobCard();
    } catch (e) {
      _showErrorSnackBar('Error checking for duplicates: $e');
    }
  }

  Future<void> _executeSaveJobCard() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) {
      _showErrorSnackBar('You are not logged in.');
      return;
    }

    // ✅ Modify Odometer validation and saving logic (2e)
    // Validate required wheel photos
    if (_wheelPhotos.length < 5) {
      final missingWheels = _requiredWheels.where((w) => !_wheelPhotos.containsKey(w)).join(', ');
      _showErrorSnackBar('Missing required wheel photos: $missingWheels');
      return;
    }

    // Validate odometer format, but NOT the value against _lastKnownOdometer here
    final odometerFormatError = Validators.validateOdometer(
        _odometerController.text); // Only checks format
    if (odometerFormatError != null) {
      _showErrorSnackBar(odometerFormatError);
      return;
    }

    final newOdometer =
        int.tryParse(_odometerController.text) ?? _lastKnownOdometer ?? 0;

    // REMOVE the blocking check:
    // if (newOdometer < (_lastKnownOdometer ?? 0)) {
    //   _showErrorSnackBar('Odometer reading cannot be lower than the last service.');
    //   return;
    // }
    setState(() => _isLoading = true);

    try {
      final marksJson =
          _damageMarks.map((p) => {'x': p.dx, 'y': p.dy}).toList();

      // ✅ FIX: Ensure executiveId is an integer or null
      final int? executiveId = (user['role'] == AppConstants.rolePickupDropoff)
          ? null
          : user['id']; // Directly use the integer ID

      // Only create a new owner record when no existing owner is loaded.
      // For existing vehicles, _ownerDetails is already set from the DB search,
      // so we skip insertion to avoid violating the owner_master unique constraint.
      if (_ownerDetails == null) {
        final ownerData = {
          'Owner name': _newClientNameController.text.trim(),
          'PhoneNumber': _newClientPhoneController.text.trim(),
          'MobileNumber': _newClientMobileController.text.trim().isEmpty ? null : _newClientMobileController.text.trim(),
          'GST Number': _ownerGstController.text.trim(),
        };
        await vehicleService.createOrUpdateOwner(context, ownerData);
      }

      // Ensure company is loaded (restore from prefs if needed)
      if (!CompanyService().hasActiveCompany) {
        await CompanyService().loadPersistedCompany();
      }
      final String? companyGuid = CompanyService().guid;
      final String? companyName = CompanyService().companyName;
      debugPrint('🔵 JobCard: Saving with Guid=$companyGuid, company=$companyName');
      if (companyGuid == null) {
        _showErrorSnackBar('No company selected. Please logout and select a company from the login screen.');
        setState(() => _isLoading = false);
        return;
      }

      // Collect tyre warranty details
      Map<String, Map<String, String>> tyreDetails = {};
      for (String wheel in _requiredWheels) {
        final qr = _tyreQRControllers[wheel]?.text.trim() ?? '';
        final spec = _tyreSpecControllers[wheel]?.text.trim() ?? '';
        if (qr.isNotEmpty || spec.isNotEmpty) {
          tyreDetails[wheel] = {};
          if (qr.isNotEmpty) tyreDetails[wheel]!['qr'] = qr;
          if (spec.isNotEmpty) tyreDetails[wheel]!['spec'] = spec;
        }
      }
      final String barcodeJson = tyreDetails.isNotEmpty ? jsonEncode(tyreDetails) : '';

      final Map<String, dynamic> insertData = {
        'vehicle_id': _currentVehicleId,
        'executive_id': executiveId, // Passes int?
        'complaint': jsonEncode(_complaints),
        if (barcodeJson.isNotEmpty) 'barcode': barcodeJson,
        'status': AppConstants.statusWorkInProgress, // Or should it be started? The timer just relies on started_at, but maybe it's fine.
        'started_at': DateTime.now().toIso8601String(), // Start the timer immediately upon creation
        'marks': jsonEncode(marksJson),
        'odometer_reading': newOdometer, // Save the entered value
        'Owner name': _newClientNameController.text.trim(),
        'client_phone': _newClientPhoneController.text.trim(),
        'technician_assignments': _technicianAssignments.isNotEmpty ? jsonEncode(_technicianAssignments) : null,
        'gdrive_folder_url': null,
        'photo_urls': null,
        'Guid': companyGuid,
        'company_name': companyName,
      };

      // Add booking_id if this job card is created from a direct booking
      if (widget.bookingId != null) {
        insertData['booking_id'] = widget.bookingId!;
      }

      // Insert report and return its ID (jobId)
      await vehicleService.createReport(context, insertData);
      
      // Get the inserted report ID by searching for the latest report for this vehicle
      final inserted = await supabase
          .from('reports')
          .select('id, job_card_id')
          .eq('vehicle_id', _currentVehicleId!)
          .order('created_at', ascending: false)
          .limit(1)
          .single();
      final int jobId = inserted['id'] as int;
      final String? jobCardId = inserted['job_card_id'] as String?;

      // Upload media to Supabase Storage
      List<String> uploadedUrls = [];
      
      for (final entry in _wheelPhotos.entries) {
        final position = entry.key;
        final photoXFile = entry.value;
        final fileName = 'job_${jobId}_wheel_${position.replaceAll(" ", "_")}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final bytes = await photoXFile.readAsBytes();
        final url = await SupabaseService().uploadJobMedia(bytes, fileName);
        if (url != null) uploadedUrls.add(url);
      }
      
      if (_vehiclePhoto != null) {
        final bytes = await _vehiclePhoto!.readAsBytes();
        final url = await SupabaseService().uploadJobMedia(bytes, 'job_${jobId}_vehicle_${DateTime.now().millisecondsSinceEpoch}.jpg');
        if (url != null) uploadedUrls.add(url);
      }
      
      for (final entry in _tyreQRImages.entries) {
        final position = entry.key;
        final imageBytes = entry.value;
        final url = await SupabaseService().uploadJobMedia(imageBytes, 'job_${jobId}_tyreqr_${position.replaceAll(" ", "_")}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        if (url != null) uploadedUrls.add(url);
      }

      if (_odometerPhoto != null) {
        final bytes = await _odometerPhoto!.readAsBytes();
        final url = await SupabaseService().uploadJobMedia(bytes, 'job_${jobId}_odometer_${DateTime.now().millisecondsSinceEpoch}.jpg');
        if (url != null) uploadedUrls.add(url);
      }
      
      // Update the reports table with the photo_urls
      if (uploadedUrls.isNotEmpty) {
        await supabase.from('reports').update({
          'photo_urls': uploadedUrls // Supabase handles list to JSON automatically
        }).eq('id', jobId);
      }

      // Audio
      if (_audioPath != null) {
        final fileName = 'voice_note_${DateTime.now().millisecondsSinceEpoch}.webm';
        final mimeType = 'audio/webm';
        Uint8List audioBytes;
        if (kIsWeb) {
          final response = await http.get(Uri.parse(_audioPath!));
          audioBytes = response.bodyBytes;
        } else {
          final audioFile = File(_audioPath!);
          audioBytes = await audioFile.readAsBytes();
        }
        final vehicleNo = (_vehicleDetails?['Vehicle Number'] as String?) ?? 'unknown';
        await LocalMediaService().saveMediaBytes(
          bytes: audioBytes,
          vehicleNo: vehicleNo,
          
          mediaType: 'audio',
          mimeType: mimeType,
          fileName: fileName,
          jobId: jobId,
        );
      }

      // Update booking status if this was created from a direct booking
      if (widget.bookingId != null) {
        await supabase.from('bookings').update({
          'status': 'Job Card Created',
        }).eq('id', widget.bookingId!);
      }

      _showSuccessSnackBar('Job card created successfully!${(_wheelPhotos.isNotEmpty || _audioPath != null) ? ' Media saved locally for this job.' : ''}');

      if (mounted) {
        // ✅ FIX: Pass the integer user ID to refresh
        await Provider.of<ReportProvider>(context, listen: false)
            .refresh(user['id']);
        
        // Show WhatsApp share dialog if tyre details exist
        if (tyreDetails.isNotEmpty) {
          final String displayJobId = jobCardId?.isNotEmpty == true ? jobCardId! : jobId.toString();
          await _showWhatsAppShareDialog(displayJobId, tyreDetails);
        }

        // If this was created from a direct booking, navigate back with success
        if (widget.bookingId != null) {
          Navigator.of(context).pop(true);
          return;
        }
      }
      _resetScreen();
    } catch (error) {
      _showErrorSnackBar('Failed to save Job Card. Error: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showWhatsAppShareDialog(String jobIdStr, Map<String, Map<String, String>> tyreDetails) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Share Warranty Details'),
        content: const Text('Would you like to share the tyre warranty details via WhatsApp to the data entry team?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Skip'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _shareToWhatsApp(jobIdStr, tyreDetails);
            },
            icon: const Icon(Icons.share),
            label: const Text('Share to WhatsApp'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareToWhatsApp(String jobIdStr, Map<String, Map<String, String>> tyreDetails) async {
    final vehicleNo = _vehicleDetails?['Vehicle Number'] ?? _vehicleNumberController.text.trim();
    final clientName = _newClientNameController.text.trim();
    final clientPhone = _newClientPhoneController.text.trim();
    final vehicleBrand = _vehicleDetails?['vehicle_models']?['brand'] ?? 'N/A';
    final vehicleModel = _vehicleDetails?['vehicle_models']?['Model name'] ?? 'N/A';

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text('Tyre Warranty Details', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Job Card: $jobIdStr', style: const pw.TextStyle(fontSize: 16)),
              pw.Text('Vehicle: $vehicleNo', style: const pw.TextStyle(fontSize: 16)),
              pw.Text('Model: $vehicleBrand $vehicleModel', style: const pw.TextStyle(fontSize: 16)),
              pw.Text('Client: $clientName ($clientPhone)', style: const pw.TextStyle(fontSize: 16)),
              pw.SizedBox(height: 20),
              pw.Wrap(
                spacing: 20,
                runSpacing: 20,
                children: tyreDetails.entries.map((entry) {
                  final position = entry.key;
                  final details = entry.value;
                  final qr = details['qr'] ?? '';
                  final spec = details['spec'] ?? '';

                  return pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(position, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 5),
                        if (spec.isNotEmpty) pw.Text('Spec: $spec', style: const pw.TextStyle(fontSize: 12)),
                        pw.SizedBox(height: 10),
                        if (qr.isNotEmpty)
                          pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: qr,
                            width: 120,
                            height: 120,
                          ),
                        if (qr.isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 8),
                            child: pw.Text(qr, style: const pw.TextStyle(fontSize: 8)),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      
      // Save PDF to temp directory
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/job_${jobIdStr}_warranty_qrs.pdf');
      await file.writeAsBytes(bytes);

      // Share PDF
      final String message = 'Warranty details for Job Card $jobIdStr (Vehicle: $vehicleNo)';
      await Share.shareXFiles(
        [XFile(file.path)],
        text: message,
        subject: 'Warranty details for Job Card $jobIdStr',
      );
    } catch (e) {
      _showErrorSnackBar('Error generating or sharing PDF: $e');
    }
  }

  // --- UI & MEDIA HELPERS ---

  void _addComplaint() {
    final complaintText = _complaintInputController.text.trim();

    // ✅ Validate complaint is not empty
    final error = Validators.validateRequired(complaintText);
    if (error != null) {
      _showErrorSnackBar(error);
      return;
    }

    // Lookup default price
    double price = 0;
    for (var service in _serviceCatalog) {
      if (service['name'].toString().toLowerCase() == complaintText.toLowerCase()) {
        if (service['default_price'] != null) {
          price = (service['default_price'] as num).toDouble();
        }
        break;
      }
    }

    setState(() {
      _complaints.add({
        'text': complaintText,
        'amount': price,
        'type': AppConstants.typeComplaint
      });
      _complaintInputController.clear();
    });
  }

  void _deleteComplaint(int index) {
    setState(() => _complaints.removeAt(index));
  }

  Future<void> _pickImage(ImageSource source) async {
    // We only use the custom in-app scanner for number plates now
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NumberPlateScannerScreen(),
      ),
    );

    if (result != null && result is Uint8List) {
      setState(() => _isLoading = true);
      try {
        final plateNumber = await OcrService.recognizeVehicleNumber(result);
        if (plateNumber != null) {
          _vehicleNumberController.text = plateNumber;
          await _searchVehicle();
        } else {
          _showErrorSnackBar(
              'Could not detect a valid number plate. Please try again.');
        }
      } catch (e) {
        _showErrorSnackBar('OCR failed: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _startRapidCapture() async {
    final List<String> missingWheels = _requiredWheels.where((w) => !_wheelPhotos.containsKey(w)).toList();
    
    if (missingWheels.isEmpty) {
      _showErrorSnackBar('All required photos are already taken!');
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiWheelCameraScreen(targets: missingWheels),
      ),
    );

    if (result != null && result is Map<String, XFile>) {
      setState(() {
        _wheelPhotos.addAll(result);
      });
    }
  }

  Future<void> _captureWheelPhoto(String position) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
                title: const Text('Take Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MultiWheelCameraScreen(targets: [position]),
                    ),
                  );

                  if (result != null && result is Map<String, XFile> && result.containsKey(position)) {
                    setState(() => _wheelPhotos[position] = result[position]!);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppTheme.primaryColor),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? pickedFile = await _picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 70,
                    maxWidth: 1280,
                  );
                  if (pickedFile != null) {
                    setState(() => _wheelPhotos[position] = pickedFile);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _removeWheelPhoto(String position) {
    setState(() => _wheelPhotos.remove(position));
  }

  Future<void> _captureVehiclePhoto() async {
    final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera, imageQuality: 60, maxWidth: 1280);
    if (pickedFile != null) {
      setState(() => _vehiclePhoto = pickedFile);
    }
  }
  
  void _removeVehiclePhoto() {
    setState(() => _vehiclePhoto = null);
  }

  Future<void> _captureOdometerPhoto() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
                title: const Text('Take Photo & Scan'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OdometerCameraScreen(),
                    ),
                  );

                  if (result != null && result is Map<String, dynamic>) {
                    setState(() {
                      if (result['photo'] != null) {
                        _odometerPhoto = result['photo'];
                      }
                      if (result['reading'] != null && result['reading'].toString().isNotEmpty) {
                        _odometerController.text = result['reading'];
                        _odometerError = Validators.validateOdometer(result['reading']);
                      }
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppTheme.primaryColor),
                title: const Text('Upload & Scan from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? pickedFile = await _picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 70,
                    maxWidth: 1280,
                  );
                  if (pickedFile != null) {
                    setState(() => _isLoading = true);
                    
                    try {
                      // Process image with Google ML Kit
                      final inputImage = InputImage.fromFilePath(pickedFile.path);
                      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
                      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
                      await textRecognizer.close();

                      // Extract best number
                      String cleanText = recognizedText.text.replaceAll(RegExp(r'[^\w\s\.,]'), ' ');
                      List<String> tokens = cleanText.split(RegExp(r'[\s\n]+'));
                      
                      String bestMatch = '';
                      int maxDigits = 0;

                      for (String token in tokens) {
                        String noCommas = token.replaceAll(',', '');
                        if (RegExp(r'^\d{3,7}$').hasMatch(noCommas)) {
                          if (noCommas.length >= maxDigits) {
                            maxDigits = noCommas.length;
                            bestMatch = noCommas;
                          }
                        }
                      }

                      if (bestMatch.isEmpty) {
                        final RegExp regExp = RegExp(r'\d+');
                        final Iterable<Match> matches = regExp.allMatches(recognizedText.text.replaceAll(',', ''));
                        for (final Match m in matches) {
                          String numStr = m.group(0) ?? '';
                          if (numStr.length >= maxDigits && numStr.length <= 7) {
                            maxDigits = numStr.length;
                            bestMatch = numStr;
                          }
                        }
                      }

                      setState(() {
                        _isLoading = false;
                        _odometerPhoto = pickedFile;
                        if (bestMatch.isNotEmpty) {
                          _odometerController.text = bestMatch;
                          _odometerError = Validators.validateOdometer(bestMatch);
                        }
                      });
                    } catch (e) {
                      setState(() => _isLoading = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to process image: $e')),
                        );
                      }
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildDynamicTechnicianAssignments() {
    List<Widget> widgets = [];
    for (int i = 0; i < _technicianAssignments.length; i++) {
      var assignment = _technicianAssignments[i];
      // Filter available techs for the selected role
      var availableTechs = _allTechnicians.where((t) => t['role'] == assignment['role']).toList();

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Role Dropdown
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Tech Type',
                    isDense: true,
                  ),
                  value: assignment['role'],
                  isExpanded: true, // Fixes RenderFlex overflow
                  items: AppConstants.techRoles.map((role) {
                    String displayRole = role.replaceAll('_', ' ');
                    displayRole = displayRole[0].toUpperCase() + displayRole.substring(1);
                    return DropdownMenuItem<String>(
                      value: role,
                      child: Text(displayRole, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      assignment['role'] = value;
                      assignment['tech_id'] = null; // Reset selected tech
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Tech Dropdown
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Technician',
                    isDense: true,
                  ),
                  value: assignment['tech_id'],
                  items: availableTechs.map((tech) {
                    return DropdownMenuItem<int>(
                      value: tech['id'] as int,
                      child: Text(tech['username'] ?? 'Unknown', style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      assignment['tech_id'] = value;
                    });
                  },
                  isExpanded: true,
                ),
              ),
              // Delete Button
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _technicianAssignments.removeAt(i);
                  });
                },
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  Future<void> _scanTyreQR(String wheel) async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CustomScannerScreen(),
        ),
      );
      if (result != null && result is Map) {
        final String? barcodeScanRes = result['barcode'];
        final Uint8List? imageBytes = result['image'];
        
        if (barcodeScanRes != null && barcodeScanRes != '-1' && barcodeScanRes.isNotEmpty) {
          setState(() {
            _tyreQRControllers[wheel]?.text = barcodeScanRes;
            if (imageBytes != null) {
              _tyreQRImages[wheel] = imageBytes;
            }
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to get QR for $wheel: $e');
    }
  }

  Widget _buildTyreWarrantyRow(String wheel) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            wheel,
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tyreQRControllers[wheel],
                  decoration: const InputDecoration(
                    hintText: 'Enter/Scan QR Code',
                    prefixIcon: Icon(Icons.qr_code, size: 18),
                    isDense: true,
                  ),
                  onChanged: (val) {
                    if (val.isEmpty) {
                      setState(() {
                        _tyreQRImages.remove(wheel);
                      });
                    }
                  }
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _scanTyreQR(wheel),
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: const Text('Scan'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  backgroundColor: Colors.blue.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RawAutocomplete<String>(
            textEditingController: _tyreSpecControllers[wheel],
            focusNode: FocusNode(),
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return _tyreCatalog.map((t) => '${t['brand']} ${t['model']} ${t['size']}');
              }
              return _tyreCatalog
                  .map((t) => '${t['brand']} ${t['model']} ${t['size']}')
                  .where((spec) => spec.toLowerCase().contains(textEditingValue.text.toLowerCase()));
            },
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  hintText: 'Select or type Tyre Specs',
                  prefixIcon: Icon(Icons.description, size: 18),
                  suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey),
                  isDense: true,
                ),
                onSubmitted: (_) => onFieldSubmitted(),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4.0,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final String option = options.elementAt(index);
                        return InkWell(
                          onTap: () => onSelected(option),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(option),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          if (_tyreQRControllers[wheel]?.text.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                color: Colors.white,
              ),
              child: QrImageView(
                data: _tyreQRControllers[wheel]!.text,
                version: QrVersions.auto,
                size: 100.0,
              ),
            ),
          ],
          const Divider(),
        ],
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      if (path != null) {
        setState(() {
          _isRecording = false;
          _audioPath = path;
        });
      }
    } else {
      if (await _audioRecorder.hasPermission()) {
        setState(() {
          _isRecording = true;
          _audioPath = null;
        });

        if (kIsWeb) {
          await _audioRecorder
              .start(const RecordConfig(encoder: AudioEncoder.opus), path: '');
        } else {
          final tempDir = await getTemporaryDirectory();
          final path =
              '${tempDir.path}/audiorecord_${DateTime.now().millisecondsSinceEpoch}.webm';
          await _audioRecorder.start(
              const RecordConfig(encoder: AudioEncoder.opus),
              path: path);
        }
      } else {
        _showErrorSnackBar('Microphone permission not granted.');
      }
    }
  }

  void _undoLastMark() {
    if (_damageMarks.isNotEmpty) setState(() => _damageMarks.removeLast());
  }

  void _clearDamageMarks() {
    setState(() => _damageMarks.clear());
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(milliseconds: 100),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    // Commented out to reduce UI noise
    // if (!mounted) return;
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text(message),
    //     backgroundColor: Colors.green,
    //     behavior: SnackBarBehavior.floating,
    //     shape: RoundedRectangleBorder(
    //         borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg)),
    //     margin: const EdgeInsets.all(16),
    //   ),
    // );
  }

  // --- WIDGET BUILDER METHODS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        leadingWidth: 150,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              CompanyService().companyName ?? '',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        title: const Text(
          'Job Card',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 24,
            color: AppTheme.primaryColor,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchCard(),

              // ✅ Use shimmer loading
              if (_isLoading &&
                  _vehicleDetails == null &&
                  !_showCreateVehicleForm)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: CircularProgressIndicator()),
                ),

              if (_vehicleDetails != null)
                _buildVehicleDetailsCard(_vehicleDetails!),
              if (_showCreateVehicleForm) _buildCreateVehicleForm(),
              if (_vehicleDetails != null) _buildNewComplaintCard(),
            ],
          ),
        ),
      ),
    );
  }

  // Google Drive status UI removed

  Widget _buildSearchCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FormLabel(text: 'Vehicle No:'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _vehicleNumberController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'enter vehicle number or scan',
                    errorText: _vehicleNumberError, // ✅ Show validation error
                    suffixIcon: _buildCameraIcon(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    // ✅ Validate on change
                    setState(() {
                      _vehicleNumberController.value = TextEditingValue(
                        text: value.toUpperCase(),
                        selection: _vehicleNumberController.selection,
                      );
                      _vehicleNumberError =
                          Validators.validateVehicleNumber(value);
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              _buildMinimalSearchButton(),
            ],
          ),
          if (_searchError != null && !_showCreateVehicleForm)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(_searchError!,
                  style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  // ✅ NEW: Camera icon inside search field (conditionally shown based on feature flag)
  Widget _buildCameraIcon() {
    return Consumer<AdminSettingsProvider>(
      builder: (context, settingsProvider, _) {
        // Hide camera icon if number plate scanner is disabled
        if (!settingsProvider.featureScanner) {
          return const SizedBox.shrink();
        }
        
        return GestureDetector(
          onTap: () => _pickImage(ImageSource.camera),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.camera_alt,
              color: Colors.grey[600],
              size: 20,
            ),
          ),
        );
      },
    );
  }

  // ✅ NEW: Minimal search button
  Widget _buildMinimalSearchButton() {
    return Tooltip(
      message: 'Search Vehicle',
      child: InkWell(
        onTap: _isLoading ? null : _searchVehicle,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.blue[600],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 20,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildVehicleDetailsCard(Map<String, dynamic> details) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              SizedBox(width: 8),
              Text(
                'Vehicle Found',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green),
              ),
            ],
          ),
          const Divider(height: 24),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _buildDetailItem(
                      'Vehicle Number', details['Vehicle Number'] ?? 'N/A')),
              Expanded(
                  child: _buildDetailItem(
                      'Vehicle Name', details['vehicle_name'] ?? 'N/A')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildDetailItem(
                      'Brand', details['vehicle_models']?['brand'] ?? 'N/A')),
              Expanded(
                  child: _buildDetailItem(
                      'Model', details['vehicle_models']?['Model name'] ?? 'N/A')),
            ],
          ),
          const Divider(height: 32),

          // ✅ Display Caution if details differ
          if (_clientNameDiffers || _clientPhoneDiffers)
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingSm),
              margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withAlpha((255 * 0.1).round()),
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusSm),
                border: Border.all(
                    color:
                        AppTheme.warningColor.withAlpha((255 * 0.5).round())),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.warningColor, size: 18),
                  const SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    child: Text(
                      'Client details differ from the vehicle\'s original record. Using latest info.',
                      style: TextStyle(
                          color: AppTheme.warningColor
                              .withAlpha((255 * 0.9).round()),
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          // --- END CAUTION ---

          const FormLabel(text: 'Client Name'),
          TextField(
            controller:
                _newClientNameController, // Already populated with latest
            decoration: const InputDecoration(hintText: 'Enter client name'),
          ),
          const SizedBox(height: 16),
          const FormLabel(text: 'Client Phone'),
          TextField(
            controller: _newClientPhoneController,
            decoration: InputDecoration(
              hintText:
                  'Enter 10-digit phone number', // Already populated with latest
              counterText: "",
              errorText: _phoneError, // Show validation error
            ),
            keyboardType: TextInputType.phone,
            maxLength: 10,
            onChanged: (value) {
              // Validate on change
              setState(() {
                _phoneError = Validators.validatePhoneNumber(value);
              });
            },
          ),
          const SizedBox(height: 16),
          const FormLabel(text: 'Client Mobile Number (Optional)'),
          TextField(
            controller: _newClientMobileController,
            decoration: const InputDecoration(
              hintText: 'Enter 10-digit mobile number',
              counterText: "",
            ),
            keyboardType: TextInputType.phone,
            maxLength: 10,
          ),
          const SizedBox(height: 16),
          const FormLabel(text: 'GST Number'),
          TextField(
            controller: _ownerGstController,
            decoration: const InputDecoration(
              hintText: 'e.g., 27AABCT1234H1Z0',
            ),
          ),
          const SizedBox(height: 16),

          const FormLabel(text: 'Odometer Reading'),
          TextField(
            controller: _odometerController, // Already populated with latest
            decoration: InputDecoration(
              hintText:
                  'Enter current kilometers', // ... (rest of odometer field, including potential warning)
              errorText: _odometerError, // Show validation error
              suffixIcon: IconButton(
                icon: Icon(
                  _odometerPhoto != null ? Icons.check_circle : Icons.document_scanner,
                  color: _odometerPhoto != null ? Colors.green : AppTheme.primaryColor,
                ),
                onPressed: _captureOdometerPhoto,
                tooltip: 'Scan Odometer',
              ),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              // Validate on change
              setState(() {
                _odometerError = Validators.validateOdometer(value);
              });
            },
          ),
          // Non-blocking warning if odometer entered is lower than last known
          if (_lastKnownOdometer != null &&
              int.tryParse(_odometerController.text) != null &&
              (int.tryParse(_odometerController.text)!) < _lastKnownOdometer!)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Entered reading is lower than last recorded ($_lastKnownOdometer km). Please verify.',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            
          if (_odometerPhoto != null)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_odometerPhoto!.path),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _odometerPhoto = null;
                      });
                    },
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    label: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCreateVehicleForm() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.add_circle, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'Register New Vehicle',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "Vehicle not found. Please add the details below.",
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          const Divider(height: 24),
          const FormLabel(text: 'Vehicle Number'),
          TextField(
            controller:
                TextEditingController(text: _vehicleNumberController.text),
            readOnly: true,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          Consumer<AdminSettingsProvider>(
            builder: (context, adminSettings, child) {
              if (!adminSettings.showFullVehicleForm) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FormLabel(text: 'Vehicle Name'),
                  TextField(
                    controller: _newVehicleNameController,
                    decoration: const InputDecoration(hintText: 'e.g., Swift VXI'),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
          BrandModelSearchDropdown(
            initialBrand: _selectedBrand,
            initialModelId: _selectedModelId,
            initialModelName: _selectedModelName,
            onSelectionChanged: (brand, modelId, modelName) {
              setState(() {
                _selectedBrand = brand;
                _selectedModelId = modelId;
                _selectedModelName = modelName;
              });
            },
          ),
          const SizedBox(height: 16),
          const FormLabel(text: 'Odometer Reading (km)'),
          TextField(
            controller: _newOdometerController,
            decoration: InputDecoration(
              hintText: 'e.g., 54000',
              errorText: _odometerError, // ✅ Show validation error
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              // ✅ Validate on change
              setState(() {
                _odometerError = Validators.validateOdometer(value);
              });
            },
          ),
          const Divider(height: 24),
          const FormLabel(text: 'Client Name', isRequired: true),
          TextField(
            controller: _newClientNameController,
            decoration: const InputDecoration(hintText: 'e.g., John Doe'),
          ),
          const SizedBox(height: 16),
          const FormLabel(text: 'Client Phone', isRequired: true),
          TextField(
            controller: _newClientPhoneController,
            decoration: InputDecoration(
              hintText: 'e.g., 9876543210',
              counterText: "",
              errorText: _phoneError, // ✅ Show validation error
            ),
            keyboardType: TextInputType.phone,
            maxLength: 10,
            onChanged: (value) {
              // ✅ Validate on change
              setState(() {
                _phoneError = Validators.validatePhoneNumber(value);
              });
            },
          ),
          const SizedBox(height: 16),
          const FormLabel(text: 'Client Mobile Number (Optional)'),
          TextField(
            controller: _newClientMobileController,
            decoration: const InputDecoration(
              hintText: 'e.g., 9876543210',
              counterText: "",
            ),
            keyboardType: TextInputType.phone,
            maxLength: 10,
          ),
          const SizedBox(height: 24),
          const FormLabel(text: 'GST Number'),
          TextField(
            controller: _ownerGstController,
            decoration: const InputDecoration(hintText: 'e.g., 27AABCT1234H1Z0'),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _createVehicle,
              icon: const Icon(Icons.save),
              label: const Text('Save Vehicle'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewComplaintCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Register New Complaint(s)',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary),
          ),
          const Divider(height: 24),

          // ✅ Use EmptyDisplay widget
          if (_complaints.isEmpty)
            const EmptyDisplay(
              message: 'No complaints added yet.',
              icon: Icons.assignment_outlined,
              subtitle: 'Add complaints to continue',
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _complaints.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: Text(_complaints[index]['text'])),
                            if (_complaints[index]['amount'] != null && _complaints[index]['amount'] > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '₹${_complaints[index]['amount']}',
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteComplaint(index),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: RawAutocomplete<String>(
                  textEditingController: _complaintInputController,
                  focusNode: _complaintFocusNode,
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return _serviceCatalog.map((s) => s['name'].toString());
                    }
                    return _serviceCatalog
                        .map((s) => s['name'].toString())
                        .where((name) => name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        hintText: 'Select or type complaint...',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ),
                      onSubmitted: (_) => _addComplaint(),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final String option = options.elementAt(index);
                              return InkWell(
                                onTap: () => onSelected(option),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(option),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addComplaint,
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(16),
                ),
                child: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const FormLabel(text: 'Tyre Warranty Details (QRs & Specs)'),
          const SizedBox(height: 8),
          ..._requiredWheels.map((wheel) => _buildTyreWarrantyRow(wheel)).toList(),
          const Divider(height: 32),
          // ✅ Conditionally show damage marking section based on feature flag
          Consumer<AdminSettingsProvider>(
            builder: (context, settingsProvider, _) {
              // Hide Mark Damages on Vehicle for now
              return const SizedBox.shrink();
              /*
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: FormLabel(text: 'Mark Damages on Vehicle'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AspectRatio(
                      aspectRatio: 0.8466666666666667,
                      child: GestureDetector(
                        onTapDown: (details) {
                          final imageBox = _imageKey.currentContext?.findRenderObject()
                              as RenderBox?;
                          if (imageBox == null || !imageBox.hasSize) return;

                          final localPos =
                              imageBox.globalToLocal(details.globalPosition);

                          if (localPos.dx >= 0 &&
                              localPos.dx <= imageBox.size.width &&
                              localPos.dy >= 0 &&
                              localPos.dy <= imageBox.size.height) {
                            final relX = localPos.dx / imageBox.size.width;
                            final relY = localPos.dy / imageBox.size.height;
                            setState(() => _damageMarks.add(Offset(relX, relY)));
                          }
                        },
                        child: CustomPaint(
                          foregroundPainter: DamagePainter(marks: _damageMarks),
                          child: Image.asset(
                            'assets/images/car_outline.png',
                            key: _imageKey,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: double.infinity,
                                height: 250,
                                color: Colors.grey.shade200,
                                child: const Center(child: Text('Car image missing')),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Click on the car image to mark scratches/damages.',
                      textAlign: TextAlign.left,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.undo, size: 18),
                          label: const Text('Undo Last'),
                          onPressed: _undoLastMark,
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            backgroundColor: Colors.blue.shade50,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        const SizedBox(width: 16),
                        TextButton.icon(
                          icon: const Icon(Icons.delete_sweep, size: 18),
                          label: const Text('Clear All'),
                          onPressed: _clearDamageMarks,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            backgroundColor: Colors.red.shade50,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 24),
                ],
              );
              */
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: const FormLabel(text: 'Wheel Photos (5 required)'),
              ),
              if (_wheelPhotos.length < 5)
                ElevatedButton.icon(
                  onPressed: _startRapidCapture,
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Start Capture'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: _requiredWheels.map<Widget>((wheel) {
              final file = _wheelPhotos[wheel];
              return _buildPhotoSlot(wheel, file, () => _captureWheelPhoto(wheel), () => _removeWheelPhoto(wheel));
            }).toList(),
          ),
          const SizedBox(height: 16),
          const FormLabel(text: 'Overall Vehicle Photo (Optional) & Voice Note'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPhotoSlot('Vehicle', _vehiclePhoto, _captureVehiclePhoto, _removeVehiclePhoto),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextButton.icon(
                  onPressed: _toggleRecording,
                  icon: Icon(_isRecording ? Icons.stop : Icons.mic, size: 24),
                  label: Text(_isRecording ? 'Stop Recording' : 'Record Note'),
                  style: TextButton.styleFrom(
                    foregroundColor: _isRecording ? Colors.white : AppTheme.primaryColor,
                    backgroundColor: _isRecording ? Colors.red : Colors.blue.shade50,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          if (_audioPath != null && !_isRecording)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Row(
                children: [
                  const Text('Voice note recorded:'),
                  IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.green),
                    onPressed: () {
                      final source = kIsWeb
                          ? UrlSource(_audioPath!)
                          : DeviceFileSource(_audioPath!);
                      _audioPlayer.play(source);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => setState(() => _audioPath = null),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 32),
          
          // Technician Assignments
          const FormLabel(text: 'Assign Technicians (Optional)'),
          const SizedBox(height: 8),
          ..._buildDynamicTechnicianAssignments(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _technicianAssignments.add({'role': null, 'tech_id': null});
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Technician'),
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveJobCard,
              icon: const Icon(Icons.add_task),
              label: const Text('Create Job Card'),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildPhotoSlot(String title, XFile? file, VoidCallback onCapture, VoidCallback onRemove) {
    return GestureDetector(
      onTap: file == null ? onCapture : null,
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: file != null ? Colors.green : Colors.grey.shade300),
                ),
                child: file != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: kIsWeb
                            ? Image.network(file.path, fit: BoxFit.cover)
                            : Image.file(File(file.path), fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, color: Colors.grey.shade400, size: 32),
                          const SizedBox(height: 4),
                          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
              ),
            ),
            if (file != null)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter for drawing damage marks
class DamagePainter extends CustomPainter {
  final List<Offset> marks;
  DamagePainter({required this.marks});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    for (final mark in marks) {
      final x = mark.dx * size.width;
      final y = mark.dy * size.height;
      canvas.drawCircle(Offset(x, y), 5.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DamagePainter oldDelegate) =>
      oldDelegate.marks != marks;
}
