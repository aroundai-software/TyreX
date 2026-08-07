// lib/screens/job_card_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'update_screen.dart';
import 'continuous_camera_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../screens/custom_scanner_screen.dart';
import '../screens/multi_wheel_camera_screen.dart';
import '../screens/unlimited_camera_screen.dart';
import '../screens/number_plate_scanner_screen.dart';
import '../screens/odometer_camera_screen.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:archive/archive.dart';
import '../utils/app_constants.dart';
import '../utils/validators.dart';
import '../utils/date_utils.dart';
import 'package:intl/intl.dart';
import '../widgets/service_catalog_picker.dart';
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
import '../widgets/service_catalog_picker.dart';

class JobCardScreen extends StatefulWidget {
  final int? bookingId;
  final String? customerName;
  final String? customerPhone;
  final Map<String, dynamic>? draftJob;
  
  const JobCardScreen({
    super.key,
    this.bookingId,
    this.customerName,
    this.customerPhone,
    this.draftJob,
  });

  @override
  State<JobCardScreen> createState() => _JobCardScreenState();
}

class _JobCardScreenState extends State<JobCardScreen> {
  final ScrollController _mainScrollController = ScrollController();
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
  final _complaintAmountController = TextEditingController();
  final _complaintCountController = TextEditingController(text: '1');
  final _laborCostController = TextEditingController(); // Added Labour Cost Controller
  final FocusNode _complaintFocusNode = FocusNode();
  String? _selectedGlobalTyreBrand;
  String? _selectedGlobalTyreModel;
  String? _selectedGlobalTyreSize;
  String? _selectedGlobalTyreLiSi;
  final TextEditingController _tyreCountController = TextEditingController();
  final TextEditingController _tyrePriceController = TextEditingController();
  final TextEditingController _tyreTotalController = TextEditingController();

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
  // ✅ True when the screen is loaded from a vehicle job card draft (existing vehicle)
  // Used to skip the vehicle search bar and creation form entirely
  bool _isVehicleJobCardDraft = false;
  dynamic _loadedRegistrationDraftId;
  int? _currentVehicleId;
  int? _lastKnownOdometer;

  // ✅ Add flags to track if details differ
  bool _clientNameDiffers = false;
  bool _clientPhoneDiffers = false;

  // Courier State
  bool _isCourierMode = false;
  final _courierNameController = TextEditingController();
  final _courierPhoneController = TextEditingController();
  final _courierAddressController = TextEditingController();
  final _courierGstController = TextEditingController();
  final List<dynamic> _courierPhotos = [];
  String? _courierTyreBrand;
  String? _courierTyreModel;
  String? _courierTyreSize;
  
  final _courierProductPriceController = TextEditingController();
  final _courierProductQtyController = TextEditingController(text: '1');
  final List<Map<String, dynamic>> _courierProductsList = [];
  int? _editingCourierProductIndex;

  void _addCourierProduct() {
    if (_courierTyreBrand == null || _courierTyreModel == null || _courierTyreSize == null) {
      _showErrorSnackBar('Please select Brand, Model, and Size.');
      return;
    }
    
    final price = double.tryParse(_courierProductPriceController.text) ?? 0.0;
    final qty = int.tryParse(_courierProductQtyController.text) ?? 1;

    setState(() {
      if (_editingCourierProductIndex != null) {
        final existingImages = _courierProductsList[_editingCourierProductIndex!]['qr_images'] as List<dynamic>? ?? [];
        _courierProductsList[_editingCourierProductIndex!] = {
          'brand': _courierTyreBrand,
          'model': _courierTyreModel,
          'size': _courierTyreSize,
          'name': '$_courierTyreBrand $_courierTyreModel - $_courierTyreSize',
          'price': price,
          'qty': qty,
          'qr_images': existingImages, 
        };
        _editingCourierProductIndex = null;
      } else {
        int existingIndex = _courierProductsList.indexWhere((p) => 
          p['brand'] == _courierTyreBrand && 
          p['model'] == _courierTyreModel && 
          p['size'] == _courierTyreSize
        );

        if (existingIndex != -1) {
          _courierProductsList[existingIndex]['qty'] = (_courierProductsList[existingIndex]['qty'] as int) + qty;
          _courierProductsList[existingIndex]['price'] = price; 
        } else {
          _courierProductsList.add({
            'brand': _courierTyreBrand,
            'model': _courierTyreModel,
            'size': _courierTyreSize,
            'name': '$_courierTyreBrand $_courierTyreModel - $_courierTyreSize',
            'price': price,
            'qty': qty,
            'qr_images': <dynamic>[], 
          });
        }
      }
      
      _courierTyreBrand = null;
      _courierTyreModel = null;
      _courierTyreSize = null;
      _courierProductPriceController.clear();
      _courierProductQtyController.text = '1';
    });
  }

  void _deleteCourierProduct(int index) {
    setState(() {
      _courierProductsList.removeAt(index);
    });
  }

  void _editCourierProduct(int index) {
    final p = _courierProductsList[index];
    setState(() {
      _courierTyreBrand = p['brand'];
      _courierTyreModel = p['model'];
      _courierTyreSize = p['size'];
      _courierProductQtyController.text = p['qty'].toString();
      _courierProductPriceController.text = p['price'].toString();
      _editingCourierProductIndex = index;
    });
  }

  void _cancelEditCourierProduct() {
    setState(() {
      _editingCourierProductIndex = null;
      _courierTyreBrand = null;
      _courierTyreModel = null;
      _courierTyreSize = null;
      _courierProductPriceController.clear();
      _courierProductQtyController.text = '1';
    });
  }

