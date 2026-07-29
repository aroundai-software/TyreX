// lib/screens/pudo_job_card_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import '../services/ocr_service.dart';
import '../services/local_media_service.dart';
import '../services/supabase_service.dart';
import '../services/vehicle_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_constants.dart';
import '../utils/validators.dart';
import '../utils/vehicle_number_utils.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/admin_settings_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../widgets/brand_model_search_dropdown.dart';

// 
class PudoJobCardScreen extends StatefulWidget {
  final int? bookingId; 

  const PudoJobCardScreen({super.key, this.bookingId}); 

  @override
  State<PudoJobCardScreen> createState() => _PudoJobCardScreenState();
}

// 
class _PudoJobCardScreenState extends State<PudoJobCardScreen> {
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

  // Google Drive removed

  // State Management
  bool _isLoading = false;
  String? _searchError;
  Map<String, dynamic>? _vehicleDetails;
  bool _showCreateVehicleForm = false;
  int? _currentVehicleId;
  int? _lastKnownOdometer;

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
  // final GlobalKey _imageKey = GlobalKey();

  // Media
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _audioPath;
  bool _isRecording = false;

  // 
  final GlobalKey _imageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchVehicleModels();
    // If navigated from a booking, prefill client details from the booking
    if (widget.bookingId != null) {
      _prefillFromBooking(widget.bookingId!);
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

  Future<void> _prefillFromBooking(int bookingId) async {
    try {
      final booking = await supabase
          .from('bookings')
          .select('customer_name, customer_phone')
          .eq('id', bookingId)
          .single();

      if (!mounted) return;
      setState(() {
        final name = (booking['customer_name'] as String?)?.trim();
        final phone = (booking['customer_phone'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          _newClientNameController.text = name;
        }
        if (phone != null && phone.isNotEmpty) {
          _newClientPhoneController.text = phone;
        }
      });
    } catch (e) {
      // Silent fail; keep fields editable
    }
  }

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
      _ownerGstController.clear();
    });
  }

  Future<void> _fetchVehicleModels() async {
    try {
      final response = await supabase.from('vehicle_models').select(
          'id, brand, "Model name"');
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
      _showErrorSnackBar('Could not load vehicle models.');
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

    if (normalizedVehicleNumber.isEmpty) {
      setState(() => _searchError = 'Please enter a vehicle number.');
      return;
    }

    setState(() {
      _isLoading = true;
      _searchError = null;
      _vehicleDetails = null;
      _showCreateVehicleForm = false;
    });
    try {
      // Use the updated SupabaseService to get vehicle and owner details
      final supabaseService = SupabaseService();
      final response = await supabaseService.searchVehicle(normalizedVehicleNumber);

      if (response == null) {
        setState(() {
          _vehicleDetails = null;
          _showCreateVehicleForm = true;
        });
      } else {
        final latestOdometer = response['latest_odometer'];
        final ownerDetails = response['owner_details'];
        
        // Debug prints
        if (kDebugMode) {
          print('🔍 PUDO Vehicle found: ${response['Vehicle Number']}');
          print('👤 PUDO Owner details: $ownerDetails');
          print('📱 PUDO Latest client phone: ${response['latest_client_phone']}');
        }
        
        setState(() {
          _vehicleDetails = response;
          _currentVehicleId = response['id'];
          _lastKnownOdometer = latestOdometer;
          
          // Populate client details from owner details if available, otherwise from vehicle
          if (_newClientNameController.text.trim().isEmpty) {
            _newClientNameController.text = ownerDetails?['Owner name'] ?? '';
          }
          if (_newClientPhoneController.text.trim().isEmpty) {
            _newClientPhoneController.text = ownerDetails?['PhoneNumber'] ?? response['MobileNumber'] ?? ''; // Client Phone -> PhoneNumber
          }
          if (_newClientMobileController.text.trim().isEmpty) {
            _newClientMobileController.text = ownerDetails?['MobileNumber'] ?? ''; // Client Mobile -> MobileNumber
          }
          
          // Debug prints after population
          if (kDebugMode) {
            print('📝 PUDO Client name populated: ${_newClientNameController.text}');
            print('📞 PUDO Client phone populated: ${_newClientPhoneController.text}');
            print('📱 PUDO Client mobile populated: ${_newClientMobileController.text}');
          }
          
          _ownerGstController.text = ownerDetails?['GST Number'] ?? '';
          _odometerController.text = latestOdometer?.toString() ?? '0';
        });
      }
    } catch (error) {
      setState(() {
        _vehicleDetails = null;
        _showCreateVehicleForm = true;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createVehicle() async {
    final adminSettings = Provider.of<AdminSettingsProvider>(context, listen: false);

    final phoneError = Validators.validatePhoneNumber(_newClientPhoneController.text);
    if (phoneError != null) {
      _showErrorSnackBar('Please enter a valid phone number.');
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
        'owner_id': ownerId, // Link to owner_master table
      };
      
      await vehicleService.createOrUpdateVehicle(context, vehicleData);
      _showSuccessSnackBar('Vehicle created successfully!');
      await _searchVehicle();
    } catch (error) {
      _showErrorSnackBar('Failed to create vehicle: ${error.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveJobCard() async {
    if (_complaints.isEmpty) {
      _showErrorSnackBar('Please add at least one complaint.');
      return;
    }

    final user = Provider
        .of<UserProvider>(context, listen: false)
        .user;
    if (_currentVehicleId == null || user == null) {
      _showErrorSnackBar('No vehicle selected or user not logged in.');
      return;
    }
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day)
        .toIso8601String();
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59)
        .toIso8601String();
    try {
      final existingReports = await supabase
          .from('reports')
          .select('id, executive:executive_id(username)')
          .eq('vehicle_id', _currentVehicleId!)
          .gte('created_at', startOfDay)
          .lte('created_at', endOfDay);
      if (existingReports.isNotEmpty && mounted) {
        final executiveName = existingReports.first['executive']?['username'] ??
            'another executive';
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) =>
              AlertDialog(
                title: const Text('Duplicate Job Card Warning'),
                content: Text(
                    'A job card for this vehicle was already created today by $executiveName. Are you sure you want to create another one?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.pop(context, true),
                      child: const Text('Confirm & Proceed')),
                ],
              ),
        );
        if (confirmed != true) return;
      }
      await _executeSaveJobCard();
    } catch (e) {
      _showErrorSnackBar('Error checking for duplicates: $e');
    }
  }

  Future<void> _executeSaveJobCard() async {
    final user = Provider
        .of<UserProvider>(context, listen: false)
        .user;
    if (user == null) {
      _showErrorSnackBar('You are not logged in.');
      return;
    }

    final newOdometer = int.tryParse(_odometerController.text) ??
        _lastKnownOdometer ?? 0;

    setState(() => _isLoading = true);

    try {
      final marksJson = _damageMarks
          .map((p) => {'x': p.dx, 'y': p.dy})
          .toList();

      // Create or update owner in owner_master table
      final ownerData = {
        'Owner name': _newClientNameController.text.trim(),
        'PhoneNumber': _newClientPhoneController.text.trim(), // Client Phone -> PhoneNumber
        'MobileNumber': _newClientMobileController.text.trim().isEmpty ? null : _newClientMobileController.text.trim(), // Client Mobile -> MobileNumber
        'GST Number': _ownerGstController.text.trim(),
      };
      
      // Create owner with company filtering
      await vehicleService.createOrUpdateOwner(context, ownerData);

      final Map<String, dynamic> insertData = {
        'vehicle_id': _currentVehicleId,
        'executive_id': null, 
        'created_by_pudo_id': user['id'], 
        'complaint': jsonEncode(_complaints.map((c) => c['text']).toList()),
        'status': AppConstants.statusNotStarted,
        'marks': jsonEncode(marksJson),
        'odometer_reading': newOdometer,
        'Owner name': _newClientNameController.text.trim(),
        'client_phone': _newClientPhoneController.text.trim(),
        'gdrive_folder_url': null,
        'photo_urls': null,
      };

      if (widget.bookingId != null) {
        insertData['booking_id'] = widget.bookingId!; 
      }

// Insert report and return id (jobId)
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

      // Save media locally (Hive) with jobId
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
        const mimeType = 'audio/webm';
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

// 
      if (widget.bookingId != null) {
        await supabase.from('bookings').update({
          'status': 'Job Card Created',
        }).eq('id', widget.bookingId!);
      }

      _showSuccessSnackBar('Job Card saved! Media saved locally for this job.');

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
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
    if (complaintText.isNotEmpty) {
      setState(() {
        _complaints.add(
            {'text': complaintText, 'amount': 0, 'type': 'complaint'});
        _complaintInputController.clear();
      });
    }
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
        final plateNumber = await OcrService.recognizeVehicleNumber(
            pickedFile.path);
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
      // Stop recording is the same for both platforms
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

        // Platform-specific recording start
        if (kIsWeb) {
          await _audioRecorder.start(
            // 
              const RecordConfig(encoder: AudioEncoder.opus), path: '');
        } else {
          // 
          final tempDir = await getTemporaryDirectory();
          final path = '${tempDir.path}/audiorecord_${DateTime
              .now()
              .millisecondsSinceEpoch}.webm'; 
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
          duration: const Duration(seconds: 2),
        ));
  }

  void _showSuccessSnackBar(String message) {
    // Commented out to reduce UI noise
    // if (!mounted) return;
    // ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text(message), backgroundColor: Colors.green));
  }

  // --- WIDGET BUILDER METHODS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'New Job Card',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppTheme.primaryColor,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: AppTheme.backgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Google Drive status removed
            _buildSearchCard(),
            if (_isLoading && _vehicleDetails == null &&
                !_showCreateVehicleForm)
              const Center(child: Padding(padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator())),
            if (_vehicleDetails != null) _buildVehicleDetailsCard(
                _vehicleDetails!),
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
          Row(children: [
            Expanded(
              child: TextField(
                controller: _vehicleNumberController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'enter vehicle number or scan...',
                  suffixIcon: Consumer<AdminSettingsProvider>(
                    builder: (context, settingsProvider, _) {
                      // Hide camera icon if number plate scanner is disabled
                      if (!settingsProvider.featureScanner) {
                        return const SizedBox.shrink();
                      }
                      
                      return Container(
                        margin: const EdgeInsets.only(right: 6),
                        child: Material(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _pickImage(ImageSource.camera),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(Icons.camera_alt, color: Colors.black54, size: 20),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                onChanged: (value) {
                  _vehicleNumberController.value = TextEditingValue(
                      text: value.toUpperCase(),
                      selection: _vehicleNumberController.selection);
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              width: 44,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _searchVehicle,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.search, color: Colors.white),
              ),
            ),
          ]),
          if (_searchError != null && !_showCreateVehicleForm)
            Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                    _searchError!, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary),
            overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildVehicleDetailsCard(Map<String, dynamic> details) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Text('Vehicle Found', style: TextStyle(fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green)),
          ]),
          const Divider(height: 24),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _buildDetailItem(
                'Vehicle Number', details['Vehicle Number'] ?? 'N/A')),
            Expanded(child: _buildDetailItem(
                'Vehicle Name', details['vehicle_name'] ?? 'N/A')),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _buildDetailItem(
                'Brand', details['vehicle_models']?['brand'] ?? 'N/A')),
            Expanded(child: _buildDetailItem(
                'Model', details['vehicle_models']?['Model name'] ?? 'N/A')),
          ]),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildDetailItem('Last Odometer', '${_lastKnownOdometer ?? 'N/A'} km')),
              const Expanded(child: SizedBox()),
            ],
          ),
          const Divider(height: 32),
          const FormLabel(text: 'Client Name'),
          TextField(
            controller: _newClientNameController,
            decoration: const InputDecoration(hintText: 'Enter client name'),
          ),
          const SizedBox(height: 16),
          const FormLabel(text: 'Client Phone'),
          TextField(
              controller: _newClientPhoneController,
              decoration: const InputDecoration(
                  hintText: 'Enter 10-digit phone number', counterText: ""),
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 10),
          const SizedBox(height: 16),
          const FormLabel(text: 'Client Mobile Number (Optional)'),
          TextField(
              controller: _newClientMobileController,
              decoration: const InputDecoration(
                  hintText: 'Enter 10-digit mobile number', counterText: ""),
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 10),
          const SizedBox(height: 16),
          const FormLabel(text: 'GST Number'),
          TextField(
              controller: _ownerGstController,
              decoration: const InputDecoration(
                  hintText: 'e.g., 27AABCT1234H1Z0')),
          const FormLabel(text: 'Odometer Reading'),
          TextField(
            controller: _odometerController,
            decoration: const InputDecoration(
              hintText: 'Enter current kilometers',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) {
              setState(() {});
            },
          ),
          if (_lastKnownOdometer != null &&
              int.tryParse(_odometerController.text) != null &&
              (int.tryParse(_odometerController.text)!) < _lastKnownOdometer!)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Entered reading is lower than last recorded ($_lastKnownOdometer km). Please verify.',
                      style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
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
                decoration: const InputDecoration(
                  hintText: 'e.g., 9876543210',
                  counterText: '',
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 10,
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
          const Text('Register Works',
              style: TextStyle(fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const Divider(height: 24),
          if (_complaints.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text('No complaints added yet.',
                      style: TextStyle(color: AppTheme.textSecondary))),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _complaints.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(_complaints[index]['text'])),
                      IconButton(
                          icon: const Icon(
                              Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteComplaint(index)),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _complaintInputController,
                    decoration: const InputDecoration(
                        hintText: 'e.g., Engine noise on startup',
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14)))),
            const SizedBox(width: 8),
            ElevatedButton(
                onPressed: _addComplaint,
                style: ElevatedButton.styleFrom(shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16)),
                child: const Icon(Icons.add)),
          ]),
          // --- ✅ ADD DAMAGE MARKING SECTION ---
          Consumer<AdminSettingsProvider>( // Use Consumer to rebuild on change
            builder: (context, settings, child) {
              if (!settings.featureDamageMarking) {
                return const SizedBox.shrink(); // Don't show if disabled
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: AppTheme.spacingLg),
                  const FormLabel(text: 'Mark Damages on Vehicle'),
                  const SizedBox(height: AppTheme.spacingSm),
                  Align(
                    alignment: Alignment.centerLeft, // Keep it aligned left
                    // Ensure consistent AspectRatio with job_card_screen
                    child: AspectRatio(
                      aspectRatio: 0.8466666666666667, // Use consistent ratio
                      child: GestureDetector(
                        onTapDown: (details) {
                          // Find RenderBox for coordinate calculation
                          final imageBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
                          if (imageBox == null || !imageBox.hasSize) return;
                          final localPos = imageBox.globalToLocal(details.globalPosition);

                          // Check if tap is within bounds
                          if (localPos.dx >= 0 && localPos.dx <= imageBox.size.width &&
                              localPos.dy >= 0 && localPos.dy <= imageBox.size.height) {
                            // Calculate relative coordinates (0.0 to 1.0)
                            final relX = localPos.dx / imageBox.size.width;
                            final relY = localPos.dy / imageBox.size.height;
                            setState(() => _damageMarks.add(Offset(relX, relY)));
                          }
                        },
                        child: CustomPaint(
                          // Use the painter defined at the end of the file
                          foregroundPainter: DamagePainter(marks: _damageMarks),
                          child: Image.asset(
                            'assets/images/car_outline.png', // Correct asset path
                            key: _imageKey, // Assign the key
                            fit: BoxFit.contain,
                            // Add error builder for robustness
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: AppTheme.borderColor.withAlpha(51),
                                child: const Center(child: Icon(Icons.error_outline, color: AppTheme.textSecondary)),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  const Align( // Instruction text
                    alignment: Alignment.centerLeft,
                    child: Text( 'Click on the car image to mark scratches/damages.', textAlign: TextAlign.left, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  Align( // Undo/Clear buttons
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(icon: const Icon(Icons.undo, size: 18), label: const Text('Undo Last'), onPressed: _undoLastMark, style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor, backgroundColor: AppTheme.primaryLight, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8))),
                        const SizedBox(width: AppTheme.spacingMd),
                        TextButton.icon(icon: const Icon(Icons.delete_sweep, size: 18), label: const Text('Clear All'), onPressed: _clearDamageMarks, style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor, backgroundColor: AppTheme.errorColor.withAlpha(25), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8))),
                      ],),
                  ),
                ],
              );
            },
          ),
          // --- END DAMAGE MARKING SECTION ---
          const Divider(height: AppTheme.spacingLg),
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
                  children: _capturedPhotos
                      .asMap()
                      .entries
                      .map((entry) {
                    return Stack(
                      children: [
                        ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: kIsWeb
                                ? Image.network(entry.value.path, width: 80,
                                height: 80,
                                fit: BoxFit.cover)
                                : Image.file(File(entry.value.path), width: 80,
                                height: 80,
                                fit: BoxFit.cover)),
                        Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                                onTap: () => _removePhoto(entry.key),
                                child: Container(
                                    decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(
                                        Icons.close, color: Colors.white,
                                        size: 14)))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          Row(children: [
            TextButton.icon(
                onPressed: _capturePhoto,
                icon: const Icon(Icons.add_a_photo, size: 18),
                label: const Text('Add Photos'),
                style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    backgroundColor: Colors.blue.shade50,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8))),
            const SizedBox(width: 16),
            TextButton.icon(
                onPressed: _toggleRecording,
                icon: Icon(_isRecording ? Icons.stop : Icons.mic, size: 18),
                label: Text(_isRecording ? 'Stop' : 'Record Note'),
                style: TextButton.styleFrom(
                    foregroundColor: _isRecording ? Colors.white : AppTheme
                        .primaryColor,
                    backgroundColor: _isRecording ? Colors.red : Colors.blue
                        .shade50,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8))),
          ]),
          if (_audioPath != null && !_isRecording)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Row(children: [
                const Text('Voice note recorded:'),
                IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.green),
                    // --- FIX 1: Platform-aware audio playback ---
                    onPressed: () {
                      final source = kIsWeb
                          ? UrlSource(_audioPath!)
                          : DeviceFileSource(_audioPath!);
                      _audioPlayer.play(source);
                    }),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => setState(() => _audioPath = null)),
              ]),
            ),
          const SizedBox(height: 32),
          SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveJobCard,
                  icon: const Icon(Icons.add_task),
                  label: const Text('Save Complaints & Media'))),
        ],
      ),
    );
  }
}

// Custom Painter for drawing damage marks. This MUST BE OUTSIDE the State class.
class DamagePainter extends CustomPainter {
  final List<Offset> marks; // relative (0.0–1.0)
  DamagePainter({required this.marks});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    for (final mark in marks) {
      // Convert relative → absolute for display
      final x = mark.dx * size.width;
      final y = mark.dy * size.height;
      canvas.drawCircle(Offset(x, y), 5.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DamagePainter oldDelegate) =>
      oldDelegate.marks != marks;
}