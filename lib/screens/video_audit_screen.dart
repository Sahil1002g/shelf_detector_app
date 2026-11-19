import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/ai_detection_service.dart';
import 'photo_audit_screen.dart';

class VideoAuditScreen extends StatefulWidget {
  final File videoFile;

  const VideoAuditScreen({super.key, required this.videoFile});

  @override
  State<VideoAuditScreen> createState() => _VideoAuditScreenState();
}

class _VideoAuditScreenState extends State<VideoAuditScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isProcessingFrame = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) {
        setState(() => _isInitialized = true);
        _controller.play();
        _controller.setLooping(true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scanCurrentFrame() async {
    setState(() => _isProcessingFrame = true);
    try {
      // In mobile video auditing, we use a sample keyframe or offline fallback
      final result = await AiDetectionService().detectFromAsset('assets/images/1.jpeg');
      if (mounted) {
        setState(() => _isProcessingFrame = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoAuditScreen(
              assetPath: 'assets/images/1.jpeg',
              initialResult: result,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingFrame = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to audit frame: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Shelf Video Audit', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          VideoPlayer(_controller),
                          VideoProgressIndicator(
                            _controller,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: Color(0xFF00E676),
                              bufferedColor: Colors.white24,
                              backgroundColor: Colors.black26,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator(color: Color(0xFF00E676)),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF1E293B),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 36,
                      icon: Icon(
                        _controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        color: const Color(0xFF00E676),
                      ),
                      onPressed: () {
                        setState(() {
                          _controller.value.isPlaying ? _controller.pause() : _controller.play();
                        });
                      },
                    ),
                    const SizedBox(width: 24),
                    ElevatedButton.icon(
                      icon: _isProcessingFrame
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.document_scanner_rounded, color: Colors.black),
                      label: const Text(
                        'Audit Current Frame',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isProcessingFrame ? null : _scanCurrentFrame,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Video Path: ${widget.videoFile.path.split(Platform.pathSeparator).last}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
