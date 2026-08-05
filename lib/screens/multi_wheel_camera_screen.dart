import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class MultiWheelCameraScreen extends StatefulWidget {
  final List<String> targets;

  const MultiWheelCameraScreen({
    super.key,
    required this.targets,
  });

  @override
  State<MultiWheelCameraScreen> createState() => _MultiWheelCameraScreenState();
}

class _MultiWheelCameraScreenState extends State<MultiWheelCameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _currentTargetIndex = 0;
  final Map<String, XFile> _capturedPhotos = {};
  bool _isInitializing = true;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        // Use the first back camera
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

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile photo = await _controller!.takePicture();
      final currentTarget = widget.targets[_currentTargetIndex];
      _capturedPhotos[currentTarget] = photo;

      if (_currentTargetIndex < widget.targets.length - 1) {
        // Move to next target
        setState(() {
          _currentTargetIndex++;
          _isCapturing = false;
        });
      } else {
        // We are done! Return the map of captured photos
        if (mounted) {
          Navigator.pop(context, _capturedPhotos);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture photo: $e')),
        );
      }
      setState(() {
        _isCapturing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(
          child: Text('Camera not available', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final currentTarget = widget.targets[_currentTargetIndex];
    final progressText = '${_currentTargetIndex + 1} of ${widget.targets.length}';

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _capturedPhotos);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
        children: [
          // Camera Preview
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),
          
          // Header / Target Indicator
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 30),
                      onPressed: () => Navigator.pop(context, _capturedPhotos), // Return whatever was captured so far
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        progressText,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 48), // Balance for back button
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    'Capture: $currentTarget',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Capture Button
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _takePicture,
                child: Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: _isCapturing ? Colors.grey : Colors.white.withOpacity(0.5),
                  ),
                  child: Center(
                    child: Container(
                      height: 60,
                      width: 60,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
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
}