  Future<void> _scanCourierProductQR(int index) async {
    final qty = _courierProductsList[index]['qty'] as int;
    final currentPhotos = _courierProductsList[index]['qr_images'] as List<dynamic>? ?? [];
    
    int remaining = qty - currentPhotos.length;
    if (remaining <= 0) {
      _showErrorSnackBar('You have already scanned all QRs for this product.');
      return;
    }

    final List<String> targets = List.generate(remaining, (i) => 'QR Code ${i + 1} of $remaining');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiWheelCameraScreen(targets: targets),
      ),
    );

    if (result != null && result is Map) {
      List<dynamic> images = List<dynamic>.from(currentPhotos);
      for (var file in result.values) {
        try {
          images.add(await file.readAsBytes());
        } catch (e) {
          debugPrint('Error reading QR file: $e');
        }
      }
      setState(() {
        _courierProductsList[index]['qr_images'] = images;
      });
    }
  }

  void _viewCourierQR(int productIndex, int photoIndex) {
    showDialog(
      context: context,
      builder: (context) {
        final images = _courierProductsList[productIndex]['qr_images'] as List<dynamic>;
        final imageItem = images[photoIndex];
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  InteractiveViewer(
                    child: imageItem is String ? Image.network(imageItem, fit: BoxFit.contain) : Image.memory(imageItem as Uint8List, fit: BoxFit.contain),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    images.removeAt(photoIndex);
                  });
                  Navigator.pop(context);
                  _scanCourierProductQR(productIndex); 
                },
                icon: const Icon(Icons.delete),
                label: const Text('Delete & Retake'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------
  // Sharing Helpers
  // -------------------
  Future<void> _shareTyreImage(String wheel) async {
    final bytes = _tyreQRImages[wheel];
    if (bytes == null) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$wheel-qr.png');
    await file.writeAsBytes(bytes);
    await Share.shareFiles([file.path], text: 'Tyre QR for $wheel');
  }

  Future<void> _shareAllTyresAsZip() async {
    final archive = Archive();
    for (final wheel in _requiredWheels) {
      final bytes = _tyreQRImages[wheel];
      if (bytes != null) {
        archive.addFile(ArchiveFile('$wheel-qr.png', bytes.length, bytes));
      }
    }
    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) return;
    final dir = await getTemporaryDirectory();
    final zipFile = File('${dir.path}/tyre_qrs_and_pdfs.zip');
    await zipFile.writeAsBytes(zipData);
    await Share.shareFiles([zipFile.path], text: 'All tyre QR images and PDFs');
  }

  // Share a PDF containing the tyre QR image and specs
  Future<void> _shareTyrePdf(String wheel) async {
    final bytes = _tyreQRImages[wheel];
    if (bytes == null) return;
    final pdf = pw.Document();
    final image = pw.MemoryImage(bytes);
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Tyre QR for $wheel', style: pw.TextStyle(fontSize: 24)),
            pw.SizedBox(height: 10),
            pw.Image(image, width: 200, height: 200),
            pw.SizedBox(height: 10),
            pw.Text('Spec: ${_tyreSpecControllers[wheel]?.text ?? ''}'),
          ],
        ),
      ),
    );
    final dir = await getTemporaryDirectory();
    final pdfFile = File('${dir.path}/$wheel-qr.pdf');
    await pdfFile.writeAsBytes(await pdf.save());
    await Share.shareFiles([pdfFile.path], text: 'Tyre PDF for $wheel');
  }

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
  final Map<String, dynamic> _wheelPhotos = {};
  final List<dynamic> _vehiclePhotos = [];
  dynamic _odometerPhoto;
  
  // Tyre Warranty Details
  final Map<String, TextEditingController> _tyreQRControllers = {};
  final Map<String, TextEditingController> _tyreSpecControllers = {};
  final Map<String, dynamic> _tyreQRImages = {};
  
  final List<String> _requiredWheels = [
    'Front Left',
    'Rear Left',
    'Rear Right',
    'Front Right',
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
    
    if (widget.draftJob != null) {
      final marksRaw = widget.draftJob!['marks'];
      Map<String, dynamic> marks = {};
      if (marksRaw != null) {
        if (marksRaw is String) {
          try { marks = jsonDecode(marksRaw); } catch (_) {}
        } else if (marksRaw is Map) {
          marks = Map<String, dynamic>.from(marksRaw);
        }
      }
      
      final bool isCourier = marks['is_courier'] == true;
      _isCourierMode = isCourier;

      if (isCourier) {
        _courierNameController.text = widget.draftJob!['Owner name'] ?? '';
        _courierPhoneController.text = widget.draftJob!['client_phone'] ?? '';
        _courierAddressController.text = marks['address'] ?? '';
        _courierGstController.text = marks['gst_no'] ?? '';
        
        final productsList = marks['products'];
        if (productsList != null && productsList is List) {
          _courierProductsList.clear();
          for (var p in productsList) {
            _courierProductsList.add({
              'brand': p['brand'],
              'model': p['model'],
              'size': p['size'],
              'name': p['name'],
              'price': double.tryParse(p['price'].toString()) ?? 0.0,
              'qty': p['qty'],
              'qr_images': <dynamic>[],
            });
          }
        }
      } else {
        // ✅ It's a vehicle job card draft — mark it so UI hides search+create form
        _isVehicleJobCardDraft = true;
        _loadDraftIntoForm(widget.draftJob!, showSnackBar: false);
      }
      
      _loadDraftMedia(widget.draftJob!);
    }
  }

  Future<void> _loadDraftMedia(Map<String, dynamic> draftJob) async {
    final photoUrlsRaw = draftJob['photo_urls'];
    if (photoUrlsRaw == null) return;
    
    List<String> urls = [];
    if (photoUrlsRaw is String) {
      try { urls = List<String>.from(jsonDecode(photoUrlsRaw)); } catch (_) {}
    } else if (photoUrlsRaw is List) {
      urls = List<String>.from(photoUrlsRaw.map((e) => e.toString()));
    }

    for (String url in urls) {
      try {
        // ─────────────── COURIER MEDIA ───────────────
        if (url.contains('_tyreqr_product_')) {
          // Format: job_{id}_tyreqr_product_{i}_qr_{j}_{timestamp}.jpg
          final match = RegExp(r'product_(\d+)_qr_(\d+)').firstMatch(url);
          if (match != null) {
            final productIndex = int.parse(match.group(1)!);
            if (productIndex < _courierProductsList.length) {
              if (mounted) {
                setState(() {
                  (_courierProductsList[productIndex]['qr_images'] as List<dynamic>).add(url);
                });
              }
            }
          }

        // ─────────────── VEHICLE TYRE QR IMAGES ───────────────
        // Format: job_{id}_tyreqr_{position}_{timestamp}.jpg
        } else if (url.contains('_tyreqr_') && !url.contains('_tyreqr_product_')) {
          // Extract position from filename, e.g. tyreqr_Front_Left_
          final match = RegExp(r'_tyreqr_(.+?)_\d+\.jpg').firstMatch(url);
          if (match != null) {
            // Reconstruct position with spaces (was saved with underscores)
            final rawPos = match.group(1)!.replaceAll('_', ' ');
            // Find the closest matching wheel position
            final position = _requiredWheels.firstWhere(
              (w) => w.replaceAll(' ', '_') == match.group(1)!,
              orElse: () => rawPos,
            );
            if (mounted) {
              setState(() {
                _tyreQRImages[position] = url;
              });
            }
          }

        // ─────────────── VEHICLE WHEEL PHOTOS ───────────────
        // Format: job_{id}_wheel_{position}_{timestamp}.jpg
        } else if (url.contains('_wheel_')) {
          final match = RegExp(r'_wheel_(.+?)_\d+\.jpg').firstMatch(url);
          if (match != null) {
            final rawPos = match.group(1)!;
            final position = _requiredWheels.firstWhere(
              (w) => w.replaceAll(' ', '_') == rawPos,
              orElse: () => rawPos.replaceAll('_', ' '),
            );
            if (mounted) {
              setState(() {
                _wheelPhotos[position] = url;
              });
            }
          }

        // ─────────────── VEHICLE / PACKAGE PHOTOS ───────────────
        // Format: job_{id}_vehicle_{i}_{timestamp}.jpg  (vehicle) or courier package
        } else if (url.contains('_vehicle_')) {
          if (mounted) {
            setState(() {
              if (_isCourierMode) {
                _courierPhotos.add(url);
              } else {
                _vehiclePhotos.add(url);
              }
            });
          }

        // ─────────────── ODOMETER PHOTO ───────────────
        // Format: job_{id}_odometer_{timestamp}.jpg
        } else if (url.contains('_odometer_')) {
          if (mounted) {
            setState(() {
              _odometerPhoto = url;
            });
          }
        }
      } catch (e) {
        debugPrint('Error assigning draft media $url: $e');
      }
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
    _mainScrollController.dispose();
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
    _complaintAmountController.dispose();
    _complaintCountController.dispose();
    _laborCostController.dispose();
    _ownerGstController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    
    for (var controller in _tyreQRControllers.values) {
      controller.dispose();
    }
    for (var controller in _tyreSpecControllers.values) {
      controller.dispose();
    }
    
    _tyreCountController.dispose();
    _tyrePriceController.dispose();
    _tyreTotalController.dispose();
    super.dispose();
  }

  void _syncTyreComplaint() {
    int count = int.tryParse(_tyreCountController.text) ?? 0;
    double price = double.tryParse(_tyrePriceController.text) ?? 0.0;
    _tyreTotalController.text = (count * price).toStringAsFixed(2);
  }

  // --- GOOGLE DRIVE REMOVED ---

  // --- DATA FETCHING & LOGIC ---

  void _resetScreen() {
    setState(() {
      _vehicleNumberController.clear();
      _vehicleDetails = null;
      _showCreateVehicleForm = false;
      _isVehicleJobCardDraft = false;
      _loadedRegistrationDraftId = null;
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
      _complaintAmountController.clear();
      _complaintCountController.text = '1';
      _laborCostController.clear();
      _selectedGlobalTyreBrand = null;
      _selectedGlobalTyreModel = null;
      _selectedGlobalTyreSize = null;
      _selectedGlobalTyreLiSi = null;
      _selectedBrand = null;
      _selectedModelId = null;
      _selectedModelName = null;
      _wheelPhotos.clear();
      _vehiclePhotos.clear();
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

      final vehicleData = {
        'Vehicle Number': VehicleNumberUtils.normalize(_vehicleNumberController.text.trim()),
        'vehicle_name': null,
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

  Future<void> _saveVehicleRegistrationDraft() async {
    final vehicleNo = VehicleNumberUtils.normalize(_vehicleNumberController.text.trim());
    if (vehicleNo.isEmpty) {
      _showErrorSnackBar('Please enter a vehicle number to save a draft.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.user;

      if (!CompanyService().hasActiveCompany) {
        await CompanyService().loadPersistedCompany();
      }
      final String? companyGuid = CompanyService().guid;

      final int? odoReading = int.tryParse(_newOdometerController.text.trim().isNotEmpty
          ? _newOdometerController.text.trim()
          : _odometerController.text.trim());

      final draftData = {
        'status': AppConstants.statusDraft,
        'vehicle_id': _currentVehicleId,
        'Owner name': _newClientNameController.text.trim().isNotEmpty ? _newClientNameController.text.trim() : null,
        'client_phone': _newClientPhoneController.text.trim().isNotEmpty ? _newClientPhoneController.text.trim() : null,
        'odometer_reading': odoReading,
        'complaint': jsonEncode(_complaints),
        'Guid': companyGuid,
        'marks': jsonEncode({
          'is_vehicle_registration_draft': true,
          'vehicle_number': vehicleNo,
          'client_mobile': _newClientMobileController.text.trim(),
          'gst_no': _ownerGstController.text.trim(),
          'brand': _selectedBrand,
          'model_id': _selectedModelId,
          'model_name': _selectedModelName,
        }),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'executive_id': user?['id'],
      };

      final dynamic targetDraftId = widget.draftJob != null ? widget.draftJob!['id'] : _loadedRegistrationDraftId;
      if (targetDraftId != null) {
        draftData.remove('created_at');
        await supabase.from('reports').update(draftData).eq('id', targetDraftId);
      } else {
        await supabase.from('reports').insert(draftData);
      }

      if (!mounted) return;
      final String formattedNow = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vehicle registration draft saved on $formattedNow!'),
          backgroundColor: Colors.purple,
        ),
      );

      _resetScreen();
    } catch (e) {
      _showErrorSnackBar('Failed to save draft: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openFullPageRegistrationDrafts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SavedRegistrationDraftsScreen(
          onSelectDraft: (draft) {
            _loadDraftIntoForm(draft);
          },
        ),
      ),
    );
  }

  void _loadDraftIntoForm(Map<String, dynamic> draft, {bool showSnackBar = true}) {
    setState(() {
      Map<String, dynamic> marks = {};
      if (draft['marks'] is String) {
        try { marks = jsonDecode(draft['marks']); } catch (_) {}
      } else if (draft['marks'] is Map) {
        marks = Map<String, dynamic>.from(draft['marks']);
      }

      int? vehId;
      if (draft['vehicle_id'] != null) {
        vehId = draft['vehicle_id'] is int ? draft['vehicle_id'] as int : int.tryParse(draft['vehicle_id'].toString());
      }
      if (vehId == null && draft['vehicles'] is Map && draft['vehicles']['id'] != null) {
        vehId = draft['vehicles']['id'] is int ? draft['vehicles']['id'] as int : int.tryParse(draft['vehicles']['id'].toString());
      }
      _currentVehicleId = vehId;

      final String vehNo = marks['vehicle_number'] ?? draft['Vehicle Number'] ?? draft['vehicles']?['Vehicle Number'] ?? '';
      _vehicleNumberController.text = vehNo;
      _newClientNameController.text = draft['Owner name'] ?? '';
      _newClientPhoneController.text = draft['client_phone'] ?? '';
      _newClientMobileController.text = marks['client_mobile'] ?? draft['client_mobile'] ?? '';
      _ownerGstController.text = marks['gst_no'] ?? draft['gst_no'] ?? '';
      _newOdometerController.text = draft['odometer_reading']?.toString() ?? '';
      
      _selectedBrand = marks['brand'] as String?;
      _selectedModelId = int.tryParse(marks['model_id']?.toString() ?? '');
      _selectedModelName = marks['model_name'] as String?;

      _selectedGlobalTyreBrand = marks['tyre_brand'] as String?;
      _selectedGlobalTyreModel = marks['tyre_model'] as String?;
      _selectedGlobalTyreSize = marks['tyre_size'] as String?;
      _selectedGlobalTyreLiSi = marks['tyre_li_si'] as String?;

      _loadedRegistrationDraftId = draft['id'];
      final bool isRegistrationDraft = marks['is_vehicle_registration_draft'] == true;

      if (isRegistrationDraft) {
        // Vehicle Registration Draft: Show vehicle registration form prefilled (vehicle not in DB yet)
        _isVehicleJobCardDraft = false;
        _showCreateVehicleForm = true;
        _vehicleDetails = null;
      } else {
        // Real Job Card Draft: Show green Vehicle Found banner and complaints section
        _isVehicleJobCardDraft = true;
        _showCreateVehicleForm = false;
        if (draft['vehicles'] is Map) {
          _vehicleDetails = Map<String, dynamic>.from(draft['vehicles']);
        } else {
          _vehicleDetails = {
            'Vehicle Number': vehNo,
            'Owner name': draft['Owner name'] ?? '',
            'client_phone': draft['client_phone'] ?? '',
            'Guid': draft['Guid'],
          };
        }

        if (_currentVehicleId == null && vehNo.isNotEmpty) {
          SupabaseService().searchVehicle(vehNo).then((resp) {
            if (resp != null && mounted) {
              setState(() {
                _currentVehicleId = resp['id'];
                _vehicleDetails = resp;
              });
            }
          });
        }
      }

      final rawComplaints = draft['complaint'];
      _complaints.clear();
      if (rawComplaints is List) {
        _complaints.addAll(List<Map<String, dynamic>>.from(rawComplaints.map((e) => Map<String, dynamic>.from(e))));
      } else if (rawComplaints is String && rawComplaints.startsWith('[')) {
        try {
          final decoded = jsonDecode(rawComplaints) as List;
          _complaints.addAll(List<Map<String, dynamic>>.from(decoded.map((e) => Map<String, dynamic>.from(e))));
        } catch (_) {}
      }

      final rawAssignments = draft['technician_assignments'];
      _technicianAssignments.clear();
      if (rawAssignments is List) {
        _technicianAssignments.addAll(List<Map<String, dynamic>>.from(rawAssignments.map((e) => Map<String, dynamic>.from(e))));
      } else if (rawAssignments is String && rawAssignments.trim().startsWith('[')) {
        try {
          final decoded = jsonDecode(rawAssignments) as List;
          _technicianAssignments.addAll(List<Map<String, dynamic>>.from(decoded.map((e) => Map<String, dynamic>.from(e))));
        } catch (_) {}
      }
    });

    if (showSnackBar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded draft for ${_vehicleNumberController.text}'),
            backgroundColor: Colors.green,
          ),
        );
      });
    }
  }

  Future<void> _saveJobCard({bool isDraft = false}) async {
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


    setState(() => _isLoading = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isDraft ? 'Saving as draft...' : 'Creating job card...', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Checking duplicates & saving details...'),
            ],
          ),
        );
      },
    );

    try {
      // ✅ Skip duplicate check entirely when updating an existing draft
      if (widget.draftJob != null) {
        await _executeSaveJobCard(isDraft: isDraft);
        return;
      }

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59).toIso8601String();

      final existingReports = await supabase
          .from('reports')
          .select('id, executive:executive_id(username)')
          .eq('vehicle_id', _currentVehicleId!)
          .gte('created_at', startOfDay)
          .lte('created_at', endOfDay);

      if (!mounted) return;
      if (existingReports.isNotEmpty) {
        Navigator.of(context).pop(); // Temporarily hide progress dialog
        
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
        if (!mounted || confirmed != true) {
          setState(() => _isLoading = false);
          return;
        }
        
        // Re-show progress dialog if confirmed
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isDraft ? 'Saving as draft...' : 'Creating job card...', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Uploading images and saving details...'),
                ],
              ),
            );
          },
        );
      }

      await _executeSaveJobCard(isDraft: isDraft);
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        setState(() => _isLoading = false);
      }
      _showErrorSnackBar('Error checking for duplicates: $e');
    }
  }

  Future<void> _executeSaveJobCard({bool isDraft = false}) async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) {
      if (mounted) {
        Navigator.of(context).pop();
        setState(() => _isLoading = false);
      }
      _showErrorSnackBar('You are not logged in.');
      return;
    }

    if (!isDraft) {
      // ✅ Modify Odometer validation and saving logic (2e)
      // Validate required wheel photos
      if (_wheelPhotos.length < 5) {
        if (mounted) {
          Navigator.of(context).pop();
          setState(() => _isLoading = false);
        }

        final missingWheels = _requiredWheels.where((w) => !_wheelPhotos.containsKey(w)).join(', ');
        final takePhotos = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Missing Photos'),
            content: Text('Missing required wheel photos: $missingWheels.\nWould you like to take them now?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Take Photos'),
              ),
            ],
          ),
        );

        if (takePhotos == true) {
          await _startRapidCapture();
          if (_wheelPhotos.length >= 5) {
            _showSuccessSnackBar('Photos added! Please click Create Job Card again.');
          }
        }
        return;
      }
    }

    final odometerFormatError = Validators.validateOdometer(
        _odometerController.text); // Only checks format
    if (odometerFormatError != null) {
      if (mounted) {
        Navigator.of(context).pop();
        setState(() => _isLoading = false);
      }
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
    // Remove duplicate dialog since it's now shown in _saveJobCard

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
        final hasImage = _tyreQRImages[wheel] != null;
        final spec = (_selectedGlobalTyreBrand != null && _selectedGlobalTyreModel != null)
            ? '$_selectedGlobalTyreBrand $_selectedGlobalTyreModel'
            : '';
        if (hasImage) { // Only add if it actually has an image
          tyreDetails[wheel] = {};
          tyreDetails[wheel]!['has_image'] = 'true';
          if (spec.isNotEmpty) tyreDetails[wheel]!['spec'] = spec;
        }
      }
      final String barcodeJson = tyreDetails.isNotEmpty ? jsonEncode(tyreDetails) : '';

      final Map<String, dynamic> marksPayload = {
        ...marksJson.asMap().map((k, v) => MapEntry(k.toString(), v)),
        // Save tyre spec fields so they're restored on draft reopen
        if (_selectedGlobalTyreBrand != null) 'tyre_brand': _selectedGlobalTyreBrand,
        if (_selectedGlobalTyreModel != null) 'tyre_model': _selectedGlobalTyreModel,
        if (_selectedGlobalTyreSize != null) 'tyre_size': _selectedGlobalTyreSize,
        if (_selectedGlobalTyreLiSi != null) 'tyre_li_si': _selectedGlobalTyreLiSi,
      };

      final Map<String, dynamic> insertData = {
        'vehicle_id': _currentVehicleId,
        'executive_id': executiveId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'complaint': jsonEncode(_complaints),
        if (barcodeJson.isNotEmpty) 'barcode': barcodeJson,
        'status': isDraft ? AppConstants.statusDraft : AppConstants.statusWorkInProgress, 
        'started_at': isDraft ? null : (widget.draftJob?['started_at'] ?? DateTime.now().toUtc().toIso8601String()),
        'marks': jsonEncode(marksPayload),
        'odometer_reading': newOdometer,
        'labour_cost': double.tryParse(_laborCostController.text) ?? 0.0,
        'Owner name': _newClientNameController.text.trim(),
        'client_phone': _newClientPhoneController.text.trim(),
        'technician_assignments': _technicianAssignments.isNotEmpty ? jsonEncode(_technicianAssignments) : null,
        'Guid': companyGuid,
        'company_name': companyName,
      };

      // Preserve existing photo_urls from draft (don't wipe them on re-save)
      if (widget.draftJob != null) {
        final existingPhotos = widget.draftJob!['photo_urls'];
        if (existingPhotos != null) {
          insertData['photo_urls'] = existingPhotos;
        }
      } else {
        insertData['photo_urls'] = null;
      }

      // Add booking_id if this job card is created from a direct booking
      if (widget.bookingId != null) {
        insertData['booking_id'] = widget.bookingId!;
      }

      int jobId;
      String? jobCardId;

      if (widget.draftJob != null) {
        jobId = widget.draftJob!['id'] is int
            ? widget.draftJob!['id'] as int
            : int.parse(widget.draftJob!['id'].toString());
        insertData.remove('created_at');
        await supabase.from('reports').update(insertData).eq('id', jobId);
        jobCardId = widget.draftJob!['job_card_id'] as String?;
      } else {
        final inserted = await vehicleService.createReport(context, insertData);
        jobId = inserted['id'] as int;
        jobCardId = inserted['job_card_id'] as String?;
      }

      // Upload media to Supabase Storage asynchronously
      _uploadMediaInBackground(
        jobId: jobId,
        wheelPhotos: Map.from(_wheelPhotos),
        vehiclePhotos: List.from(_vehiclePhotos),
        tyreQRImages: Map.from(_tyreQRImages),
        odometerPhoto: _odometerPhoto,
      );

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

      final String formattedNow = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
      _showSuccessSnackBar(isDraft 
          ? 'Draft saved successfully on $formattedNow!' 
          : (widget.draftJob?['status'] == AppConstants.statusWorkInProgress 
              ? 'Job card updated successfully!' 
              : 'Job card created successfully!${(_wheelPhotos.isNotEmpty || _audioPath != null) ? ' Media saved locally for this job.' : ''}'));

      if (mounted) {
        // ✅ FIX: Pass the integer user ID to refresh
        await Provider.of<ReportProvider>(context, listen: false)
            .refresh(user['id']);
        
        // Show WhatsApp share dialog if tyre details exist (only when creating full job card, not on draft)
        if (!isDraft && tyreDetails.isNotEmpty && widget.draftJob?['status'] != AppConstants.statusWorkInProgress) {
          final String displayJobId = jobCardId?.isNotEmpty == true ? jobCardId! : jobId.toString();
          await _showWhatsAppShareDialog(displayJobId, tyreDetails);
        }

        // If this was opened for editing/draft, pop back after saving
        if (widget.bookingId != null || widget.draftJob != null) {
          Navigator.of(context).pop(true);
          return;
        }
      }
      _resetScreen();
    } catch (error) {
      _showErrorSnackBar('Failed to save Job Card. Error: $error');
    } finally {
      if (mounted) {
        Navigator.of(context).pop(); // Close the progress dialog
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _uploadMediaInBackground({
    required int jobId,
    required Map<String, dynamic> wheelPhotos,
    required List<dynamic> vehiclePhotos,
    required Map<String, dynamic> tyreQRImages,
    required dynamic odometerPhoto,
  }) async {
    List<String> uploadedUrls = [];
    List<Future<String?>> uploadTasks = [];

    for (final entry in wheelPhotos.entries) {
      if (entry.value is String) continue;
      final position = entry.key;
      final photoXFile = entry.value as XFile;
      final fileName = 'job_${jobId}_wheel_${position.replaceAll(" ", "_")}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      uploadTasks.add(photoXFile.readAsBytes().then((bytes) => SupabaseService().uploadJobMedia(bytes, fileName)));
    }
    
    for (int i = 0; i < vehiclePhotos.length; i++) {
      if (vehiclePhotos[i] is String) continue;
      final photoXFile = vehiclePhotos[i] as XFile;
      uploadTasks.add(photoXFile.readAsBytes().then((bytes) => SupabaseService().uploadJobMedia(bytes, 'job_${jobId}_vehicle_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg')));
    }
    
    for (final entry in tyreQRImages.entries) {
      if (entry.value is String) continue;
      final position = entry.key;
      final imageBytes = entry.value as Uint8List;
      uploadTasks.add(SupabaseService().uploadJobMedia(imageBytes, 'job_${jobId}_tyreqr_${position.replaceAll(" ", "_")}_${DateTime.now().millisecondsSinceEpoch}.jpg'));
    }

    if (odometerPhoto != null && odometerPhoto is! String) {
      final photoXFile = odometerPhoto as XFile;
      uploadTasks.add(photoXFile.readAsBytes().then((bytes) => SupabaseService().uploadJobMedia(bytes, 'job_${jobId}_odometer_${DateTime.now().millisecondsSinceEpoch}.jpg')));
    }
    
    final results = await Future.wait(uploadTasks);
    uploadedUrls = results.where((url) => url != null).cast<String>().toList();

    // Update the reports table with the photo_urls (merging with existing draft photos if any)
    if (uploadedUrls.isNotEmpty) {
      List<String> finalUrls = List.from(uploadedUrls);
      final existingPhotos = widget.draftJob?['photo_urls'];
      if (existingPhotos != null) {
        List<String> prevUrls = [];
        if (existingPhotos is String) {
          try { prevUrls = List<String>.from(jsonDecode(existingPhotos)); } catch (_) {}
        } else if (existingPhotos is List) {
          prevUrls = List<String>.from(existingPhotos.map((e) => e.toString()));
        }
        for (final u in prevUrls) {
          if (!finalUrls.contains(u)) finalUrls.add(u);
        }
      }
      await supabase.from('reports').update({
        'photo_urls': finalUrls
      }).eq('id', jobId);
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
    final odo = _newOdometerController.text.trim().isNotEmpty ? _newOdometerController.text.trim() : _odometerController.text.trim();

    try {
      final pdf = pw.Document();

      for (final entry in tyreDetails.entries) {
        final position = entry.key;
        final details = entry.value;
        final hasImage = details['has_image'] == 'true';
        final spec = details['spec'] ?? '';

        // Only add a PDF page if a QR image was actually captured for this wheel
        if (!hasImage || _tyreQRImages[position] == null) continue;

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
                  if (vehicleNo.isNotEmpty && vehicleNo != 'Courier Package' && vehicleNo != 'N/A') ...[
                    pw.Text('Vehicle: $vehicleNo', style: const pw.TextStyle(fontSize: 16)),
                    if (vehicleBrand.isNotEmpty || vehicleModel.isNotEmpty)
                      pw.Text('Model: $vehicleBrand $vehicleModel', style: const pw.TextStyle(fontSize: 16)),
                    if (odo.isNotEmpty && odo != 'N/A')
                      pw.Text('Odometer Reading: $odo km', style: const pw.TextStyle(fontSize: 16)),
                  ],
                  pw.Text('Client: $clientName ($clientPhone)', style: const pw.TextStyle(fontSize: 16)),
                  if (_courierAddressController.text.trim().isNotEmpty)
                    pw.Text('Address: ${_courierAddressController.text.trim()}', style: const pw.TextStyle(fontSize: 16)),
                  pw.SizedBox(height: 20),
                  if (spec.isNotEmpty) pw.Text('Spec: $spec', style: const pw.TextStyle(fontSize: 16)),
                  pw.SizedBox(height: 10),
                  if (hasImage && _tyreQRImages[position] != null)
                    pw.Expanded(
                      child: pw.Center(
                        child: pw.Image(
                          pw.MemoryImage(_tyreQRImages[position]!),
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
      
      // Save PDF to temp directory
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/job_${jobIdStr}_warranty_qrs.pdf');
      await file.writeAsBytes(bytes);

      // Share PDF
      final String message = 'Warranty details for Job Card $jobIdStr (Vehicle: $vehicleNo)';
      await Share.shareFiles(
        [file.path],
        text: message,
        subject: 'Warranty details for Job Card $jobIdStr',
      );
    } catch (e) {
      _showErrorSnackBar('Error generating or sharing PDF: $e');
    }
  }

  Future<String?> _showSearchableDropdown(String title, List<String> items) async {
    String searchQuery = '';
    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredItems = items
                .where((item) => item.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(filteredItems[index]),
                            onTap: () => Navigator.pop(context, filteredItems[index]),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- UI & MEDIA HELPERS ---

  void _showServiceCatalogModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ServiceCatalogPicker(
        serviceCatalog: _serviceCatalog,
        onServiceSelected: (String serviceName, double? defaultPrice) {
          _complaintInputController.text = serviceName;
          _addComplaint();
        },
      ),
    );
  }

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

  void _addTyreComplaint() {
    if (_selectedGlobalTyreBrand == null || _selectedGlobalTyreModel == null) {
      _showErrorSnackBar('Please select Tyre Brand and Model first.');
      return;
    }
    final sizeStr = _selectedGlobalTyreSize != null ? ' $_selectedGlobalTyreSize' : '';
    final liSiStr = _selectedGlobalTyreLiSi != null ? ' $_selectedGlobalTyreLiSi' : '';
    final complaintText = 'Tyre - $_selectedGlobalTyreBrand $_selectedGlobalTyreModel$sizeStr$liSiStr';

    double unitPrice = double.tryParse(_tyrePriceController.text) ?? 0.0;
    int count = int.tryParse(_tyreCountController.text) ?? 1;
    if (count < 1) count = 1;
    double totalPrice = double.tryParse(_tyreTotalController.text) ?? (unitPrice * count);

    setState(() {
      _complaints.add({
        'text': complaintText,
        'amount': totalPrice,
        'unit_price': unitPrice,
        'count': count,
        'type': AppConstants.typeComplaint
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "$complaintText" ($count × ₹${unitPrice.toStringAsFixed(2)})'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  void _deleteComplaint(int index) {
    setState(() => _complaints.removeAt(index));
  }

  void _editComplaintAmount(int index) {
    final TextEditingController editAmountController = TextEditingController(
      text: (_complaints[index]['amount'] ?? '').toString()
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Amount'),
        content: TextField(
          controller: editAmountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount (₹)',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                final double? parsed = double.tryParse(editAmountController.text);
                _complaints[index]['amount'] = parsed ?? 0.0;
                // Update unit_price if count exists
                if (_complaints[index]['count'] != null && _complaints[index]['count'] > 0) {
                  _complaints[index]['unit_price'] = (parsed ?? 0.0) / _complaints[index]['count'];
                }
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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

  Widget _buildPhotoSlot(String label, dynamic photo, VoidCallback onTap, VoidCallback onRemove) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              InkWell(
                onTap: onTap,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: photo == null
                    ? const Icon(Icons.add_a_photo, color: Colors.grey, size: 30)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: photo is String ? Image.network(photo, fit: BoxFit.cover) : Image.file(File(photo.path), fit: BoxFit.cover),
                      ),
              ),
            ),
            if (photo != null)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _pickWheelPhoto(String position) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiWheelCameraScreen(targets: [position]),
      ),
    );

    if (result != null && result is Map<String, XFile> && result.containsKey(position)) {
      setState(() => _wheelPhotos[position] = result[position]!);
    }
  }

  void _removeWheelPhoto(String position) {
    setState(() => _wheelPhotos.remove(position));
  }

  Future<void> _pickVehiclePhoto() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ContinuousCameraScreen(),
      ),
    );

    if (result != null && result is List<String>) {
      setState(() {
        for (String path in result) {
          _vehiclePhotos.add(XFile(path));
        }
      });
    }
  }
  
  void _removeVehiclePhoto(int index) {
    setState(() => _vehiclePhotos.removeAt(index));
  }

  Future<void> _captureOdometerPhoto() async {
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
  }

  List<Widget> _buildDynamicTechnicianAssignments() {
    // Group technicians by role
    final Map<String, List<Map<String, dynamic>>> techsByRole = {};
    for (var tech in _allTechnicians) {
      final role = tech['role']?.toString() ?? 'Unassigned';
      techsByRole.putIfAbsent(role, () => []).add(tech);
    }

    List<Widget> widgets = [];
    techsByRole.forEach((role, techs) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role.toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              ...techs.map((tech) {
                final isSelected = _technicianAssignments.any((a) => a['tech_id'] == tech['id']);
                return CheckboxListTile(
                  title: Text(tech['username'] ?? 'Unknown', style: const TextStyle(fontSize: 14)),
                  value: isSelected,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (bool? checked) {
                    setState(() {
                      if (checked == true) {
                        _technicianAssignments.add({'role': role, 'tech_id': tech['id']});
                      } else {
                        _technicianAssignments.removeWhere((a) => a['tech_id'] == tech['id']);
                      }
                    });
                  },
                );
              }).toList(),
            ],
          ),
        ),
      );
    });

    if (widgets.isEmpty) {
      return [const Padding(padding: EdgeInsets.only(bottom: 16), child: Text('No technicians available.'))];
    }
    return widgets;
  }

  Future<void> _scanTyreQR(String wheel) async {
    try {
        final picker = ImagePicker();
        final XFile? photo = await picker.pickImage(source: ImageSource.camera);
        if (photo != null) {
          final bytes = await photo.readAsBytes();
          setState(() {
            _tyreQRImages[wheel] = bytes;
          });
        }
    } catch (e) {
      _showErrorSnackBar('Failed to capture QR photo for $wheel: $e');
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
              if (_tyreQRImages[wheel] != null)
                _tyreQRImages[wheel] is String ? Image.network(
                  _tyreQRImages[wheel],
                  height: 80,
                  width: 80,
                  fit: BoxFit.cover,
                ) : Image.memory(
                  _tyreQRImages[wheel] as Uint8List,
                  height: 80,
                  width: 80,
                  fit: BoxFit.cover,
                )
              else
                ElevatedButton.icon(
                  onPressed: () => _scanTyreQR(wheel),
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Capture QR'),
                ),
            ],
          ),
          const SizedBox(height: 8),
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
    String displayMessage = message;
    final lower = message.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('connection abort') ||
        lower.contains('failed host lookup') ||
        lower.contains('network_error') ||
        lower.contains('timeoutexception') ||
        lower.contains('failed to connect')) {
      displayMessage = '📶 No internet connection. Please check your network and try again.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                displayMessage,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        duration: const Duration(seconds: 4),
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
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          children: [
            const Text(
              'Job Card',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            if (CompanyService().companyName != null && CompanyService().companyName!.isNotEmpty)
              Text(
                CompanyService().companyName!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.primaryColor),
            tooltip: 'Options',
            onSelected: (value) {
              if (value == 'drafts') {
                _openFullPageRegistrationDrafts();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'drafts',
                child: Row(
                  children: [
                    Icon(Icons.drafts_outlined, color: Colors.purple, size: 20),
                    SizedBox(width: 10),
                    Text('Saved Registration Drafts', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          controller: _mainScrollController,
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildModeToggle(),
              const SizedBox(height: 16),
              
              if (!_isCourierMode) ...[
                // ✅ Hide search bar and vehicle creation form when editing a vehicle draft
                // (vehicle already exists — skip straight to complaint section)
                if (!_isVehicleJobCardDraft) _buildSearchCard(),

                if (_isLoading &&
                    _vehicleDetails == null &&
                    !_showCreateVehicleForm)
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),

                if (_vehicleDetails != null)
                  _buildVehicleDetailsCard(_vehicleDetails!),
                // ✅ Only show vehicle creation form when NOT editing a vehicle draft
                if (_showCreateVehicleForm && !_isVehicleJobCardDraft)
                  _buildCreateVehicleForm(),
                if (_vehicleDetails != null || _isVehicleJobCardDraft)
                  _buildNewComplaintCard(),
              ] else ...[
                _buildCourierForm(),
              ],
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
                      child: _odometerPhoto is String ? Image.network(
                        _odometerPhoto,
                        fit: BoxFit.cover,
                      ) : Image.file(
                        File(_odometerPhoto.path),
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
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _saveVehicleRegistrationDraft,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.purple),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save as Draft', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createVehicle,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Vehicle', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                ),
              ),
            ],
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
                            if (_complaints[index]['count'] != null && _complaints[index]['count'] > 1)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Qty: ${_complaints[index]['count']}',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            InkWell(
                              onTap: () => _editComplaintAmount(index),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _complaints[index]['amount'] != null && _complaints[index]['amount'] > 0
                                          ? '₹${_complaints[index]['amount']}'
                                          : 'Add ₹',
                                      style: const TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.edit, size: 12, color: AppTheme.primaryColor),
                                  ],
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
                child: TextField(
                  controller: _complaintInputController,
                  focusNode: _complaintFocusNode,
                  readOnly: true,
                  onTap: _showServiceCatalogModal,
                  decoration: const InputDecoration(
                    hintText: 'Select or add service...',
                    hintStyle: TextStyle(fontSize: 13),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    suffixIcon: Icon(Icons.list_alt, color: AppTheme.primaryColor),
                    border: OutlineInputBorder(),
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
          const FormLabel(text: 'Tyre Specification (Applies to all)'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final brands = _tyreCatalog.map((t) => t['brand'].toString().toUpperCase()).toSet().toList();
                    brands.sort();
                    final selected = await _showSearchableDropdown('Select Brand', brands);
                    if (selected != null) {
                      setState(() {
                        _selectedGlobalTyreBrand = selected;
                        _selectedGlobalTyreModel = null;
                        _selectedGlobalTyreSize = null;
                        _selectedGlobalTyreLiSi = null;
                        _syncTyreComplaint();
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Brand',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(_selectedGlobalTyreBrand ?? 'Select Brand', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: _selectedGlobalTyreBrand == null ? null : () async {
                    final models = _tyreCatalog
                        .where((t) => t['brand'].toString().toUpperCase() == _selectedGlobalTyreBrand)
                        .map((t) => t['model'].toString()).toSet().toList();
                    models.sort();
                    final selected = await _showSearchableDropdown('Select Model/Pattern', models);
                    if (selected != null) {
                      setState(() {
                        _selectedGlobalTyreModel = selected;
                        _selectedGlobalTyreSize = null;
                        _selectedGlobalTyreLiSi = null;
                        _syncTyreComplaint();
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Model/Pattern',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(_selectedGlobalTyreModel ?? 'Select Model', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectedGlobalTyreModel == null ? null : () async {
                    final sizes = _tyreCatalog
                        .where((t) => t['brand'].toString().toUpperCase() == _selectedGlobalTyreBrand && t['model'].toString() == _selectedGlobalTyreModel)
                        .map((t) => t['size'].toString()).toSet().toList();
                    sizes.sort();
                    final selected = await _showSearchableDropdown('Select Size', sizes);
                    if (selected != null) {
                      setState(() {
                        _selectedGlobalTyreSize = selected;
                        _selectedGlobalTyreLiSi = null;
                        
                        // Check if LI/SI can be auto-selected
                        final liSis = _tyreCatalog
                          .where((t) => t['brand'].toString().toUpperCase() == _selectedGlobalTyreBrand && t['model'].toString() == _selectedGlobalTyreModel && t['size'].toString() == selected)
                          .map((t) => t['li_si']?.toString() ?? '')
                          .where((liSi) => liSi.isNotEmpty)
                          .toSet()
                          .toList();
                          
                        if (liSis.length == 1) {
                          _selectedGlobalTyreLiSi = liSis.first;
                          final matchedTyre = _tyreCatalog.firstWhere(
                            (t) => t['brand'].toString().toUpperCase() == _selectedGlobalTyreBrand && t['model'].toString() == _selectedGlobalTyreModel && t['size'].toString() == selected && t['li_si'].toString() == _selectedGlobalTyreLiSi,
                            orElse: () => {},
                          );
                          if (matchedTyre.isNotEmpty && matchedTyre['billing_price'] != null) {
                            _tyrePriceController.text = matchedTyre['billing_price'].toString();
                          }
                        } else {
                          _tyrePriceController.clear();
                        }
                        
                        _syncTyreComplaint();
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Size',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(_selectedGlobalTyreSize ?? 'Select Size', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: _selectedGlobalTyreSize == null ? null : () async {
                    final liSis = _tyreCatalog
                        .where((t) => t['brand'].toString().toUpperCase() == _selectedGlobalTyreBrand && t['model'].toString() == _selectedGlobalTyreModel && t['size'].toString() == _selectedGlobalTyreSize)
                        .map((t) => t['li_si']?.toString() ?? '')
                        .where((liSi) => liSi.isNotEmpty)
                        .toSet().toList();
                    liSis.sort();
                    final selected = await _showSearchableDropdown('Select LI/SI', liSis);
                    if (selected != null) {
                      setState(() {
                        _selectedGlobalTyreLiSi = selected;
                        
                        // Autofill price
                        final matchedTyre = _tyreCatalog.firstWhere(
                          (t) => t['brand'].toString().toUpperCase() == _selectedGlobalTyreBrand && t['model'].toString() == _selectedGlobalTyreModel && t['size'].toString() == _selectedGlobalTyreSize && t['li_si'].toString() == selected,
                          orElse: () => {},
                        );
                        if (matchedTyre.isNotEmpty && matchedTyre['billing_price'] != null) {
                          _tyrePriceController.text = matchedTyre['billing_price'].toString();
                        }
                        
                        _syncTyreComplaint();
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'LI/SI',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(_selectedGlobalTyreLiSi ?? 'Select LI/SI', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tyreCountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Tyre Count',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _syncTyreComplaint(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _tyrePriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price/Tyre',
                    prefixText: '₹',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _syncTyreComplaint(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _tyreTotalController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Total',
                    prefixText: '₹',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.black12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addTyreComplaint,
              icon: const Icon(Icons.add_shopping_cart, size: 20),
              label: const Text('Add Tyre', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const FormLabel(text: 'Tyre QR Photos'),
          const SizedBox(height: 8),
          // Individual tyre rows
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
              return _buildPhotoSlot(wheel, file, () => _pickWheelPhoto(wheel), () => _removeWheelPhoto(wheel));
            }).toList(),
          ),
          const SizedBox(height: 16),
          const FormLabel(text: 'Overall Vehicle Photo (Optional) & Voice Note'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 120, // Match the typical height of an aspect ratio 1 box
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _vehiclePhotos.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _vehiclePhotos.length) {
                        return Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 8),
                          child: _buildPhotoSlot('Add Photo', null, _pickVehiclePhoto, () {}),
                        );
                      }
                      return Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 8),
                        child: _buildPhotoSlot('Vehicle ${index + 1}', _vehiclePhotos[index], () {}, () => _removeVehiclePhoto(index)),
                      );
                    },
                  ),
                ),
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
          const SizedBox(height: 24),

          Row(
            children: [
              if (widget.draftJob?['status'] != AppConstants.statusWorkInProgress) ...[
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => _saveJobCard(isDraft: true),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Save as Draft',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _saveJobCard(isDraft: false),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      widget.draftJob?['status'] == AppConstants.statusWorkInProgress ? 'Save Updates' : 'Create Job Card',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isCourierMode = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: !_isCourierMode ? AppTheme.primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '🚗 Vehicle Service',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: !_isCourierMode ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isCourierMode = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _isCourierMode ? AppTheme.primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '📦 Send Courier',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: _isCourierMode ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourierForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FormLabel(text: 'Customer Details'),
              const SizedBox(height: 12),
              TextField(
                controller: _courierNameController,
                decoration: const InputDecoration(labelText: 'Customer Name', prefixIcon: Icon(Icons.person)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _courierPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _courierAddressController,
                decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.home)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _courierGstController,
                decoration: const InputDecoration(labelText: 'GST Number (Optional)', prefixIcon: Icon(Icons.receipt)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FormLabel(text: 'Package Products'),
              const SizedBox(height: 12),
              
              if (_courierProductsList.isEmpty)
                const EmptyDisplay(
                  message: 'No products added yet.',
                  icon: Icons.inventory_2_outlined,
                  subtitle: 'Add products to continue',
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _courierProductsList.length,
                  itemBuilder: (context, index) {
                    final product = _courierProductsList[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${product['brand'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text('${product['model'] ?? ''}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                    Text('${product['size'] ?? ''}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                    const SizedBox(height: 6),
                                    Text('Qty: ${product['qty']}  |  Unit: ₹${product['price']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Total: ₹${((product['price'] as double) * (product['qty'] as int)).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () => _editCourierProduct(index),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => _deleteCourierProduct(index),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                                  final qrImages = product['qr_images'] as List<dynamic>? ?? [];
                                  final qty = product['qty'] as int;
                                  
                                  if (qrImages.isEmpty) {
                                    return ElevatedButton.icon(
                                      onPressed: () => _scanCourierProductQR(index),
                                      icon: const Icon(Icons.qr_code_scanner, size: 16),
                                      label: const Text('Scan QR / Barcode'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                    );
                                  } else {
                                    return Row(
                                      children: [
                                        Expanded(
                                          child: SizedBox(
                                            height: 40,
                                            child: ListView.builder(
                                              scrollDirection: Axis.horizontal,
                                              itemCount: qrImages.length,
                                              itemBuilder: (context, i) {
                                                return Padding(
                                                  padding: const EdgeInsets.only(right: 8),
                                                  child: GestureDetector(
                                                    onTap: () => _viewCourierQR(index, i),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(4),
                                                      child: qrImages[i] is String ? Image.network(qrImages[i], height: 40, width: 40, fit: BoxFit.cover) : Image.memory(qrImages[i] as Uint8List, height: 40, width: 40, fit: BoxFit.cover),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (qrImages.length < qty)
                                          ElevatedButton.icon(
                                            onPressed: () => _scanCourierProductQR(index),
                                            icon: const Icon(Icons.qr_code_scanner, size: 14),
                                            label: Text('Scan Remaining (${qty - qrImages.length})'),
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              textStyle: const TextStyle(fontSize: 12),
                                            ),
                                          )
                                        else if (qrImages.length > qty)
                                          const Row(
                                            children: [
                                              Icon(Icons.warning, color: Colors.orange, size: 16),
                                              SizedBox(width: 4),
                                              Text('Excess QRs (Delete)', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                                            ],
                                          )
                                        else
                                          const Row(
                                            children: [
                                              Icon(Icons.check_circle, color: Colors.green, size: 16),
                                              SizedBox(width: 4),
                                              Text('All QRs Scanned', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                                            ],
                                          )
                                      ],
                                    );
                                  }
                                },
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
                    child: InkWell(
                      onTap: () async {
                        final brands = _tyreCatalog.map((t) => t['brand'].toString().toUpperCase()).toSet().toList();
                        brands.sort();
                        final selected = await _showSearchableDropdown('Select Brand', brands);
                        if (selected != null) {
                          setState(() {
                            _courierTyreBrand = selected;
                            _courierTyreModel = null;
                            _courierTyreSize = null;
                            _courierProductPriceController.clear();
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Brand', isDense: true, border: OutlineInputBorder()),
                        child: Text(_courierTyreBrand ?? 'Select', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: _courierTyreBrand == null ? null : () async {
                        final models = _tyreCatalog
                            .where((t) => t['brand'].toString().toUpperCase() == _courierTyreBrand)
                            .map((t) => t['model'].toString()).toSet().toList();
                        models.sort();
                        final selected = await _showSearchableDropdown('Select Model', models);
                        if (selected != null) {
                          setState(() {
                            _courierTyreModel = selected;
                            _courierTyreSize = null;
                            _courierProductPriceController.clear();
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Model', isDense: true, border: OutlineInputBorder()),
                        child: Text(_courierTyreModel ?? 'Select', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: _courierTyreModel == null ? null : () async {
                        final sizes = _tyreCatalog
                            .where((t) => t['brand'].toString().toUpperCase() == _courierTyreBrand && t['model'].toString() == _courierTyreModel)
                            .map((t) => t['size'].toString()).toSet().toList();
                        sizes.sort();
                        final selected = await _showSearchableDropdown('Select Size', sizes);
                        if (selected != null) {
                          setState(() {
                            _courierTyreSize = selected;
                            final matchingTyre = _tyreCatalog.firstWhere(
                              (t) => t['brand'].toString().toUpperCase() == _courierTyreBrand && 
                                     t['model'].toString() == _courierTyreModel && 
                                     t['size'].toString() == _courierTyreSize,
                              orElse: () => {},
                            );
                            if (matchingTyre.isNotEmpty && matchingTyre['billing_price'] != null) {
                              _courierProductPriceController.text = matchingTyre['billing_price'].toString();
                            }
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Size', isDense: true, border: OutlineInputBorder()),
                        child: Text(_courierTyreSize ?? 'Select', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _courierProductQtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Qty',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _courierProductPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Unit Price',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_editingCourierProductIndex != null)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _cancelEditCourierProduct,
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel Edit'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _addCourierProduct,
                        icon: const Icon(Icons.check),
                        label: const Text('Update Product'),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addCourierProduct,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Product'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FormLabel(text: 'Additional Package Photos'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _takeCourierPhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Package Photo'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              if (_courierPhotos.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _courierPhotos.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: () => _viewCourierPackagePhoto(i),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _courierPhotos[i] is String ? Image.network(_courierPhotos[i], width: 100, height: 100, fit: BoxFit.cover) : Image.file(File(_courierPhotos[i].path), width: 100, height: 100, fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            right: 0, top: 0,
                            child: IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: () => setState(() => _courierPhotos.removeAt(i)),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : () => _submitCourierReport(status: AppConstants.statusCompleted),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Create Courier Job Card', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _isLoading ? null : () => _submitCourierReport(status: AppConstants.statusDraft),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Save as Draft', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Future<void> _takeCourierPhoto() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UnlimitedCameraScreen(),
      ),
    );

    if (result != null && result is List<XFile>) {
      setState(() {
        _courierPhotos.addAll(result);
      });
    }
  }

  void _viewCourierPackagePhoto(int photoIndex) {
    showDialog(
      context: context,
      builder: (context) {
        final item = _courierPhotos[photoIndex];
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  InteractiveViewer(
                    child: item is String ? Image.network(item, fit: BoxFit.contain) : Image.file(File(item.path), fit: BoxFit.contain),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _courierPhotos.removeAt(photoIndex);
                  });
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.delete),
                label: const Text('Delete Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitCourierReport({required String status}) async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) {
      _showErrorSnackBar('You are not logged in.');
      return;
    }

    if (_courierNameController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter Customer Name.');
      return;
    }
    
    if (_courierProductsList.isEmpty) {
      _showErrorSnackBar('Please add at least one product before submitting.');
      return;
    }
    
    setState(() => _isLoading = true);

    try {
      final List<Map<String, dynamic>> finalProducts = _courierProductsList.map((p) {
        return {
          'brand': p['brand'],
          'model': p['model'],
          'size': p['size'],
          'name': p['name'],
          'price': p['price'],
          'qty': p['qty'],
        };
      }).toList();

      final marksJson = {
        'is_courier': true,
        'products': finalProducts,
        'gst_no': _courierGstController.text.trim(),
        'address': _courierAddressController.text.trim(),
      };

      final int? executiveId = (user['role'] == AppConstants.rolePickupDropoff) ? null : user['id'];
      
      if (!CompanyService().hasActiveCompany) {
        await CompanyService().loadPersistedCompany();
      }
      
      final Map<String, dynamic> insertData = {
        'vehicle_id': null, // Explicitly null for couriers
        'executive_id': executiveId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'complaint': jsonEncode(['Courier Dispatch']),
        'status': status, 
        'started_at': status == AppConstants.statusDraft ? null : DateTime.now().toUtc().toIso8601String(),
        'completed_at': status == AppConstants.statusCompleted ? DateTime.now().toUtc().toIso8601String() : null,
        'marks': jsonEncode(marksJson),
        'labour_cost': 0, // Removed labour_cost calculation for Couriers
        'Owner name': _courierNameController.text.trim(),
        'client_phone': _courierPhoneController.text.trim(),
        'Guid': CompanyService().guid,
        'company_name': CompanyService().companyName,
      };

      int jobId;
      if (widget.draftJob != null) {
        jobId = widget.draftJob!['id'];
        await supabase.from('reports').update(insertData).eq('id', jobId);
      } else {
        final inserted = await vehicleService.createReport(context, insertData);
        jobId = inserted['id'] as int;
      }

      Map<String, dynamic> productQRs = {};
      for (int i = 0; i < _courierProductsList.length; i++) {
        final images = _courierProductsList[i]['qr_images'] as List<dynamic>? ?? [];
        for (int j = 0; j < images.length; j++) {
          productQRs['product_${i}_qr_$j'] = images[j];
        }
      }

      if (_courierPhotos.isNotEmpty || productQRs.isNotEmpty) {
        _uploadMediaInBackground(
          jobId: jobId,
          wheelPhotos: {},
          vehiclePhotos: List.from(_courierPhotos),
          tyreQRImages: productQRs,
          odometerPhoto: null,
        );
      }

      if (mounted) {
        _showSuccessSnackBar(widget.draftJob != null ? 'Courier Job Card updated successfully!' : 'Courier Job Card created successfully!');
        if (widget.draftJob != null) {
          Navigator.pop(context);
        } else {
          _resetScreen(); // Existing reset form function
          
          // Reset courier fields too
          _courierNameController.clear();
          _courierPhoneController.clear();
          _courierAddressController.clear();
          _courierGstController.clear();
          setState(() {
            _courierProductsList.clear();
            _courierPhotos.clear();
            _isCourierMode = false;
          });
        }
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

class SavedRegistrationDraftsScreen extends StatefulWidget {
  final Function(Map<String, dynamic> draft) onSelectDraft;
  const SavedRegistrationDraftsScreen({super.key, required this.onSelectDraft});

  @override
  State<SavedRegistrationDraftsScreen> createState() => _SavedRegistrationDraftsScreenState();
}

class _SavedRegistrationDraftsScreenState extends State<SavedRegistrationDraftsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _drafts = [];

  @override
  void initState() {
    super.initState();
    _fetchDrafts();
  }

  Future<void> _fetchDrafts() async {
    setState(() => _isLoading = true);
    try {
      if (!CompanyService().hasActiveCompany) {
        await CompanyService().loadPersistedCompany();
      }
      final String? companyGuid = CompanyService().guid;

      var query = Supabase.instance.client
          .from('reports')
          .select('*')
          .eq('status', AppConstants.statusDraft);

      if (companyGuid != null && companyGuid.isNotEmpty) {
        query = query.eq('Guid', companyGuid);
      }

      final res = await query.order('created_at', ascending: false);

      final List<Map<String, dynamic>> loaded = [];
      for (var r in (res as List)) {
        final map = Map<String, dynamic>.from(r);
        final marks = map['marks'];
        bool isCourier = false;
        if (marks is String && marks.contains('"is_courier":true')) {
          isCourier = true;
        } else if (marks is Map && marks['is_courier'] == true) {
          isCourier = true;
        }
        if (!isCourier) {
          loaded.add(map);
        }
      }

      if (mounted) {
        setState(() {
          _drafts = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('🔴 Error fetching drafts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteDraft(Map<String, dynamic> draft) async {
    final dynamic rawId = draft['id'];
    final int? id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Draft'),
        content: const Text('Are you sure you want to delete this draft registration?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        try {
          await Supabase.instance.client.from('reports').delete().eq('id', id);
        } catch (e) {
          debugPrint('⚠️ Hard delete failed: $e');
        }

        // Soft delete / cancel status to guarantee removal from Drafts
        await Supabase.instance.client.from('reports').update({
          'status': AppConstants.statusCancelled,
        }).eq('id', id);

        if (mounted) {
          setState(() {
            _drafts.removeWhere((item) {
              final itemRawId = item['id'];
              final itemId = itemRawId is int ? itemRawId : int.tryParse(itemRawId?.toString() ?? '');
              return itemId == id;
            });
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Draft deleted successfully'), backgroundColor: Colors.red),
          );
        }
        await _fetchDrafts();
      } catch (e) {
        debugPrint('🔴 Error deleting draft: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete draft: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Saved Registration Drafts',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _drafts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.drafts_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text(
                        'No saved registration drafts found',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _drafts.length,
                      itemBuilder: (context, index) {
                        final draft = _drafts[index];
                        Map<String, dynamic> marksMap = {};
                        final marks = draft['marks'];
                        if (marks is String) {
                          try { marksMap = jsonDecode(marks); } catch (_) {}
                        } else if (marks is Map) {
                          marksMap = Map<String, dynamic>.from(marks);
                        }

                        final vehicleNo = marksMap['vehicle_number'] ?? draft['Vehicle Number'] ?? draft['vehicles']?['Vehicle Number'] ?? 'Vehicle Registration';
                        final clientName = draft['Owner name'] ?? 'N/A';
                        final phone = draft['client_phone'] ?? 'N/A';
                        final dateStr = draft['created_at'] != null
                            ? DateFormat('dd MMM yyyy, hh:mm a').format(AppDateUtils.parseUtcToLocal(draft['created_at']))
                            : '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple.shade50,
                          child: const Icon(Icons.directions_car, color: Colors.purple),
                        ),
                        title: Text(
                          vehicleNo,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Client: $clientName ($phone)\nSaved: $dateStr',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteDraft(draft),
                              tooltip: 'Delete Draft',
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                          ],
                        ),
                        onTap: () {
                          widget.onSelectDraft(draft);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
