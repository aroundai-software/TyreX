// lib/screens/job_card_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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

// ✅ NEW IMPORTS
import '../utils/app_constants.dart';
import '../utils/validators.dart';
import '../utils/vehicle_number_utils.dart';
import '../widgets/error_display.dart';

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
  final List<XFile> _capturedPhotos = [];
  final List<Offset> _damageMarks = [];
  final GlobalKey _imageKey = GlobalKey();

  // Media
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _audioPath;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _fetchVehicleModels();
    
    // Prefill customer data if coming from a booking
    if (widget.customerName != null) {
      _newClientNameController.text = widget.customerName!;
    }
    if (widget.customerPhone != null) {
      _newClientPhoneController.text = widget.customerPhone!;
    }
  }

  @override
  void dispose() {
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
      _capturedPhotos.clear();
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
    
    // Only phone number is mandatory
    final phoneError =
        Validators.validatePhoneNumber(_newClientPhoneController.text);

    if (phoneError != null) {
      setState(() {
        _phoneError = phoneError;
      });
      _showErrorSnackBar(AppConstants.errorInvalidInput);
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
        'PhoneNumber': _newClientPhoneController.text.trim(),
        'MobileNumber': null,
        'GST Number': '',
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
        'MobileNumber': _newClientPhoneController.text.trim(),
        'owner_id': ownerId,
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

      final Map<String, dynamic> insertData = {
        'vehicle_id': _currentVehicleId,
        'executive_id': executiveId, // Passes int?
        'complaint': jsonEncode(_complaints.map((c) => c['text']).toList()),
        'status': AppConstants.statusNotStarted,
        'marks': jsonEncode(marksJson),
        'odometer_reading': newOdometer, // Save the entered value
        'Owner name': _newClientNameController.text.trim(),
        'client_phone': _newClientPhoneController.text.trim(),
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
          .select('id')
          .eq('vehicle_id', _currentVehicleId!)
          .order('created_at', ascending: false)
          .limit(1)
          .single();
      final int jobId = inserted['id'] as int;

      // Save media locally (Hive) and associate with jobId
      final vehicleNo = (_vehicleDetails?['Vehicle Number'] as String?) ?? 'unknown';
      // Photos
      for (int i = 0; i < _capturedPhotos.length; i++) {
        final photoXFile = _capturedPhotos[i];
        final fileName = 'photo_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final bytes = await photoXFile.readAsBytes();
        await LocalMediaService().saveMediaBytes(
          bytes: bytes,
          vehicleNo: vehicleNo,
          mediaType: 'photo',
          mimeType: 'image/jpeg',
          fileName: fileName,
          jobId: jobId,
        );
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

      _showSuccessSnackBar('Job card created successfully!${(_capturedPhotos.isNotEmpty || _audioPath != null) ? ' Media saved locally for this job.' : ''}');

      if (mounted) {
        // ✅ FIX: Pass the integer user ID to refresh
        await Provider.of<ReportProvider>(context, listen: false)
            .refresh(user['id']);
        
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

  // --- UI & MEDIA HELPERS ---

  void _addComplaint() {
    final complaintText = _complaintInputController.text.trim();

    // ✅ Validate complaint is not empty
    final error = Validators.validateRequired(complaintText);
    if (error != null) {
      _showErrorSnackBar(error);
      return;
    }

    setState(() {
      _complaints.add({
        'text': complaintText,
        'amount': 0,
        'type': AppConstants.typeComplaint
      }); // ✅ Use constant
      _complaintInputController.clear();
    });
  }

  void _deleteComplaint(int index) {
    setState(() => _complaints.removeAt(index));
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(
        source: source, imageQuality: 60, maxWidth: 1280);
    if (pickedFile != null) {
      setState(() => _isLoading = true);
      try {
        final plateNumber =
            await OcrService.recognizeVehicleNumber(pickedFile.path);
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

  Future<void> _capturePhoto() async {
    final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera, imageQuality: 60, maxWidth: 1280);
    if (pickedFile != null) {
      setState(() => _capturedPhotos.add(pickedFile));
    }
  }

  void _removePhoto(int index) {
    setState(() => _capturedPhotos.removeAt(index));
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
      body: SingleChildScrollView(
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

          const FormLabel(text: 'Odometer Reading'),
          TextField(
            controller: _odometerController, // Already populated with latest
            decoration: InputDecoration(
              hintText:
                  'Enter current kilometers', // ... (rest of odometer field, including potential warning)
              errorText: _odometerError, // Show validation error
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
        ],
      ),
    );
  }

  Widget _buildCreateVehicleForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        const Row(
          children: [
            Icon(Icons.add_circle, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'Register New Vehicle',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Vehicle not found. Please add the details below.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),

        // Box 1 — Mandatory fields
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.35), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FormLabel(text: 'Vehicle Number', isRequired: true),
              TextField(
                controller: TextEditingController(text: _vehicleNumberController.text),
                readOnly: true,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              const FormLabel(text: 'Phone Number', isRequired: true),
              TextField(
                controller: _newClientPhoneController,
                decoration: InputDecoration(
                  hintText: 'e.g., 9876543210',
                  counterText: '',
                  errorText: _phoneError,
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10,
                onChanged: (value) {
                  setState(() {
                    _phoneError = Validators.validatePhoneNumber(value);
                  });
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Box 2 — Optional fields
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FormLabel(text: 'Client Name'),
              TextField(
                controller: _newClientNameController,
                decoration: const InputDecoration(hintText: 'e.g., John Doe'),
              ),
              const SizedBox(height: 16),
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
                decoration: const InputDecoration(hintText: 'e.g., 54000'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
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
    );
  }

  Widget _buildNewComplaintCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Register Works',
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
                      Expanded(child: Text(_complaints[index]['text'])),
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
                child: TextField(
                  controller: _complaintInputController,
                  decoration: const InputDecoration(
                    hintText: 'e.g., Engine noise on startup',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
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
          // ✅ Conditionally show damage marking section based on feature flag
          Consumer<AdminSettingsProvider>(
            builder: (context, settingsProvider, _) {
              if (!settingsProvider.featureDamageMarking) {
                return const SizedBox.shrink();
              }
              
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
            },
          ),
          const FormLabel(text: 'Attach Photos & Voice Note'),
          const SizedBox(height: 12),
          if (_capturedPhotos.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _capturedPhotos.asMap().entries.map((entry) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: kIsWeb
                              ? Image.network(entry.value.path,
                                  width: 80, height: 80, fit: BoxFit.cover)
                              : Image.file(File(entry.value.path),
                                  width: 80, height: 80, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => _removePhoto(entry.key),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          Row(
            children: [
              TextButton.icon(
                onPressed: _capturePhoto,
                icon: const Icon(Icons.add_a_photo, size: 18),
                label: const Text('Add Photos'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  backgroundColor: Colors.blue.shade50,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: _toggleRecording,
                icon: Icon(_isRecording ? Icons.stop : Icons.mic, size: 18),
                label: Text(_isRecording ? 'Stop' : 'Record Note'),
                style: TextButton.styleFrom(
                  foregroundColor:
                      _isRecording ? Colors.white : AppTheme.primaryColor,
                  backgroundColor:
                      _isRecording ? Colors.red : Colors.blue.shade50,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveJobCard,
              icon: const Icon(Icons.add_task),
              label: const Text('Save Complaints & Media'),
            ),
          ),
        ],
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
