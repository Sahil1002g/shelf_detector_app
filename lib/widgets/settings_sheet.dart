import 'package:flutter/material.dart';
import '../services/ai_detection_service.dart';

class SettingsSheet extends StatefulWidget {
  final double shelfConf;
  final double productConf;
  final int scanIntervalMs;
  final bool showShelves;
  final bool showProducts;
  final bool showEmptySpaces;
  final bool showLabels;
  final Function({
    required double shelfConf,
    required double productConf,
    required int scanIntervalMs,
    required bool showShelves,
    required bool showProducts,
    required bool showEmptySpaces,
    required bool showLabels,
  }) onSettingsChanged;

  const SettingsSheet({
    super.key,
    required this.shelfConf,
    required this.productConf,
    required this.scanIntervalMs,
    required this.showShelves,
    required this.showProducts,
    required this.showEmptySpaces,
    required this.showLabels,
    required this.onSettingsChanged,
  });

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late TextEditingController _urlController;
  late double _shelfConf;
  late double _productConf;
  late int _scanIntervalMs;
  late bool _showShelves;
  late bool _showProducts;
  late bool _showEmptySpaces;
  late bool _showLabels;

  bool _isTesting = false;
  String? _testMessage;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: AiDetectionService().serverUrl);
    _shelfConf = widget.shelfConf;
    _productConf = widget.productConf;
    _scanIntervalMs = widget.scanIntervalMs;
    _showShelves = widget.showShelves;
    _showProducts = widget.showProducts;
    _showEmptySpaces = widget.showEmptySpaces;
    _showLabels = widget.showLabels;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _applyChanges() {
    AiDetectionService().serverUrl = _urlController.text.trim();
    widget.onSettingsChanged(
      shelfConf: _shelfConf,
      productConf: _productConf,
      scanIntervalMs: _scanIntervalMs,
      showShelves: _showShelves,
      showProducts: _showProducts,
      showEmptySpaces: _showEmptySpaces,
      showLabels: _showLabels,
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testMessage = null;
    });

    AiDetectionService().serverUrl = _urlController.text.trim();
    final ok = await AiDetectionService().checkHealth();

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testSuccess = ok;
        _testMessage = ok
            ? 'Connected successfully to AI models!'
            : 'Connection failed: ${AiDetectionService().lastError ?? "Unreachable"}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: Color(0xFF00E676), size: 24),
                const SizedBox(width: 10),
                const Text(
                  'Detection & Vision Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () {
                    _applyChanges();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 24),

            // Server URL
            const Text(
              'AI Backend Server URL',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'http://10.0.2.2:8000',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.black26,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isTesting ? null : _testConnection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('Test', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            if (_testMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                _testMessage!,
                style: TextStyle(
                  color: _testSuccess == true ? const Color(0xFF00E676) : Colors.redAccent,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 18),

            // Shelf Confidence
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Shelf Confidence Threshold', style: TextStyle(color: Colors.white)),
                Text('${(_shelfConf * 100).toInt()}%',
                    style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: _shelfConf,
              min: 0.10,
              max: 0.90,
              divisions: 16,
              activeColor: const Color(0xFF00E676),
              inactiveColor: Colors.white12,
              onChanged: (val) {
                setState(() => _shelfConf = val);
                _applyChanges();
              },
            ),

            // Product Confidence
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Product Confidence Threshold', style: TextStyle(color: Colors.white)),
                Text('${(_productConf * 100).toInt()}%',
                    style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: _productConf,
              min: 0.10,
              max: 0.90,
              divisions: 16,
              activeColor: const Color(0xFF00E5FF),
              inactiveColor: Colors.white12,
              onChanged: (val) {
                setState(() => _productConf = val);
                _applyChanges();
              },
            ),

            // Scan Interval
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Live Stream Scan Interval', style: TextStyle(color: Colors.white)),
                Text('$_scanIntervalMs ms',
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: _scanIntervalMs.toDouble(),
              min: 250,
              max: 2000,
              divisions: 7,
              activeColor: Colors.amber,
              inactiveColor: Colors.white12,
              onChanged: (val) {
                setState(() => _scanIntervalMs = val.toInt());
                _applyChanges();
              },
            ),
            const Divider(color: Colors.white12, height: 20),

            // Visibility Toggles
            SwitchListTile(
              title: const Text('Show Shelf Rows Layer', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('Green bounding boxes identifying shelf rows',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              value: _showShelves,
              activeColor: const Color(0xFF00E676),
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() => _showShelves = val);
                _applyChanges();
              },
            ),
            SwitchListTile(
              title: const Text('Show Products Layer', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('Cyan boxes for detected products',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              value: _showProducts,
              activeColor: const Color(0xFF00E5FF),
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() => _showProducts = val);
                _applyChanges();
              },
            ),
            SwitchListTile(
              title: const Text('Show Out-of-Stock / Empty Slots',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('Red warning boxes on empty shelf areas',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              value: _showEmptySpaces,
              activeColor: const Color(0xFFFF1744),
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() => _showEmptySpaces = val);
                _applyChanges();
              },
            ),
            SwitchListTile(
              title: const Text('Show Confidence Badges', style: TextStyle(color: Colors.white, fontSize: 14)),
              value: _showLabels,
              activeColor: Colors.white,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() => _showLabels = val);
                _applyChanges();
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _applyChanges();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save & Apply', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
