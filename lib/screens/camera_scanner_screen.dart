import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/detection_models.dart';
import '../services/ai_detection_service.dart';
import '../widgets/bounding_box_overlay.dart';
import '../widgets/metrics_hud_bar.dart';
import '../widgets/settings_sheet.dart';
import 'photo_audit_screen.dart';
import 'video_audit_screen.dart';
import 'sample_gallery_screen.dart';

class CameraScannerScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScannerScreen({super.key, required this.cameras});

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  FlashMode _currentFlashMode = FlashMode.off;

  // Real-time Detection Stream State
  bool _isRealTimeActive = true;
  bool _isProcessingFrame = false;
  Timer? _liveScanTimer;
  int _scanIntervalMs = 600;

  // Active Detection Results
  DetectionResult? _currentResult;

  // Video Recording State
  bool _isRecordingVideo = false;
  int _videoDurationSeconds = 0;
  Timer? _videoTimer;

  // Settings & Thresholds
  double _shelfConf = 0.25;
  double _productConf = 0.25;
  bool _showShelves = true;
  bool _showProducts = true;
  bool _showEmptySpaces = true;
  bool _showLabels = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _checkServer();
  }

  Future<void> _checkServer() async {
    final ok = await AiDetectionService().checkHealth();
    if (!ok && mounted) {
      debugPrint('AI Server not detected yet; will use resilient fallback if offline.');
    }
  }

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty) {
      debugPrint('No cameras available on this device');
      return;
    }

    final camera = widget.cameras[_selectedCameraIndex];
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _cameraController = controller;

    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });

      // Start periodic real-time scanner
      _startLiveScanLoop();
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _stopLiveScanLoop();
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLiveScanLoop();
    _stopVideoTimer();
    _cameraController?.dispose();
    super.dispose();
  }

  void _startLiveScanLoop() {
    _stopLiveScanLoop();
    if (!_isRealTimeActive) return;

    _liveScanTimer = Timer.periodic(Duration(milliseconds: _scanIntervalMs), (_) {
      _processLiveFrame();
    });
  }

  void _stopLiveScanLoop() {
    _liveScanTimer?.cancel();
    _liveScanTimer = null;
  }

  /// Process live frame non-blockingly so camera preview stays buttery smooth
  Future<void> _processLiveFrame() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (_isProcessingFrame || _isRecordingVideo) return;

    _isProcessingFrame = true;
    try {
      final XFile photo = await controller.takePicture();
      final Uint8List bytes = await photo.readAsBytes();

      // Clean up temp photo
      try {
        await File(photo.path).delete();
      } catch (_) {}

      final result = await AiDetectionService().detectFromBytes(
        bytes,
        shelfConf: _shelfConf,
        productConf: _productConf,
      );

      if (mounted) {
        setState(() {
          _currentResult = result;
          _isProcessingFrame = false;
        });
      }
    } catch (e) {
      _isProcessingFrame = false;
      // In case takePicture isn't supported while recording or emulator virtual scene
    }
  }

  Future<void> _toggleCamera() async {
    if (widget.cameras.length < 2) return;
    setState(() {
      _isCameraInitialized = false;
      _selectedCameraIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
    });
    _stopLiveScanLoop();
    await _cameraController?.dispose();
    _initCamera();
  }

  Future<void> _cycleFlash() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    FlashMode nextMode;
    switch (_currentFlashMode) {
      case FlashMode.off:
        nextMode = FlashMode.torch;
        break;
      case FlashMode.torch:
        nextMode = FlashMode.auto;
        break;
      default:
        nextMode = FlashMode.off;
        break;
    }

    try {
      await controller.setFlashMode(nextMode);
      setState(() => _currentFlashMode = nextMode);
    } catch (e) {
      debugPrint('Flash mode error: $e');
    }
  }

  /// Capture High-Resolution Image & Process Audit
  Future<void> _capturePhotoAndAudit() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    _stopLiveScanLoop();

    try {
      final XFile photo = await controller.takePicture();
      final file = File(photo.path);

      // Run deep audit
      final result = await AiDetectionService().detectFromFile(
        file,
        shelfConf: _shelfConf,
        productConf: _productConf,
      );

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoAuditScreen(
            imageFile: file,
            initialResult: result,
          ),
        ),
      );

      // Resume live scan when coming back
      if (_isRealTimeActive) {
        _startLiveScanLoop();
      }
    } catch (e) {
      debugPrint('Photo capture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture photo: $e')),
        );
      }
      if (_isRealTimeActive) _startLiveScanLoop();
    }
  }

  /// Start / Stop Video Recording
  Future<void> _toggleVideoRecording() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (_isRecordingVideo) {
      // Stop recording
      _stopVideoTimer();
      try {
        final XFile video = await controller.stopVideoRecording();
        setState(() => _isRecordingVideo = false);

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoAuditScreen(videoFile: File(video.path)),
          ),
        );
      } catch (e) {
        debugPrint('Error stopping video recording: $e');
        setState(() => _isRecordingVideo = false);
      }
      if (_isRealTimeActive) _startLiveScanLoop();
    } else {
      // Start recording
      _stopLiveScanLoop();
      try {
        await controller.startVideoRecording();
        setState(() {
          _isRecordingVideo = true;
          _videoDurationSeconds = 0;
        });
        _videoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() => _videoDurationSeconds++);
          }
        });
      } catch (e) {
        debugPrint('Error starting video recording: $e');
      }
    }
  }

  void _stopVideoTimer() {
    _videoTimer?.cancel();
    _videoTimer = null;
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SettingsSheet(
        shelfConf: _shelfConf,
        productConf: _productConf,
        scanIntervalMs: _scanIntervalMs,
        showShelves: _showShelves,
        showProducts: _showProducts,
        showEmptySpaces: _showEmptySpaces,
        showLabels: _showLabels,
        onSettingsChanged: ({
          required double shelfConf,
          required double productConf,
          required int scanIntervalMs,
          required bool showShelves,
          required bool showProducts,
          required bool showEmptySpaces,
          required bool showLabels,
        }) {
          setState(() {
            _shelfConf = shelfConf;
            _productConf = productConf;
            _scanIntervalMs = scanIntervalMs;
            _showShelves = showShelves;
            _showProducts = showProducts;
            _showEmptySpaces = showEmptySpaces;
            _showLabels = showLabels;
          });
          if (_isRealTimeActive) {
            _startLiveScanLoop();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview
          if (_isCameraInitialized && controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: 1 / controller.value.aspectRatio,
                child: CameraPreview(controller),
              ),
            )
          else
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00E676)),
                  SizedBox(height: 16),
                  Text(
                    'Initializing Smart Camera...',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ],
              ),
            ),

          // 2. Real-Time Shelf & Product Bounding Boxes
          if (_isCameraInitialized && controller != null && _currentResult != null)
            Center(
              child: AspectRatio(
                aspectRatio: 1 / controller.value.aspectRatio,
                child: BoundingBoxOverlay(
                  result: _currentResult,
                  previewSize: controller.value.previewSize ?? const Size(640, 480),
                  showShelves: _showShelves,
                  showProducts: _showProducts,
                  showEmptySpaces: _showEmptySpaces,
                  showLabels: _showLabels,
                ),
              ),
            ),

          // 3. Top Status HUD & Metrics Bar
          SafeArea(
            child: Column(
              children: [
                _buildTopNavigationBar(),
                MetricsHudBar(
                  metrics: _currentResult?.metrics,
                  isLiveActive: _isRealTimeActive,
                  isProcessing: _isProcessingFrame,
                ),
                if (_isRecordingVideo) _buildRecordingIndicator(),
              ],
            ),
          ),

          // 4. Bottom Camera Controls & Mode Toolbar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: _buildBottomControls(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavigationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // App Logo / Title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xCC1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00E676).withOpacity(0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storefront_rounded, color: Color(0xFF00E676), size: 18),
                SizedBox(width: 6),
                Text(
                  'ShelfVision AI',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
          const Spacer(),

          // Benchmark / Test Images shortcut
          IconButton(
            icon: const Icon(Icons.psychology_rounded, color: Color(0xFF00E5FF)),
            tooltip: 'Benchmark Test Images',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SampleGalleryScreen()),
              );
            },
          ),

          // Flash button
          IconButton(
            icon: Icon(
              _currentFlashMode == FlashMode.torch
                  ? Icons.flash_on_rounded
                  : (_currentFlashMode == FlashMode.auto ? Icons.flash_auto_rounded : Icons.flash_off_rounded),
              color: _currentFlashMode != FlashMode.off ? Colors.amber : Colors.white,
            ),
            onPressed: _cycleFlash,
          ),

          // Camera Flip
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
            onPressed: _toggleCamera,
          ),

          // Settings
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            onPressed: _openSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    final minutes = (_videoDurationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_videoDurationSeconds % 60).toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text(
            'REC $minutes:$seconds',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.9),
            Colors.black.withOpacity(0.0),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Live toggle switch pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xCC1E293B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Live Auto-Scan', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(width: 8),
                Switch(
                  value: _isRealTimeActive,
                  activeColor: const Color(0xFF00E676),
                  onChanged: (val) {
                    setState(() => _isRealTimeActive = val);
                    if (val) {
                      _startLiveScanLoop();
                    } else {
                      _stopLiveScanLoop();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Main Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Test Images button
              _buildCircularActionButton(
                icon: Icons.photo_library_rounded,
                tooltip: 'Test Images Gallery',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SampleGalleryScreen()),
                  );
                },
              ),

              // Capture Photo & Audit Button (Center)
              GestureDetector(
                onTap: _isRecordingVideo ? null : _capturePhotoAndAudit,
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: Colors.transparent,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF00E676),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.black, size: 36),
                  ),
                ),
              ),

              // Video Record Button
              _buildCircularActionButton(
                icon: _isRecordingVideo ? Icons.stop_rounded : Icons.videocam_rounded,
                tooltip: _isRecordingVideo ? 'Stop Recording' : 'Record Shelf Video',
                color: _isRecordingVideo ? Colors.redAccent : Colors.white,
                backgroundColor: _isRecordingVideo ? Colors.red.withOpacity(0.3) : const Color(0x991E293B),
                onPressed: _toggleVideoRecording,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircularActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color color = Colors.white,
    Color backgroundColor = const Color(0x991E293B),
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 24),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
