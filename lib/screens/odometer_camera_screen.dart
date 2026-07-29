import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../theme/app_theme.dart';

class OdometerCameraScreen extends StatefulWidget {
  const OdometerCameraScreen({super.key});

  @override
  State<OdometerCameraScreen> createState() => _OdometerCameraScreenState();
}

class _OdometerCameraScreenState extends State<OdometerCameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitializing = true;
  bool _isCapturing = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        final backCamera = _cameras!.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras!.first,
        );
        
        _controller = CameraController(
          backCamera,
          ResolutionPreset.high,
          enableAudio: false,
        );
        
        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize camera: $e')),
        );
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePictureAndScan() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing || _isProcessing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile photo = await _controller!.takePicture();
      
      setState(() {
        _isCapturing = false;
        _isProcessing = true;
      });

      // Process image with Google ML Kit
      final inputImage = InputImage.fromFilePath(photo.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      // Extract numbers
      String extractedNumber = _extractBestNumber(recognizedText.text);

      if (mounted) {
        Navigator.pop(context, {
          'photo': photo,
          'reading': extractedNumber,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process image: $e')),
        );
        setState(() {
          _isCapturing = false;
          _isProcessing = false;
        });
      }
    }
  }

  String _extractBestNumber(String rawText) {
    // 1. Clean the text, keeping only letters, numbers, and basic punctuation
    String cleanText = rawText.replaceAll(RegExp(r'[^\w\s\.,]'), ' ');
    
    // 2. Split into distinct tokens
    List<String> tokens = cleanText.split(RegExp(r'[\s\n]+'));
    
    String bestMatch = '';
    int maxDigits = 0;

    for (String token in tokens) {
      // Strip commas from numbers like 45,000
      String noCommas = token.replaceAll(',', '');
      
      // If it perfectly matches a 3 to 7 digit number
      if (RegExp(r'^\d{3,7}$').hasMatch(noCommas)) {
        if (noCommas.length >= maxDigits) {
          maxDigits = noCommas.length;
          bestMatch = noCommas;
        }
      }
    }

    // Fallback if no perfect match: just find the longest digit sequence up to 7 digits
    if (bestMatch.isEmpty) {
      final RegExp regExp = RegExp(r'\d+');
      final Iterable<Match> matches = regExp.allMatches(rawText.replaceAll(',', ''));
      for (final Match m in matches) {
        String numStr = m.group(0) ?? '';
        if (numStr.length >= maxDigits && numStr.length <= 7) {
          maxDigits = numStr.length;
          bestMatch = numStr;
        }
      }
    }

    return bestMatch;
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Camera Error')),
        body: const Center(child: Text('Camera could not be initialized.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          Center(
            child: CameraPreview(_controller!),
          ),

          // Overlay Guideline (Rectangle)
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Align Odometer Here',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
              ),
            ),
          ),

          // Top Bar
          Positioned(
            top: 50,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Bottom Bar
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isProcessing)
                  const Column(
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Scanning Odometer...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  )
                else
                  GestureDetector(
                    onTap: _takePictureAndScan,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: _isCapturing ? Colors.white54 : Colors.transparent,
                      ),
                      child: Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
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
    );
  }
}
